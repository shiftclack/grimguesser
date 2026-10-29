local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI or {}
local GrimDatabase = ns.GrimDatabase
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
local GrimConstants = ns.GrimConstants
local GrimLogic = ns.GrimLogic
ns.GrimUI = GrimUI

GrimUI.LOG_TOGGLE_BUTTON_TEXT = "LOG"
GrimUI.HISTORY_SUBTITLE_ALL = "All Predictions"
GrimUI.HISTORY_SUBTITLE_SUCCESS_ONLY = "Successful Predictions"
GrimUI.HISTORY_FILTER_BUTTON_SHOW_ALL = "SHOW ALL"
GrimUI.HISTORY_FILTER_BUTTON_SHOW_SUCCESS_ONLY = "SHOW SUCCESS ONLY"

GrimUI.LEVEL_RANGES = { "None" }
for _, levelRange in ipairs(GrimConstants.SCORING.levelRanges) do
    table.insert(GrimUI.LEVEL_RANGES, levelRange)
end

GrimUI.DEATH_LOG_COLUMNS = {
    { key = "time", label = "Time", x = 0, width = 50, justifyH = "LEFT" },
    { key = "sourceName", label = "Source", x = 58, width = 290, justifyH = "LEFT" },
    { key = "level", label = "Level", x = 278, width = 40, justifyH = "LEFT" },
    { key = "zone", label = "Location", x = 328, width = 400, justifyH = "LEFT" },
    { key = "awardedPoints", label = "Points", x = 530, width = 46, justifyH = "RIGHT" },
}

GrimUI.HISTORY_LOG_COLUMNS = {
    { key = "time", label = "Time", x = 0, width = 45, justifyH = "LEFT" },
    { key = "sourceName", label = "Source", x = 50, width = 100, justifyH = "LEFT" },
    { key = "awardedPoints", label = "Points", x = 160, width = 32, justifyH = "RIGHT" },
}

GrimUI.HISTORY_SUCCESS_RANK_LABEL = "Rank"

GrimUI.COLLAPSED_LOG_COLUMNS = {
    { key = "time", label = "Time", x = 0, width = 45, justifyH = "LEFT" },
    { key = "sourceName", label = "Source", x = 47, width = 94, justifyH = "LEFT" },
    { key = "level", label = "Lvl", x = 152, width = 24, justifyH = "LEFT" },
    { key = "zone", label = "Location", x = 182, width = 90, justifyH = "LEFT" },
    { key = "awardedPoints", label = "Points", x = 266, width = 40, justifyH = "RIGHT" },
}

GrimUI.COLORS = {
    commonMatchDeath = { 1.0, 1.0, 1.0 },
    epicMatchDeath = { 0.64, 0.21, 0.93 },
    poorMatchDeath = { 0.62, 0.62, 0.62 },
    predictionInputActive = { 1.0, 1.0, 1.0, 1.0 },
    predictionInputLocked = { 0.5, 0.5, 0.5, 1.0 },
    rareMatchDeath = { 0.0, 0.44, 0.87 },
    uncommonMatchDeath = { 0.12, 1.0, 0.0 },
}

GrimUI.LAYOUT = {
    actionButtonGap = 16,
    collapsedLogHeaderY = -32,
    collapsedLogRowHeight = 16,
    collapsedLogVisibleRows = 5,
    collapsedWindowHeight = 165,
    collapsedWindowMaxHeight = 165,
    collapsedWindowMinHeight = 100,
    collapsedWindowWidth = 350,
    compactButtonHeight = 24,
    deathLogDividerY = -132,
    deathLogFrameY = -48,
    deathLogHeaderY = -36,
    deathLogRowHeight = 16,
    expandedWindowWidth = 620,
    footerGutter = 15,
    logVisibleRows = 19,
    logWindowHeight = 424,
    logWindowWidth = 260,
    mainWindowHeight = 424,
    modalButtonGap = 12,
    outsideGutter = 22,
    predictionButtonY = 15,
    predictionControlX = 96,
    predictionIntroDemoPanelHeight = 58,
    predictionIntroDemoPanelWidth = 314,
    predictionIntroDemoPanelX = 284,
    predictionIntroDemoPanelY = -235,
    predictionLabelX = 22,
    predictionLevelRowY = -206,
    predictionSectionTop = -170,
    predictionSourceRowY = -246,
    predictionSummaryWidth = 390,
    predictionSummaryY = 88,
    predictionZoneRowY = -282,
    scrollbarInset = 10,
    scrollbarWidth = 26,
    standardButtonHeight = 28,
    standardButtonWidth = 120,
    titlebarDragHeight = 22,
    titlebarDragLeftInset = 8,
    titlebarDragRightInset = 32,
    titlebarDragTopInset = -4,
}

