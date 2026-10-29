local FixtureFactory = {}

---@param GrimConstants table
---@param GrimDatabase table
---@return table
function FixtureFactory.Create(GrimConstants, GrimDatabase)
local Fixtures = {}
local SCORE_RULES = GrimConstants.SCORING
local DATABASE_DEFAULTS = GrimDatabase.DEFAULTS or {}

local function cloneValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = cloneValue(nestedValue)
    end

    return copy
end

local function isLevelMatched(options)
    if options.levelMatched ~= nil then
        return options.levelMatched == true
    end

    if options.levelRange == nil or options.level == nil then
        return false
    end

    local numericLevel = tonumber(options.level)
    if not numericLevel then
        return false
    end

    if options.levelRange == "60" then
        return numericLevel == 60
    end

    local minLevel, maxLevel = string.match(options.levelRange, "^(%d+)%-(%d+)$")
    minLevel = tonumber(minLevel)
    maxLevel = tonumber(maxLevel)

    return minLevel ~= nil and maxLevel ~= nil and numericLevel >= minLevel and numericLevel <= maxLevel
end

local function getLevelPoints(levelRange, level)
    if levelRange == nil then
        return 0
    end

    if SCORE_RULES.levelPointMode == "fixedRange" then
        return tonumber(SCORE_RULES.fixedLevelRangePoints[levelRange]) or 0
    end

    return tonumber(level) or 0
end

local function getBasePoints(options)
    local basePoints = 0
    local levelMatched = isLevelMatched(options)

    if options.levelRange ~= nil and levelMatched then
        basePoints = basePoints + getLevelPoints(options.levelRange, options.level)
    end

    if options.source == true and not levelMatched then
        basePoints = basePoints + SCORE_RULES.fixedElementPoints.source
    end

    if options.zone == true and not levelMatched then
        basePoints = basePoints + SCORE_RULES.fixedElementPoints.zone
    end

    return basePoints
end

local function getDisplayMultiplier(matchCount, streak)
    if matchCount == nil or matchCount <= 0 then
        return 0
    end

    local streakBonus = math.min(
        math.max((tonumber(streak) or 0) - 1, 0) * (tonumber(SCORE_RULES.streakBonusStep) or 1),
        SCORE_RULES.maxStreakBonus
    )

    local comboTotal = SCORE_RULES.predictionElementBonusByCount[matchCount] or 0

    return math.max(comboTotal + streakBonus, 1)
end

local function merge(defaults, overrides)
    local result = {}

    for key, value in pairs(defaults or {}) do
        result[key] = value
    end

    for key, value in pairs(overrides or {}) do
        result[key] = value
    end

    return result
end

local function normalizeFalseAsNil(values, allowedFalseKeys)
    -- Tests use false as a readable "explicitly unset this default field" marker.
    allowedFalseKeys = allowedFalseKeys or {}

    for key, value in pairs(values) do
        if value == false and allowedFalseKeys[key] ~= true then
            values[key] = nil
        end
    end

    return values
end

local function buildDatabaseFixture(overrides)
    local database = cloneValue(DATABASE_DEFAULTS)
    database.lockedPrediction = nil
    database.draftPrediction = nil
    database.lastPrediction = nil

    return merge(database, overrides)
end

function Fixtures.prediction(overrides)
    local prediction = {
        elements = {
            levelRange = "10-19",
            source = "hogger",
            zone = "elwynn forest",
        },
        lockedAt = 12345,
    }

    overrides = overrides or {}

    if overrides.elements ~= nil then
        for key, value in pairs(overrides.elements) do
            if value == false then
                prediction.elements[key] = nil
            else
                prediction.elements[key] = value
            end
        end
        overrides.elements = nil
    end

    for _, key in ipairs({ "levelRange", "source", "zone" }) do
        if overrides[key] == false then
            prediction.elements[key] = nil
            overrides[key] = nil
        elseif overrides[key] ~= nil then
            prediction.elements[key] = overrides[key]
            overrides[key] = nil
        end
    end

    return normalizeFalseAsNil(merge(prediction, overrides))
end

function Fixtures.death(overrides)
    return normalizeFalseAsNil(merge({
        timestamp = os.time(),
        name = "Drakedog",
        level = 12,
        causeType = "HARDCORE_CAUSEOFDEATH_CREATURE",
        sourceName = "Hogger",
        zone = "Elwynn Forest",
        server = "Defias Pillager",
        sourceMessage = "[Drakedog] has been slain by Hogger in Elwynn Forest! They were level 12",
        isBlizzardVerified = true,
    }, overrides))
end

function Fixtures.database(overrides)
    return normalizeFalseAsNil(buildDatabaseFixture(overrides), {
        hidden = true,
        hasSeenIntroDemo = true,
        hasSeenFirstRun = true,
        logWindowShown = true,
        historySuccessfulOnly = true,
        showInCombat = true,
        collapsed = true,
    })
end

