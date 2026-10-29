local assert = require("luassert")
describe("Scoring logic", function()
    local LogicTestContext = require("tests.support_logic_test_context")
    local context
    local GrimLogic
    local Fixtures
    local SCORE_RULES
    local Helpers

    before_each(function()
        context = LogicTestContext.Create()
        GrimLogic = context.GrimLogic
        Fixtures = context.Fixtures
        SCORE_RULES = context.SCORE_RULES
        Helpers = context.Helpers
    end)

    describe("evaluation and bonuses", function()
        it("matches all selected fields", function()
            local evaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction(),
                Fixtures.death()
            )

            assert.is_truthy(evaluation.levelMatched, "evaluation should match level")
            assert.is_truthy(evaluation.sourceMatched, "evaluation should match source")
            assert.is_truthy(evaluation.zoneMatched, "evaluation should match zone")
            assert.is_truthy(evaluation.matched, "evaluation should mark overall match")
            assert.equals(3, evaluation.matchedElementCount, "evaluation should still count all three matched elements")
            assert.equals(
                SCORE_RULES.predictionElementBonusByCount[3] or 0,
                evaluation.comboBonus,
                "evaluation should expose the combo bonus under one canonical field name"
            )
            assert.equals(nil, evaluation.matchBonus, "evaluation should not keep a duplicate combo bonus alias")
            assert.equals(
                Helpers.getExpectedBasePoints({ levelRange = "10-19", level = 12, source = true, zone = true }),
                evaluation.basePoints,
                "evaluation should award the matched level, source, and zone base points together"
            )
        end)

        it("awards points for partial matches", function()
            local partialEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    zone = false,
                }),
                Fixtures.death({
                    sourceName = "Defias",
                })
            )

            assert.is_truthy(partialEvaluation.levelMatched, "partial evaluation should still track which fields matched")
            assert.equals(false, partialEvaluation.sourceMatched, "partial evaluation should track the missed field")
            assert.is_truthy(partialEvaluation.matched, "partial evaluation should now count any matched element as a win")
            assert.equals(
                GrimLogic.GetLevelPointsForLevel(12),
                partialEvaluation.basePoints,
                "partial evaluation should give level-only matches the configured level points"
            )
        end)

        it("awards source points when the level misses", function()
            local levelMissSourceHitEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    levelRange = "20-29",
                    source = "hogger",
                    zone = false,
                }),
                Fixtures.death({
                    level = 12,
                })
            )

            assert.equals(false, levelMissSourceHitEvaluation.levelMatched, "a missed level prediction should stay marked as missed")
            assert.is_truthy(levelMissSourceHitEvaluation.sourceMatched, "a matched source should still be tracked when level misses")
            assert.equals(
                Helpers.getExpectedBasePoints({ levelRange = "20-29", level = 12, levelMatched = false, source = true }),
                levelMissSourceHitEvaluation.basePoints,
                "source points should still be awarded when the selected level prediction misses"
            )
        end)

        it("supports single-field predictions", function()
            local singleFieldEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    levelRange = false,
                    source = "hogger",
                    zone = false,
                }),
                Fixtures.death({
                    level = 7,
                    zone = "Durotar",
                })
            )

            assert.is_truthy(singleFieldEvaluation.matched, "single selected fields should still win when that field matches")
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true }),
                singleFieldEvaluation.basePoints,
                "single selected field wins should award that field's points"
            )
        end)

        it("rejects empty predictions", function()
            local emptyPredictionEvaluation = GrimLogic.EvaluatePrediction({}, Fixtures.death())

            assert.equals(false, emptyPredictionEvaluation.matched, "empty predictions should not count as wins")
            assert.equals(0, emptyPredictionEvaluation.basePoints, "empty predictions should award no points")
        end)

        it("scores high-level range matches", function()
            local highLevelEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    source = false,
                    zone = false,
                    levelRange = "50-59",
                }),
                Fixtures.death({
                    level = 58,
                })
            )

            assert.is_truthy(highLevelEvaluation.matched, "high-level range predictions should still match normally")
            assert.equals(
                GrimLogic.GetLevelPointsForLevel(58),
                highLevelEvaluation.basePoints,
                "high-level range wins should award the configured matched level points"
            )
        end)

        it("returns zero scoring data for complete misses", function()
            local missedHighValueEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    levelRange = "60",
                    source = "hogger",
                    zone = "elwynn forest",
                }),
                Fixtures.death({
                    level = 42,
                    sourceName = "Defias Pillager",
                    zone = "Westfall",
                })
            )

            assert.equals(false, missedHighValueEvaluation.matched, "full misses should not count as matched")
            assert.equals(0, missedHighValueEvaluation.basePoints, "full misses should not use prediction points from selected elements")
            assert.equals(0, missedHighValueEvaluation.combinationCount, "full misses should not build any scoring combinations")
        end)

        it("normalizes source and zone comparisons", function()
            local zoneCombinationEvaluation = GrimLogic.EvaluatePrediction(
                Fixtures.prediction({
                    levelRange = false,
                    source = "defias pillager",
                    zone = "westfall",
                }),
                Fixtures.death({
                    sourceName = "  Defias Pillager  ",
                    zone = "  WESTFALL  ",
                })
            )

            assert.is_truthy(zoneCombinationEvaluation.sourceMatched, "zone combination evaluation should still match source text after trimming")
            assert.is_truthy(zoneCombinationEvaluation.zoneMatched, "zone combination evaluation should match zone text after trimming")
            assert.is_truthy(zoneCombinationEvaluation.matched, "zone combination evaluation should count source plus zone as a win")
            assert.equals(
                Helpers.getExpectedBasePoints({ source = true, zone = true }),
                zoneCombinationEvaluation.basePoints,
                "zone combination evaluation should include the zone points in the combined base total"
            )
            assert.equals(
                Helpers.getCombinationCount(2),
                zoneCombinationEvaluation.combinationCount,
                "zone combination evaluation should include the zone-based subsets"
            )
        end)

        it("awards same-zone bonus points", function()
            local matchedEvaluation = GrimLogic.ScoreDeathEvent(
                GrimLogic.GetPredictionElements(Fixtures.prediction()),
                Fixtures.death(),
                2,
                { playerZone = "Elwynn Forest" }
            )
            local basePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
                zone = true,
            })
            local totalMultiplier = Helpers.getDisplayMultiplier(3, 2)

            assert.equals(
                SCORE_RULES.sameZoneFixedBonusPoints,
                matchedEvaluation.sameZoneBonusPoints,
                "same-zone bonus should add the configured fixed points on matched deaths"
            )
            assert.equals(
                (basePoints + SCORE_RULES.sameZoneFixedBonusPoints) * totalMultiplier,
                matchedEvaluation.awardedPoints,
                "same-zone bonus should contribute to awarded points before multiplier math"
            )
            assert.equals(
                SCORE_RULES.predictionElementBonusByCount[3] or 0,
                matchedEvaluation.comboBonus,
                "same-zone bonus should not change combo bonus"
            )
            assert.equals(
                SCORE_RULES.streakBonusStep,
                matchedEvaluation.streakBonus,
                "same-zone bonus should not change streak bonus"
            )
            assert.equals(
                3,
                matchedEvaluation.matchedElementCount,
                "same-zone bonus should not change the matched element count when zone was predicted"
            )

            local noZonePredictionEvaluation = GrimLogic.ScoreDeathEvent(
                GrimLogic.GetPredictionElements(Fixtures.prediction({
                    zone = false,
                })),
                Fixtures.death(),
                2,
                { playerZone = "Elwynn Forest" }
            )
            local noZoneBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
            })
            local noZoneMultiplier = Helpers.getDisplayMultiplier(2, 2)

            assert.equals(
                SCORE_RULES.sameZoneFixedBonusPoints,
                noZonePredictionEvaluation.sameZoneBonusPoints,
                "same-zone bonus should still apply when another predicted field matched in the same zone"
            )
            assert.equals(
                2,
                noZonePredictionEvaluation.matchedElementCount,
                "same-zone bonus should not count as a matched prediction element when zone was not predicted"
            )
            assert.equals(
                (noZoneBasePoints + SCORE_RULES.sameZoneFixedBonusPoints) * noZoneMultiplier,
                noZonePredictionEvaluation.awardedPoints,
                "same-zone bonus should add into the total even when zone was not predicted"
            )

            local nonBonusEvaluation = GrimLogic.ScoreDeathEvent(
                GrimLogic.GetPredictionElements(Fixtures.prediction()),
                Fixtures.death(),
                2,
                { playerZone = "Westfall" }
            )
            assert.equals(0, nonBonusEvaluation.sameZoneBonusPoints, "same-zone bonus should stay zero when the flag is off")

            local previewEvaluation = GrimLogic.ScorePreview(
                GrimLogic.GetPredictionElements(Fixtures.prediction()),
                2
            )
            assert.equals(
                0,
                previewEvaluation.sameZoneBonusPoints,
                "preview scoring should not apply the live same-zone bonus"
            )

            local missedEvaluation = GrimLogic.ScoreDeathEvent(
                GrimLogic.GetPredictionElements(Fixtures.prediction({
                    levelRange = "60",
                    source = "defias pillager",
                    zone = "westfall",
                })),
                Fixtures.death(),
                2,
                { playerZone = "Elwynn Forest" }
            )
            assert.equals(false, missedEvaluation.matched, "full misses should still count as misses with same-zone bonus enabled")
            assert.equals(0, missedEvaluation.sameZoneBonusPoints, "same-zone bonus should not apply on full misses")
            assert.equals(0, missedEvaluation.awardedPoints, "full misses should still award zero points")
        end)

        it("reports combo details", function()
            local details = GrimLogic.GetComboDetails(
                Fixtures.prediction({
                    levelRange = false,
                    source = "benny blaanco",
                    zone = "elwynn forest",
                }),
                Fixtures.death({
                    sourceName = "Benny Blaanco",
                    zone = "Elwynn Forest",
                }),
                2
            )

            assert.is_truthy(details.matched, "combo details should report when the prediction scored")
            local expectedBasePoints = Helpers.getExpectedBasePoints({ source = true, zone = true })
            local expectedComboSum = Helpers.getDisplayMultiplier(2, 2)
            assert.equals(expectedBasePoints, details.basePoints, "combo details should use the matched base points")
            assert.equals(expectedComboSum, details.comboSum, "combo details should use the best successful combination multiplier")
            assert.equals("x" .. tostring(expectedComboSum), details.displayComboSum, "combo details should provide a formatted combo sum")
            assert.equals(expectedBasePoints * expectedComboSum, details.awardedPoints, "combo details should include the awarded total")
            assert.equals(Helpers.getCombinationCount(2), #details.combos, "combo details should include only the best successful combination")
            assert.equals("Benny Blaanco + Elwynn Forest", details.combos[1].label, "combo details should label the best combination with the prediction values")
            assert.equals(
                "x" .. tostring(SCORE_RULES.predictionElementBonusByCount[2] or 0),
                details.combos[1].displayMultiplier,
                "combo details should format the best combo bonus without repeating the streak"
            )

            local missedDetails = GrimLogic.GetComboDetails(
                Fixtures.prediction({
                    levelRange = false,
                    source = "benny blaanco",
                    zone = "elwynn forest",
                }),
                Fixtures.death({
                    sourceName = "Defias Pillager",
                    zone = "Westfall",
                }),
                2
            )

            assert.equals(false, missedDetails.matched, "combo details should mark a full miss")
            assert.equals(0, missedDetails.basePoints, "combo details should not carry prediction points into misses")
            assert.equals(0, missedDetails.comboSum, "combo details should use x0 for misses")
            assert.equals(0, #missedDetails.combos, "combo details should not emit successful combination rows for misses")
        end)
    end)

    describe("multipliers", function()
        it("calculates scoring multipliers", function()
            local streakCases = {
                { streak = 0, bonus = 0, label = "zero streak should use no streak bonus" },
                { streak = 1, bonus = 0, label = "the first correct prediction should apply no streak bonus" },
                { streak = 2, bonus = 1 * SCORE_RULES.streakBonusStep, label = "the second correct prediction should apply one streak step" },
                { streak = 3, bonus = 2 * SCORE_RULES.streakBonusStep, label = "the third correct prediction should apply two streak steps" },
                {
                    streak = 4,
                    bonus = math.min(3 * SCORE_RULES.streakBonusStep, SCORE_RULES.maxStreakBonus),
                    label = "the fourth correct prediction should apply three streak steps until the configured cap",
                },
                {
                    streak = 5,
                    bonus = math.min(4 * SCORE_RULES.streakBonusStep, SCORE_RULES.maxStreakBonus),
                    label = "the fifth correct prediction should keep stepping until the cap",
                },
                {
                    streak = 9,
                    bonus = math.min(8 * SCORE_RULES.streakBonusStep, SCORE_RULES.maxStreakBonus),
                    label = "later correct predictions should continue using the configured streak step offset by one",
                },
                {
                    streak = SCORE_RULES.maxStreakBonus,
                    bonus = math.min(
                        (SCORE_RULES.maxStreakBonus - 1) * SCORE_RULES.streakBonusStep,
                        SCORE_RULES.maxStreakBonus
                    ),
                    label = "the configured max streak should still respect the first-hit offset",
                },
                { streak = SCORE_RULES.maxStreakBonus + 1, bonus = SCORE_RULES.maxStreakBonus, label = "streaks beyond the configured cap should stay capped" },
            }

            local nilStreakScore = GrimLogic.ScoreDeathEvent(
                GrimLogic.GetPredictionElements(Fixtures.prediction({
                    levelRange = false,
                    zone = false,
                })) or {},
                Fixtures.death(),
                nil
            )
            assert.equals(0, nilStreakScore.streakBonus, "nil streak should default to no streak bonus at the scoring boundary")

            for _, case in ipairs(streakCases) do
                local actual = GrimLogic._CalculateStreakBonus(case.streak)
                assert.equals(case.bonus, actual, case.label)
            end

            local multiplierCases = {
                {
                    streak = 1,
                    prediction = Fixtures.prediction({
                        source = false,
                        zone = false,
                        levelRange = "10-19",
                    }),
                    death = Fixtures.death({
                        level = 12,
                    }),
                    matched = true,
                    matchedElementCount = 1,
                    comboBonus = SCORE_RULES.predictionElementBonusByCount[1] or 0,
                    streakBonus = 0,
                    totalMultiplier = Helpers.getDisplayMultiplier(1, 1),
                    label = "a matched level prediction should use the one-field combo bonus on the first hit",
                },
                {
                    streak = 1,
                    prediction = Fixtures.prediction({
                        zone = false,
                        levelRange = "10-19",
                        source = "hogger",
                    }),
                    death = Fixtures.death({
                        level = 12,
                        sourceName = "Hogger",
                    }),
                    matched = true,
                    matchedElementCount = 2,
                    comboBonus = SCORE_RULES.predictionElementBonusByCount[2] or 0,
                    streakBonus = 0,
                    totalMultiplier = Helpers.getDisplayMultiplier(2, 1),
                    label = "level plus one matched field should use the two-field combo bonus before any streak bonus",
                },
                {
                    streak = 1,
                    prediction = Fixtures.prediction(),
                    death = Fixtures.death(),
                    matched = true,
                    matchedElementCount = 3,
                    comboBonus = SCORE_RULES.predictionElementBonusByCount[3] or 0,
                    streakBonus = 0,
                    totalMultiplier = Helpers.getDisplayMultiplier(3, 1),
                    label = "three matched fields on the first hit should use the three-field combo bonus",
                },
                {
                    streak = 2,
                    prediction = Fixtures.prediction({
                        levelRange = false,
                        zone = false,
                        source = "hogger",
                    }),
                    death = Fixtures.death({
                        sourceName = "Hogger",
                    }),
                    matched = true,
                    matchedElementCount = 1,
                    comboBonus = SCORE_RULES.predictionElementBonusByCount[1] or 0,
                    streakBonus = SCORE_RULES.streakBonusStep,
                    totalMultiplier = Helpers.getDisplayMultiplier(1, 2),
                    label = "one-field winning predictions on the second hit should include the first streak step",
                },
                {
                    streak = 3,
                    prediction = Fixtures.prediction(),
                    death = Fixtures.death(),
                    matched = true,
                    matchedElementCount = 3,
                    comboBonus = SCORE_RULES.predictionElementBonusByCount[3] or 0,
                    streakBonus = 2 * SCORE_RULES.streakBonusStep,
                    totalMultiplier = Helpers.getDisplayMultiplier(3, 3),
                    label = "three matched fields on the third hit should combine the combo bonus with the second streak step",
                },
                {
                    streak = 3,
                    prediction = Fixtures.prediction({
                        levelRange = "60",
                        source = "defias pillager",
                        zone = "westfall",
                    }),
                    death = Fixtures.death(),
                    matched = false,
                    matchedElementCount = 0,
                    comboBonus = 0,
                    streakBonus = 0,
                    totalMultiplier = 0,
                    label = "an unmatched death should not apply combo or streak multipliers",
                },
            }

            for _, case in ipairs(multiplierCases) do
                local elements = GrimLogic.GetPredictionElements(case.prediction) or {}
                local score = GrimLogic.ScoreDeathEvent(elements, case.death, case.streak)

                assert.equals(case.matched, score.matched, case.label .. " matched state")
                assert.equals(
                    case.matchedElementCount,
                    score.matchedElementCount,
                    case.label .. " matched element count"
                )
                assert.equals(case.comboBonus, score.comboBonus, case.label .. " combo bonus")
                assert.equals(case.streakBonus, score.streakBonus, case.label .. " streak bonus")
                assert.equals(case.totalMultiplier, score.totalMultiplier, case.label .. " total multiplier")
            end
        end)
    end)

    describe("preview and formatting", function()
        it("calculates prediction preview scoring", function()
            local function scorePredictionPreview(prediction)
                return GrimLogic.ScorePreview(
                    GrimLogic.GetPredictionElements(prediction) or {},
                    GrimLogic.GetPreviewStreak()
                )
            end

            local emptyBasePoints = 0
            local sourceBasePoints = Helpers.getExpectedBasePoints({ source = true })
            local levelBasePoints = GrimLogic.GetLevelPointsForRange("50-59")
            local levelSourceBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "20-29",
                level = 20,
                source = true,
            })
            local fullBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 10,
                source = true,
                zone = true,
            })
            local cases = {
                {
                    prediction = Fixtures.prediction({
                        levelRange = false,
                        source = false,
                        zone = false,
                    }),
                    basePoints = emptyBasePoints,
                    totalMultiplier = 0,
                    label = "empty prediction previews",
                },
                {
                    prediction = Fixtures.prediction({
                        levelRange = false,
                        zone = false,
                    }),
                    basePoints = sourceBasePoints,
                    totalMultiplier = Helpers.getDisplayMultiplier(1, SCORE_RULES.previewStreak),
                    label = "source-only prediction previews",
                },
                {
                    prediction = Fixtures.prediction({
                        source = false,
                        zone = false,
                        levelRange = "50-59",
                    }),
                    basePoints = levelBasePoints,
                    totalMultiplier = Helpers.getDisplayMultiplier(1, SCORE_RULES.previewStreak),
                    label = "level-only prediction previews",
                },
                {
                    prediction = Fixtures.prediction({
                        levelRange = "20-29",
                        zone = false,
                    }),
                    basePoints = levelSourceBasePoints,
                    totalMultiplier = Helpers.getDisplayMultiplier(2, SCORE_RULES.previewStreak),
                    label = "two-element prediction previews",
                },
                {
                    prediction = Fixtures.prediction(),
                    basePoints = fullBasePoints,
                    totalMultiplier = Helpers.getDisplayMultiplier(3, SCORE_RULES.previewStreak),
                    label = "three-element prediction previews",
                },
            }

            for _, case in ipairs(cases) do
                local score = scorePredictionPreview(case.prediction)

                assert.equals(case.basePoints, score.basePoints, case.label .. " base points")
                assert.equals(case.totalMultiplier, score.totalMultiplier, case.label .. " total multiplier")
                assert.equals(
                    case.basePoints * case.totalMultiplier,
                    score.awardedPoints,
                    case.label .. " awarded points"
                )
            end
        end)

        it("formats multipliers", function()
            local cases = {
                { multiplier = nil, expected = "x0", label = "missing multiplier should format as x0" },
                { multiplier = 0, expected = "x0", label = "zero multiplier should format as x0" },
                { multiplier = 7, expected = "x7", label = "positive multiplier should use xN notation" },
            }

            for _, case in ipairs(cases) do
                assert.equals(case.expected, GrimLogic.FormatMultiplier(case.multiplier), case.label)
            end
        end)
    end)

    describe("display values", function()
        it("builds prediction payout preview rows", function()
            local function getPayoutRowPoints(prediction)
                return GrimLogic.ScorePreview(
                    GrimLogic.GetPredictionElements(prediction) or {},
                    0
                ).awardedPoints or 0
            end

            local emptyRows = GrimLogic.GetPredictionPayoutPreviewRows(Fixtures.prediction({
                levelRange = false,
                source = false,
                zone = false,
            }))
            assert.equals(0, #emptyRows, "payout preview rows should omit impossible rows when nothing is selected")

            local oneFieldRows = GrimLogic.GetPredictionPayoutPreviewRows(Fixtures.prediction({
                source = false,
                zone = false,
                levelRange = "50-59",
            }))
            local oneFieldPrediction = Fixtures.prediction({
                source = false,
                zone = false,
                levelRange = "50-59",
            })
            local oneFieldPoints = getPayoutRowPoints(oneFieldPrediction)
            assert.equals(1, #oneFieldRows, "payout preview rows should include one row for one selected field")
            assert.equals("Level", oneFieldRows[1].label, "level-only payout preview should label the single selected field")
            assert.equals(oneFieldPoints, oneFieldRows[1].awardedPoints, "level-only payout preview should use the actual no-streak payout")
            assert.equals("1 match: Level = " .. tostring(oneFieldPoints) .. " points", oneFieldRows[1].text, "level-only payout preview should format the payout row")

            local twoFieldPrediction = Fixtures.prediction({
                zone = false,
                levelRange = "20-29",
                source = "hogger",
            })
            local twoFieldRows = GrimLogic.GetPredictionPayoutPreviewRows(twoFieldPrediction)
            local twoFieldLevelOnlyPoints = getPayoutRowPoints(Fixtures.prediction({
                zone = false,
                levelRange = "20-29",
                source = false,
            }))
            local twoFieldSourceOnlyPoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = false,
                source = "hogger",
                zone = false,
            }))
            local twoFieldCombinedPoints = getPayoutRowPoints(twoFieldPrediction)
            assert.equals(3, #twoFieldRows, "payout preview rows should include singles plus one pair for two selected fields")
            assert.equals("1 match: Level = " .. tostring(twoFieldLevelOnlyPoints) .. " points", twoFieldRows[1].text, "two-field payout preview should show the level-only win")
            assert.equals("1 match: Source = " .. tostring(twoFieldSourceOnlyPoints) .. " points", twoFieldRows[2].text, "two-field payout preview should show the source-only win")
            assert.equals("2 match: Level + Source = " .. tostring(twoFieldCombinedPoints) .. " points", twoFieldRows[3].text, "two-field payout preview should show the combined win")

            local threeFieldPrediction = Fixtures.prediction({
                levelRange = "10-19",
                source = "benny",
                zone = "westfall",
            })
            local threeFieldRows = GrimLogic.GetPredictionPayoutPreviewRows(threeFieldPrediction)
            local threeFieldLevelOnlyPoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = "10-19",
                source = false,
                zone = false,
            }))
            local threeFieldSourceOnlyPoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = false,
                source = "benny",
                zone = false,
            }))
            local threeFieldZoneOnlyPoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = false,
                source = false,
                zone = "westfall",
            }))
            local threeFieldLevelSourcePoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = "10-19",
                source = "benny",
                zone = false,
            }))
            local threeFieldLevelZonePoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = "10-19",
                source = false,
                zone = "westfall",
            }))
            local threeFieldSourceZonePoints = getPayoutRowPoints(Fixtures.prediction({
                levelRange = false,
                source = "benny",
                zone = "westfall",
            }))
            local threeFieldCombinedPoints = getPayoutRowPoints(threeFieldPrediction)
            assert.equals(7, #threeFieldRows, "payout preview rows should include singles, pairs, and the triple for three selected fields")
            assert.equals(
                "1 match: Level = " .. tostring(threeFieldLevelOnlyPoints) .. " points",
                threeFieldRows[1].text,
                "three-field payout preview should show the level-only win"
            )
            assert.equals(
                "1 match: Source = " .. tostring(threeFieldSourceOnlyPoints) .. " points",
                threeFieldRows[2].text,
                "three-field payout preview should show the source-only win"
            )
            assert.equals(
                "1 match: Zone = " .. tostring(threeFieldZoneOnlyPoints) .. " points",
                threeFieldRows[3].text,
                "three-field payout preview should show the zone-only win"
            )
            assert.equals(
                "2 match: Level + Source = " .. tostring(threeFieldLevelSourcePoints) .. " points",
                threeFieldRows[4].text,
                "three-field payout preview should show the level-plus-source win"
            )
            assert.equals(
                "2 match: Level + Zone = " .. tostring(threeFieldLevelZonePoints) .. " points",
                threeFieldRows[5].text,
                "three-field payout preview should show the level-plus-zone win"
            )
            assert.equals(
                "2 match: Source + Zone = " .. tostring(threeFieldSourceZonePoints) .. " points",
                threeFieldRows[6].text,
                "three-field payout preview should list the distinct source-plus-zone win"
            )
            assert.equals(
                "3 match: Level + Source + Zone = " .. tostring(threeFieldCombinedPoints) .. " points",
                threeFieldRows[7].text,
                "three-field payout preview should show the full-match win"
            )
        end)

        it("maps point totals to quality colors", function()
            local epicCarryoverPoints = SCORE_RULES.pointColorThresholds.rare
                + math.max(
                    1,
                    tonumber(SCORE_RULES.fixedLevelRangePoints["10-19"]) or 0,
                    tonumber(SCORE_RULES.fixedElementPoints.source) or 0,
                    tonumber(SCORE_RULES.fixedElementPoints.zone) or 0
                )
            local cases = {
                { points = 0, quality = 0, label = "zero points should map to poor gray quality" },
                { points = 1, quality = 1, label = "one point should map to common white quality" },
                { points = SCORE_RULES.pointColorThresholds.common, quality = 1, label = "the common threshold should stay in white quality" },
                { points = SCORE_RULES.pointColorThresholds.common + 1, quality = 2, label = "just above the common threshold should map to uncommon green quality" },
                { points = SCORE_RULES.pointColorThresholds.uncommon, quality = 2, label = "the uncommon threshold should stay in uncommon green quality" },
                { points = SCORE_RULES.pointColorThresholds.uncommon + 1, quality = 3, label = "just above the uncommon threshold should map to rare blue quality" },
                { points = SCORE_RULES.pointColorThresholds.rare, quality = 3, label = "the rare threshold should stay in rare blue quality" },
                { points = SCORE_RULES.pointColorThresholds.rare + 1, quality = 4, label = "just above the rare threshold should map to epic purple quality" },
                { points = epicCarryoverPoints, quality = 4, label = "large point totals should stay in epic purple quality" },
            }

            if SCORE_RULES.pointColorThresholds.common + 1 < SCORE_RULES.pointColorThresholds.uncommon then
                cases[#cases + 1] = {
                    points = SCORE_RULES.pointColorThresholds.uncommon - 1,
                    quality = 2,
                    label = "points inside the uncommon band should stay in uncommon green quality",
                }
            end

            for _, case in ipairs(cases) do
                assert.equals(case.quality, GrimLogic.GetPointColorQuality(case.points), case.label)
            end
        end)
    end)
end)
