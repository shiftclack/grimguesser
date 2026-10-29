local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIAutocomplete = ns.GrimUIAutocomplete
local GrimDatabase = ns.GrimDatabase
local GrimDebug = ns.GrimDebug
local GrimConstants = ns.GrimConstants
local GrimUIDemo = ns.GrimUIDemo
local GrimUIMainPrediction = ns.GrimUIMainPrediction or {}
local GrimUIMode = ns.GrimUIMode
local GrimUISetup = ns.GrimUISetup
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUIMainPrediction = GrimUIMainPrediction

local SCORE_RULES = GrimConstants.SCORING
local CURRENT_PREDICTION_BONUS_TITLE = "Bonus Multipliers"
local PREDICTION_CONTROL_HEIGHT = 24
local PREDICTION_EDIT_CONTROL_OFFSET_X = 7
local PREDICTION_LEVEL_CONTROL_ROW_OFFSET_Y = 8
local PREDICTION_EDIT_CONTROL_ROW_OFFSET_Y = 11

local function DebugUI(...)
    GrimDebug.Log(...)
end

---@param frame GrimMainFrameShell
---@return boolean
local function IsIntroDemoActive(frame)
    local introDemoController = frame.introDemoController
    return introDemoController ~= nil and introDemoController:IsActive() == true
end

---@param points number
---@return string
local function FormatPointCallout(points)
    local awardedPoints = points or 0

    if awardedPoints == 1 then
        return "1 point"
    end

    return tostring(awardedPoints) .. " points"
end

---@param frame GrimMainFrameShell
---@param region GrimWidget
---@param lines string[]|fun(): string[]
local function AttachPredictionGameInfoCallout(frame, region, lines)
    GrimUITooltip.AttachGameInfoCallout(region, {
        callout = function()
            return frame.gameInfoCallout
        end,
        owner = function()
            return frame.lockButton
        end,
        relativeTo = function()
            return frame.lockButton
        end,
        point = "BOTTOMRIGHT",
        relativePoint = "TOPRIGHT",
        xOffset = 0,
        yOffset = 10,
        lines = lines,
        shouldShow = function()
            return frame.gameInfoCallout ~= nil
                and frame.isCollapsed ~= true
                and frame:IsShown()
        end,
    })
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimPredictionElements
local function BuildPredictionElements(frame, logic)
    return {
        levelRange = GrimUI.NormalizeLevelRangeValue(frame.selectedLevelRange),
        source = logic.NormalizePredictionValue(frame.sourceEditBox:GetText()),
        zone = logic.NormalizePredictionValue(frame.zoneEditBox:GetText()),
    }
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return boolean
local function HasAnyPredictionSelected(frame, logic)
    local elements = BuildPredictionElements(frame, logic)
    return elements.levelRange ~= nil or elements.source ~= nil or elements.zone ~= nil
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimPrediction
local function BuildLockedPrediction(frame, logic)
    return {
        elements = BuildPredictionElements(frame, logic),
        lockedAt = time(),
    }
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimPrediction
local function BuildDraftPrediction(frame, logic)
    return {
        elements = BuildPredictionElements(frame, logic),
    }
end

---@param value any
---@return string|nil
local function GetTrimmedInputText(value)
    if value == nil then
        return nil
    end

    local trimmed = strtrim(tostring(value))
    if trimmed == "" then
        return nil
    end

    return trimmed
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimPrediction|nil
local function UpdateDraftPrediction(frame, logic)
    if frame.predictionInputsLocked then
        return nil
    end

    local draftPrediction = logic.UpdateDraftPrediction(GrimUI.GetState(frame), BuildDraftPrediction(frame, logic))

    return draftPrediction
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimDisplayState
local function GetMainPredictionDisplayState(frame, logic)
    return GrimUI.GetIntroDemoDisplayedState(frame, logic) or logic.GetDisplayState(GrimUI.GetState(frame))
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return GrimUIModeState
local function ResolveMainPredictionMode(frame, logic)
    return GrimUIMode.Resolve(frame, GetMainPredictionDisplayState(frame, logic), GrimUI.GetState(frame))
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
local function RefreshActionButtonState(frame, logic)
    local uiMode = ResolveMainPredictionMode(frame, logic)

    if uiMode.mainBlocked then
        frame.lockButton:Disable()
        frame.pauseButton:Disable()
        return
    end

    if GrimUIMode.IsDemoMode(uiMode) then
        frame.lockButton:Enable()
        frame.pauseButton:Disable()
        return
    end

    local hasLockedPrediction = GrimDatabase.GetLockedPrediction(GrimUI.GetState(frame)) ~= nil

    if hasLockedPrediction then
        frame.lockButton:Disable()
    elseif HasAnyPredictionSelected(frame, logic) then
        frame.lockButton:Enable()
    else
        frame.lockButton:Disable()
    end

    if hasLockedPrediction then
        frame.pauseButton:Enable()
    else
        frame.pauseButton:Disable()
    end
