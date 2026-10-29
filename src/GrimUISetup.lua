local _, ns = ...
---@cast ns GrimNamespace

local GrimUISetup = {}
local GrimUI = ns.GrimUI
local GrimUIAutocomplete = ns.GrimUIAutocomplete
local GrimDatabase = ns.GrimDatabase
local GrimSetup = ns.GrimSetup
ns.GrimUISetup = GrimUISetup

---@class GrimSetupFrame
---@field Show fun(self: GrimSetupFrame)
---@field Hide fun(self: GrimSetupFrame)
---@field IsShown fun(self: GrimSetupFrame): boolean
---@field SetSize fun(self: GrimSetupFrame, width: number, height: number)
---@field SetPoint fun(self: GrimSetupFrame, point: string, relativeTo: table, relativePoint: string, xOffset: number, yOffset: number)
---@field SetFrameStrata fun(self: GrimSetupFrame, strata: string)
---@field SetToplevel fun(self: GrimSetupFrame, enabled: boolean)
---@field SetMovable fun(self: GrimSetupFrame, enabled: boolean)
---@field EnableMouse fun(self: GrimSetupFrame, enabled: boolean)
---@field SetScript fun(self: GrimSetupFrame, scriptType: string, handler: function)
---@field CreateFontString fun(self: GrimSetupFrame, name: string|nil, layer: string, template: string): GrimSetupFontString
---@field title GrimSetupFontString
---@field subtitle GrimSetupFontString
---@field enableDeathAnnouncementsButton GrimSetupButton
---@field enableDeathAnnouncementsText GrimSetupFontString
---@field joinHardcoreDeathsButton GrimSetupButton
---@field joinHardcoreDeathsText GrimSetupFontString
---@field backdropOverlay GrimModalBackdropOverlay
---@field titlebarDragHandle GrimModalTitlebarDragHandle
---@field CloseButton GrimSetupButton|nil
---@field ownerFrame table

---@class GrimSetupButton
---@field Enable fun(self: GrimSetupButton)
---@field Disable fun(self: GrimSetupButton)
---@field IsEnabled fun(self: GrimSetupButton): boolean
---@field SetSize fun(self: GrimSetupButton, width: number, height: number)
---@field SetPoint fun(self: GrimSetupButton, point: string, relativeTo: table, relativePoint: string, xOffset: number, yOffset: number)
---@field SetText fun(self: GrimSetupButton, text: string)
---@field SetScript fun(self: GrimSetupButton, scriptType: string, handler: function)
---@field GetFontString fun(self: GrimSetupButton): GrimSetupFontString

---@class GrimSetupFontString
---@field ClearAllPoints fun(self: GrimSetupFontString)
---@field SetPoint fun(self: GrimSetupFontString, point: string, relativeTo: table, relativePoint: string, xOffset: number, yOffset: number)
---@field SetText fun(self: GrimSetupFontString, text: string)
---@field SetJustifyH fun(self: GrimSetupFontString, justify: string)
---@field SetJustifyV fun(self: GrimSetupFontString, justify: string)
---@field SetTextColor fun(self: GrimSetupFontString, red: number, green: number, blue: number, alpha: number)

---@param ownerFrame table
local function RefreshOwnerFrame(ownerFrame)
    ownerFrame:RefreshDeaths()
    ownerFrame:RefreshLockedPrediction()
    ownerFrame:RefreshCollapsedSummary()
end

---@param ownerFrame table
---@param active boolean
local function ApplyMainWindowState(ownerFrame, active)
    ownerFrame.setupActive = active == true

    if ownerFrame.setupActive then
        for _, button in ipairs(ownerFrame.levelRangeButtons) do
            button:Disable()
        end

        ownerFrame.sourceEditBox:Disable()
        ownerFrame.zoneEditBox:Disable()
        ownerFrame.sourceEditBox:SetTextColor(unpack(GrimUI.COLORS.predictionInputLocked))
        ownerFrame.zoneEditBox:SetTextColor(unpack(GrimUI.COLORS.predictionInputLocked))
        ownerFrame.emptyPredictionPrompt:Hide()
        GrimUIAutocomplete.HideDropdown(ownerFrame)
        return
    end

    GrimUI.ApplyPredictionInputLockState(
        ownerFrame,
        GrimDatabase.GetLockedPrediction(GrimUI.GetState(ownerFrame)) ~= nil
    )
end

