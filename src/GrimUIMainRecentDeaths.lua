local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIDeathLogList = ns.GrimUIDeathLogList
local GrimUIMainRecentDeaths = ns.GrimUIMainRecentDeaths or {}
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUIMainRecentDeaths = GrimUIMainRecentDeaths

local EMPTY_PREDICTION_PROMPT_TEXT = "Make your prediction"

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param maxRecentDeaths integer
---@param deathLogColumns GrimDeathLogColumn[]
function GrimUIMainRecentDeaths.CreateMainRecentDeathsSection(frame, layout, maxRecentDeaths, deathLogColumns)
    local gutter = layout.outsideGutter
    local promptWidth = math.floor(((layout.expandedWindowWidth - (gutter * 2)) * 2) / 3)

    for _, column in ipairs(deathLogColumns) do
        local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", gutter + column.x, layout.deathLogHeaderY)
        header:SetWidth(column.width)
        header:SetJustifyH(column.justifyH or "LEFT")
        header:SetWordWrap(false)
        header:SetNonSpaceWrap(false)
        header:SetText(column.label)
        GrimUI.RegisterCollapsibleRegion(frame, header)
    end

    local recentDeathsFrame = CreateFrame("Frame", nil, frame)
    recentDeathsFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", gutter, layout.deathLogFrameY)
    recentDeathsFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -gutter, layout.deathLogFrameY)
    recentDeathsFrame:SetHeight(maxRecentDeaths * layout.deathLogRowHeight)
    frame.recentDeathsFrame = recentDeathsFrame
    GrimUI.RegisterCollapsibleRegion(frame, recentDeathsFrame)

    local demoModeWatermark = recentDeathsFrame:CreateFontString(nil, "BACKGROUND", "QuestTitleFont")
    demoModeWatermark:SetPoint("CENTER", recentDeathsFrame, "CENTER", 0, 20)
    demoModeWatermark:SetWidth(promptWidth)
    demoModeWatermark:SetJustifyH("CENTER")
    demoModeWatermark:SetJustifyV("MIDDLE")
    demoModeWatermark:SetWordWrap(true)
    demoModeWatermark:SetTextColor(0.5, 0.5, 0.5, 0.1)
    demoModeWatermark:SetText("DEMO MODE")
    demoModeWatermark:Hide()
    recentDeathsFrame.demoModeWatermark = demoModeWatermark
    frame.demoModeWatermark = demoModeWatermark

    local emptyPredictionPrompt = recentDeathsFrame:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    emptyPredictionPrompt:SetPoint("CENTER", recentDeathsFrame, "CENTER", 0, 20)
    emptyPredictionPrompt:SetWidth(promptWidth)
    emptyPredictionPrompt:SetJustifyH("CENTER")
    emptyPredictionPrompt:SetJustifyV("MIDDLE")
    emptyPredictionPrompt:SetWordWrap(true)
    emptyPredictionPrompt:SetTextColor(1, 0.82, 0, 1)
    emptyPredictionPrompt:SetText(EMPTY_PREDICTION_PROMPT_TEXT)
    emptyPredictionPrompt:Hide()
    recentDeathsFrame.emptyPredictionPrompt = emptyPredictionPrompt
    frame.emptyPredictionPrompt = emptyPredictionPrompt

    local waitingPromptText = recentDeathsFrame:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    waitingPromptText:SetPoint("CENTER", recentDeathsFrame, "CENTER", 0, 20)
    waitingPromptText:SetJustifyH("CENTER")
    waitingPromptText:SetJustifyV("MIDDLE")
    waitingPromptText:SetWordWrap(false)
    waitingPromptText:SetTextColor(1, 0.82, 0, 1)
    waitingPromptText:Hide()
    recentDeathsFrame.waitingPromptText = waitingPromptText
    frame.waitingPromptText = waitingPromptText

    local waitingPromptDots = recentDeathsFrame:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    waitingPromptDots:SetPoint("LEFT", waitingPromptText, "RIGHT", 0, 0)
    waitingPromptDots:SetJustifyH("LEFT")
    waitingPromptDots:SetJustifyV("MIDDLE")
    waitingPromptDots:SetWordWrap(false)
    waitingPromptDots:SetTextColor(1, 0.82, 0, 1)
    waitingPromptDots:Hide()
    recentDeathsFrame.waitingPromptDots = waitingPromptDots
    frame.waitingPromptDots = waitingPromptDots

    local waitingPromptHelpText = recentDeathsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    waitingPromptHelpText:SetPoint("TOP", waitingPromptText, "BOTTOM", 0, -6)
    waitingPromptHelpText:SetWidth(promptWidth)
    waitingPromptHelpText:SetJustifyH("CENTER")
    waitingPromptHelpText:SetJustifyV("TOP")
    waitingPromptHelpText:SetWordWrap(true)
    waitingPromptHelpText:SetTextColor(1, 0.82, 0, 1)
    waitingPromptHelpText:Hide()
    recentDeathsFrame.waitingPromptHelpText = waitingPromptHelpText
    frame.waitingPromptHelpText = waitingPromptHelpText

    GrimUIDeathLogList.CreateDeathLogList(recentDeathsFrame, {
        columns = deathLogColumns,
        rowCount = maxRecentDeaths,
        rowHeight = layout.deathLogRowHeight,
        rowLeft = 0,
        rowTop = 0,
        rowRight = 0,
        tooltipOptions = GrimUITooltip.MAIN_LOG_TOOLTIP_OPTIONS,
    })

    frame.deathRows = recentDeathsFrame.rows
end