end

---@param frame GrimMainFrameShell
---@param selectedLevelRange string
local function SelectLevelRange(frame, selectedLevelRange)
    frame.selectedLevelRange = selectedLevelRange
    for _, button in ipairs(frame.levelRangeButtons) do
        if button.levelRangeValue == selectedLevelRange then
            button:Disable()
        else
            button:Enable()
        end
    end
end

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param logic GrimMainLogic
---@param levelRanges string[]
local function CreateLevelRangeButtons(frame, layout, logic, levelRanges)
    frame.selectedLevelRange = levelRanges[1]
    frame.levelRangeButtons = {}

    for index, levelRange in ipairs(levelRanges) do
        local button = CreateFrame("Button", "GrimLevelRangeButton" .. index, frame, "GameMenuButtonTemplate")
        button:SetSize(64, layout.compactButtonHeight)
        button:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            layout.predictionControlX + ((index - 1) * 68),
            layout.predictionLevelRowY + PREDICTION_LEVEL_CONTROL_ROW_OFFSET_Y
        )
        button:SetText(levelRange)
        button.levelRangeValue = levelRange
        button:SetMotionScriptsWhileDisabled(true)
        button:SetScript("OnClick", function(self)
            if frame.predictionInputsLocked then
                return
            end

            SelectLevelRange(frame, self.levelRangeValue)
            UpdateDraftPrediction(frame, logic)
            if frame.RefreshRecentDeathLogState then
                frame:RefreshRecentDeathLogState()
            end
            RefreshActionButtonState(frame, logic)
        end)
        frame.levelRangeButtons[index] = button
        GrimUI.RegisterCollapsibleRegion(frame, button)
        AttachPredictionGameInfoCallout(frame, button, {
            FormatPointCallout(SCORE_RULES.fixedLevelRangePoints[levelRange]),
        })
    end

    frame.levelRangeButtons[1]:Disable()
end

---@param frame GrimMainFrameShell
---@param name string
---@param pointX number
---@param pointY number
---@return GrimEditBox
local function CreatePredictionEditBox(frame, name, pointX, pointY)
    local editBox = CreateFrame("EditBox", name, frame, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", pointX, pointY)
    editBox:SetAutoFocus(false)
    editBox:SetSize(180, PREDICTION_CONTROL_HEIGHT)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetText("")
    editBox:SetCursorPosition(0)
    return editBox
end

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param text string
---@param rowY number
---@param controlRowOffsetY number
---@return GrimWidget
local function CreatePredictionControlLabel(frame, layout, text, rowY, controlRowOffsetY)
    local label = GrimUI.AddLabel(
        frame,
        text,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        layout.predictionLabelX,
        rowY + controlRowOffsetY
    )
    label:SetHeight(PREDICTION_CONTROL_HEIGHT)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
local function CreateIntroDemoAttractPanel(frame, layout)
    local width = layout.predictionIntroDemoPanelWidth
    local height = layout.predictionIntroDemoPanelHeight
    local panel = CreateFrame("Frame", nil, frame)

    panel:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        layout.predictionIntroDemoPanelX,
        layout.predictionIntroDemoPanelY
    )
    panel:SetSize(width, height)
    panel:Hide()

    local text = panel:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    text:SetPoint("CENTER", panel, "CENTER", 0, 0)
    text:SetWidth(width - 24)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    text:SetTextColor(1, 0.82, 0, 1)
    text:SetFontObject(GameFontHighlightLarge)
    text:SetText(GrimUIDemo.GetIntroDemoAttractModeText())
    panel.text = text

    frame.introDemoAttractPanel = panel
    GrimUI.RegisterCollapsibleRegion(frame, panel)