---@param setupFrame GrimSetupFrame
---@param setupState GrimSetupState
local function RefreshSetupRows(setupFrame, setupState)
    if setupState.hasEnabledDeathAnnouncements then
        setupFrame.enableDeathAnnouncementsButton:SetText("ENABLED")
        setupFrame.enableDeathAnnouncementsButton:Disable()
    else
        setupFrame.enableDeathAnnouncementsButton:SetText("ENABLE")
        setupFrame.enableDeathAnnouncementsButton:Enable()
    end

    if setupState.hasJoinedHardcoreDeathsChannel then
        setupFrame.joinHardcoreDeathsButton:SetText("JOINED")
        setupFrame.joinHardcoreDeathsButton:Disable()
    else
        setupFrame.joinHardcoreDeathsButton:SetText("JOIN")
        setupFrame.joinHardcoreDeathsButton:Enable()
    end
end

---@param ownerFrame table
local function HideOwnerLogWindow(ownerFrame)
    ownerFrame.logFrame:Hide()
end

---@param ownerFrame table
---@return boolean
local function CanCloseSetupWindow(ownerFrame)
    local database = GrimUI.GetState(ownerFrame)
    return GrimDatabase.GetHasSeenIntroDemo(database)
        and GrimDatabase.GetHasSeenFirstRun(database)
end

---@param setupFrame GrimSetupFrame
---@param ownerFrame table
local function RefreshSetupCloseButtonState(setupFrame, ownerFrame)
    local closeButton = setupFrame.CloseButton
    if not closeButton then
        return
    end

    if CanCloseSetupWindow(ownerFrame) then
        closeButton:Enable()
    else
        closeButton:Disable()
    end
end

---@param setupFrame GrimSetupFrame
---@param ownerFrame table
---@param forceHide boolean
function GrimUISetup.Refresh(setupFrame, ownerFrame, forceHide)
    local setupState = GrimSetup.GetState()
    local active = setupState.isComplete ~= true and forceHide ~= true and setupFrame:IsShown()

    if active then
        GrimUI.ShowExpandedOwnerFrame(ownerFrame)
        HideOwnerLogWindow(ownerFrame)
    end

    ApplyMainWindowState(ownerFrame, active)
    RefreshSetupRows(setupFrame, setupState)
    RefreshSetupCloseButtonState(setupFrame, ownerFrame)

    if active then
        setupFrame.backdropOverlay:Show()
        setupFrame:Show()
    else
        setupFrame.backdropOverlay:Hide()
        setupFrame:Hide()
    end
end

---@param setupFrame GrimSetupFrame
---@param ownerFrame table
---@return boolean
function GrimUISetup.ShowOnMainWindowOpen(setupFrame, ownerFrame)
    if setupFrame:IsShown() then
        return true
    end

    if not GrimSetup.ShouldShowOnMainWindowOpen() then
        return false
    end

    if ownerFrame.introDemoController and ownerFrame.introDemoController:IsActive() then
        return false
    end

    GrimUISetup.Show(setupFrame, ownerFrame)
    return true
end

---@param setupFrame GrimSetupFrame
---@param ownerFrame table
function GrimUISetup.Show(setupFrame, ownerFrame)
    local setupState = GrimSetup.GetState()

    GrimUI.ShowExpandedOwnerFrame(ownerFrame)
    HideOwnerLogWindow(ownerFrame)
    ApplyMainWindowState(ownerFrame, setupState.isComplete ~= true)
    RefreshSetupRows(setupFrame, setupState)
    RefreshSetupCloseButtonState(setupFrame, ownerFrame)
    setupFrame.backdropOverlay:Show()
    setupFrame:Show()
end

