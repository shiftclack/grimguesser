local assert = require("luassert")
describe("Death handling", function()
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

    describe("normalization", function()
        it("normalizes death events", function()
            context.env.time = function()
                return 12345
            end

            local death = GrimLogic.NormalizeDeathEvent(Fixtures.death({
                name = "Drakedog",
                level = 10,
                causeType = "HARDCORE_CAUSEOFDEATH_CREATURE",
                sourceName = "Kobold Miner",
                zone = "Elwynn Forest",
                sourceMessage = "raw",
            }))

            assert.equals(12345, death.timestamp, "normalized death should use the global time function")
            assert.equals("Defias Pillager", death.server, "normalized death should preserve the parsed server when present")
            assert.is_truthy(death.isBlizzardVerified, "normalized death should mark Blizzard verification")
        end)
    end)

    describe("stored-death accessors", function()
        it("returns stored death values", function()
            assert.equals(
                math.min(3 * SCORE_RULES.streakBonusStep, SCORE_RULES.maxStreakBonus),
                GrimLogic.GetStoredDeathStreakMultiplierValue(Fixtures.storedDeath({
                    predictionStreak = 4,
                })),
                "stored death streak display value should use the raw streak bonus step"
            )

            local fullMatchBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
                zone = true,
            })
            local fullMatchMultiplier = Helpers.getDisplayMultiplier(3, 1)
            local death = Fixtures.storedDeath({
                points = 999,
                multiplierValue = 9,
                awardedPoints = 8991,
                streakMultiplier = 99,
                predictionStreak = 1,
                prediction = Fixtures.prediction({
                    lockedAt = 54321,
                }),
            })

            assert.equals(fullMatchBasePoints, GrimLogic.GetStoredDeathBasePoints(death), "stored death base points should be recalculated from the saved prediction")
            assert.equals(fullMatchMultiplier, GrimLogic.GetStoredDeathMultiplierValue(death), "stored death multiplier should be recalculated from prediction data and streak")
            assert.equals(fullMatchBasePoints * fullMatchMultiplier, GrimLogic.GetStoredDeathAwardedPoints(death), "stored death awarded points should ignore stale persisted totals")
            assert.equals(
                0,
                GrimLogic.GetStoredDeathStreakMultiplierValue(death),
                "stored death streak contribution should ignore stale persisted values"
            )

            local sameZoneDeath = Fixtures.storedDeath({
                sameZoneBonusApplied = true,
                points = 1,
                awardedPoints = 1,
            })
            assert.equals(
                SCORE_RULES.sameZoneFixedBonusPoints,
                GrimLogic.GetStoredDeathSameZoneBonusPoints(sameZoneDeath),
                "stored death same-zone bonus should be recomputed from the persisted flag"
            )
            assert.equals(
                (fullMatchBasePoints + SCORE_RULES.sameZoneFixedBonusPoints) * fullMatchMultiplier,
                GrimLogic.GetStoredDeathAwardedPoints(sameZoneDeath),
                "stored death awarded points should include the recomputed same-zone bonus"
            )

            local missingSameZoneFlagDeath = Fixtures.storedDeath({
                sameZoneBonusApplied = nil,
                points = 1,
                awardedPoints = 1,
            })
            assert.equals(
                0,
                GrimLogic.GetStoredDeathSameZoneBonusPoints(missingSameZoneFlagDeath),
                "stored deaths without the persisted same-zone flag should not infer a bonus during recomputation"
            )
        end)
    end)

    describe("persisted and computed contributions", function()
        it("combines persisted and computed death contributions", function()
            local persistedContributionDeath = Fixtures.storedDeath({
                streakMultiplier = 7,
                predictionStreak = 99,
            })
            assert.equals(
                SCORE_RULES.maxStreakBonus,
                GrimLogic.GetStoredDeathStreakMultiplierValue(persistedContributionDeath),
                "stored death streak contribution should be recomputed from score data even when stale values were persisted"
            )

            local partialMatchDeath = Fixtures.storedDeath({
                predictionStreak = 3,
                prediction = Fixtures.prediction({
                    zone = false,
                }),
                zone = "Westfall",
            })
            assert.equals(
                SCORE_RULES.predictionElementBonusByCount[2] or 0,
                GrimLogic.GetStoredDeathComboMultiplierValue(partialMatchDeath),
                "stored death combo multiplier should isolate the non-streak portion for partial wins"
            )
            assert.equals(
                (3 - 1) * SCORE_RULES.streakBonusStep,
                GrimLogic.GetStoredDeathStreakMultiplierValue(partialMatchDeath),
                "stored death streak contribution should be recomputed when no persisted value exists"
            )

            local comboDetails = GrimLogic.GetStoredDeathComboDetails(partialMatchDeath)
            assert.is_truthy(comboDetails.matched, "stored death combo details should reuse the stored death prediction and death row")
            assert.equals(
                GrimLogic.GetStoredDeathAwardedPoints(partialMatchDeath),
                comboDetails.awardedPoints,
                "stored death combo details should match the computed awarded points"
            )

            local sameZonePartialDeath = Fixtures.storedDeath({
                predictionStreak = 3,
                sameZoneBonusApplied = true,
                prediction = Fixtures.prediction(),
            })
            local partialBasePoints = Helpers.getExpectedBasePoints({
                levelRange = "10-19",
                level = 12,
                source = true,
                zone = true,
            })
            local partialMultiplier = (SCORE_RULES.predictionElementBonusByCount[3] or 0)
                + ((3 - 1) * SCORE_RULES.streakBonusStep)
            assert.equals(
                (partialBasePoints + SCORE_RULES.sameZoneFixedBonusPoints) * partialMultiplier,
                GrimLogic.GetStoredDeathAwardedPoints(sameZonePartialDeath),
                "stored death awarded points should include same-zone bonus when the zone prediction matched"
            )
        end)
    end)
end)
