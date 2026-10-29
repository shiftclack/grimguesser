-- Copyright © 2026 Shiftclack. Licensed under the PolyForm Strict License 1.0.0; see LICENSE.md.
-- You should have received a copy of the PolyForm Strict License 1.0.0 along with this program.
-- If not, see https://github.com/shiftclack/grimguesser/blob/main/LICENSE.md.

---@alias GrimPrint fun(message: string|number)

local ADDON_NAME, ns = ...
---@cast ns GrimNamespace
local GrimConstants = ns.GrimConstants
local GrimDatabase = ns.GrimDatabase
local GrimDebug = ns.GrimDebug
local GrimParser = ns.GrimParser
local GrimLogic = ns.GrimLogic
local GrimAnnouncements = ns.GrimAnnouncements
local GrimCommands = ns.GrimCommands
local GrimSettings = ns.GrimSettings
local GrimUI = ns.GrimUI
local GrimUIMain = ns.GrimUIMain
local GrimUIMinimap = ns.GrimUIMinimap
local GrimUISetup = ns.GrimUISetup
local GrimUISettings = ns.GrimUISettings
local GrimDemo = ns.GrimDemo

local STORAGE_RULES = GrimConstants.STORAGE
local HARDCORE_DEATHS_CHANNEL_NAME = "HardcoreDeaths"
local STARTUP_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "PLAYER_DEAD",
    "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_DISABLED",
    "CHAT_MSG_CHANNEL",
}

local GrimController = CreateFrame("Frame", "GrimAddonFrame")

---@param message string|number
local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333[Grim Guesser]|r " .. tostring(message))
end

---@return GrimCharacterState
local function GetState()
    return GrimController.state
end

local function RegisterStartupEvents(frame)
    for _, eventName in ipairs(STARTUP_EVENTS) do
        frame:RegisterEvent(eventName)
    end
end

---@param frame table
---@param state GrimCharacterState
local function ShouldAutoStartIntroDemo(frame, state)
    return not GrimDatabase.GetHasSeenIntroDemo(state)
        and not frame.introDemoController:IsActive()
end

local function AttachMainFrameScripts(frame, addonFrame)
    local existingOnHide = frame:GetScript("OnHide")

    frame:SetScript("OnShow", function(self)
        local state = addonFrame.state

        GrimDatabase.SetHidden(state, false)
        GrimUI.ApplyDesiredLogWindowState(self, state)

        if self.introDemoController:IsActive() then
            self:RefreshIntroDemoVisibility()
        elseif ShouldAutoStartIntroDemo(self, state) then
            self.introDemoController:Show()
        elseif self.setupFrame then
            GrimUISetup.ShowOnMainWindowOpen(self.setupFrame, self)
        end
    end)

    frame:SetScript("OnHide", function(self)
        if existingOnHide then
            existingOnHide(self)
        end

        if not addonFrame.isShuttingDown then
            GrimDatabase.SetHidden(addonFrame.state, true)
        end

        if self.setupFrame and self.setupFrame:IsShown() then
            self.setupFrame:Hide()
        end

        if self.logFrame then
            self.logFrame:Hide()
        end

        if self.githubLinkFrame then
            self.githubLinkFrame:Hide()
        end

        if self.helpFrame then
            self.helpFrame:Hide()
        end
    end)
end

function GrimController:RefreshMainFrame()
    if not self.mainFrame then
        return
    end

    self.mainFrame:RefreshDeaths()
    self.mainFrame:RefreshLockedPrediction()
    self.mainFrame:RefreshCollapsedSummary()
end

