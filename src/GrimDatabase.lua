---@class GrimFrameAnchor
---@field point string
---@field relativePoint string
---@field x number
---@field y number

---@class GrimMinimapSettings
---@field hide boolean

---@class GrimAnnouncementSettings
---@field enabled boolean
---@field announceScoreOnDeath boolean
---@field announceScoreOnLevelUp boolean

---@class GrimPredictionElements
---@field levelRange string|nil
---@field source string|nil
---@field zone string|nil

---@class GrimPrediction
---@field elements GrimPredictionElements
---@field lockedAt integer|nil

---@class GrimDeath
---@field timestamp integer
---@field name string
---@field level integer
---@field causeType string|nil
---@field sourceName string|nil
---@field zone string|nil
---@field server string|nil
---@field sourceMessage string|nil
---@field prediction GrimPrediction|nil
---@field matchedPrediction boolean|nil
---@field points integer|nil
---@field streakMultiplier integer|nil
---@field awardedPoints integer|nil
---@field predictionStreak integer|nil
---@field sameZoneBonusApplied boolean|nil

---@class GrimCharacterState
---@field databaseVersion integer
---@field hidden boolean
---@field hasSeenIntroDemo boolean
---@field hasSeenFirstRun boolean
---@field logWindowShown boolean
---@field historySuccessfulOnly boolean
---@field announcements GrimAnnouncementSettings
---@field showInCombat boolean
---@field collapsed boolean
---@field collapsedWindowHeight integer|nil
---@field recentDeaths GrimDeath[]
---@field deathHistory GrimDeath[]
---@field successfullyPredictedDeaths GrimDeath[]
---@field lockedPrediction GrimPrediction|nil
---@field draftPrediction GrimPrediction|nil
---@field lastPrediction GrimPrediction|nil
---@field totalPoints integer
---@field correctPredictionStreak integer
---@field longestPredictionStreak integer
---@field minimap GrimMinimapSettings
---@field windowPosition GrimFrameAnchor|nil
---@field collapsedWindowPosition GrimFrameAnchor|nil

local _, ns = ...
---@cast ns GrimNamespace

local GrimDatabase = ns.GrimDatabase or {}
ns.GrimDatabase = GrimDatabase
GrimDatabase.DEFAULTS = {
    hidden = true,
    hasSeenIntroDemo = false,
    hasSeenFirstRun = false,
    logWindowShown = false,
    historySuccessfulOnly = true,
    announcements = {
        enabled = false,
        announceScoreOnDeath = true,
        announceScoreOnLevelUp = false,
    },
    showInCombat = false,
    collapsed = false,
    recentDeaths = {},
    deathHistory = {},
    successfullyPredictedDeaths = {},
    draftPrediction = nil,
    totalPoints = 0,
    correctPredictionStreak = 0,
    longestPredictionStreak = 0,
}

---@param database table
---@param key string
---@return table
local function EnsureTableField(database, key)
    if type(database[key]) ~= "table" then
        database[key] = {}
    end

    return database[key]
end

---@param value any
---@return any
local function CloneValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = CloneValue(nestedValue)
    end

    return copy
end

---@param database table
---@return GrimAnnouncementSettings
local function EnsureAnnouncements(database)
    local announcements = EnsureTableField(database, "announcements")

    if announcements.enabled == nil then
        announcements.enabled = GrimDatabase.DEFAULTS.announcements.enabled
    else
        announcements.enabled = announcements.enabled == true
    end
    announcements.announceScoreOnDeath = announcements.announceScoreOnDeath ~= false
    announcements.announceScoreOnLevelUp = announcements.announceScoreOnLevelUp ~= false
    announcements.levelUpFrequency = nil

    return announcements
end

---@param database table
local function EnsureDatabaseVersion(database)
    database.databaseVersion = tonumber(database.databaseVersion) or 0
end

--- if database is nil one will be returned with default values
--- also try to fix any corrupt or missing fields
--- any state initialization that needs to happen before migrations should go here
---@param database GrimCharacterState|table|nil
---@return GrimCharacterState
local function EnsureDatabase(database)
    if type(database) ~= "table" then
        ---@diagnostic disable-next-line: missing-fields
        database = {}
    end

    -- This mutates the provided table in place and preserves identity.
    for fieldName, defaultValue in pairs(GrimDatabase.DEFAULTS) do
        if database[fieldName] == nil then
            database[fieldName] = CloneValue(defaultValue)
        end
    end

    EnsureTableField(database, "recentDeaths")
    EnsureTableField(database, "deathHistory")
    EnsureTableField(database, "successfullyPredictedDeaths")
    EnsureTableField(database, "minimap")
    EnsureAnnouncements(database)
    EnsureDatabaseVersion(database)

    -- Debug mode is session-only and should not remain in SavedVariables.
    database.debugEnabled = nil

    database.totalPoints = tonumber(database.totalPoints) or 0
    database.correctPredictionStreak = tonumber(database.correctPredictionStreak) or 0
    database.longestPredictionStreak = tonumber(database.longestPredictionStreak) or 0

    return database
