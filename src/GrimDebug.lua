---@alias GrimDebugDeathLike GrimDeath|GrimDeathEvent

---@class GrimDebugDatabaseApi
---@field GetTotalPoints fun(database: GrimCharacterState): integer
---@field GetCorrectPredictionStreak fun(database: GrimCharacterState): integer
---@field GetLongestPredictionStreak fun(database: GrimCharacterState): integer
---@field GetLockedPrediction fun(database: GrimCharacterState): any
---@field GetRecentDeaths fun(database: GrimCharacterState): GrimDeath[]

---@class GrimDebugFrame
---@field Show fun(self: GrimDebugFrame)
---@field Hide fun(self: GrimDebugFrame)
---@field RefreshLatestDeathDetails fun(self: GrimDebugFrame, death: GrimDebugDeathLike|nil, state: table)|nil

---@class GrimDebugAddonFrame
---@field HandleBlizzardDeathMessage fun(self: GrimDebugAddonFrame, message: string): boolean

local _, ns = ...
---@cast ns GrimNamespace

local GrimDebug = ns.GrimDebug or {}
local GrimDebugState = ns.GrimDebugState or {}
ns.GrimDebug = GrimDebug
ns.GrimDebugState = GrimDebugState

---@type GrimCharacterState|nil
local activeState = nil
---@type GrimDebugDatabaseApi|nil
local activeDatabaseApi = nil
---@type GrimPrint
local Print = function() end
---@type GrimDebugFrame|nil
local activeDebugFrame = nil
---@type GrimDebugAddonFrame|nil
local activeAddonFrame = nil
local debugEnabled = false

---@param addonFrame GrimDebugAddonFrame
---@param state GrimCharacterState
---@param databaseApi GrimDebugDatabaseApi
---@param debugFrame GrimDebugFrame|nil
---@param printMessage GrimPrint
function GrimDebug.Initialize(addonFrame, state, databaseApi, debugFrame, printMessage)
    activeAddonFrame = addonFrame
    activeState = state
    activeDatabaseApi = databaseApi
    activeDebugFrame = debugFrame
    Print = printMessage
    debugEnabled = false
end

---@return boolean
function GrimDebugState.IsEnabled()
    return debugEnabled == true
end

---@param enabled boolean|nil
---@return boolean
function GrimDebugState.SetEnabled(enabled)
    debugEnabled = enabled == true
    return debugEnabled
end

---@return boolean
function GrimDebugState.Toggle()
    return GrimDebugState.SetEnabled(not GrimDebugState.IsEnabled())
end

---@param message any
function GrimDebug.Print(message)
    if not GrimDebugState.IsEnabled() then
        return
    end

    GrimDebug.Log(message)
end

function GrimDebug.Log(...)
    if not GrimDebugState.IsEnabled() then
        return
    end

    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end

    Print(table.concat(parts, " "))
end

---@param death GrimDebugDeathLike|nil
function GrimDebug.DebugDeathData(death)
    if not death then
        GrimDebug.Print("death was nil")
        return
    end

    local message = string.format(
        "Death debug: timestamp=%s, name=%s, level=%s, "
            .. "causeType=%s, sourceName=%s, zone=%s, server=%s, sourceMessage=%s, ",
        tostring(death.timestamp or "-"),
        tostring(death.name or "-"),
        tostring(death.level or "-"),
        tostring(death.causeType or "-"),
        tostring(death.sourceName or "-"),
        tostring(death.zone or "-"),
        tostring(death.server or "-"),
        tostring(death.sourceMessage or "-")
    )

    GrimDebug.Print(message)
end

---@param death GrimDebugDeathLike|nil
function GrimDebug.RefreshLatestDeathDetails(death)
    local GrimDatabase = activeDatabaseApi
    local state = activeState
    local debugFrame = activeDebugFrame
    if type(GrimDatabase) ~= "table" or type(state) ~= "table" then
        return
    end

    if debugFrame and debugFrame.RefreshLatestDeathDetails then
        debugFrame:RefreshLatestDeathDetails(death, {
            totalPoints = GrimDatabase.GetTotalPoints(state),
            currentPredictionStreak = GrimDatabase.GetCorrectPredictionStreak(state),
            longestPredictionStreak = GrimDatabase.GetLongestPredictionStreak(state),
            lockedPrediction = GrimDatabase.GetLockedPrediction(state),
        })
    end
end

function GrimDebug.RefreshFromRecentDeaths()
    local GrimDatabase = activeDatabaseApi
    local state = activeState
    if type(GrimDatabase) ~= "table" or type(state) ~= "table" then
        return
    end

    local recentDeaths = GrimDatabase.GetRecentDeaths(state)
    GrimDebug.RefreshLatestDeathDetails(recentDeaths and recentDeaths[#recentDeaths])
end

function GrimDebug.ApplyWindowVisibility()
    local debugFrame = activeDebugFrame
    if not debugFrame then
        return
    end

    if GrimDebugState.IsEnabled() then
        debugFrame:Show()
        return
    end

    debugFrame:Hide()
end

function GrimDebug.HandleDeathAdded()
    GrimDebug.RefreshFromRecentDeaths()
end

function GrimDebug.OnAddonLoaded()
    GrimDebug.RefreshFromRecentDeaths()
end

function GrimDebug.ToggleDebugCommand()
    local isEnabled = GrimDebugState.Toggle()

    if isEnabled then
        GrimDebug.RefreshFromRecentDeaths()
        GrimDebug.ApplyWindowVisibility()
        Print("Debug mode enabled.")
        return
    end

    GrimDebug.ApplyWindowVisibility()
    Print("Debug mode disabled.")
end

function GrimDebug.AddTestDeath()
    local addonFrame = activeAddonFrame
    if not addonFrame or not addonFrame.HandleBlizzardDeathMessage then
        return
    end

    local rawMessage = "[Testdeath] has been slain by a Kobold Geomancer in Elwynn Forest! They were level 60"
    addonFrame:HandleBlizzardDeathMessage(rawMessage)
end

---@param message string|nil
function GrimDebug.HandleDebugDeathCommand(message)
    local addonFrame = activeAddonFrame
    local rawMessage = string.match(message or "", "^%S+%s+(.+)$")

    if not rawMessage or rawMessage == "" then
        Print("Usage: /grimguesser debugdeath <Blizzard death message>")
        return
    end

    if not addonFrame or not addonFrame.HandleBlizzardDeathMessage then
        return
    end

    if not addonFrame:HandleBlizzardDeathMessage(rawMessage) then
        Print("No Blizzard death pattern matched that message.")
    end
end

---@param command string|nil
---@return boolean
function GrimDebug.IsDebugDeathCommand(command)
    return string.sub(command or "", 1, 10) == "debugdeath"
end

return GrimDebug