GrimUI.LAYOUT.logVerticalSpacing = GrimUI.LAYOUT.deathLogHeaderY - GrimUI.LAYOUT.deathLogFrameY
GrimUI.LAYOUT.historyScrollbarGap = math.floor(GrimUI.LAYOUT.scrollbarWidth / 2)
GrimUI.LAYOUT.collapsedLogFrameY = GrimUI.LAYOUT.collapsedLogHeaderY
    - GrimUI.LAYOUT.logVerticalSpacing
GrimUI.LAYOUT.historySubtitleY = GrimUI.LAYOUT.deathLogHeaderY
GrimUI.LAYOUT.historySubtitleHeaderSpacing = GrimUI.LAYOUT.logVerticalSpacing + 8
GrimUI.LAYOUT.historyLogHeaderY = GrimUI.LAYOUT.historySubtitleY
    - GrimUI.LAYOUT.historySubtitleHeaderSpacing
GrimUI.LAYOUT.historyLogFrameY = GrimUI.LAYOUT.historyLogHeaderY - GrimUI.LAYOUT.logVerticalSpacing
GrimUI.LAYOUT.scoreSummaryY = GrimUI.LAYOUT.deathLogDividerY
    - (GrimUI.LAYOUT.outsideGutter - GrimUI.LAYOUT.footerGutter)

---@class GrimModalBackdropOverlay
---@field Show fun(self: GrimModalBackdropOverlay)
---@field Hide fun(self: GrimModalBackdropOverlay)
---@field SetAllPoints fun(self: GrimModalBackdropOverlay)
---@field SetFrameLevel fun(self: GrimModalBackdropOverlay, frameLevel: number)
---@field EnableMouse fun(self: GrimModalBackdropOverlay, enabled: boolean)
---@field RegisterForDrag fun(self: GrimModalBackdropOverlay, button: string)
---@field SetScript fun(self: GrimModalBackdropOverlay, scriptType: string, handler: function)
---@field CreateTexture fun(self: GrimModalBackdropOverlay, name: string|nil, layer: string): GrimModalBackdropTexture
---@field texture GrimModalBackdropTexture

---@class GrimModalTitlebarDragHandle
---@field SetPoint fun(self: GrimModalTitlebarDragHandle, point: string, relativeTo: table, relativePoint: string, xOffset: number, yOffset: number)
---@field SetHeight fun(self: GrimModalTitlebarDragHandle, height: number)
---@field EnableMouse fun(self: GrimModalTitlebarDragHandle, enabled: boolean)
---@field RegisterForDrag fun(self: GrimModalTitlebarDragHandle, button: string)
---@field SetScript fun(self: GrimModalTitlebarDragHandle, scriptType: string, handler: function)

---@class GrimModalBackdropTexture
---@field SetAllPoints fun(self: GrimModalBackdropTexture)
---@field SetColorTexture fun(self: GrimModalBackdropTexture, red: number, green: number, blue: number, alpha: number)

local MODAL_BACKDROP_ALPHA = 0.58
local MODAL_BACKDROP_FRAME_LEVEL_OFFSET = 40
local MODAL_DRAG_BUTTON = "LeftButton"

---@param ownerFrame table
local function StartOwnerFrameDrag(ownerFrame)
    ownerFrame:StartMoving()
end

---@param ownerFrame table
local function StopOwnerFrameDrag(ownerFrame)
    ownerFrame:StopMovingOrSizing()
    GrimUI.SaveWindowPosition(ownerFrame, GrimUI.GetState(ownerFrame), ownerFrame.isCollapsed)
end

---@param ownerFrame table
function GrimUI.ShowExpandedOwnerFrame(ownerFrame)
    if ownerFrame.isCollapsed == true then
        GrimUI.SetWindowCollapsed(ownerFrame, GrimUI.GetState(ownerFrame), false)
    end

    if not ownerFrame:IsShown() then
        ownerFrame:Show()
    end
end

