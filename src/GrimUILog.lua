local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimDatabase = ns.GrimDatabase
local GrimUIDeathLogList = ns.GrimUIDeathLogList
local GrimUILog = ns.GrimUILog or {}
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUILog = GrimUILog

---@class GrimHistoryParentFrame: GrimMainFrameShell
---@field [string] any
---@field frameStrata string|nil
---@field GetFrameLevel fun(self: GrimHistoryParentFrame): number

---@class GrimHistoryFrame: GrimRefreshHistoryFrame
---@field [string] any
---@field CloseButton table|nil
---@field dragHandle table
---@field rows table[]
---@field logSubtitle table
---@field filterButton table
---@field columnHeaders table<string, table>
---@field showSuccessfulOnly boolean
---@field scrollFrame table

---@param parentFrame GrimHistoryParentFrame
---@return GrimHistoryFrame
function GrimUILog.CreateHistoryWindow(parentFrame)
    ---@type GrimDeathLogColumn[]
    local historyColumns = GrimUI.HISTORY_LOG_COLUMNS
    ---@type GrimMainLayout
    local layout = GrimUI.LAYOUT
    local visibleRows = layout.logVisibleRows
    local rowHeight = layout.deathLogRowHeight
    local rowLeft = layout.outsideGutter
    local headerTop = layout.historyLogHeaderY
    local rowTop = layout.historyLogFrameY
    local filterButtonBottom = layout.footerGutter
    ---@type GrimCharacterState
    local state = GrimUI.GetState(parentFrame)

    local GrimLog = CreateFrame("Frame", "GrimLogFrame", UIParent, "BasicFrameTemplateWithInset")
    ---@cast GrimLog GrimHistoryFrame
    GrimLog:SetSize(layout.logWindowWidth, layout.logWindowHeight)
    GrimLog:SetPoint("TOPLEFT", parentFrame, "TOPRIGHT", 12, 0)
    GrimLog:SetFrameStrata(parentFrame.frameStrata or "MEDIUM")
    GrimLog:SetFrameLevel(parentFrame:GetFrameLevel())
    GrimLog:SetToplevel(false)
    GrimLog:SetMovable(false)
    GrimLog:EnableMouse(true)
    GrimLog:Hide()

    local dragHandle = CreateFrame("Frame", nil, GrimLog)
    dragHandle:SetPoint(
        "TOPLEFT",
        GrimLog,
        "TOPLEFT",
        layout.titlebarDragLeftInset,
        layout.titlebarDragTopInset
    )
    dragHandle:SetPoint(
        "TOPRIGHT",
        GrimLog,
        "TOPRIGHT",
        -layout.titlebarDragRightInset,
        layout.titlebarDragTopInset
    )
    dragHandle:SetHeight(layout.titlebarDragHeight)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        parentFrame:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        parentFrame:StopMovingOrSizing()
        GrimUI.SaveWindowPosition(parentFrame, state, parentFrame.isCollapsed)
    end)
    GrimLog.dragHandle = dragHandle

    if GrimLog.CloseButton then
        GrimLog.CloseButton:SetScript("OnClick", function()
            GrimUI.SetLogWindowShown(parentFrame, state, false)
        end)
    end

    local logTitle = GrimLog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    logTitle:SetPoint("TOP", GrimLog, "TOP", 0, -5)
    logTitle:SetText("LOG")

    local logSubtitle = GrimLog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logSubtitle:SetPoint("TOP", GrimLog, "TOP", 0, layout.historySubtitleY)
    logSubtitle:SetText(
        GrimDatabase.GetHistorySuccessfulOnly(state)
            and GrimUI.HISTORY_SUBTITLE_SUCCESS_ONLY
            or GrimUI.HISTORY_SUBTITLE_ALL
    )
    GrimLog.logSubtitle = logSubtitle
    GrimLog.showSuccessfulOnly = GrimDatabase.GetHistorySuccessfulOnly(state)
    ---@type table<string, table>
    GrimLog.columnHeaders = {}

    for _, column in ipairs(historyColumns) do
        local header = GrimLog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", GrimLog, "TOPLEFT", rowLeft + column.x, headerTop)
        header:SetWidth(column.width)
        header:SetJustifyH(column.justifyH)
        header:SetWordWrap(false)
        header:SetNonSpaceWrap(false)
        if column.key == "time" and GrimLog.showSuccessfulOnly == true then
            header:SetText(GrimUI.HISTORY_SUCCESS_RANK_LABEL)
        else
            header:SetText(column.label)
        end
        GrimLog.columnHeaders[column.key] = header
    end

    local logScrollFrame = CreateFrame(
        "ScrollFrame",
        "GrimLogScrollFrame",
        GrimLog,
        "FauxScrollFrameTemplate"
    )
    logScrollFrame:SetPoint("TOPLEFT", GrimLog, "TOPLEFT", layout.outsideGutter, rowTop)
    logScrollFrame:SetPoint("BOTTOMRIGHT", GrimLog, "BOTTOMRIGHT", -(layout.outsideGutter + layout.scrollbarInset), 50)
    GrimLog.scrollFrame = logScrollFrame

    GrimUIDeathLogList.CreateDeathLogList(GrimLog, {
        columns = historyColumns,
        rowCount = visibleRows,
        rowHeight = rowHeight,
        rowLeft = rowLeft,
        rowTop = rowTop,
        rowRight = -(layout.outsideGutter + layout.historyScrollbarGap + layout.scrollbarInset),
        tooltipOptions = GrimUITooltip.LOG_WINDOW_TOOLTIP_OPTIONS,
    })

    local filterButton = CreateFrame("Button", "GrimLogFilterButton", GrimLog, "GameMenuButtonTemplate")
    filterButton:SetSize(160, layout.compactButtonHeight)
    filterButton:SetPoint("BOTTOM", GrimLog, "BOTTOM", 0, filterButtonBottom)
    filterButton:SetText(
        GrimLog.showSuccessfulOnly == true
            and GrimUI.HISTORY_FILTER_BUTTON_SHOW_ALL
            or GrimUI.HISTORY_FILTER_BUTTON_SHOW_SUCCESS_ONLY
    )
    filterButton:SetScript("OnClick", function()
        GrimLog.showSuccessfulOnly = GrimLog.showSuccessfulOnly ~= true
        GrimDatabase.SetHistorySuccessfulOnly(state, GrimLog.showSuccessfulOnly)
        if GrimLog.scrollFrame then
            GrimLog.scrollFrame.offset = 0
        end
        if GrimLog.RefreshHistory then
            GrimLog:RefreshHistory()
        end
    end)
    GrimLog.filterButton = filterButton

    logScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, function()
            GrimLog:RefreshHistory()
        end)
    end)

    return GrimLog
end