---@param ownerFrame table
---@return GrimSetupFrame
function GrimUISetup.CreateWindow(ownerFrame)
    local layout = GrimUI.LAYOUT
    local setupFrame = CreateFrame("Frame", "GrimSetupFrame", UIParent, "BasicFrameTemplateWithInset")
    ---@cast setupFrame GrimSetupFrame
    setupFrame.ownerFrame = ownerFrame
    setupFrame:SetSize(430, 150)
    setupFrame:SetPoint("CENTER", ownerFrame, "CENTER", 0, 0)
    setupFrame:SetFrameStrata("DIALOG")
    setupFrame:SetToplevel(true)
    setupFrame:SetMovable(false)
    setupFrame:EnableMouse(true)
    setupFrame:Hide()

    setupFrame.backdropOverlay = GrimUI.CreateModalBackdropOverlay(ownerFrame)

    setupFrame:SetScript("OnShow", function(self)
        self.backdropOverlay:Show()
        RefreshSetupCloseButtonState(self, ownerFrame)
        HideOwnerLogWindow(ownerFrame)
    end)
    setupFrame:SetScript("OnHide", function(self)
        self.backdropOverlay:Hide()
        ApplyMainWindowState(ownerFrame, false)
    end)

    if setupFrame.CloseButton then
        setupFrame.CloseButton:SetScript("OnClick", function()
            if CanCloseSetupWindow(ownerFrame) then
                setupFrame:Hide()
            end
        end)
        RefreshSetupCloseButtonState(setupFrame, ownerFrame)
    end

    local title = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    ---@cast title GrimSetupFontString
    title:SetPoint("TOP", setupFrame, "TOP", 0, -6)
    title:SetText("SETUP")
    setupFrame.title = title

    setupFrame.titlebarDragHandle = GrimUI.CreateModalTitlebarDragHandle(setupFrame, ownerFrame)

    local subtitle = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ---@cast subtitle GrimSetupFontString
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -14)
    subtitle:SetText("Let's make sure you're set up!")
    setupFrame.subtitle = subtitle

    local enableDeathAnnouncementsButton = CreateFrame("Button", nil, setupFrame, "GameMenuButtonTemplate")
    ---@cast enableDeathAnnouncementsButton GrimSetupButton
    enableDeathAnnouncementsButton:SetSize(96, layout.compactButtonHeight)
    enableDeathAnnouncementsButton:SetPoint("TOPLEFT", setupFrame, "TOPLEFT", 70, -64)
    enableDeathAnnouncementsButton:GetFontString():ClearAllPoints()
    enableDeathAnnouncementsButton:GetFontString():SetPoint("CENTER", enableDeathAnnouncementsButton, "CENTER", 0, -1)
    enableDeathAnnouncementsButton:GetFontString():SetJustifyV("MIDDLE")
    enableDeathAnnouncementsButton:SetText("ENABLE")
    enableDeathAnnouncementsButton:SetScript("OnClick", function()
        if not enableDeathAnnouncementsButton:IsEnabled() then
            return
        end

        GrimSetup.EnableDeathAnnouncements()
        RefreshOwnerFrame(ownerFrame)
    end)
    setupFrame.enableDeathAnnouncementsButton = enableDeathAnnouncementsButton

    local enableDeathAnnouncementsText = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ---@cast enableDeathAnnouncementsText GrimSetupFontString
    enableDeathAnnouncementsText:SetPoint("LEFT", enableDeathAnnouncementsButton, "RIGHT", 10, 0)
    enableDeathAnnouncementsText:SetJustifyH("LEFT")
    enableDeathAnnouncementsText:SetTextColor(1, 0.82, 0, 1)
    enableDeathAnnouncementsText:SetText("Hardcore death announcements")
    setupFrame.enableDeathAnnouncementsText = enableDeathAnnouncementsText

    local joinHardcoreDeathsButton = CreateFrame("Button", nil, setupFrame, "GameMenuButtonTemplate")
    ---@cast joinHardcoreDeathsButton GrimSetupButton
    joinHardcoreDeathsButton:SetSize(96, layout.compactButtonHeight)
    joinHardcoreDeathsButton:SetPoint("TOPLEFT", enableDeathAnnouncementsButton, "BOTTOMLEFT", 0, -8)
    joinHardcoreDeathsButton:GetFontString():ClearAllPoints()
    joinHardcoreDeathsButton:GetFontString():SetPoint("CENTER", joinHardcoreDeathsButton, "CENTER", 0, -1)
    joinHardcoreDeathsButton:GetFontString():SetJustifyV("MIDDLE")
    joinHardcoreDeathsButton:SetText("JOIN")
    joinHardcoreDeathsButton:SetScript("OnClick", function()
        if not joinHardcoreDeathsButton:IsEnabled() then
            return
        end

        GrimSetup.JoinHardcoreDeathsChannel()
        RefreshOwnerFrame(ownerFrame)
    end)
    setupFrame.joinHardcoreDeathsButton = joinHardcoreDeathsButton

    local joinHardcoreDeathsText = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ---@cast joinHardcoreDeathsText GrimSetupFontString
    joinHardcoreDeathsText:SetPoint("LEFT", joinHardcoreDeathsButton, "RIGHT", 10, 0)
    joinHardcoreDeathsText:SetJustifyH("LEFT")
    joinHardcoreDeathsText:SetTextColor(1, 0.82, 0, 1)
    joinHardcoreDeathsText:SetText("The HardcoreDeaths channel")
    setupFrame.joinHardcoreDeathsText = joinHardcoreDeathsText

    return setupFrame
end

return GrimUISetup
