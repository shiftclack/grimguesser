---@class GrimCommandsAddonFrame
---@field state GrimCharacterState
---@field mainFrame GrimMinimapControllerFrame|nil

---@class GrimSlashCommand
---@field raw string
---@field lowered string
---@field command string

local _, ns = ...
---@cast ns GrimNamespace

local GrimCommands = ns.GrimCommands or {}
local GrimDatabase = ns.GrimDatabase
local GrimDebug = ns.GrimDebug
local GrimDebugState = ns.GrimDebugState
local GrimSettings = ns.GrimSettings
local GrimStats = ns.GrimStats
local GrimUI = ns.GrimUI
local GrimUISetup = ns.GrimUISetup
local GrimUIMinimap = ns.GrimUIMinimap
ns.GrimCommands = GrimCommands

---@type GrimCommandsAddonFrame|nil
local activeAddonFrame = nil

---@type GrimPrint
local Print = function() end

---@return GrimCommandsAddonFrame|nil
local function GetAddonFrame()
    return activeAddonFrame
end

---@return GrimCharacterState|nil
local function GetState()
    local addonFrame = GetAddonFrame()
    return addonFrame and addonFrame.state or nil
end

---@param message string
---@return GrimSlashCommand
local function NormalizeSlashCommand(message)
    local trimmedMessage = message ~= nil and strtrim(tostring(message)) or ""
    local loweredMessage = string.lower(trimmedMessage)

    return {
        raw = trimmedMessage,
        lowered = loweredMessage,
        command = string.match(loweredMessage, "^(%S+)") or "",
    }
end

local function PrintSlashHelp()
    Print("Commands: /grimguesser show, /grimguesser hide, /grimguesser toggle, /grimguesser summary, /grimguesser minimap")
    Print("Windows: /grimguesser log, /grimguesser demo, /grimguesser setup, /grimguesser showincombat, /grimguesser resetui")
    Print("Debug: /grimguesser debug, /grimguesser testdeath, /grimguesser debugdeath <deathstring>")
    Print("Dangerous: /grimguesser resetintro, /grimguesser reset")
    Print("Aliases: /gg and /hgg support the same commands as /grimguesser.")
end

---@param value number
---@return string
local function FormatPercent(value)
    if value == math.floor(value) then
        return tostring(value) .. "%"
    end

    return string.format("%.1f%%", value)
end

---@param entry GrimStatEntry|nil
---@return string
local function FormatStatEntry(entry)
    if not entry then
        return "none yet"
    end

    return entry.label .. " (" .. tostring(entry.count) .. ", " .. FormatPercent(entry.percent) .. ")"
end

---@param trend GrimTrendEntry|nil
---@return string
local function FormatTrendEntry(trend)
    if not trend then
        return "none yet"
    end

    local deltaPrefix = trend.deltaPercent >= 0 and "+" or ""
    return trend.label
        .. " ("
        .. trend.trend
        .. ", "
        .. deltaPrefix
        .. FormatPercent(trend.deltaPercent)
        .. ")"
end

---@param cluster GrimRecentCluster|nil
---@return string
local function FormatRecentCluster(cluster)
    if not cluster then
        return "none yet"
    end

    return cluster.label .. " repeated " .. tostring(cluster.count) .. " times recently"
end

local function SummaryCommand()
    local state = GetState()
    if not state then
        return
    end

    local summary = GrimStats.GetDeathSummary(state, {
        topLimit = 3,
        trendLimit = 1,
        recentWindowSize = 5,
    })

    if summary.sampleSize <= 0 then
        Print("Summary: no retained deaths yet.")
        return
    end

    Print("Summary: " .. tostring(summary.sampleSize) .. " retained deaths, " .. tostring(summary.recentSampleSize) .. " recent.")
    Print("Deadliest source: " .. FormatStatEntry(summary.deadliestSource))
    Print("Deadliest location: " .. FormatStatEntry(summary.deadliestLocation))
    Print("Deadliest level: " .. FormatStatEntry(summary.deadliestLevelBracket))
    Print("Recent trend: " .. FormatTrendEntry(summary.recentTrend))
    Print("Recent pattern: " .. FormatRecentCluster(summary.recentRepeat))
end

---@param hidden boolean
local function SetMainWindowHidden(hidden)
    local addonFrame = GetAddonFrame()
    local state = GetState()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if not mainFrame or not state then
        return
    end

    if hidden then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end

    GrimDatabase.SetHidden(state, hidden)
end