---@param ownerFrame table
---@return GrimModalBackdropOverlay
function GrimUI.CreateModalBackdropOverlay(ownerFrame)
    local backdropOverlay = CreateFrame("Frame", nil, ownerFrame)
    ---@cast backdropOverlay GrimModalBackdropOverlay
    backdropOverlay:SetAllPoints()
    backdropOverlay:SetFrameLevel(ownerFrame:GetFrameLevel() + MODAL_BACKDROP_FRAME_LEVEL_OFFSET)
    backdropOverlay:EnableMouse(true)
    backdropOverlay:RegisterForDrag(MODAL_DRAG_BUTTON)
    backdropOverlay:SetScript("OnDragStart", function()
        StartOwnerFrameDrag(ownerFrame)
    end)
    backdropOverlay:SetScript("OnDragStop", function()
        StopOwnerFrameDrag(ownerFrame)
    end)

    local backdropTexture = backdropOverlay:CreateTexture(nil, "BACKGROUND")
    ---@cast backdropTexture GrimModalBackdropTexture
    backdropTexture:SetAllPoints()
    backdropTexture:SetColorTexture(0, 0, 0, MODAL_BACKDROP_ALPHA)
    backdropOverlay.texture = backdropTexture
    backdropOverlay:Hide()

    return backdropOverlay
end

---@param modalFrame table
---@param ownerFrame table
---@return GrimModalTitlebarDragHandle
function GrimUI.CreateModalTitlebarDragHandle(modalFrame, ownerFrame)
    local layout = GrimUI.LAYOUT
    local titlebarDragHandle = CreateFrame("Frame", nil, modalFrame)
    ---@cast titlebarDragHandle GrimModalTitlebarDragHandle
    titlebarDragHandle:SetPoint(
        "TOPLEFT",
        modalFrame,
        "TOPLEFT",
        layout.titlebarDragLeftInset,
        layout.titlebarDragTopInset
    )
    titlebarDragHandle:SetPoint(
        "TOPRIGHT",
        modalFrame,
        "TOPRIGHT",
        -layout.titlebarDragRightInset,
        layout.titlebarDragTopInset
    )
    titlebarDragHandle:SetHeight(layout.titlebarDragHeight)
    titlebarDragHandle:EnableMouse(true)
    titlebarDragHandle:RegisterForDrag(MODAL_DRAG_BUTTON)
    titlebarDragHandle:SetScript("OnDragStart", function()
        StartOwnerFrameDrag(ownerFrame)
    end)
    titlebarDragHandle:SetScript("OnDragStop", function()
        StopOwnerFrameDrag(ownerFrame)
    end)

    return titlebarDragHandle
end

---@param height number|nil
---@return number
function GrimUI.NormalizeCollapsedWindowHeight(height)
    local layout = GrimUI.LAYOUT
    local normalizedHeight = height

    if normalizedHeight == nil then
        normalizedHeight = layout.collapsedWindowHeight
    end

    normalizedHeight = tonumber(normalizedHeight) or layout.collapsedWindowHeight
    if normalizedHeight < layout.collapsedWindowMinHeight then
        normalizedHeight = layout.collapsedWindowMinHeight
    end
    if normalizedHeight > layout.collapsedWindowMaxHeight then
        normalizedHeight = layout.collapsedWindowMaxHeight
    end

    return normalizedHeight
end

---@param height number|nil
---@return integer
function GrimUI.GetCollapsedVisibleRowCount(height)
    local layout = GrimUI.LAYOUT
    local normalizedHeight = GrimUI.NormalizeCollapsedWindowHeight(height)
    local visibleRowCount = math.floor(
        ((normalizedHeight - layout.collapsedWindowMinHeight) / layout.collapsedLogRowHeight) + 1
    )

    if visibleRowCount < 1 then
        return 1
    end
    if visibleRowCount > layout.collapsedLogVisibleRows then
        return layout.collapsedLogVisibleRows
    end

    return visibleRowCount
end

---@param frame table
---@param database GrimCharacterState
---@return number|nil
function GrimUI.SaveCollapsedWindowHeight(frame, database)
    if not frame then
        return nil
    end

    local height = GrimUI.NormalizeCollapsedWindowHeight(frame:GetHeight())
    GrimDatabase.SetCollapsedWindowHeight(database, height)
    return height
end

---@param frame table
---@param region table
function GrimUI.RegisterCollapsibleRegion(frame, region)
    frame.collapsibleRegions = frame.collapsibleRegions or {}
    table.insert(frame.collapsibleRegions, region)
end

