local assert = require("luassert")
describe("Database state", function()
    local LogicTestContext = require("tests.support_logic_test_context")
    local context
    local GrimLogic
    local GrimDatabase
    local Fixtures
    local SCORE_RULES
    local STORAGE_RULES
    local Helpers

    before_each(function()
        context = LogicTestContext.Create()
        GrimLogic = context.GrimLogic
        GrimDatabase = context.GrimDatabase
        Fixtures = context.Fixtures
        SCORE_RULES = context.SCORE_RULES
        STORAGE_RULES = context.STORAGE_RULES
        Helpers = context.Helpers
    end)

    describe("initialization and normalization", function()
        it("preserves database identity", function()
            local database = {}
            local returnedDatabase = GrimDatabase.Init(database)

            assert.equals(database, returnedDatabase, "database init should return the same table instance")
            assert.equals(
                context.GrimMigration.CURRENT_VERSION,
                database.databaseVersion,
                "database init should migrate state to the current database version"
            )
            assert.is_table(database.recentDeaths, "database init should populate default recent death storage")
            assert.is_table(database.minimap, "database init should populate minimap settings")
            assert.is_table(
                database.announcements,
                "database init should populate guild announcement settings"
            )
        end)

        it("repairs corrupt top-level values", function()
            local returnedDatabase = GrimDatabase.Init(nil)

            assert.is_table(returnedDatabase, "database init should repair a corrupt top-level savedvariables value")
            assert.is_table(returnedDatabase.recentDeaths, "database init should still populate default recent death storage after repair")
            assert.is_table(returnedDatabase.minimap, "database init should still populate minimap settings after repair")
            assert.is_table(
                returnedDatabase.announcements,
                "database init should still populate guild announcement settings after repair"
            )
        end)

        it("normalizes stored state", function()
            local database = {
                databaseVersion = "invalid",
                recentDeaths = false,
                deathHistory = false,
                successfullyPredictedDeaths = false,
                announcements = {
                    enabled = "yes",
                    announceScoreOnDeath = false,
                    announceScoreOnLevelUp = false,
                    levelUpFrequency = "-4",
                },
                guildAnnouncements = {
                    enabled = true,
                },
                totalPoints = "17",
                correctPredictionStreak = "4",
                longestPredictionStreak = "10",
            }

            GrimDatabase.Init(database)

            assert.equals(
                context.GrimMigration.CURRENT_VERSION,
                database.databaseVersion,
                "database init should repair and migrate an invalid database version"
            )
            assert.is_table(database.recentDeaths, "database init should repair recent death storage")
            assert.is_table(database.deathHistory, "database init should repair death history storage")
            assert.is_table(
                database.successfullyPredictedDeaths,
                "database init should repair successful prediction storage"
            )
            assert.is_table(database.announcements, "database init should repair guild announcement settings")
            assert.equals(
                false,
                database.announcements.enabled,
                "database init should normalize guild announcement enablement to a boolean"
            )
            assert.equals(
                false,
                database.announcements.announceScoreOnDeath,
                "database init should preserve disabled death score announcements"
            )
            assert.equals(
                false,
                database.announcements.announceScoreOnLevelUp,
                "database init should preserve disabled level-up score announcements"
            )
            assert.equals(17, database.totalPoints, "database init should normalize total points to a number")
            assert.equals(
                4,
                database.correctPredictionStreak,
                "database init should normalize the current prediction streak to a number"
            )
            assert.equals(
                10,
                database.longestPredictionStreak,
                "database init should keep the longest streak at least as large as the current streak"
            )
        end)

        it("defaults guild announcements", function()
            local database = {}

            GrimDatabase.Init(database)

            assert.equals(false, database.announcements.enabled, "database init should disable guild announcements by default")
            assert.equals(
                true,
                database.announcements.announceScoreOnDeath,
                "database init should enable death score announcements by default"
            )
            assert.equals(
                false,
                database.announcements.announceScoreOnLevelUp,
                "database init should disable level-up score announcements by default"
            )
        end)

        it("adds guild announcements without resetting gameplay state", function()
            local database = {
                recentDeaths = {
                    Fixtures.storedDeath({
                        name = "Recent",
                    }),
                },
                deathHistory = {
                    Fixtures.storedDeath({
                        name = "History",
                    }),
                },
                successfullyPredictedDeaths = {
                    Fixtures.storedDeath({
                        name = "Success",
                    }),
                },
                totalPoints = 12345,
                correctPredictionStreak = 4,
                longestPredictionStreak = 7,
            }
            local recentDeaths = database.recentDeaths
            local deathHistory = database.deathHistory
            local successfulDeaths = database.successfullyPredictedDeaths

            GrimDatabase.Init(database)

            assert.equals(recentDeaths, database.recentDeaths, "database init should preserve recent death table identity")
            assert.equals(deathHistory, database.deathHistory, "database init should preserve death history table identity")
            assert.equals(
                successfulDeaths,
                database.successfullyPredictedDeaths,
                "database init should preserve successful prediction table identity"
            )
            assert.equals("Recent", database.recentDeaths[1].name, "database init should preserve recent deaths")
            assert.equals("History", database.deathHistory[1].name, "database init should preserve death history")
            assert.equals(
                "Success",
                database.successfullyPredictedDeaths[1].name,
                "database init should preserve successful predictions"
            )
            assert.equals(12345, database.totalPoints, "database init should preserve total points")
            assert.equals(4, database.correctPredictionStreak, "database init should preserve the current streak")
            assert.equals(7, database.longestPredictionStreak, "database init should preserve the longest streak")
            assert.is_table(database.announcements, "database init should add guild announcement settings")
        end)

        it("exposes guild announcement accessors", function()
            local emptyDatabase = {}
            ---@cast emptyDatabase table
            local database = GrimDatabase.Init(emptyDatabase)

            assert.equals(
                false,
                GrimDatabase.GetGuildAnnouncementsEnabled(database),
                "guild announcements should be disabled by default"
            )
            assert.equals(
                true,
                GrimDatabase.SetGuildAnnouncementsEnabled(database, true),
                "guild announcement setter should persist enabled state"
            )
            assert.equals(
                true,
                database.announcements.enabled,
                "guild announcement setter should update the nested settings table"
            )

            assert.equals(
                true,
                GrimDatabase.GetAnnounceDeathToGuild(database),
                "death score announcement getter should use the nested default"
            )
            assert.equals(
                false,
                GrimDatabase.SetAnnounceDeathToGuild(database, false),
                "death score announcement setter should persist disabled state"
            )
            assert.equals(
                false,
                database.announcements.announceScoreOnDeath,
                "death score announcement setter should update the nested settings table"
            )

            assert.equals(
                false,
                GrimDatabase.GetAnnounceScoreOnLevelUp(database),
                "level-up score announcement getter should use the nested default"
            )
            assert.equals(
                false,
                GrimDatabase.SetAnnounceScoreOnLevelUp(database, false),
                "level-up score announcement setter should persist disabled state"
            )
            assert.equals(
                false,
                database.announcements.announceScoreOnLevelUp,
                "level-up score announcement setter should update the nested settings table"
            )
        end)

        it("defaults the first-run flag", function()
            local database = {}

            GrimDatabase.Init(database)

            assert.equals(false, database.hasSeenFirstRun, "database init should default the first-run flag to false")
            assert.equals(
                false,
                GrimDatabase.GetHasSeenFirstRun(database),
                "database getter should report unseen first-run state by default"
            )
            assert.equals(
                true,
                GrimDatabase.SetHasSeenFirstRun(database, true),
                "database setter should persist a seen first-run state"
            )
            assert.equals(
                true,
                GrimDatabase.GetHasSeenFirstRun(database),
                "database getter should report the persisted first-run state"
            )
        end)
    end)

    describe("suggestions and reset", function()
        it("returns unique sorted death-history suggestions", function()
            local database = Fixtures.database({
                deathHistory = {
                    Fixtures.storedDeath({
                        sourceName = "Zebra Beast",
                        zone = "Zed Canyon",
                    }),
                    Fixtures.storedDeath({
                        sourceName = "Alpha Beast",
                        zone = "Westfall",
                    }),
                    Fixtures.storedDeath({
                        sourceName = "Zebra Beast",
                        zone = "Ashenvale",
                    }),
                    {
                        sourceName = 17,
                        zone = 17,
                    },
                    "corrupt death entry",
                },
            })

            local sources = GrimDatabase.GetDeathHistorySourceNames(database)
            local zones = GrimDatabase.GetDeathHistoryZones(database)

            assert.equals(2, #sources, "history sources should contain each normalized value once")
            assert.equals("Alpha Beast", sources[1], "history sources should be sorted alphabetically")
            assert.equals("Zebra Beast", sources[2], "history sources should preserve parsed values")
            assert.equals(3, #zones, "history zones should ignore invalid values and retain unique names")
            assert.equals("Ashenvale", zones[1], "history zones should be sorted alphabetically")
            assert.equals("Westfall", zones[2], "history zones should preserve stored display text")
            assert.equals("Zed Canyon", zones[3], "history zones should preserve parsed values")
        end)

        it("resets gameplay state", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
                lastPrediction = Fixtures.prediction({
                    source = "defias",
                    sourceLabel = "Defias",
                }),
                draftPrediction = Fixtures.prediction({
                    zone = "westfall",
                    zoneLabel = "Westfall",
                }),
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 1001,
                    }),
                },
                deathHistory = {
                    Fixtures.storedDeath({
                        timestamp = 1002,
                    }),
                },
                successfullyPredictedDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 1003,
                    }),
                },
                totalPoints = 17,
                correctPredictionStreak = 3,
                longestPredictionStreak = 5,
                hidden = false,
            })
            local recentDeaths = database.recentDeaths
            local deathHistory = database.deathHistory
            local successfulDeaths = database.successfullyPredictedDeaths

            GrimDatabase.ResetGameplayState(database)

            assert.equals(nil, database.lockedPrediction, "reset gameplay state should clear the locked prediction")
            assert.equals(nil, database.lastPrediction, "reset gameplay state should clear the last prediction")
            assert.equals(nil, database.draftPrediction, "reset gameplay state should clear the draft prediction")
            assert.equals(0, database.totalPoints, "reset gameplay state should zero total points")
            assert.equals(0, database.correctPredictionStreak, "reset gameplay state should zero the current streak")
            assert.equals(0, database.longestPredictionStreak, "reset gameplay state should zero the longest streak")
            assert.equals(recentDeaths, database.recentDeaths, "reset gameplay state should preserve recent death table identity")
            assert.equals(deathHistory, database.deathHistory, "reset gameplay state should preserve death history table identity")
            assert.equals(
                successfulDeaths,
                database.successfullyPredictedDeaths,
                "reset gameplay state should preserve successful prediction table identity"
            )
            assert.equals(0, #database.recentDeaths, "reset gameplay state should clear recent deaths")
            assert.equals(0, #database.deathHistory, "reset gameplay state should clear death history")
            assert.equals(
                0,
                #database.successfullyPredictedDeaths,
                "reset gameplay state should clear successful prediction history"
            )
            assert.equals(false, database.hidden, "reset gameplay state should keep unrelated window state")
        end)
    end)

    describe("prediction state", function()
        it("transitions locked predictions", function()
            local samePredictionDatabase = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
                lastPrediction = Fixtures.prediction(),
                correctPredictionStreak = 4,
                longestPredictionStreak = 6,
            })
            local samePrediction = Fixtures.prediction({
                lockedAt = 99999,
            })

            GrimLogic.ApplyLockedPrediction(samePredictionDatabase, samePrediction)
            assert.equals(
                4,
                samePredictionDatabase.correctPredictionStreak,
                "re-locking the same prediction should preserve the current streak"
            )
            assert.equals(
                "hogger",
                GrimLogic.GetPredictionElements(samePredictionDatabase.lockedPrediction).source,
                "apply locked prediction should store the normalized prediction elements"
            )
            assert.equals(
                99999,
                samePredictionDatabase.lockedPrediction.lockedAt,
                "apply locked prediction should preserve the prediction timestamp"
            )
            assert.equals(
                99999,
                samePredictionDatabase.lastPrediction.lockedAt,
                "apply locked prediction should refresh the last prediction snapshot"
            )

            local changedPredictionDatabase = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
                lastPrediction = Fixtures.prediction(),
                correctPredictionStreak = 4,
                longestPredictionStreak = 6,
            })
            local changedPrediction = Fixtures.prediction({
                source = "defias",
                sourceLabel = "Defias",
            })

            GrimLogic.ApplyLockedPrediction(changedPredictionDatabase, changedPrediction)
            assert.equals(
                0,
                changedPredictionDatabase.correctPredictionStreak,
                "locking in a different prediction should reset the active streak"
            )
            assert.equals(
                6,
                changedPredictionDatabase.longestPredictionStreak,
                "locking in a different prediction should not erase the longest streak"
            )

            local clearedDatabase = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
                lastPrediction = Fixtures.prediction({
                    source = "defias",
                    sourceLabel = "Defias",
                }),
            })

            GrimLogic.ClearLockedPrediction(clearedDatabase)
            assert.equals(nil, clearedDatabase.lockedPrediction, "clearing the locked prediction should unlock the database state")
            assert.is_not_nil(clearedDatabase.lastPrediction, "clearing the locked prediction should preserve a draft prediction")
            assert.equals(
                "hogger",
                GrimLogic.GetPredictionElements(clearedDatabase.lastPrediction).source,
                "clearing the locked prediction should keep the most recent locked prediction as the draft"
            )
        end)

        it("transitions draft predictions", function()
            local lockedPrediction = Fixtures.prediction()
            local database = Fixtures.database({
                lockedPrediction = lockedPrediction,
            })

            local updatedDraft = GrimLogic.UpdateDraftPrediction(database, {
                elements = {
                    source = "Defias Pillager",
                    zone = "Westfall",
                },
            })

            assert.is_not_nil(updatedDraft, "updating a draft prediction should return the normalized draft")
            assert.equals(
                "defias pillager",
                GrimLogic.GetPredictionElements(database.draftPrediction).source,
                "updating a draft prediction should normalize the stored source"
            )
            assert.equals(
                "westfall",
                GrimLogic.GetPredictionElements(database.draftPrediction).zone,
                "updating a draft prediction should normalize the stored zone"
            )
            assert.equals(
                lockedPrediction,
                database.lockedPrediction,
                "updating a draft prediction should not disturb the locked prediction"
            )

            local clearedDraft = GrimLogic.UpdateDraftPrediction(database, {
                elements = {},
            })

            assert.equals(nil, clearedDraft, "clearing every draft element should return nil")
            assert.equals(nil, database.draftPrediction, "clearing every draft element should remove the stored draft")
        end)
    end)

    describe("multiplier and scoring state", function()
        it("advances the multiplier sequence", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                    zoneLabel = false,
                }),
            })
            local sourcePoints = Helpers.getExpectedBasePoints({ source = true })
            local expectedTotals = {}
            local expectedMultipliers = {}
            local runningTotal = 0
            local failedInsertIndex

            for index = 1, 6 do
                local expectedMultiplier = Helpers.getDisplayMultiplier(1, index)
                expectedMultipliers[index] = expectedMultiplier
                runningTotal = runningTotal + (sourcePoints * expectedMultiplier)
                expectedTotals[index] = runningTotal
            end

            for index, expectedMultiplier in ipairs(expectedMultipliers) do
                local added, evaluation = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = "Streak" .. tostring(index),
                    sourceName = "Hogger",
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = 10,
                }))

                if not added and failedInsertIndex == nil then
                    failedInsertIndex = index
                end

                if failedInsertIndex == nil then
                    assert.is_truthy(evaluation.matched, "streak match " .. tostring(index) .. " should evaluate as matched")
                    assert.equals(
                        sourcePoints,
                        evaluation.basePoints,
                        "streak match " .. tostring(index) .. " should keep the same base points"
                    )
                    assert.equals(
                        index,
                        database.correctPredictionStreak,
                        "streak match " .. tostring(index) .. " should update the stored streak"
                    )
                    assert.equals(
                        index,
                        database.longestPredictionStreak,
                        "streak match " .. tostring(index) .. " should update the stored longest streak"
                    )
                    assert.equals(
                        expectedMultiplier,
                        GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[index]),
                        "streak match " .. tostring(index) .. " should use the right multiplier"
                    )
                    assert.equals(
                        nil,
                        database.recentDeaths[index].multiplier,
                        "streak match " .. tostring(index) .. " should not persist a formatted multiplier string"
                    )
                    assert.equals(
                        sourcePoints * expectedMultiplier,
                        GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[index]),
                        "streak match " .. tostring(index) .. " should award multiplied points"
                    )
                    assert.equals(expectedTotals[index], database.totalPoints, "streak match " .. tostring(index) .. " should roll into the running total")
                end
            end

            assert.equals(nil, failedInsertIndex, "all streak matches should be inserted")
        end)

        it("calculates the full point formula", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
            })
            local fullMatchBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
                zone = true,
            })
            local runningTotal = 0
            local failedInsertIndex

            for index = 1, 10 do
                local added, evaluation = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                    name = "Formula" .. tostring(index),
                }), Fixtures.addDeathOptions({
                    maxRecentDeaths = STORAGE_RULES.maxRecentDeaths + 7,
                }))

                local expectedMultiplier = Helpers.getDisplayMultiplier(3, index)
                local expectedAward = fullMatchBasePoints * expectedMultiplier

                runningTotal = runningTotal + expectedAward

                if not added and failedInsertIndex == nil then
                    failedInsertIndex = index
                end

                if failedInsertIndex == nil then
                    assert.equals(fullMatchBasePoints, evaluation.basePoints, "full formula should use the configured full-match base points")
                    assert.equals(
                        expectedMultiplier,
                        GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[index]),
                        "full formula should use the summed display multiplier for streak " .. tostring(index)
                    )
                    assert.equals(
                        expectedAward,
                        GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[index]),
                        "full formula should award the correct total for streak " .. tostring(index)
                    )
                    assert.equals(
                        runningTotal,
                        database.totalPoints,
                        "full formula should roll each awarded total into the running score"
                    )
                end
            end

            assert.equals(nil, failedInsertIndex, "all formula test deaths should be inserted")
        end)

        it("resets the multiplier after a miss", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                    zoneLabel = false,
                }),
            })
            GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "HitOne",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))
            GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "HitTwo",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))

            local missedAdded = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "Missed",
                sourceName = "Defias",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))
            assert.is_truthy(missedAdded, "a missed prediction should still create a death row")
            assert.equals(
                0,
                database.correctPredictionStreak,
                "a missed prediction should reset the streak to zero"
            )
            assert.equals(2, database.longestPredictionStreak, "a missed prediction should preserve the best streak reached")
            assert.equals(0, GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[3]), "a missed prediction should display x0")
            assert.equals(0, GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[3]), "a missed prediction should award zero points")

            local resetAdded = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "HitAfterMiss",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))
            assert.is_truthy(resetAdded, "a new correct prediction after a miss should still be inserted")
            assert.equals(1, database.correctPredictionStreak, "the first hit after a miss should restart at streak one")
            assert.equals(2, database.longestPredictionStreak, "the first hit after a miss should not reduce the longest streak")
            assert.equals(
                Helpers.getDisplayMultiplier(1, 1),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[4]),
                "the first hit after a miss should restart at the configured one-field multiplier"
            )
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * Helpers.getDisplayMultiplier(1, 1),
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[4]),
                "the first hit after a miss should award the configured one-field multiplier"
            )
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }) * (
                    Helpers.getDisplayMultiplier(1, 1)
                    + Helpers.getDisplayMultiplier(1, 2)
                    + Helpers.getDisplayMultiplier(1, 1)
                ),
                database.totalPoints,
                "the running total should only include the actual awarded values"
            )
        end)

        it("resets the streak after a partial multi-field miss", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction(),
                correctPredictionStreak = 2,
            })
            local added, evaluation = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "AlmostRight",
                zone = "Westfall",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))

            assert.is_truthy(added, "partial multi-field misses should still be recorded")
            assert.equals(true, evaluation.levelMatched, "partial multi-field misses should keep per-field match data")
            assert.equals(true, evaluation.sourceMatched, "partial multi-field misses should keep per-field source data")
            assert.equals(false, evaluation.zoneMatched, "partial multi-field misses should mark the missed field")
            assert.is_truthy(evaluation.matched, "partial multi-field misses should now count as partial wins")
            assert.equals(3, database.correctPredictionStreak, "partial multi-field wins should advance the streak")
            assert.equals(
                Helpers.getExpectedBasePoints({ levelRange = "10-19", level = 12, source = true }),
                database.recentDeaths[1].points,
                "partial multi-field wins should award the matched base points"
            )
            assert.equals(
                Helpers.getDisplayMultiplier(2, 3),
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[1]),
                "partial multi-field wins should show the summed matched-combination multiplier"
            )
            assert.equals(
                Helpers.getExpectedBasePoints({ levelRange = "10-19", level = 12, source = true })
                    * Helpers.getDisplayMultiplier(2, 3),
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[1]),
                "partial multi-field wins should apply the combo sum to the matched base points"
            )
        end)

        it("persists same-zone bonuses on stored deaths", function()
            local database = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = "10-19",
                    source = "hogger",
                    zone = "elwynn forest",
                }),
            })
            local added, evaluation = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "SameZone",
                sourceName = "Hogger",
                zone = "Elwynn Forest",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
                playerZone = "Elwynn Forest",
            }))
            local expectedBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
                zone = true,
            })
            local expectedMultiplier = Helpers.getDisplayMultiplier(3, 1)
            local expectedAwardedPoints = (expectedBasePoints + SCORE_RULES.sameZoneFixedBonusPoints) * expectedMultiplier

            assert.is_truthy(added, "same-zone bonus deaths should still be inserted")
            assert.equals(
                SCORE_RULES.sameZoneFixedBonusPoints,
                evaluation.sameZoneBonusPoints,
                "same-zone bonus should be included in the live score result"
            )
            assert.equals(
                true,
                database.recentDeaths[1].sameZoneBonusApplied,
                "same-zone bonus flag should persist on recent deaths"
            )
            assert.equals(
                true,
                database.deathHistory[1].sameZoneBonusApplied,
                "same-zone bonus flag should persist on history deaths"
            )
            assert.equals(
                expectedAwardedPoints,
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[1]),
                "same-zone bonus should roll into stored awarded points"
            )
            assert.equals(
                expectedAwardedPoints,
                database.totalPoints,
                "same-zone bonus should roll into the running total"
            )

            local noZoneDatabase = Fixtures.database({
                lockedPrediction = Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                    zoneLabel = false,
                }),
            })
            local noZoneAdded, noZoneEvaluation = GrimLogic.AddDeathToDatabase(
                noZoneDatabase,
                Helpers.createDeathForInsert({
                    name = "SameZoneNoPrediction",
                    sourceName = "Hogger",
                    zone = "Elwynn Forest",
                }),
                Fixtures.addDeathOptions({
                    maxRecentDeaths = 10,
                    playerZone = "Elwynn Forest",
                })
            )
            local expectedNoZoneBasePoints = Helpers.getExpectedBasePoints({
                source = true,
            })
            local expectedNoZoneMultiplier = Helpers.getDisplayMultiplier(1, 1)
            local expectedNoZoneAwardedPoints = (expectedNoZoneBasePoints + SCORE_RULES.sameZoneFixedBonusPoints)
                * expectedNoZoneMultiplier

            assert.is_truthy(noZoneAdded, "same-zone bonus deaths without a zone prediction should still be inserted")
            assert.equals(
                SCORE_RULES.sameZoneFixedBonusPoints,
                noZoneEvaluation.sameZoneBonusPoints,
                "same-zone bonus should still apply when the scoring match came from another field"
            )
            assert.equals(
                1,
                noZoneEvaluation.matchedElementCount,
                "same-zone bonus should not increase the matched prediction count when zone was not selected"
            )
            assert.equals(
                expectedNoZoneAwardedPoints,
                GrimLogic.GetStoredDeathAwardedPoints(noZoneDatabase.recentDeaths[1]),
                "same-zone bonus should still roll into stored awarded points without a zone prediction"
            )
        end)

        it("uses the default multiplier when no points are awarded", function()
            local database = Fixtures.database({
                correctPredictionStreak = 3,
                longestPredictionStreak = 3,
            })
            local added, evaluation = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "Unpredicted",
                sourceName = "Hogger",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 10,
            }))

            assert.is_truthy(added, "a death with no locked prediction should still be inserted")
            assert.equals(0, evaluation.basePoints, "a missing prediction should evaluate to zero base points")
            assert.equals(
                0,
                database.correctPredictionStreak,
                "a missing prediction should reset any existing streak"
            )
            assert.equals(3, database.longestPredictionStreak, "a missing prediction should preserve the existing longest streak")
            assert.equals(1, #database.recentDeaths, "a death with no locked prediction should be recorded once")
            assert.equals(1, #database.deathHistory, "historical log should still record deaths with no prediction")
            assert.equals(0, #database.successfullyPredictedDeaths, "a death with no locked prediction should not add a successful predicted death")
            assert.equals(
                0,
                GrimLogic.GetStoredDeathMultiplierValue(database.recentDeaths[1]),
                "a death with no locked prediction should display x0"
            )
            assert.equals(
                0,
                GrimLogic.GetStoredDeathAwardedPoints(database.recentDeaths[1]),
                "a death with no locked prediction should award zero points"
            )
            assert.equals(0, database.totalPoints, "a death with no locked prediction should not change the total")
        end)
    end)

    describe("stored deaths and display state", function()
        it("initializes death history when adding a death", function()
            local database = Fixtures.database({
                deathHistory = false,
            })
            local added = GrimLogic.AddDeathToDatabase(database, Helpers.createDeathForInsert({
                name = "HistoryInit",
                sourceName = "Defias",
            }), Fixtures.addDeathOptions({
                maxRecentDeaths = 5,
            }))

            assert.is_truthy(added, "add death should succeed when deathHistory is missing")
            assert.equals(1, #database.deathHistory, "add death should initialize missing historical log state")
            assert.equals(0, #database.successfullyPredictedDeaths, "add death should initialize missing successful predicted death state")
        end)

        it("builds display state from persisted data", function()
            local recentDeath = Fixtures.storedDeath({
                timestamp = 200,
                name = "Displaydeath",
            })
            local historyDeath = Fixtures.storedDeath({
                timestamp = 180,
                points = 999,
                multiplierValue = 9,
                awardedPoints = 8991,
            })
            local database = Fixtures.database({
                recentDeaths = { recentDeath },
                deathHistory = { historyDeath },
                totalPoints = 12345,
                correctPredictionStreak = 4,
                longestPredictionStreak = 7,
                lockedPrediction = Fixtures.prediction(),
                draftPrediction = Fixtures.prediction({
                    source = "gnoll",
                }),
                lastPrediction = Fixtures.prediction({
                    source = "defias",
                    sourceLabel = "Defias",
                }),
            })

            local state = GrimLogic.GetDisplayState(database)

            assert.equals(database.recentDeaths, state.deaths, "display state should expose the stored recent deaths")
            assert.equals(
                12345,
                state.totalPoints,
                "display state should expose the persisted total points"
            )
            assert.equals(4, state.currentPredictionStreak, "display state should expose the current streak")
            assert.equals(7, state.longestPredictionStreak, "display state should expose the longest streak")
            assert.equals(database.lockedPrediction, state.lockedPrediction, "display state should expose the locked prediction")
            assert.equals(database.draftPrediction, state.draftPrediction, "display state should expose the live draft prediction")
            assert.equals(database.lastPrediction, state.lastPrediction, "display state should expose the last prediction draft")
        end)
    end)
end)
