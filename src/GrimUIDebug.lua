local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIDebug = ns.GrimUIDebug or {}
ns.GrimUIDebug = GrimUIDebug

---@param parent table
---@param pointX number
---@param pointY number
---@return table
local function CreateRawMessageEditBox(parent, pointX, pointY)
    local gutter = GrimUI.LAYOUT.outsideGutter
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", pointX, pointY)
    editBox:SetSize(parent:GetWidth() - (gutter * 2), 36)
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetTextInsets(8, 8, 4, 4)
    editBox:SetText("")
    editBox:SetCursorPosition(0)
    ---@param self table
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return editBox
end

function GrimUIDebug.CreateDebugWindow()
    local addLabel = GrimUI.AddLabel
    local gutter = GrimUI.LAYOUT.outsideGutter

    local debugFrame = CreateFrame("Frame", "GrimDebugFrame", UIParent, "BasicFrameTemplateWithInset")
    debugFrame:SetSize(560, 400)
    debugFrame:SetPoint("CENTER", UIParent, "CENTER", 40, -40)
    debugFrame:SetFrameStrata("DIALOG")
    debugFrame:SetToplevel(true)
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
    debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
    debugFrame:Hide()

    local debugTitle = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    debugTitle:SetPoint("TOP", debugFrame, "TOP", 0, -6)
    debugTitle:SetText("DEBUG")

    local debugSubtitle = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugSubtitle:SetPoint("TOP", debugTitle, "BOTTOM", 0, -4)
    debugSubtitle:SetText("Latest live values, parsed death, and score breakdown")

    local debugStateTitle = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugStateTitle:SetPoint("TOPLEFT", debugFrame, "TOPLEFT", gutter, -54)
    debugStateTitle:SetText("Latest Values")

    local debugDetailsTitle = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugDetailsTitle:SetPoint("TOPLEFT", debugFrame, "TOPLEFT", gutter, -140)
    debugDetailsTitle:SetText("Latest Parsed Blizzard Data")

    local debugScoreTitle = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugScoreTitle:SetPoint("TOPLEFT", debugFrame, "TOPLEFT", gutter, -230)
    debugScoreTitle:SetText("Latest Point Calculation")

    debugFrame.detailLabels = {}
    debugFrame.detailValues = {}
    local debugDetailFields = {
        { key = "totalPoints", label = "Total points:", x = 22, y = -82, width = 80 },
        { key = "currentPredictionStreak", label = "Current streak:", x = 180, y = -82, width = 80 },
        { key = "longestPredictionStreak", label = "Longest streak:", x = 340, y = -82, width = 80 },
        { key = "lockedPrediction", label = "Locked prediction:", x = 22, y = -114, width = 500 },
        { key = "time", label = "Time:", x = 22, y = -160, width = 120 },
        { key = "name", label = "Name:", x = 260, y = -160, width = 200 },
        { key = "level", label = "Level:", x = 22, y = -178, width = 80 },
        { key = "sourceName", label = "Source:", x = 260, y = -178, width = 220 },
        { key = "zone", label = "Zone:", x = 22, y = -195, width = 458 },
        { key = "predictionStreak", label = "Prediction streak:", x = 22, y = -250, width = 80 },
        { key = "basePoints", label = "Base points:", x = 180, y = -250, width = 80 },
        { key = "awardedPoints", label = "Awarded:", x = 340, y = -250, width = 80 },
        { key = "comboMultiplier", label = "Combo bonus:", x = 22, y = -265, width = 80 },
        { key = "streakMultiplier", label = "Streak bonus:", x = 180, y = -265, width = 80 },
        { key = "multiplier", label = "Total multiplier:", x = 340, y = -265, width = 100 },
        { key = "pointFormula", label = "Formula:", x = 22, y = -280, width = 110 },
        { key = "comboDetails", label = "Winning combo:", x = 180, y = -280, width = 250 },
    }

    for _, field in ipairs(debugDetailFields) do
        local label = addLabel(debugFrame, field.label, "TOPLEFT", debugFrame, "TOPLEFT", field.x, field.y)
        debugFrame.detailLabels[field.key] = label
        local value = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("LEFT", label, "RIGHT", 8, 0)
        value:SetWidth(field.width)
        value:SetJustifyH("LEFT")
        if field.key == "lockedPrediction" or field.key == "comboDetails" then
            value:SetJustifyV("TOP")
            value:SetWordWrap(true)
        end
        debugFrame.detailValues[field.key] = value
    end

    local rawMessageLabel = addLabel(debugFrame, "Raw message:", "TOPLEFT", debugFrame, "TOPLEFT", gutter, -300)
    debugFrame.detailLabels.sourceMessage = rawMessageLabel
    debugFrame.detailValues.sourceMessage = CreateRawMessageEditBox(debugFrame, gutter, -315)

    return debugFrame
end