---@param frame table
---@param region table
function GrimUI.RegisterCollapsedVisibleRegion(frame, region)
    frame.collapsedVisibleRegions = frame.collapsedVisibleRegions or {}
    table.insert(frame.collapsedVisibleRegions, region)
end

---@param frame table|nil
---@param closable boolean|nil
function GrimUI.SetEscapeClosable(frame, closable)
    if not frame then
        return
    end

    local specialFrames = _G.UISpecialFrames
    local frameName
    if frame.GetName then
        frameName = frame:GetName()
    else
        frameName = frame.name
    end
    if type(specialFrames) ~= "table" or not frameName or frameName == "" then
        return
    end

    local existingIndex = nil
    for index, existingName in ipairs(specialFrames) do
        if existingName == frameName then
            existingIndex = index
            break
        end
    end

    if closable == true then
        if existingIndex == nil then
            table.insert(specialFrames, frameName)
        end
        return
    end

    if existingIndex ~= nil then
        table.remove(specialFrames, existingIndex)
    end
end

---@param value any
---@return string
function GrimUI.GetDeathFieldValue(value)
    if value == nil or value == "" then
        return "-"
    end

    return tostring(value)
end

---@param value any
---@param allowEmptyValue boolean|nil
---@return string
function GrimUI.GetTooltipFieldValue(value, allowEmptyValue)
    if allowEmptyValue == true and value == "" then
        return ""
    end

    return GrimUI.GetDeathFieldValue(value)
end

---@param timestamp number
---@return string
local function FormatClockTime(timestamp)
    return tostring(date("%H:%M", timestamp))
end

---@param timestamp number
---@return string
local function FormatFullDate(timestamp)
    return tostring(date("%B %d, %Y", timestamp))
end

---@param death GrimDeath
---@return string
function GrimUI.GetStoredDeathTime(death)
    return FormatClockTime(tonumber(death.timestamp) or 0)
end

---@param death GrimDeath
---@return string
function GrimUI.GetStoredDeathDate(death)
    return FormatFullDate(tonumber(death.timestamp) or 0)
end

---@param death GrimDeath
---@return string
function GrimUI.GetStoredDeathDateTime(death)
    return string.format(
        "%s %s",
        GrimUI.GetStoredDeathDate(death),
        GrimUI.GetStoredDeathTime(death)
    )
end

---@param multiplierValue number|string|nil
---@return string
function GrimUI.GetMultiplierDisplay(multiplierValue)
    if tonumber(multiplierValue) == 0 then
        return "-"
    end

    return GrimLogic.FormatMultiplier(multiplierValue)
end

---@param parent table
---@param text string
---@param point string
---@param relativeTo table|nil
---@param relativePoint string|nil
---@param x number|nil
---@param y number|nil
---@return table
function GrimUI.AddLabel(parent, text, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetText(text)
    return label
end

---@param index integer
---@param fallbackColor number[]
---@return number[]
local function GetItemQualityColor(index, fallbackColor)
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[index] then
        local qualityColor = ITEM_QUALITY_COLORS[index]
        return { qualityColor.r, qualityColor.g, qualityColor.b }
    end

    return fallbackColor
end

---@param points number
---@return number[]
local function GetScoreColor(points)
    local colors = GrimUI.COLORS
    local quality = GrimLogic.GetPointColorQuality(points)

    if quality == 0 then
        return GetItemQualityColor(0, colors.poorMatchDeath)
    end

    if quality == 1 then
        return GetItemQualityColor(1, colors.commonMatchDeath)
    end

    if quality == 2 then
        return GetItemQualityColor(2, colors.uncommonMatchDeath)
    end

    if quality == 3 then
        return GetItemQualityColor(3, colors.rareMatchDeath)
    end

    return GetItemQualityColor(4, colors.epicMatchDeath)
end

---@param frame table
---@return GrimFrameAnchor|nil
local function GetFrameAnchor(frame)
    if not frame.GetPoint then
        return nil
    end

    local point, _, relativePoint, xOffset, yOffset = frame:GetPoint(1)
    if not point then
        return nil
    end

    return {
        point = point,
        relativePoint = relativePoint,
        x = xOffset or 0,
        y = yOffset or 0,
    }
end

---@param frame table
---@param anchor GrimFrameAnchor
---@return boolean
local function ApplyFrameAnchor(frame, anchor)
    if not anchor.point then
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        anchor.point,
        UIParent,
        anchor.relativePoint or anchor.point,
        anchor.x or 0,
        anchor.y or 0
    )
    return true
