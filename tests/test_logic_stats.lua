local assert = require("luassert")
describe("Statistics", function()
    local LogicTestContext = require("tests.support_logic_test_context")
    local context
    local GrimStats
    local GrimDatabase
    local Fixtures

    before_each(function()
        context = LogicTestContext.Create()
        GrimStats = context.GrimStats
        GrimDatabase = context.GrimDatabase
        Fixtures = context.Fixtures
    end)

    ---@param deaths GrimDeath[]
    ---@return GrimCharacterState
    local function createDatabaseWithHistory(deaths)
        return GrimDatabase.Init({
            deathHistory = deaths,
        })
    end

    ---@param timestamp integer
    ---@param sourceName string|nil|false
    ---@param zone string|nil|false
    ---@param level integer|nil|false
    ---@return GrimDeath
    local function death(timestamp, sourceName, zone, level)
        return Fixtures.storedDeath({
            timestamp = timestamp,
            sourceName = sourceName,
            zone = zone,
            level = level,
        })
    end

    describe("basic statistics", function()
        it("returns nil for empty history", function()
            local database = GrimDatabase.Init({})
            local summary = GrimStats.GetDeathSummary(database)

            assert.is_nil(GrimStats.GetDeadliestSource(database), "empty history should have no deadliest source")
            assert.is_nil(
                GrimStats.GetDeadliestLevelBracket(database),
                "empty history should have no deadliest level bracket"
            )
            assert.is_nil(GrimStats.GetDeadliestLocation(database), "empty history should have no deadliest location")
            assert.equals(0, #GrimStats.GetTopSources(database), "empty history should return no top sources")
            assert.equals(0, summary.sampleSize, "empty summary should report zero samples")
            assert.is_nil(summary.deadliestSource, "empty summary should have no deadliest source")
        end)

        it("uses retained death history for base statistics", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Murloc Forager", "Elwynn Forest", 22),
                death(300, "Hogger", "Westfall", 18),
                death(400, "Murloc Forager", "Elwynn Forest", 27),
            })

            assert.equals(
                "Murloc Forager",
                GrimStats.GetDeadliestSource(database),
                "deadliest source should use count, then latest death as a tie-breaker"
            )
            assert.equals(
                "20-29",
                GrimStats.GetDeadliestLevelBracket(database),
                "deadliest level bracket should use the configured prediction ranges"
            )
            assert.equals(
                "Elwynn Forest",
                GrimStats.GetDeadliestLocation(database),
                "deadliest location should return the most common retained zone"
            )
        end)
    end)

    describe("rankings and missing values", function()
        it("includes counts, percentages, and limits in top statistics", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Murloc Forager", "Elwynn Forest", 22),
                death(300, "Hogger", "Westfall", 18),
                death(400, "Murloc Forager", "Elwynn Forest", 27),
                death(500, "Defias Pillager", "Westfall", 31),
            })
            local sources = GrimStats.GetTopSources(database, 2)
            local brackets = GrimStats.GetTopLevelBrackets(database)

            assert.equals(2, #sources, "top source limit should cap returned rows")
            assert.equals("Murloc Forager", sources[1].label, "top source should honor latest tie-breaks")
            assert.equals(2, sources[1].count, "top source should include its count")
            assert.equals(40, sources[1].percent, "top source should include its share of counted deaths")
            assert.equals(400, sources[1].latestTimestamp, "top source should expose latest timestamp")
            assert.equals("20-29", brackets[1].label, "top brackets should be ranked")
            assert.equals(2, brackets[1].count, "top bracket should include its count")
        end)

        it("ignores missing values", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, false, "Westfall", 18),
                death(300, false, false, 22),
                death(400, "Murloc Forager", "Darkshore", 7),
            })
            local sources = GrimStats.GetTopSources(database)
            local locations = GrimStats.GetTopLocations(database)
            local brackets = GrimStats.GetTopLevelBrackets(database)

            assert.equals(2, #sources, "source stats should ignore missing sources")
            assert.equals(3, #locations, "location stats should ignore only missing locations")
            assert.equals(2, #brackets, "level bracket stats should ignore levels outside configured brackets")
        end)

        it("requires both source and location values for pairs", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Hogger", "Elwynn Forest", 18),
                death(300, "Hogger", false, 18),
                death(400, false, "Elwynn Forest", 18),
                death(500, "Murloc Forager", "Darkshore", 22),
            })
            local pairs = GrimStats.GetTopSourceLocationPairs(database)

            assert.equals(2, #pairs, "source-location pairs should require both source and location")
            assert.equals("Hogger in Elwynn Forest", pairs[1].label, "top pair should combine source and location")
            assert.equals("Hogger", pairs[1].source, "top pair should expose the source")
            assert.equals("Elwynn Forest", pairs[1].location, "top pair should expose the location")
            assert.equals(2, pairs[1].count, "top pair should count matching source-location deaths")
        end)
    end)

    describe("trends and repeats", function()
        it("compares the recent window to older history", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Hogger", "Elwynn Forest", 14),
                death(300, "Hogger", "Elwynn Forest", 18),
                death(400, "Hogger", "Elwynn Forest", 18),
                death(500, "Murloc Forager", "Darkshore", 22),
                death(600, "Murloc Forager", "Darkshore", 24),
                death(700, "Murloc Forager", "Darkshore", 27),
                death(800, "Hogger", "Elwynn Forest", 32),
            })
            local sourceTrends = GrimStats.GetRecentSourceTrends(database, 4)
            local locationTrends = GrimStats.GetRecentLocationTrends(database, 4)
            local bracketTrends = GrimStats.GetRecentLevelBracketTrends(database, 4)

            assert.equals("Murloc Forager", sourceTrends[1].label, "new recent source should lead recent trends")
            assert.equals("new", sourceTrends[1].trend, "source absent from older history should be marked new")
            assert.equals(3, sourceTrends[1].recentCount, "source trend should include recent count")
            assert.equals(0, sourceTrends[1].historicalCount, "source trend should include historical count")
            assert.equals(75, sourceTrends[1].deltaPercent, "source trend should include recent minus historical share")
            assert.equals("Hogger", sourceTrends[2].label, "older dominant source can still appear as cooling")
            assert.equals("cooling", sourceTrends[2].trend, "source with lower recent share should be marked cooling")
            assert.equals("Darkshore", locationTrends[1].label, "recent location trends should use zones")
            assert.equals("20-29", bracketTrends[1].label, "recent bracket trends should use level brackets")
            assert.equals("new", bracketTrends[1].trend, "new recent bracket should be marked new")
        end)

        it("finds recent repeats and clusters", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Defias Pillager", "Westfall", 18),
                death(300, "Murloc Forager", "Darkshore", 22),
                death(400, "Murloc Forager", "Darkshore", 24),
                death(500, "Murloc Raider", "Darkshore", 27),
            })
            local repeatSource = GrimStats.GetRecentRepeatSource(database, 3)
            local repeatLocation = GrimStats.GetRecentRepeatLocation(database, 3)
            local repeatBracket = GrimStats.GetRecentRepeatLevelBracket(database, 3)
            local cluster = GrimStats.GetRecentCluster(database, 3)

            assert.equals("Murloc Forager", repeatSource.label, "recent repeat source should find repeated recent source")
            assert.equals(2, repeatSource.count, "recent repeat source should require more than one hit")
            assert.equals("Darkshore", repeatLocation.label, "recent repeat location should find repeated recent location")
            assert.equals(3, repeatLocation.count, "recent repeat location should count the recent window")
            assert.equals("20-29", repeatBracket.label, "recent repeat bracket should find repeated recent bracket")
            assert.equals("location", cluster.kind, "recent cluster should return the strongest repeated pattern")
            assert.equals("Darkshore", cluster.label, "recent cluster should expose the clustered label")
        end)
    end)

    describe("summaries", function()
        it("combines statistics into a death summary", function()
            local database = createDatabaseWithHistory({
                death(100, "Hogger", "Elwynn Forest", 12),
                death(200, "Hogger", "Elwynn Forest", 18),
                death(300, "Murloc Forager", "Darkshore", 22),
                death(400, "Murloc Forager", "Darkshore", 24),
                death(500, "Murloc Raider", "Darkshore", 27),
            })
            local summary = GrimStats.GetDeathSummary(database, {
                topLimit = 2,
                trendLimit = 1,
                recentWindowSize = 3,
            })

            assert.equals(5, summary.sampleSize, "summary should include retained history sample size")
            assert.equals(3, summary.recentSampleSize, "summary should include recent sample size")
            assert.equals("Darkshore", summary.deadliestLocation.label, "summary should include deadliest location entry")
            assert.equals(2, #summary.topSources, "summary should apply the top stat limit")
            assert.equals(1, #summary.sourceTrends, "summary should apply the trend limit")
            assert.equals("location", summary.recentRepeat.kind, "summary should include strongest recent repeat pattern")
        end)

        it("keeps the most notable trend outside the trend limit", function()
            local database = createDatabaseWithHistory({
                death(100, "Source A", "Elwynn Forest", 22),
                death(200, "Source A", "Elwynn Forest", 22),
                death(300, "Source A", "Elwynn Forest", 22),
                death(400, "Source A", "Elwynn Forest", 22),
                death(500, "Source A", "Elwynn Forest", 22),
                death(600, "Source A", "Elwynn Forest", 22),
                death(700, "Source A", "Elwynn Forest", 22),
                death(800, "Source A", "Elwynn Forest", 22),
                death(900, "Source A", "Elwynn Forest", 22),
                death(1000, "Source B", "Elwynn Forest", 22),
                death(1100, "Source A", "Elwynn Forest", 22),
                death(1200, "Source B", "Elwynn Forest", 22),
                death(1300, "Source B", "Elwynn Forest", 22),
                death(1400, "Source C", "Elwynn Forest", 22),
                death(1500, "Source C", "Elwynn Forest", 22),
            })
            local summary = GrimStats.GetDeathSummary(database, {
                trendLimit = 1,
                recentWindowSize = 5,
            })

            assert.equals("Source C", summary.sourceTrends[1].label, "limited source trends should still keep top positive movement")
            assert.equals("new", summary.sourceTrends[1].trend, "limited source trends should preserve existing ranking behavior")
            assert.equals("Source A", summary.recentTrend.label, "summary should keep the largest movement for the compact trend line")
            assert.equals("cooling", summary.recentTrend.trend, "summary should allow a cooling trend to surface")
        end)
    end)
end)
