local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIDeathLogList = ns.GrimUIDeathLogList
local GrimUIMainCollapsed = ns.GrimUIMainCollapsed or {}
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUIMainCollapsed = GrimUIMainCollapsed

---@param frame GrimMainFrameShell
---@param layout GrimMainLayout
---@param maxRecentDeaths integer
---@param collapsedLogColumns GrimDeathLogColumn[]
function GrimUIMainCollapsed.CreateMainCollapsedSection(frame, layout, maxRecentDeaths, collapsedLogColumns)
    local gutter = layout.outsideGutter
    local footerGutter = layout.footerGutter

    frame.collapsedLogHeaders = {}
    for _, column in ipairs(collapsedLogColumns) do
        local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", gutter + column.x, layout.collapsedLogHeaderY)
        header:SetWidth(column.width)
        header:SetJustifyH(column.justifyH or "LEFT")
        header:SetWordWrap(false)
        header:SetNonSpaceWrap(false)
        header:SetText(column.label)
        header:Hide()
        frame.collapsedLogHeaders[#frame.collapsedLogHeaders + 1] = header
        GrimUI.RegisterCollapsedVisibleRegion(frame, header)
    end

    local collapsedLogFrame = CreateFrame("Frame", nil, frame)
    collapsedLogFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", gutter, layout.collapsedLogFrameY)
    collapsedLogFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -gutter, 34)
    collapsedLogFrame:Hide()
    frame.collapsedLogFrame = collapsedLogFrame
    GrimUI.RegisterCollapsedVisibleRegion(frame, collapsedLogFrame)
    GrimUIDeathLogList.CreateDeathLogList(collapsedLogFrame, {
        columns = collapsedLogColumns,
        rowCount = math.min(maxRecentDeaths, layout.collapsedLogVisibleRows),
        rowHeight = layout.collapsedLogRowHeight,
        rowLeft = 0,
        rowTop = 0,
        rowRight = 0,
        tooltipOptions = GrimUITooltip.COLLAPSED_LOG_TOOLTIP_OPTIONS,
    })

    for _, row in ipairs(collapsedLogFrame.rows) do
        row:Hide()
        row:SetScript("OnMouseUp", function(_, button)
            if frame.isCollapsed == true and button == "LeftButton" then
                GrimUI.SetWindowCollapsed(frame, GrimUI.GetState(frame), false)
            end
        end)
        GrimUI.RegisterCollapsedVisibleRegion(frame, row)
    end

    local collapsedScoreDivider = frame:CreateTexture(nil, "ARTWORK")
    collapsedScoreDivider:SetColorTexture(1, 0.82, 0, 0.45)
    collapsedScoreDivider:SetSize(layout.collapsedWindowWidth - (gutter * 2), 1)
    collapsedScoreDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", gutter, 30)
    collapsedScoreDivider:Hide()
    frame.collapsedScoreDivider = collapsedScoreDivider
    GrimUI.RegisterCollapsedVisibleRegion(frame, collapsedScoreDivider)

    local collapsedPointsValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    collapsedPointsValue:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -gutter, footerGutter)
    collapsedPointsValue:SetWidth(60)
    collapsedPointsValue:SetJustifyH("RIGHT")
    collapsedPointsValue:Hide()
    frame.collapsedPointsValue = collapsedPointsValue
    GrimUI.RegisterCollapsedVisibleRegion(frame, collapsedPointsValue)

    local collapsedPointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapsedPointsLabel:SetPoint("RIGHT", collapsedPointsValue, "LEFT", -6, 0)
    collapsedPointsLabel:SetText("Score:")
    collapsedPointsLabel:Hide()
    frame.collapsedPointsLabel = collapsedPointsLabel
    GrimUI.RegisterCollapsedVisibleRegion(frame, collapsedPointsLabel)

    local collapsedResizeHandle = CreateFrame("Button", nil, frame)
    collapsedResizeHandle:SetSize(16, 16)
    collapsedResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    collapsedResizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    collapsedResizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    collapsedResizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    collapsedResizeHandle:Hide()
    collapsedResizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or frame.isCollapsed ~= true then
            return
        end

        frame:StartSizing("BOTTOMRIGHT")
    end)
    collapsedResizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        GrimUI.SaveCollapsedWindowHeight(frame, GrimUI.GetState(frame))
    end)
    frame.collapsedResizeHandle = collapsedResizeHandle
    GrimUI.RegisterCollapsedVisibleRegion(frame, collapsedResizeHandle)
end