end

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param logic GrimMainLogic
---@param levelRanges string[]
function GrimUIMainPrediction.CreateMainPredictionSection(frame, layout, logic, levelRanges)
    local predictionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    predictionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.predictionLabelX, layout.predictionSectionTop)
    predictionTitle:SetText("Prediction")
    GrimUI.RegisterCollapsibleRegion(frame, predictionTitle)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 0.82, 0, 0.45)
    divider:SetSize(layout.expandedWindowWidth - (layout.outsideGutter * 2), 1)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.outsideGutter, layout.deathLogDividerY)
    GrimUI.RegisterCollapsibleRegion(frame, divider)

    local levelRangeLabel = CreatePredictionControlLabel(
        frame,
        layout,
        "Level range:",
        layout.predictionLevelRowY,
        PREDICTION_LEVEL_CONTROL_ROW_OFFSET_Y
    )
    GrimUI.RegisterCollapsibleRegion(frame, levelRangeLabel)
    frame.levelRangeLabel = levelRangeLabel
    CreateLevelRangeButtons(frame, layout, logic, levelRanges)

    local sourceLabel = CreatePredictionControlLabel(
        frame,
        layout,
        "Source:",
        layout.predictionSourceRowY,
        PREDICTION_EDIT_CONTROL_ROW_OFFSET_Y
    )
    GrimUI.RegisterCollapsibleRegion(frame, sourceLabel)
    frame.sourceLabel = sourceLabel
    AttachPredictionGameInfoCallout(frame, sourceLabel, {
        FormatPointCallout(SCORE_RULES.fixedElementPoints.source),
    })

    frame.sourceEditBox = CreatePredictionEditBox(
        frame,
        "GrimSourceEditBox",
        layout.predictionControlX + PREDICTION_EDIT_CONTROL_OFFSET_X,
        layout.predictionSourceRowY + PREDICTION_EDIT_CONTROL_ROW_OFFSET_Y
    )
    GrimUI.RegisterCollapsibleRegion(frame, frame.sourceEditBox)
    AttachPredictionGameInfoCallout(frame, frame.sourceEditBox, {
        FormatPointCallout(SCORE_RULES.fixedElementPoints.source),
    })
    CreateIntroDemoAttractPanel(frame, layout)

    local zoneLabel = CreatePredictionControlLabel(
        frame,
        layout,
        "Location:",
        layout.predictionZoneRowY,
        PREDICTION_EDIT_CONTROL_ROW_OFFSET_Y
    )
    GrimUI.RegisterCollapsibleRegion(frame, zoneLabel)
    frame.zoneLabel = zoneLabel
    AttachPredictionGameInfoCallout(frame, zoneLabel, {
        FormatPointCallout(SCORE_RULES.fixedElementPoints.zone),
    })

    frame.zoneEditBox = CreatePredictionEditBox(
        frame,
        "GrimZoneEditBox",
        layout.predictionControlX + PREDICTION_EDIT_CONTROL_OFFSET_X,
        layout.predictionZoneRowY + PREDICTION_EDIT_CONTROL_ROW_OFFSET_Y
    )
    GrimUI.RegisterCollapsibleRegion(frame, frame.zoneEditBox)
    AttachPredictionGameInfoCallout(frame, frame.zoneEditBox, {
        FormatPointCallout(SCORE_RULES.fixedElementPoints.zone),
    })
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
---@return string[]
local function GetCurrentPredictionGameInfoCalloutLines(frame, logic)
    local displayState
    local prediction
    local lines = {
        CURRENT_PREDICTION_BONUS_TITLE,
    }

    if IsIntroDemoActive(frame) then
        displayState = GrimUI.GetIntroDemoDisplayedState(frame, logic) or logic.GetDisplayState(GrimUI.GetState(frame))
    else
        displayState = logic.GetDisplayState(GrimUI.GetState(frame))
    end

    prediction = displayState.lockedPrediction or displayState.draftPrediction or displayState.lastPrediction

    for _, row in ipairs(logic.GetPredictionPayoutPreviewRows(prediction)) do
        lines[#lines + 1] = row.text
    end

    return lines
end

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param logic GrimMainLogic
function GrimUIMainPrediction.CreateMainCurrentPredictionSummarySection(frame, layout, logic)
    local currentPredictionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentPredictionTitle:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        layout.predictionLabelX,
        layout.predictionZoneRowY + (layout.predictionZoneRowY - layout.predictionSourceRowY)
    )
    currentPredictionTitle:SetText("Current prediction:")
    frame.currentPredictionLabel = currentPredictionTitle
    GrimUI.RegisterCollapsibleRegion(frame, currentPredictionTitle)
    AttachPredictionGameInfoCallout(frame, currentPredictionTitle, function()
        return GetCurrentPredictionGameInfoCalloutLines(frame, logic)
    end)

    local currentPredictionValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    currentPredictionValue:SetPoint("TOPLEFT", currentPredictionTitle, "BOTTOMLEFT", 0, -6)
    currentPredictionValue:SetWidth(layout.predictionSummaryWidth)
    currentPredictionValue:SetJustifyH("LEFT")
    currentPredictionValue:SetJustifyV("TOP")
    currentPredictionValue:SetWordWrap(true)
    currentPredictionValue:SetText(logic.FormatLockedPrediction(nil))
    frame.lockedPredictionValue = currentPredictionValue
    GrimUI.RegisterCollapsibleRegion(frame, currentPredictionValue)
    AttachPredictionGameInfoCallout(frame, currentPredictionValue, function()
        return GetCurrentPredictionGameInfoCalloutLines(frame, logic)
    end)
end

