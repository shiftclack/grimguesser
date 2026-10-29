local assert = require("luassert")
describe("Prediction logic", function()
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

    describe("level scoring", function()
        it("defines level ranges", function()
            assert.is_truthy(GrimLogic.IsLevelInRange(10, "10-19"), "10 should fall in the 10-19 range")
            assert.equals(false, GrimLogic.IsLevelInRange(20, "10-19"), "20 should not fall in the 10-19 range")
            assert.is_truthy(GrimLogic.IsLevelInRange(60, "60"), "60 should match the capped 60 range")
            assert.equals(
                "20-29",
                GrimLogic.GetLevelRangeForLevel(27),
                "level range lookup should return the configured bucket label"
            )
            assert.equals(
                nil,
                GrimLogic.GetLevelRangeForLevel(9),
                "level range lookup should return nil for levels outside configured buckets"
            )
        end)

        it("assigns level point tiers", function()
            local cases = {
                { level = 9, points = 0, label = "levels below 10 should not award level points" },
            }

            for _, levelRange in ipairs(SCORE_RULES.levelRanges) do
                local level = Helpers.getRepresentativeLevelForRange(levelRange)
                cases[#cases + 1] = {
                    level = level,
                    points = SCORE_RULES.levelPointMode == "fixedRange"
                        and (tonumber(SCORE_RULES.fixedLevelRangePoints[levelRange]) or 0)
                        or level,
                    label = levelRange .. " should award the configured level points for a matched death",
                }
            end

            for _, case in ipairs(cases) do
                assert.equals(case.points, GrimLogic.GetLevelPointsForLevel(case.level), case.label)
            end
        end)

        it("assigns level-range point tiers", function()
            local cases = {
                { levelRange = nil, points = 0, label = "missing level ranges should award zero preview points" },
            }

            for _, levelRange in ipairs(SCORE_RULES.levelRanges) do
                local expectedPoints

                if SCORE_RULES.levelPointMode == "fixedRange" then
                    expectedPoints = tonumber(SCORE_RULES.fixedLevelRangePoints[levelRange]) or 0
                elseif levelRange == "60" then
                    expectedPoints = 60
                else
                    expectedPoints = tonumber(string.match(levelRange, "^(%d+)%-%d+$")) or 0
                end

                cases[#cases + 1] = {
                    levelRange = levelRange,
                    points = expectedPoints,
                    label = levelRange .. " should preview the configured base points for that range",
                }
            end

            for _, case in ipairs(cases) do
                assert.equals(case.points, GrimLogic.GetLevelPointsForRange(case.levelRange), case.label)
            end
        end)

        it("uses fixed points for configured level ranges", function()
            SCORE_RULES.levelPointMode = "fixedRange"
            SCORE_RULES.fixedLevelRangePoints["50-59"] = 77

            assert.equals(
                77,
                GrimLogic.GetLevelPointsForLevel(58),
                "fixed-range mode should use the configured bucket points for matched deaths"
            )
            assert.equals(
                77,
                GrimLogic.GetLevelPointsForRange("50-59"),
                "fixed-range mode should use the configured bucket points for previews"
            )
        end)
    end)

    describe("formatting", function()
        it("formats predictions", function()
            assert.equals(
                "Prediction not locked in yet.",
                GrimLogic.FormatLockedPrediction(nil),
                "empty prediction should have the placeholder summary"
            )

            assert.equals(
                "Level 20-29, source Hogger, or zone Elwynn Forest.",
                GrimLogic.FormatLockedPrediction(Fixtures.prediction({
                    levelRange = "20-29",
                })),
                "locked prediction should render labels directly"
            )

            assert.equals(
                "Level none, source none, or zone none.",
                GrimLogic.FormatLockedPrediction(Fixtures.prediction({
                    levelRange = false,
                    source = false,
                    zone = false,
                })),
                "locked prediction should show that level can be intentionally unset"
            )
        end)
    end)

    describe("normalization and helpers", function()
        it("normalizes prediction values", function()
            assert.equals(
                "hogger",
                GrimLogic.NormalizePredictionValue("Hogger", "No Source Prediction"),
                "prediction normalization should lowercase real values"
            )
            assert.equals(
                "hogger",
                GrimLogic.NormalizePredictionValue("  Hogger  ", "No Source Prediction"),
                "prediction normalization should trim real values"
            )
            assert.equals(
                nil,
                GrimLogic.NormalizePredictionValue("No Source Prediction", "No Source Prediction"),
                "prediction normalization should treat the placeholder as unset"
            )
            assert.equals(
                nil,
                GrimLogic.NormalizePredictionValue("  No Source Prediction  ", "No Source Prediction"),
                "prediction normalization should trim placeholders before treating them as unset"
            )
            assert.equals(
                "Elwynn Forest",
                GrimLogic.ToDisplayText("elwynn forest"),
                "display text should title-case lowercase values"
            )
        end)

        it("provides prediction helper utilities", function()
            assert.equals(
                3,
                GrimLogic.GetSelectedPredictionCount(Fixtures.prediction()),
                "selected prediction helper should count all chosen fields"
            )
            assert.equals(
                1,
                GrimLogic.GetSelectedPredictionCount(Fixtures.prediction({
                    levelRange = false,
                    zone = false,
                    zoneLabel = false,
                })),
                "selected prediction helper should ignore omitted fields"
            )
            assert.equals(
                2,
                GrimLogic.GetMatchedPredictionCount({
                    levelMatched = true,
                    sourceMatched = true,
                    zoneMatched = false,
                }),
                "matched prediction helper should count only matched fields"
            )
            assert.equals(
                0,
                GrimLogic.GetMatchedPredictionCount(nil),
                "matched prediction helper should default nil evaluations to zero"
            )
            assert.is_truthy(
                GrimLogic.ArePredictionsEquivalent(
                    Fixtures.prediction(),
                    Fixtures.prediction()
                ),
                "prediction equivalence should treat identical normalized predictions as equal"
            )
            assert.equals(
                false,
                GrimLogic.ArePredictionsEquivalent(
                    Fixtures.prediction(),
                    Fixtures.prediction({ source = "defias", sourceLabel = "Defias" })
                ),
                "prediction equivalence should detect changed prediction fields"
            )
        end)
    end)
end)