end

---@param frame table
---@return GrimCharacterState
function GrimUI.GetState(frame)
    local currentFrame = frame

    while currentFrame do
        if currentFrame.state then
            return currentFrame.state
        end

        if not currentFrame.GetParent then
            break
        end

        currentFrame = currentFrame:GetParent()
    end

    --- this used to return nil, but now we consider it programmer error
    error("state table is required", 2)
end

---@param frame table
---@param logic GrimMainLogic
---@return GrimDisplayState|nil
function GrimUI.GetIntroDemoDisplayedState(frame, logic)
    local introDemoController = frame.introDemoController
    if introDemoController then
        return introDemoController:GetDisplayedState(logic)
    end

    return nil
end

---@param frame table|nil
---@param database GrimCharacterState
---@param collapsed boolean|nil
function GrimUI.SaveWindowPosition(frame, database, collapsed)
    if not frame then
        return
    end

    local anchor = GetFrameAnchor(frame)
    if not anchor then
        return
    end

    GrimDatabase.SetWindowPosition(database, collapsed, anchor)
end

---@param frame table
---@param database GrimCharacterState
---@param collapsed boolean
---@return boolean
local function RestoreWindowPosition(frame, database, collapsed)
    local anchor = GrimDatabase.GetWindowPosition(database, collapsed)
    if not anchor or not anchor.point then
        return false
    end

    return ApplyFrameAnchor(frame, anchor)
end

---@param value string|nil
---@return string|nil
function GrimUI.NormalizeLevelRangeValue(value)
    if value == nil or value == "" or value == GrimUI.LEVEL_RANGES[1] then
        return nil
    end

    return value
end

---@param frame table
---@param logic table
---@param prediction GrimPrediction|GrimPredictionElements|nil
function GrimUI.ApplyPredictionInputState(frame, logic, prediction)
    local elements = logic.GetPredictionElements(prediction) or {}
    local selectedLevelRange = GrimUI.NormalizeLevelRangeValue(elements.levelRange) or GrimUI.LEVEL_RANGES[1]

    frame.selectedLevelRange = selectedLevelRange

    if frame.sourceEditBox then
        frame.sourceEditBox:SetText(logic.ToDisplayText(elements.source) or "")
    end

    if frame.zoneEditBox then
        frame.zoneEditBox:SetText(logic.ToDisplayText(elements.zone) or "")
    end
end

---@param frame table
---@return boolean
local function HasActiveIntroDemo(frame)
    local introDemoController = frame.introDemoController
    return introDemoController ~= nil and introDemoController:IsActive() == true
end

---@param frame table
---@param predictionInputsLocked boolean
---@return string
local function GetLockButtonLabel(frame, predictionInputsLocked)
    local isIntroDemoShown = HasActiveIntroDemo(frame)

    if isIntroDemoShown then
        return "START GAME"
    end

    if predictionInputsLocked then
        return "LOCKED IN"
    end

    return "LOCK IN"
end

---@param frame table
---@param predictionInputsLocked boolean
local function ApplyLevelRangeButtonLockState(frame, predictionInputsLocked)
    local shouldDisableAllLevelButtons = predictionInputsLocked and HasActiveIntroDemo(frame)

    for _, button in ipairs(frame.levelRangeButtons or {}) do
        if shouldDisableAllLevelButtons then
            button:Disable()
        elseif predictionInputsLocked then
            if button.levelRangeValue == frame.selectedLevelRange then
                button:Enable()
            else
                button:Disable()
            end
        elseif button.levelRangeValue == frame.selectedLevelRange then
            button:Disable()
        else
            button:Enable()
        end
    end
end

---@param frame table
---@param locked boolean|nil
function GrimUI.ApplyPredictionInputLockState(frame, locked)
    local predictionInputsLocked = locked == true
    frame.predictionInputsLocked = predictionInputsLocked
    local editBoxColor

    if predictionInputsLocked then
        editBoxColor = GrimUI.COLORS.predictionInputLocked
    else
        editBoxColor = GrimUI.COLORS.predictionInputActive
    end

    if frame.lockButton then
        frame.lockButton:SetText(GetLockButtonLabel(frame, predictionInputsLocked))
    end

    ApplyLevelRangeButtonLockState(frame, predictionInputsLocked)

    if frame.sourceEditBox then
        if predictionInputsLocked then
            frame.sourceEditBox:Disable()
        else
            frame.sourceEditBox:Enable()
        end
        frame.sourceEditBox:SetTextColor(unpack(editBoxColor))
    end

    if frame.zoneEditBox then
        if predictionInputsLocked then
            frame.zoneEditBox:Disable()
        else
            frame.zoneEditBox:Enable()
        end
        frame.zoneEditBox:SetTextColor(unpack(editBoxColor))
    end

    if predictionInputsLocked then
        ns.GrimUIAutocomplete.HideDropdown(frame)
    end