local function ToggleLogCommand()
    local addonFrame = GetAddonFrame()
    local state = GetState()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if not mainFrame or not state then
        return
    end

    GrimUI.SetLogWindowShown(mainFrame, state, not GrimUI.ShouldLogWindowBeShown(state))
end

---@return boolean
local function ToggleShowInCombatCommand()
    local enabled = GrimSettings.ToggleShowInCombat()
    if enabled then
        Print("Show in combat enabled.")
    else
        Print("Show in combat disabled.")
    end

    return enabled
end

local function ToggleMinimapCommand()
    local addonFrame = GetAddonFrame()
    local state = GetState()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if GrimUIMinimap and GrimUIMinimap.ToggleHidden and mainFrame and state then
        if GrimUIMinimap.ToggleHidden(mainFrame, state) then
            Print("Minimap icon disabled.")
        else
            Print("Minimap icon enabled.")
        end
    end
end

local function ShowCommand()
    SetMainWindowHidden(false)
end

local function HideCommand()
    SetMainWindowHidden(true)
end

local function DemoCommand()
    local addonFrame = GetAddonFrame()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if not mainFrame then
        return
    end

    if mainFrame.isCollapsed == true then
        Print("Expand the main window before using /grimguesser demo.")
        return
    end

    SetMainWindowHidden(false)
    if mainFrame.introDemoController then
        mainFrame.introDemoController:Show()
    end
end

local function SetupCommand()
    local addonFrame = GetAddonFrame()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    local setupFrame = mainFrame and mainFrame.setupFrame or nil
    if not mainFrame or not setupFrame then
        return
    end

    GrimUISetup.Show(setupFrame, mainFrame)
end

local function IntroCommand()
    local state = GetState()
    if not state then
        return
    end

    if not GrimDebugState.IsEnabled() then
        Print("Intro reset requires debug mode")
        return
    end

    GrimDatabase.SetHasSeenIntroDemo(state, false)
    GrimDatabase.SetHasSeenFirstRun(state, false)
    Print("Introduction enabled.")
end

local function ResetCommand()
    local state = GetState()
    if not state then
        return
    end

    if not GrimDebugState.IsEnabled() then
        Print("Database reset requires debug mode")
        return
    end

    GrimDatabase.ResetAllState(state)
    Print("Database reset complete")
end

local function ResetUICommand()
    local addonFrame = GetAddonFrame()
    local state = GetState()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if not mainFrame or not state then
        return
    end

    GrimUI.ResetMainWindow(mainFrame, state)
    Print("Main window position reset.")
end

local function ToggleWindowCommand()
    local state = GetState()
    local addonFrame = GetAddonFrame()
    local mainFrame = addonFrame and addonFrame.mainFrame or nil
    if not mainFrame or not state then
        return
    end

    local hidden = GrimDatabase.GetHidden(state)
    SetMainWindowHidden(not hidden)
end

local SLASH_COMMAND_HANDLERS = {
    show = ShowCommand,
    hide = HideCommand,
    debug = GrimDebug.ToggleDebugCommand,
    log = ToggleLogCommand,
    demo = DemoCommand,
    setup = SetupCommand,
    resetui = ResetUICommand,
    resetintro = IntroCommand,
    reset = ResetCommand,
    showincombat = ToggleShowInCombatCommand,
    minimap = ToggleMinimapCommand,
    summary = SummaryCommand,
    toggle = ToggleWindowCommand,
    [""] = ToggleWindowCommand,
    help = PrintSlashHelp,
    testdeath = GrimDebug.AddTestDeath,
}

---@param addonFrame GrimCommandsAddonFrame
---@param printMessage GrimPrint
function GrimCommands.Initialize(addonFrame, printMessage)
    activeAddonFrame = addonFrame
    Print = printMessage
end

---@param message string
function GrimCommands.HandleSlashCommand(message)
    local parsedCommand = NormalizeSlashCommand(message)

    if GrimDebug.IsDebugDeathCommand(parsedCommand.lowered) then
        GrimDebug.HandleDebugDeathCommand(parsedCommand.raw)
        return
    end

    local handler = SLASH_COMMAND_HANDLERS[parsedCommand.command]
    if handler then
        handler()
        return
    end

    PrintSlashHelp()
end

SLASH_GRIM1 = "/gg"
SLASH_GRIM2 = "/grimguesser"
SLASH_GRIM3 = "/hgg"
SlashCmdList.GRIM = function(message)
    GrimCommands.HandleSlashCommand(message)
end

return GrimCommands
