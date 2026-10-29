---@class GrimUISettingsPanelCheckbox
---@field label table|nil
---@field SetPoint fun(self: GrimUISettingsPanelCheckbox, point: string, relativeTo: table, relativePoint: string, x: number, y: number)
---@field SetScript fun(self: GrimUISettingsPanelCheckbox, eventName: string, handler: function)
---@field SetSize fun(self: GrimUISettingsPanelCheckbox, width: number, height: number)
---@field CreateFontString fun(self: GrimUISettingsPanelCheckbox, childName: string|nil, layer: string|nil, template: string|nil): table
---@field SetChecked fun(self: GrimUISettingsPanelCheckbox, value: boolean)
---@field GetChecked fun(self: GrimUISettingsPanelCheckbox): boolean
---@field Enable fun(self: GrimUISettingsPanelCheckbox)
---@field Disable fun(self: GrimUISettingsPanelCheckbox)
---@field IsEnabled fun(self: GrimUISettingsPanelCheckbox): boolean
---@field Click fun(self: GrimUISettingsPanelCheckbox, button: string|nil)

---@class GrimUISettingsSettingsApi
---@field GetDisableMinimapIcon fun(): boolean
---@field GetGuildAnnouncementsEnabled fun(): boolean
---@field GetDeathAnnouncementToGuild fun(): boolean
---@field GetAnnounceScoreOnLevelUp fun(): boolean
---@field GetShowInCombat fun(): boolean
---@field SetDisableMinimapIcon fun(disabled: boolean): boolean
---@field SetGuildAnnouncementsEnabled fun(enabled: boolean): boolean
---@field SetDeathAnnouncementToGuild fun(enabled: boolean): boolean
---@field SetAnnounceScoreOnLevelUp fun(enabled: boolean): boolean
---@field SetShowInCombat fun(enabled: boolean): boolean

---@class GrimUISettingsPanelModule
---@field categoryFrame table|nil
---@field guildAnnouncementsEnabledCheckbox GrimUISettingsPanelCheckbox|nil
---@field announceDeathToGuildCheckbox GrimUISettingsPanelCheckbox|nil
---@field announceScoreOnLevelUpCheckbox GrimUISettingsPanelCheckbox|nil
---@field disableMinimapIconCheckbox GrimUISettingsPanelCheckbox|nil
---@field showInCombatCheckbox GrimUISettingsPanelCheckbox|nil
---@field Initialize fun(settingsApi: GrimUISettingsSettingsApi)

local _, ns = ...
---@cast ns GrimNamespace

local GrimUISettings = ns.GrimUISettings or {}
---@cast GrimUISettings GrimUISettingsPanelModule
local GrimConstants = ns.GrimConstants
local GrimUI = ns.GrimUI
local Settings = _G.Settings
ns.GrimUISettings = GrimUISettings

---@type GrimUISettingsSettingsApi|nil
local activeSettingsApi = nil
local categoryRegistered = false
local categoryFrame = nil
local guildAnnouncementsEnabledCheckbox = nil
local announceDeathToGuildCheckbox = nil
local announceScoreOnLevelUpCheckbox = nil
local disableMinimapIconCheckbox = nil
local showInCombatCheckbox = nil
local GUILD_ANNOUNCEMENT_CHILD_INDENT = 24

---@return GrimUISettingsSettingsApi
local function GetSettingsApi()
    local settingsApi = activeSettingsApi
    ---@cast settingsApi GrimUISettingsSettingsApi
    return settingsApi
end

local function RefreshCheckboxStates()
    local settingsApi = GetSettingsApi()
    local guildAnnouncementsEnabled = settingsApi.GetGuildAnnouncementsEnabled()

    if guildAnnouncementsEnabledCheckbox then
        guildAnnouncementsEnabledCheckbox:SetChecked(guildAnnouncementsEnabled)
    end

    if announceDeathToGuildCheckbox then
        announceDeathToGuildCheckbox:SetChecked(settingsApi.GetDeathAnnouncementToGuild())
        if guildAnnouncementsEnabled then
            announceDeathToGuildCheckbox:Enable()
        else
            announceDeathToGuildCheckbox:Disable()
        end
    end

    if announceScoreOnLevelUpCheckbox then
        announceScoreOnLevelUpCheckbox:SetChecked(settingsApi.GetAnnounceScoreOnLevelUp())
        if guildAnnouncementsEnabled then
            announceScoreOnLevelUpCheckbox:Enable()
        else
            announceScoreOnLevelUpCheckbox:Disable()
        end
    end

    if showInCombatCheckbox then
        showInCombatCheckbox:SetChecked(settingsApi.GetShowInCombat())
    end

    if disableMinimapIconCheckbox then
        disableMinimapIconCheckbox:SetChecked(settingsApi.GetDisableMinimapIcon())
    end