end

---@param database GrimCharacterState|nil
---@return GrimCharacterState
function GrimDatabase.Init(database)
    local migration = ns.GrimMigration
    database = EnsureDatabase(database)
    database = migration.Apply(database)
    return database
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetHidden(database)
    return database.hidden == true
end

---@param database GrimCharacterState
---@param hidden boolean
---@return boolean
function GrimDatabase.SetHidden(database, hidden)
    database.hidden = hidden == true
    return database.hidden
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetHasSeenIntroDemo(database)
    return database.hasSeenIntroDemo == true
end

---@param database GrimCharacterState
---@param seen boolean
---@return boolean
function GrimDatabase.SetHasSeenIntroDemo(database, seen)
    database.hasSeenIntroDemo = seen == true
    return database.hasSeenIntroDemo
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetHasSeenFirstRun(database)
    return database.hasSeenFirstRun == true
end

---@param database GrimCharacterState
---@param seen boolean
---@return boolean
function GrimDatabase.SetHasSeenFirstRun(database, seen)
    database.hasSeenFirstRun = seen == true
    return database.hasSeenFirstRun
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetLogWindowShown(database)
    return database.logWindowShown == true
end

---@param database GrimCharacterState
---@param shown boolean
---@return boolean
function GrimDatabase.SetLogWindowShown(database, shown)
    database.logWindowShown = shown == true
    return database.logWindowShown
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetHistorySuccessfulOnly(database)
    return database.historySuccessfulOnly ~= false
end

---@param database GrimCharacterState
---@param successfulOnly boolean
---@return boolean
function GrimDatabase.SetHistorySuccessfulOnly(database, successfulOnly)
    database.historySuccessfulOnly = successfulOnly == true
    return database.historySuccessfulOnly
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetAnnounceDeathToGuild(database)
    return database.announcements.announceScoreOnDeath == true
end

---@param database GrimCharacterState
---@param enabled boolean
---@return boolean
function GrimDatabase.SetAnnounceDeathToGuild(database, enabled)
    database.announcements.announceScoreOnDeath = enabled == true
    return database.announcements.announceScoreOnDeath
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetAnnounceScoreOnLevelUp(database)
    return database.announcements.announceScoreOnLevelUp == true
end

---@param database GrimCharacterState
---@param enabled boolean
---@return boolean
function GrimDatabase.SetAnnounceScoreOnLevelUp(database, enabled)
    database.announcements.announceScoreOnLevelUp = enabled == true
    return database.announcements.announceScoreOnLevelUp
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetGuildAnnouncementsEnabled(database)
    return database.announcements.enabled == true
end

---@param database GrimCharacterState
---@param enabled boolean
---@return boolean
function GrimDatabase.SetGuildAnnouncementsEnabled(database, enabled)
    database.announcements.enabled = enabled == true
    return database.announcements.enabled
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetShowInCombat(database)
    return database.showInCombat == true
end

---@param database GrimCharacterState
---@param enabled boolean
---@return boolean
function GrimDatabase.SetShowInCombat(database, enabled)
    database.showInCombat = enabled == true
    return database.showInCombat
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetCollapsed(database)
    return database.collapsed == true
end

---@param database GrimCharacterState
---@param collapsed boolean
---@return boolean
function GrimDatabase.SetCollapsed(database, collapsed)
    database.collapsed = collapsed == true
    return database.collapsed
end

---@param database GrimCharacterState
---@return integer|nil
function GrimDatabase.GetCollapsedWindowHeight(database)
    local height = tonumber(database.collapsedWindowHeight)
    if height == nil or height <= 0 then
        return nil
    end

    return height
end

---@param database GrimCharacterState
---@param height integer
---@return integer
function GrimDatabase.SetCollapsedWindowHeight(database, height)
    database.collapsedWindowHeight = tonumber(height)
    return database.collapsedWindowHeight
end

---@param database GrimCharacterState
---@return GrimPrediction|nil
function GrimDatabase.GetLockedPrediction(database)
    return database.lockedPrediction
end

---@param database GrimCharacterState
---@param prediction GrimPrediction|nil
---@return GrimPrediction|nil
function GrimDatabase.SetLockedPrediction(database, prediction)
    database.lockedPrediction = prediction
    return database.lockedPrediction
end

---@param database GrimCharacterState
---@return GrimPrediction|nil
function GrimDatabase.GetLastPrediction(database)
    return database.lastPrediction
end

---@param database GrimCharacterState
---@param prediction GrimPrediction|nil
---@return GrimPrediction|nil
function GrimDatabase.SetLastPrediction(database, prediction)
    database.lastPrediction = prediction
    return database.lastPrediction
end

---@param database GrimCharacterState
---@return GrimPrediction|nil
function GrimDatabase.GetDraftPrediction(database)
    return database.draftPrediction
end