end

---@param death GrimDeath
---@return number[]
function GrimUI.GetDeathRowColor(death)
    return GetScoreColor(GrimLogic.GetStoredDeathAwardedPoints(death))
end

---@param regions table[]|nil
---@param shown boolean|nil
local function SetRegionsShown(regions, shown)
    if not regions then
        return
    end

    for _, region in ipairs(regions) do
        if shown then
            region:Show()
        else
            region:Hide()
        end
    end
end

---@param frame table
local function UpdateCollapseButton(frame)
    if frame.minimizeButton then
        local texturePrefix = frame.isCollapsed and "UI-PlusButton" or "UI-MinusButton"

        frame.minimizeButton:SetNormalTexture("Interface\\Buttons\\" .. texturePrefix .. "-UP")
        frame.minimizeButton:SetPushedTexture("Interface\\Buttons\\" .. texturePrefix .. "-DOWN")
        frame.minimizeButton:SetHighlightTexture("Interface\\Buttons\\" .. texturePrefix .. "-Hilight")
        frame.minimizeButton:SetDisabledTexture("Interface\\Buttons\\" .. texturePrefix .. "-DISABLED")
    end
end

---@param frame table
---@param stateKey string
local function RememberAndHideWindow(frame, stateKey)
    local childFrame = frame[stateKey]
    if not childFrame then
        return
    end

    local childShown = childFrame:IsShown()

    if childShown or frame:IsShown() or frame.collapsedWindowStates[stateKey] == nil then
        frame.collapsedWindowStates[stateKey] = childShown
    end
    childFrame:Hide()
end

---@param frame table
---@param stateKey string
local function RestoreCollapsedWindowState(frame, stateKey)
    local childFrame = frame[stateKey]
    if childFrame and frame.collapsedWindowStates[stateKey] then
        childFrame:Show()
    end

    frame.collapsedWindowStates[stateKey] = false
end

---@param frame table
local function ApplyWindowResizeState(frame)
    local layout = GrimUI.LAYOUT

    if not frame.SetResizable then
        return
    end

    frame:SetResizable(frame.isCollapsed)
    if frame.isCollapsed ~= true then
        return
    end

    if frame.SetMinResize then
        frame:SetMinResize(layout.collapsedWindowWidth, layout.collapsedWindowMinHeight)
    end
    if frame.SetMaxResize then
        frame:SetMaxResize(layout.collapsedWindowWidth, layout.collapsedWindowMaxHeight)
    end
end

---@param frame table
local function ApplyCollapsedChildWindowState(frame)
    if frame.isCollapsed then
        if frame.githubLinkFrame then
            frame.githubLinkFrame:Hide()
        end
        RememberAndHideWindow(frame, "logFrame")
        RememberAndHideWindow(frame, "helpFrame")
        return
    end

    RestoreCollapsedWindowState(frame, "logFrame")
    RestoreCollapsedWindowState(frame, "helpFrame")
end

---@param logFrame table
---@param shouldShow boolean
local function ApplyLogWindowDisplayState(logFrame, shouldShow)
    if shouldShow then
        if logFrame.RefreshHistory then
            logFrame:RefreshHistory()
        end
        logFrame:Show()
        return
    end

    logFrame:Hide()
end

---@param frame table
---@return boolean
local function IsSetupWindowShown(frame)
    return frame.setupFrame ~= nil and frame.setupFrame:IsShown() == true
end

---@param frame table
---@return boolean
local function IsHelpWindowShown(frame)
    return frame.helpFrame ~= nil and frame.helpFrame:IsShown() == true
end

---@param frame table
---@return boolean
local function IsGitHubLinkDialogShown(frame)
    return frame.githubLinkFrame ~= nil and frame.githubLinkFrame:IsShown() == true
end

---@param frame table
---@return boolean
local function IsHelpModalShown(frame)
    return IsHelpWindowShown(frame) or IsGitHubLinkDialogShown(frame)
