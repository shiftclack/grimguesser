local assert = require("luassert")
describe("Database retention", function()
    local LogicTestContext = require("tests.support_logic_test_context")
    local context
    local GrimLogic
    local Fixtures
    local SCORE_RULES
    local STORAGE_RULES
    local Helpers

    before_each(function()
        context = LogicTestContext.Create()
        GrimLogic = context.GrimLogic
        Fixtures = context.Fixtures
        SCORE_RULES = context.SCORE_RULES
        STORAGE_RULES = context.STORAGE_RULES
        Helpers = context.Helpers
    end)

    -- TODO: not great tests

    describe("recent deaths", function()
        it("retains the configured number of recent deaths", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                }),
            })
            local added = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "Drakedog",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 2,
            }))
            assert.is_truthy(added, "first death should be accepted")
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * Helpers.getDisplayMultiplier(1, 1),
                database.totalPoints,
                "first matching source should add multiplied points"
            )
            assert.equals(1, database.correctPredictionStreak, "first match should start a streak")
            assert.equals(1, database.longestPredictionStreak, "first match should initialize the longest streak")
            assert.equals(true, database.recentDeaths[1].matchedPrediction, "matching source should mark the death as matched")
            assert.equals(Helpers.getExpectedBasePoints({ source = true }), database.recentDeaths[1].points, "matching source should store base points on the death row")
            assert.equals(nil, database.recentDeaths[1].time, "stored deaths should not persist formatted time strings")
            assert.equals(nil, database.recentDeaths[1].isBlizzardVerified, "stored deaths should not persist constant verification flags")
            assert.equals("Defias Pillager", database.recentDeaths[1].server, "stored deaths should persist the server they were parsed on")
            assert.equals(
                Helpers.getDisplayMultiplier(1, 1),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[1]),
                "first match should use the configured one-field multiplier"
            )
            assert.equals(nil, database.recentDeaths[1].multiplier, "first match should not persist formatted multiplier text")
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * Helpers.getDisplayMultiplier(1, 1),
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[1]),
                "first match should store awarded multiplied points"
            )
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * Helpers.getDisplayMultiplier(1, 1),
                database.recentDeaths[1].awardedPoints,
                "recent death rows should persist awarded totals for UI rendering"
            )
            assert.equals(1, database.recentDeaths[1].predictionStreak, "stored deaths should persist the resolved streak count")
            assert.equals(0, database.recentDeaths[1].streakMultiplier, "recent death rows should persist the streak multiplier contribution")
            assert.equals(
                12345,
                database.recentDeaths[1].prediction and database.recentDeaths[1].prediction.lockedAt,
                "per-death prediction snapshots should persist the full prediction timestamp"
            )

            GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "Alamo",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 2,
            }))
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * (Helpers.getDisplayMultiplier(1, 1) + Helpers.getDisplayMultiplier(1, 2)),
                database.totalPoints,
                "second consecutive match should apply the streak bonus"
            )
            assert.equals(2, database.correctPredictionStreak, "second match should increase the streak")
            assert.equals(2, database.longestPredictionStreak, "second match should raise the longest streak")
            assert.equals(
                Helpers.getDisplayMultiplier(1, 2),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[2]),
                "second match should combine the configured one-field bonus with the streak bonus"
            )
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * Helpers.getDisplayMultiplier(1, 2),
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[2]),
                "second match should award the combined multiplier"
            )

            GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "Drakedog",
                sourceName = "Murloc",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 2,
            }))

            assert.equals(2, #database.recentDeaths, "history should retain only the configured number of recent deaths")
            assert.equals(3, #database.deathHistory, "historical log should keep every accepted death")
            assert.equals("Alamo", database.recentDeaths[1].name, "oldest retained death should roll forward after trimming")
            assert.equals("Drakedog", database.recentDeaths[2].name, "newest death should be appended after trimming")
            assert.equals("Drakedog", database.deathHistory[1].name, "historical log should keep the oldest accepted death")
            assert.equals("Drakedog", database.deathHistory[3].name, "historical log should append the newest accepted death")
            assert.equals("Defias Pillager", database.deathHistory[1].server, "historical log should also persist the parsed server")
            assert.equals(nil, database.deathHistory[1].awardedPoints, "historical log rows should keep awarded points computed-on-read for compatibility")
            assert.equals(1, database.deathHistory[1].predictionStreak, "historical log rows should keep streak context for dynamic scoring")
            assert.equals(2, #database.successfullyPredictedDeaths, "successful predicted deaths should record only matched deaths")
            assert.equals("Drakedog", database.successfullyPredictedDeaths[1].name, "successful predicted deaths should store full death rows")
            assert.equals(0, database.correctPredictionStreak, "a miss should reset the streak")
            assert.equals(2, database.longestPredictionStreak, "a miss should not wipe the longest streak")
            assert.equals(0, GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[2]), "a miss should display the default x0 multiplier")
            assert.equals(0, GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[2]), "a miss should award no points")
        end)
    end)

    describe("history", function()
        it("caps the historical death log", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                }),
            })
            local maxDeathHistory = 100
            local sourceOnlyBasePoints = Helpers.getExpectedBasePoints({ source = true })
            local runningTotal = 0
            local failedInsertIndex

            for index = 1, maxDeathHistory + 5 do
                local expectedAward = sourceOnlyBasePoints * Helpers.getDisplayMultiplier(1, index)
                local added = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = "History" .. tostring(index),
                    sourceName = "Hogger",
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = STORAGE_RULES.maxRecentDeaths,
                    maxDeathHistory = maxDeathHistory,
                }))

                if not added and failedInsertIndex == nil then
                    failedInsertIndex = index
                end
                runningTotal = runningTotal + expectedAward
            end

            assert.equals(nil, failedInsertIndex, "all history cap test deaths should be inserted")
            assert.equals(maxDeathHistory, #database.deathHistory, "historical log should retain at most the configured number of deaths")
            assert.equals("History6", database.deathHistory[1].name, "historical log should trim the oldest deaths first")
            assert.equals("History" .. tostring(maxDeathHistory + 5), database.deathHistory[maxDeathHistory].name, "historical log should keep the newest death")
            assert.equals(runningTotal, database.totalPoints, "running score should keep cumulative points after history trimming")
            assert.equals(
                runningTotal,
                GrimLogic.GetDisplayState(database).totalPoints,
                "display state should keep using the persisted cumulative score after history trimming"
            )
        end)
    end)

    describe("successful predictions", function()
        it("caps the successful prediction history", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                }),
            })
            local maxSuccessfullyPredictedDeaths = STORAGE_RULES.maxSuccessfullyPredictedDeaths
            local failedInsertIndex

            for index = 1, maxSuccessfullyPredictedDeaths + 5 do
                local added = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = "Success" .. tostring(index),
                    sourceName = "Hogger",
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = maxSuccessfullyPredictedDeaths + 5,
                    maxSuccessfullyPredictedDeaths = maxSuccessfullyPredictedDeaths,
                }))

                if not added and failedInsertIndex == nil then
                    failedInsertIndex = index
                end
            end

            assert.equals(nil, failedInsertIndex, "all successful prediction retention test deaths should be inserted")
            assert.equals(
                maxSuccessfullyPredictedDeaths,
                #database.successfullyPredictedDeaths,
                "successful predicted deaths should retain at most the configured number of entries"
            )
            assert.equals(
                "Success6",
                database.successfullyPredictedDeaths[1].name,
                "successful predicted deaths should keep higher-scoring plateau entries after trimming"
            )
            assert.equals(
                "Success" .. tostring(maxSuccessfullyPredictedDeaths + 5),
                database.successfullyPredictedDeaths[maxSuccessfullyPredictedDeaths].name,
                "successful predicted deaths should keep the newest retained entries"
            )
        end)

        it("retains the highest-scoring successful predictions", function()
            local database = Fixtures.database()
            local function addSuccessfulDeath(options)
                database.lockedPrediction = options.prediction
                database.correctPredictionStreak = options.streakBefore or 0
                database.longestPredictionStreak = math.max(database.longestPredictionStreak or 0, database.correctPredictionStreak)

                local added = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = options.name,
                    level = options.level or 12,
                    sourceName = options.sourceName or "Hogger",
                    zone = options.zone or "Elwynn Forest",
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = 10,
                    maxSuccessfullyPredictedDeaths = 3,
                }))

                assert.is_truthy(added, options.name .. " should be inserted")
            end

            local candidates = {
                {
                    name = "HighOne",
                    order = 1,
                    streakBefore = 4,
                    prediction = Fixtures.prediction(),
                },
                {
                    name = "HighTwo",
                    order = 2,
                    streakBefore = 3,
                    prediction = Fixtures.prediction(),
                },
                {
                    name = "MidThree",
                    order = 3,
                    streakBefore = 0,
                    prediction = Fixtures.prediction({
                        levelRange = false,
                        source = "hogger",
                        zone = false,
                    }),
                },
                {
                    name = "LowFour",
                    order = 4,
                    streakBefore = 0,
                    prediction = Fixtures.prediction({
                        levelRange = "10-19",
                        source = false,
                        zone = false,
                    }),
                },
            }

            local function getRetentionPoints(candidate)
                local death = Helpers.createDeathForInsert({
                    name = candidate.name,
                    level = candidate.level or 12,
                    sourceName = candidate.sourceName or "Hogger",
                    zone = candidate.zone or "Elwynn Forest",
                })
                local elements = GrimLogic.GetPredictionElements(candidate.prediction) or {}
                local score = GrimLogic.ScoreDeathEvent(elements, death, SCORE_RULES.previewStreak)
                return score.awardedPoints or 0
            end

            for _, candidate in ipairs(candidates) do
                addSuccessfulDeath(candidate)
            end

            assert.equals(3, #database.successfullyPredictedDeaths, "successful predicted deaths should still honor the configured cap")

            local expectedDroppedCandidate = candidates[1]
            local expectedDroppedPoints = getRetentionPoints(expectedDroppedCandidate)

            for index = 2, #candidates do
                local candidate = candidates[index]
                local candidatePoints = getRetentionPoints(candidate)

                if candidatePoints < expectedDroppedPoints
                    or (candidatePoints == expectedDroppedPoints and candidate.order < expectedDroppedCandidate.order) then
                    expectedDroppedCandidate = candidate
                    expectedDroppedPoints = candidatePoints
                end
            end

            local retainedNames = {}
            for index, death in ipairs(database.successfullyPredictedDeaths) do
                retainedNames[index] = death.name
            end

            local retainedNameList = table.concat(retainedNames, ",")
            assert.equals(
                nil,
                string.find(retainedNameList, expectedDroppedCandidate.name, 1, true),
                "successful predicted deaths should discard the weakest baseline-scoring entry when the cap is exceeded"
            )

            for _, candidate in ipairs(candidates) do
                if candidate.name ~= expectedDroppedCandidate.name then
                    assert.is_not_nil(
                        string.find(retainedNameList, candidate.name, 1, true),
                        "successful predicted deaths should keep every stronger baseline-scoring entry within the cap"
                    )
                end
            end
        end)
    end)

    describe("multiplier tiers", function()
        it("caps displayed multipliers at the highest tier", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                    zoneLabel = false,
                }),
            })
            for index = 1, 11 do
                GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = "Match" .. tostring(index),
                    sourceName = "Hogger",
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = 11,
                }))
            end

            local expectedTotalPoints = 0
            local sourceOnlyBasePoints = Helpers.getExpectedBasePoints({ source = true })

            for index = 1, 11 do
                expectedTotalPoints = expectedTotalPoints + (sourceOnlyBasePoints * Helpers.getDisplayMultiplier(1, index))
            end

            assert.equals(11, database.correctPredictionStreak, "streak should keep counting after the highest tier is reached")
            assert.equals(11, database.longestPredictionStreak, "longest streak should track uncapped consecutive wins")
            assert.equals(
                Helpers.getDisplayMultiplier(1, 10),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[10]),
                "tenth consecutive match should combine the configured one-field bonus with the capped streak bonus"
            )
            assert.equals(
                Helpers.getDisplayMultiplier(1, 11),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[11]),
                "later matches should keep the capped combined multiplier for single-field hits"
            )
            assert.equals(expectedTotalPoints, database.totalPoints, "total points should include the combined match and streak multipliers")
        end)
    end)
end)