end

---@param parent table
---@param labelText string
---@param onClick fun(self: table)
---@return GrimUISettingsPanelCheckbox
local function CreateCheckbox(parent, labelText, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    ---@cast checkbox GrimUISettingsPanelCheckbox
    checkbox:SetSize(24, 24)
    checkbox:SetScript("OnClick", onClick)

    local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    checkbox.label = label

    return checkbox
end

local function CreateCategoryFrame()
    local layout = GrimUI.LAYOUT
    local frame = CreateFrame("Frame", "GrimSettingsPanel", UIParent)
    frame.name = "Grim Guesser"

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.outsideGutter, -layout.outsideGutter)
    title:SetJustifyH("LEFT")
    title:SetText("Grim Guesser")

    showInCombatCheckbox = CreateCheckbox(frame, "Show in combat", function(self)
        local settingsApi = GetSettingsApi()
        settingsApi.SetShowInCombat(self:GetChecked())
        RefreshCheckboxStates()
    end)
    showInCombatCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    guildAnnouncementsEnabledCheckbox = CreateCheckbox(frame, "Enable guild announcements", function(self)
        local settingsApi = GetSettingsApi()
        settingsApi.SetGuildAnnouncementsEnabled(self:GetChecked())
        RefreshCheckboxStates()
    end)
    guildAnnouncementsEnabledCheckbox:SetPoint("TOPLEFT", showInCombatCheckbox, "BOTTOMLEFT", 0, -12)

    announceDeathToGuildCheckbox = CreateCheckbox(frame, "Announce death to guild", function(self)
        local settingsApi = GetSettingsApi()
        settingsApi.SetDeathAnnouncementToGuild(self:GetChecked())
        RefreshCheckboxStates()
    end)
    announceDeathToGuildCheckbox:SetPoint(
        "TOPLEFT",
        guildAnnouncementsEnabledCheckbox,
        "BOTTOMLEFT",
        GUILD_ANNOUNCEMENT_CHILD_INDENT,
        -12
    )

    announceScoreOnLevelUpCheckbox = CreateCheckbox(
        frame,
        "Announce score every " .. GrimConstants.ANNOUNCEMENTS.levelUpFrequency .. " levels",
        function(self)
            local settingsApi = GetSettingsApi()
            settingsApi.SetAnnounceScoreOnLevelUp(self:GetChecked())
            RefreshCheckboxStates()
        end
    )
    announceScoreOnLevelUpCheckbox:SetPoint("TOPLEFT", announceDeathToGuildCheckbox, "BOTTOMLEFT", 0, -12)

    disableMinimapIconCheckbox = CreateCheckbox(frame, "Disable minimap icon", function(self)
        local settingsApi = GetSettingsApi()
        settingsApi.SetDisableMinimapIcon(self:GetChecked())
        RefreshCheckboxStates()
    end)
    disableMinimapIconCheckbox:SetPoint(
        "TOPLEFT",
        announceScoreOnLevelUpCheckbox,
        "BOTTOMLEFT",
        -GUILD_ANNOUNCEMENT_CHILD_INDENT,
        -12
    )

    frame:SetScript("OnShow", RefreshCheckboxStates)

    return frame
end

---@param settingsApi GrimUISettingsSettingsApi
function GrimUISettings.Initialize(settingsApi)
    activeSettingsApi = settingsApi

    if categoryRegistered ~= true then
        categoryFrame = CreateCategoryFrame()
        local category = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Grim Guesser")
        Settings.RegisterAddOnCategory(category)
        categoryRegistered = true

        GrimUISettings.categoryFrame = categoryFrame
        GrimUISettings.guildAnnouncementsEnabledCheckbox = guildAnnouncementsEnabledCheckbox
        GrimUISettings.announceDeathToGuildCheckbox = announceDeathToGuildCheckbox
        GrimUISettings.announceScoreOnLevelUpCheckbox = announceScoreOnLevelUpCheckbox
        GrimUISettings.disableMinimapIconCheckbox = disableMinimapIconCheckbox
        GrimUISettings.showInCombatCheckbox = showInCombatCheckbox
    end

    RefreshCheckboxStates()
end

return GrimUISettings