end

---@param frame table
local function ReapplyHelpModalPredictionState(frame)
    if not IsHelpModalShown(frame) then
        return
    end

    if frame.SetPredictionInputsLocked then
        frame.SetPredictionInputsLocked(true)
    end

    if frame.RefreshPredictionActionButtonState then
        frame.RefreshPredictionActionButtonState()
    end
end

---@param frame table
local function RefreshWindowAfterCollapseStateChange(frame)
    if frame.RefreshCollapsedSummary then
        frame:RefreshCollapsedSummary()
    end

    if not frame.isCollapsed then
        if frame.RefreshRecentDeathLogState then
            frame:RefreshRecentDeathLogState()
        end
        ReapplyHelpModalPredictionState(frame)
    end

    if frame.RefreshIntroDemoVisibility and HasActiveIntroDemo(frame) then
        frame:RefreshIntroDemoVisibility()
    elseif frame.demoModeWatermark then
        frame.demoModeWatermark:Hide()
        if frame.introDemoAttractPanel then
            frame.introDemoAttractPanel:Hide()
        end
    end
end

---@param frame table
---@param database GrimCharacterState
---@param collapsed boolean
function GrimUI.SetWindowCollapsed(frame, database, collapsed)
    local layout = GrimUI.LAYOUT

    frame.collapsedWindowStates = frame.collapsedWindowStates or {}
    if frame.isCollapsed ~= nil and frame.isCollapsed ~= (collapsed == true) then
        GrimUI.SaveWindowPosition(frame, database, frame.isCollapsed)
    end
    frame.isCollapsed = collapsed == true
    frame:SetSize(
        frame.isCollapsed and layout.collapsedWindowWidth or layout.expandedWindowWidth,
        frame.isCollapsed
            and GrimUI.NormalizeCollapsedWindowHeight(GrimDatabase.GetCollapsedWindowHeight(database))
            or layout.mainWindowHeight
    )
    ApplyWindowResizeState(frame)
    RestoreWindowPosition(frame, database, frame.isCollapsed)
    SetRegionsShown(frame.collapsibleRegions, not frame.isCollapsed)
    SetRegionsShown(frame.collapsedVisibleRegions, frame.isCollapsed)
    UpdateCollapseButton(frame)
    GrimUI.SetEscapeClosable(frame, not frame.isCollapsed)
    ApplyCollapsedChildWindowState(frame)
    ns.GrimUITooltip.HideGameInfoCallout(frame.gameInfoCallout)

    GrimDatabase.SetCollapsed(database, frame.isCollapsed)
    RefreshWindowAfterCollapseStateChange(frame)
end

---@param frame table
---@param database GrimCharacterState
function GrimUI.ResetMainWindow(frame, database)
    GrimUI.SetWindowCollapsed(frame, database, false)
    GrimDatabase.SetWindowPosition(database, false, nil)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
end

---@param database GrimCharacterState
---@return boolean
function GrimUI.ShouldLogWindowBeShown(database)
    return GrimDatabase.GetLogWindowShown(database)
end

---@param frame table|nil
---@param database GrimCharacterState
---@param shown boolean|nil
function GrimUI.SetLogWindowShown(frame, database, shown)
    if not frame or not frame.logFrame then
        return
    end

    frame.collapsedWindowStates = frame.collapsedWindowStates or {}
    local shouldShow = shown == true
    GrimDatabase.SetLogWindowShown(database, shouldShow)

    if frame.isCollapsed then
        frame.collapsedWindowStates.logFrame = shouldShow
    end

    if IsSetupWindowShown(frame) then
        frame.logFrame:Hide()
        return
    end

    ApplyLogWindowDisplayState(frame.logFrame, shouldShow)
end

---@param frame table|nil
---@param database GrimCharacterState
function GrimUI.ApplyDesiredLogWindowState(frame, database)
    if not frame or not frame.logFrame then
        return
    end

    local shouldShow = GrimUI.ShouldLogWindowBeShown(database)

    frame.collapsedWindowStates = frame.collapsedWindowStates or {}
    frame.collapsedWindowStates.logFrame = shouldShow

    if frame.isCollapsed or not frame:IsShown() or IsSetupWindowShown(frame) then
        frame.logFrame:Hide()
        return
    end

    ApplyLogWindowDisplayState(frame.logFrame, shouldShow)
end

return GrimUI