function Fixtures.storedDeath(overrides)
    local defaultBasePoints = getBasePoints({
        levelRange = "10-19",
        level = 12,
        source = true,
        zone = true,
    })
    local defaultMultiplier = getDisplayMultiplier(3, 1)

    return normalizeFalseAsNil(merge({
        timestamp = 12345,
        name = "Drakedog",
        level = 12,
        sourceName = "Hogger",
        zone = "Elwynn Forest",
        server = "Defias Pillager",
        sourceMessage = "Drakedog was slain by Hogger",
        points = defaultBasePoints,
        awardedPoints = defaultBasePoints * defaultMultiplier,
        matchedPrediction = true,
        predictionStreak = 1,
        causeType = "HARDCORE_CAUSEOFDEATH_CREATURE",
        prediction = {
            elements = {
                levelRange = "10-19",
                source = "hogger",
                zone = "elwynn forest",
            },
            lockedAt = 12345,
        },
    }, overrides), {
        matchedPrediction = true,
        isBlizzardVerified = true,
    })
end

function Fixtures.uiDatabase(overrides)
    local database = merge(buildDatabaseFixture(), {
        totalPoints = 1066,
        correctPredictionStreak = 2,
        longestPredictionStreak = 5,
        lockedPrediction = Fixtures.prediction({
            levelRange = "20-29",
        }),
    })

    return normalizeFalseAsNil(merge(database, overrides), {
        hidden = true,
        hasSeenIntroDemo = true,
        hasSeenFirstRun = true,
        logWindowShown = true,
        historySuccessfulOnly = true,
        showInCombat = true,
        collapsed = true,
    })
end

function Fixtures.addonDatabase(overrides)
    return normalizeFalseAsNil(merge(buildDatabaseFixture(), overrides), {
        hidden = true,
        hasSeenIntroDemo = true,
        hasSeenFirstRun = true,
        logWindowShown = true,
        historySuccessfulOnly = true,
        showInCombat = true,
        collapsed = true,
    })
end

function Fixtures.addDeathOptions(overrides)
    return normalizeFalseAsNil(merge({
        maxRecentDeaths = GrimConstants.STORAGE.maxRecentDeaths,
        maxSuccessfullyPredictedDeaths = GrimConstants.STORAGE.maxSuccessfullyPredictedDeaths,
    }, overrides))
end

function Fixtures.introDemoState(overrides)
    local database = Fixtures.database({
        totalPoints = 1580,
        correctPredictionStreak = 2,
        longestPredictionStreak = 3,
        lockedPrediction = Fixtures.prediction({
            levelRange = "60",
            source = "blackhand elite",
            zone = "upper blackrock spire",
        }),
        recentDeaths = {
            Fixtures.storedDeath({
                timestamp = 1001,
                name = "Leeroy",
                level = 60,
                sourceName = "Blackhand Elite",
                zone = "Upper Blackrock Spire",
                points = 0,
                multiplierValue = 0,
                awardedPoints = 0,
                matchedPrediction = false,
                prediction = false,
                predictionStreak = false,
            }),
            Fixtures.storedDeath({
                timestamp = 1002,
                name = "Ming",
                points = getBasePoints({
                    levelRange = "10-19",
                    level = 12,
                }),
                multiplierValue = getDisplayMultiplier(1, 1),
                awardedPoints = getBasePoints({
                    levelRange = "10-19",
                    level = 12,
                }) * getDisplayMultiplier(1, 1),
                prediction = {
                    elements = {
                        levelRange = "10-19",
                    },
                    lockedAt = 1001,
                },
                predictionStreak = 1,
            }),
            Fixtures.storedDeath({
                timestamp = 1003,
                name = "Drakedog",
                level = 19,
                sourceName = "Defias Pillager",
                zone = "Westfall",
                points = getBasePoints({
                    levelRange = "10-19",
                    level = 19,
                    source = true,
                    zone = true,
                }),
                multiplierValue = getDisplayMultiplier(3, 2),
                awardedPoints = getBasePoints({
                    levelRange = "10-19",
                    level = 19,
                    source = true,
                    zone = true,
                }) * getDisplayMultiplier(3, 2),
                prediction = {
                    elements = {
                        levelRange = "10-19",
                        source = "defias pillager",
                        zone = "westfall",
                    },
                    lockedAt = 1002,
                },
                predictionStreak = 2,
            }),
            Fixtures.storedDeath({
                timestamp = 1004,
                name = "Alamo",
                level = 20,
                sourceName = "Lurking Owlbeast",
                zone = "Moonglade",
                points = getBasePoints({
                    levelRange = "20-29",
                    level = 20,
                }),
                multiplierValue = getDisplayMultiplier(1, 2),
                awardedPoints = getBasePoints({
                    levelRange = "20-29",
                    level = 20,
                }) * getDisplayMultiplier(1, 2),
                prediction = {
                    elements = {
                        levelRange = "20-29",
                    },
                    lockedAt = 1003,
                },
                predictionStreak = 2,
            }),
            Fixtures.storedDeath({
                timestamp = 1005,
                name = "Shiftclack",
                level = 18,
                sourceName = "Benny Blaanco",
                zone = "Westfall",
                points = getBasePoints({
                    source = true,
                    zone = true,
                }),
                multiplierValue = getDisplayMultiplier(2, 1),
                awardedPoints = getBasePoints({
                    source = true,
                    zone = true,
                }) * getDisplayMultiplier(2, 1),
                prediction = {
                    elements = {
                        source = "benny blaanco",
                        zone = "westfall",
                    },
                    lockedAt = 1004,
                },
                predictionStreak = 1,
            }),
        },
    })

    database.draftPrediction = database.lockedPrediction
    database.lastPrediction = database.lockedPrediction

    return normalizeFalseAsNil(merge(database, overrides))
end

return Fixtures
end

return FixtureFactory