---@param frame GrimMainFrame
---@param logic GrimMainLogic
---@param levelRanges string[]
function GrimUIMainPrediction.OnMainPredictionLockButtonClicked(frame, logic, levelRanges)
    if IsIntroDemoActive(frame) then
        if frame.introDemoController and frame.introDemoController.Dismiss then
            frame.introDemoController:Dismiss()
        end
        if frame.setupFrame then
            GrimUISetup.ShowOnMainWindowOpen(frame.setupFrame, frame)
        end
        return
    end

    local sourceText = GetTrimmedInputText(frame.sourceEditBox:GetText())
    local zoneText = GetTrimmedInputText(frame.zoneEditBox:GetText())
    local lockedPrediction = BuildLockedPrediction(frame, logic)
    logic.ApplyLockedPrediction(GrimUI.GetState(frame), lockedPrediction)
    GrimDatabase.SetHasSeenFirstRun(GrimUI.GetState(frame), true)
    local lockedElements = logic.GetPredictionElements(lockedPrediction)
    ---@cast lockedElements GrimPredictionElements

    local prediction = string.format(
        "Prediction locked at %s: levelRange=%s, source=%s, zone=%s",
        date("%H:%M:%S"),
        lockedElements.levelRange or levelRanges[1],
        sourceText or "-",
        zoneText or "-"
    )
    DebugUI(prediction)
    GrimUI.ApplyPredictionInputLockState(frame, true)
    frame:RefreshLockedPrediction()
    RefreshActionButtonState(frame, logic)
    frame:RefreshAuxiliaryWindowState()
end

---@param frame GrimMainFrame
---@param logic GrimMainLogic
function GrimUIMainPrediction.OnMainPredictionPauseButtonClicked(frame, logic)
    local preservedSourceText = frame.sourceEditBox:GetText()
    local preservedZoneText = frame.zoneEditBox:GetText()

    logic.ClearLockedPrediction(GrimUI.GetState(frame))
    GrimUIAutocomplete.HideDropdown(frame)
    GrimUI.ApplyPredictionInputLockState(frame, false)
    frame:RefreshLockedPrediction()
    frame.sourceEditBox:SetText(preservedSourceText or "")
    frame.zoneEditBox:SetText(preservedZoneText or "")
    UpdateDraftPrediction(frame, logic)
    RefreshActionButtonState(frame, logic)
end

---@param frame GrimMainFrame
---@param logic GrimMainLogic
---@param editBox GrimEditBox
---@param suggestionKind string
local function AttachPredictionEditBoxHandler(frame, logic, editBox, suggestionKind)
    ---@param activeEditBox GrimEditBox
    local function SetActiveSuggestionInput(activeEditBox)
        frame.activeEditBox = activeEditBox
        frame.suggestionKind = suggestionKind
        if suggestionKind == "source" then
            frame.suggestionList = GrimUIAutocomplete.GetSourceSuggestions(GrimUI.GetState(frame))
        else
            frame.suggestionList = GrimUIAutocomplete.GetZoneSuggestions(GrimUI.GetState(frame))
        end
    end

    ---@param self GrimEditBox
    ---@param userInput boolean
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if frame.predictionInputsLocked then
            return
        end
        SetActiveSuggestionInput(self)
        if userInput then
            GrimUIAutocomplete.UpdateSuggestions(frame, self:GetText())
        else
            GrimUIAutocomplete.HideDropdown(frame)
        end
        UpdateDraftPrediction(frame, logic)
        if frame.RefreshRecentDeathLogState then
            frame:RefreshRecentDeathLogState()
        end
        RefreshActionButtonState(frame, logic)
    end)

    editBox:SetScript("OnEditFocusGained", function(self)
        if frame.predictionInputsLocked then
            return
        end
        SetActiveSuggestionInput(self)
    end)

    editBox:SetScript("OnEditFocusLost", function()
        GrimUIAutocomplete.HideDropdown(frame)
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        GrimUIAutocomplete.HideDropdown(frame)
    end)
end

---@param frame GrimMainFrame
---@param logic GrimMainLogic
function GrimUIMainPrediction.AttachMainPredictionEditBoxHandlers(frame, logic)
    AttachPredictionEditBoxHandler(frame, logic, frame.sourceEditBox, "source")
    AttachPredictionEditBoxHandler(frame, logic, frame.zoneEditBox, "zone")
end

---@param frame GrimMainFrameShell
---@param logic GrimMainLogic
function GrimUIMainPrediction.AttachMainPredictionMethods(frame, logic)
    frame.ApplyPredictionInputState = function(prediction)
        GrimUI.ApplyPredictionInputState(frame, logic, prediction)
    end
    frame.RefreshPredictionActionButtonState = function()
        ---@cast frame GrimMainFrame
        RefreshActionButtonState(frame, logic)
    end
    frame.SetPredictionInputsLocked = function(locked)
        GrimUI.ApplyPredictionInputLockState(frame, locked)
    end
end