function GrimController:ADDON_LOADED(addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    GrimCharacterState = GrimDatabase.Init(GrimCharacterState)
    self.state = GrimCharacterState
    self.isShuttingDown = false

    self.mainFrame, self.debugFrame, self.logFrame = GrimUIMain.Initialize(
        self.state,
        GrimLogic,
        STORAGE_RULES.maxRecentDeaths
    )

    GrimParser.Initialize()

    GrimSettings.Initialize(
        self.state,
        GrimDatabase
    )

    GrimUISettings.Initialize(
        GrimSettings
    )

    self.demoController = GrimDemo.Initialize(
        self.state,
        function() self:RefreshMainFrame() end
    )
    self.demoController:AttachFrame(self.mainFrame)

    GrimUIMinimap.Initialize(
        self.mainFrame,
        self.state
    )

    GrimCommands.Initialize(
        self,
        Print
    )

    GrimDebug.Initialize(
        self,
        self.state,
        GrimDatabase,
        self.debugFrame,
        Print
    )
    GrimDebug.OnAddonLoaded()

    AttachMainFrameScripts(self.mainFrame, self)
    RegisterStartupEvents(self)
    GrimUI.SetWindowCollapsed(self.mainFrame, self.state, GrimDatabase.GetCollapsed(self.state))
    self:RefreshMainFrame()
    self.logFrame:RefreshHistory()
end

GrimController:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

GrimController:RegisterEvent("ADDON_LOADED")

---@param death GrimDeathEvent
function GrimController:AddDeath(death)
    local mainFrame = self.mainFrame
    local state = GetState()

    local addDeathOptions = {
        maxRecentDeaths = STORAGE_RULES.maxRecentDeaths,
        maxDeathHistory = STORAGE_RULES.maxDeathHistory,
        maxSuccessfullyPredictedDeaths = STORAGE_RULES.maxSuccessfullyPredictedDeaths,
        playerZone = GetZoneText()
    }

    local added = GrimLogic.AddDeathToDatabase(
        state,
        death,
        addDeathOptions
    )

    if not added then
        return
    end

    if mainFrame then
        self:RefreshMainFrame()
    end

    GrimDebug.HandleDeathAdded()
end

---@param message string
function GrimController:HandleBlizzardDeathMessage(message)
    local parsedDeath = GrimParser.ParseBlizzardDeathMessage(message)
    if parsedDeath then
        local normalizedDeath = GrimLogic.NormalizeDeathEvent(parsedDeath)
        GrimDebug.DebugDeathData(normalizedDeath)
        self:AddDeath(normalizedDeath)
        return true
    end

    return false
end

---@param message string
---@param _sender string
---@param _languageName string
---@param _channelName string
---@param _target string
---@param _flags string
---@param _zoneChannelID number
---@param _channelIndex number
---@param channelBaseName string
function GrimController:CHAT_MSG_CHANNEL(
    message,
    _sender,
    _languageName,
    _channelName,
    _target,
    _flags,
    _zoneChannelID,
    _channelIndex,
    channelBaseName
)
    if channelBaseName ~= HARDCORE_DEATHS_CHANNEL_NAME then
        return
    end

    if not message or message == "" then
        return
    end

    self:HandleBlizzardDeathMessage(message)
end

function GrimController:PLAYER_LOGIN()
    local mainFrame = self.mainFrame

    if mainFrame and not GrimDatabase.GetHidden(self.state) then
        mainFrame:Show()
    end
end

function GrimController:PLAYER_LOGOUT()
    self.isShuttingDown = true
end

-- luacheck: ignore self
function GrimController:PLAYER_DEAD()
    GrimAnnouncements.AnnouncePlayerDeath(GetState(), Print)
end

-- luacheck: ignore self
---@param level integer
function GrimController:PLAYER_LEVEL_UP(level)
    GrimAnnouncements.AnnouncePlayerLevelUp(GetState(), level)
end

-- automatically minimize the main ui in combat
function GrimController:PLAYER_REGEN_DISABLED()
    local mainFrame = self.mainFrame

    if not mainFrame then
        return
    end

    if mainFrame.isCollapsed then
        return
    end

    if not mainFrame:IsShown() then
        return
    end

    if GrimDatabase.GetShowInCombat(GetState()) then
        return
    end

    GrimUI.SetWindowCollapsed(mainFrame, GetState(), true)
end