---@param database GrimCharacterState
---@param prediction GrimPrediction|nil
---@return GrimPrediction|nil
function GrimDatabase.SetDraftPrediction(database, prediction)
    database.draftPrediction = prediction
    return database.draftPrediction
end

---@param database GrimCharacterState
---@return GrimDeath[]
function GrimDatabase.GetRecentDeaths(database)
    return EnsureTableField(database, "recentDeaths")
end

---@param database GrimCharacterState
---@return GrimDeath[]
function GrimDatabase.GetDeathHistory(database)
    return EnsureTableField(database, "deathHistory")
end

---@param database GrimCharacterState
---@param fieldName string
---@return string[]
local function GetUniqueDeathHistoryValues(database, fieldName)
    local values = {}
    local seenValues = {}

    for _, death in ipairs(GrimDatabase.GetDeathHistory(database)) do
        if type(death) == "table" and type(death[fieldName]) == "string" then
            local value = death[fieldName]
            if not seenValues[value] then
                seenValues[value] = true
                values[#values + 1] = value
            end
        end
    end

    table.sort(values)

    return values
end

---@param database GrimCharacterState
---@return string[]
function GrimDatabase.GetDeathHistorySourceNames(database)
    return GetUniqueDeathHistoryValues(database, "sourceName")
end

---@param database GrimCharacterState
---@return string[]
function GrimDatabase.GetDeathHistoryZones(database)
    return GetUniqueDeathHistoryValues(database, "zone")
end

---@param database GrimCharacterState
---@return GrimDeath[]
function GrimDatabase.GetSuccessfullyPredictedDeaths(database)
    return EnsureTableField(database, "successfullyPredictedDeaths")
end

---@param database GrimCharacterState
---@return GrimCharacterState
function GrimDatabase.ResetGameplayState(database)
    database.correctPredictionStreak = 0
    database.draftPrediction = nil
    database.lastPrediction = nil
    database.lockedPrediction = nil
    database.longestPredictionStreak = 0
    database.totalPoints = 0
    wipe(EnsureTableField(database, "recentDeaths"))
    wipe(EnsureTableField(database, "deathHistory"))
    wipe(EnsureTableField(database, "successfullyPredictedDeaths"))
    return database
end

---@param database GrimCharacterState
---@return GrimCharacterState
function GrimDatabase.ResetAllState(database)
    wipe(database)
    EnsureDatabase(database)
    return database
end

---@param database GrimCharacterState
---@return integer
function GrimDatabase.GetTotalPoints(database)
    return tonumber(database.totalPoints) or 0
end

---@param database GrimCharacterState
---@param points number
---@return integer
function GrimDatabase.SetTotalPoints(database, points)
    database.totalPoints = tonumber(points) or 0
    return database.totalPoints
end

---@param database GrimCharacterState
---@return integer
function GrimDatabase.GetCorrectPredictionStreak(database)
    return tonumber(database.correctPredictionStreak) or 0
end

---@param database GrimCharacterState
---@param streak number
---@return integer
function GrimDatabase.SetCorrectPredictionStreak(database, streak)
    database.correctPredictionStreak = tonumber(streak) or 0
    return database.correctPredictionStreak
end

---@param database GrimCharacterState
---@return integer
function GrimDatabase.GetLongestPredictionStreak(database)
    return tonumber(database.longestPredictionStreak) or 0
end

---@param database GrimCharacterState
---@param streak number
---@return integer
function GrimDatabase.SetLongestPredictionStreak(database, streak)
    database.longestPredictionStreak = tonumber(streak) or 0
    return database.longestPredictionStreak
end

---@param database GrimCharacterState
---@return GrimMinimapSettings
function GrimDatabase.GetMinimapSettings(database)
    local minimap = EnsureTableField(database, "minimap")
    if minimap.hide == nil then
        minimap.hide = false
    end

    return minimap
end

---@param database GrimCharacterState
---@return boolean
function GrimDatabase.GetMinimapHidden(database)
    return GrimDatabase.GetMinimapSettings(database).hide == true
end

---@param database GrimCharacterState
---@param hidden boolean
---@return boolean
function GrimDatabase.SetMinimapHidden(database, hidden)
    local minimap = GrimDatabase.GetMinimapSettings(database)
    minimap.hide = hidden == true
    return minimap.hide
end

---@param database GrimCharacterState
---@param collapsed boolean|nil
---@return GrimFrameAnchor|nil
function GrimDatabase.GetWindowPosition(database, collapsed)
    if collapsed == true then
        return database.collapsedWindowPosition
    end

    return database.windowPosition
end

---@param database GrimCharacterState
---@param collapsed boolean|nil
---@param anchor GrimFrameAnchor|nil
---@return GrimFrameAnchor|nil
function GrimDatabase.SetWindowPosition(database, collapsed, anchor)
    if collapsed == true then
        database.collapsedWindowPosition = anchor
    else
        database.windowPosition = anchor
    end

    return anchor
end

return GrimDatabase
