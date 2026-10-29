local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimLogic = ns.GrimLogic
local GrimUIDeathLogList = ns.GrimUIDeathLogList or {}
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUIDeathLogList = GrimUIDeathLogList
local EMPTY_DEATHS = {}

---@class GrimDeathDisplayFields
---@field time string
---@field name string
---@field level string
---@field sourceName string
---@field zone string
---@field points string
---@field multiplier string
---@field streakMultiplier string
---@field awardedPoints string

---@class GrimDeathLogDisplayEntry
---@field death GrimDeath
---@field displayFields GrimDeathDisplayFields
---@field awardedPointsValue integer
---@field timestampValue integer
---@field color number[]

---@class GrimDeathLogCacheView
---@field sourceRef GrimDeath[]|nil
---@field sourceSnapshot GrimDeath[]
---@field orderedEntries GrimDeathLogDisplayEntry[]

---@class GrimDeathLogDisplayCache
---@field entriesByDeath table<GrimDeath, GrimDeathLogDisplayEntry>
---@field recentView GrimDeathLogCacheView
---@field historyView GrimDeathLogCacheView
---@field successfulView GrimDeathLogCacheView
---@field [string] GrimDeathLogCacheView|table<GrimDeath, GrimDeathLogDisplayEntry>

---@class GrimDeathLogColumn
---@field key string
---@field label string
---@field x number
---@field width number
---@field justifyH string|nil

---@class GrimDeathLogViewOptions
---@field sortMode string|nil

---@class GrimDeathLogCreateOptions
---@field columns GrimDeathLogColumn[]|nil
---@field rowHeight integer|nil
---@field rowCount integer|nil
---@field rowLeft number|nil
---@field rowTop number|nil
---@field rowRight number|nil
---@field tooltipOptions GrimLogTooltipOptions|nil
---@field fontObject string|nil

---@class GrimDeathLogColumnContext
---@field showRank boolean|nil
---@field rank integer|nil

---@class GrimDeathLogRefreshOptions
---@field columns GrimDeathLogColumn[]|nil
---@field offset integer|nil
---@field maxRows integer|nil
---@field reverseOrder boolean|nil
---@field columnContext GrimDeathLogColumnContext|nil

---@return GrimDeathLogCacheView
local function CreateCacheView()
    return {
        sourceRef = nil,
        sourceSnapshot = {},
        orderedEntries = {},
    }
end

---@param death GrimDeath
---@return integer
local function GetDisplayedPointsValue(death)
    return GrimLogic.GetStoredDeathBasePoints(death)
        + GrimLogic.GetStoredDeathSameZoneBonusPoints(death)
end

---@param death GrimDeath
---@return GrimDeathDisplayFields
local function CreateDisplayFields(death)
    return {
        time = GrimUI.GetDeathFieldValue(GrimUI.GetStoredDeathTime(death)),
        name = GrimUI.GetDeathFieldValue(death.name),
        level = GrimUI.GetDeathFieldValue(death.level),
        sourceName = GrimUI.GetDeathFieldValue(death.sourceName),
        zone = GrimUI.GetDeathFieldValue(death.zone),
        points = GrimUI.GetDeathFieldValue(GetDisplayedPointsValue(death)),
        multiplier = GrimUI.GetDeathFieldValue(
            GrimUI.GetMultiplierDisplay(GrimLogic.GetStoredDeathComboMultiplierValue(death))
        ),
        streakMultiplier = GrimUI.GetDeathFieldValue(
            GrimUI.GetMultiplierDisplay(GrimLogic.GetStoredDeathStreakMultiplierValue(death))
        ),
        awardedPoints = GrimUI.GetDeathFieldValue(GrimLogic.GetStoredDeathAwardedPoints(death)),
    }
end

---@param death GrimDeath
---@return GrimDeathLogDisplayEntry
local function CreateDisplayCacheEntry(death)
    return {
        death = death,
        displayFields = CreateDisplayFields(death),
        awardedPointsValue = GrimLogic.GetStoredDeathAwardedPoints(death),
        timestampValue = tonumber(death.timestamp) or 0,
        color = GrimUI.GetDeathRowColor(death),
    }
end

---@param left GrimDeathLogDisplayEntry
---@param right GrimDeathLogDisplayEntry
---@return boolean
local function CompareSuccessfulEntries(left, right)
    if left.awardedPointsValue == right.awardedPointsValue then
        return left.timestampValue < right.timestampValue
    end

    return left.awardedPointsValue < right.awardedPointsValue
end

---@param view GrimDeathLogCacheView
---@param sourceDeaths GrimDeath[]
---@return boolean
local function SnapshotMatches(view, sourceDeaths)
    if view.sourceRef ~= sourceDeaths then
        return false
    end

    if #view.sourceSnapshot ~= #sourceDeaths then
        return false
    end

    for index, death in ipairs(sourceDeaths) do
        if view.sourceSnapshot[index] ~= death then
            return false
        end
    end

    return true
end

---@param view GrimDeathLogCacheView
---@param sourceDeaths GrimDeath[]
---@param orderedEntries GrimDeathLogDisplayEntry[]
local function ReplaceViewEntries(view, sourceDeaths, orderedEntries)
    view.sourceRef = sourceDeaths
    view.sourceSnapshot = {}
    view.orderedEntries = orderedEntries

    for index, death in ipairs(sourceDeaths) do
        view.sourceSnapshot[index] = death
    end
end

---@param cache GrimDeathLogDisplayCache
---@param death GrimDeath
---@return GrimDeathLogDisplayEntry
local function GetOrCreateCacheEntry(cache, death)
    local entry = cache.entriesByDeath[death]
    if entry then
        return entry
    end

    entry = CreateDisplayCacheEntry(death)
    cache.entriesByDeath[death] = entry
    return entry
end

---@return GrimDeathLogDisplayCache
function GrimUIDeathLogList.CreateDeathLogDisplayCache()
    return {
        entriesByDeath = {},
        recentView = CreateCacheView(),
        historyView = CreateCacheView(),
        successfulView = CreateCacheView(),
    }
end

---@param cache GrimDeathLogDisplayCache
---@param viewKey string
---@param sourceDeaths GrimDeath[]
---@param options GrimDeathLogViewOptions
---@return GrimDeathLogDisplayEntry[]
function GrimUIDeathLogList.GetOrderedDeathLogViewEntries(cache, viewKey, sourceDeaths, options)
    if not cache or not cache.entriesByDeath or not viewKey then
        return {}
    end

    sourceDeaths = sourceDeaths or EMPTY_DEATHS
    options = options or {}

    local view = cache[viewKey]
    if not view then
        view = CreateCacheView()
        cache[viewKey] = view
    end

    if SnapshotMatches(view, sourceDeaths) then
        return view.orderedEntries
    end

    local orderedEntries = {}
    for index, death in ipairs(sourceDeaths) do
        orderedEntries[index] = GetOrCreateCacheEntry(cache, death)
    end

    if options.sortMode == "successful" then
        table.sort(orderedEntries, CompareSuccessfulEntries)
    end

    ReplaceViewEntries(view, sourceDeaths, orderedEntries)
    return view.orderedEntries
end

---@param item GrimDeathLogDisplayEntry
---@param columnKey string
---@param context GrimDeathLogColumnContext
---@return any
local function GetDeathLogItemValue(item, columnKey, context)
    if columnKey == "time" and context.showRank == true then
        return "#" .. tostring(context.rank or 0)
    end

    return item.displayFields[columnKey]
end

---@param item GrimDeath|GrimDeathLogDisplayEntry
---@return GrimDeathLogDisplayEntry
local function NormalizeDeathLogItem(item)
    if item.displayFields then
        ---@cast item GrimDeathLogDisplayEntry
        return item
    end

    ---@cast item GrimDeath
    return CreateDisplayCacheEntry(item)
end

---@param row table
---@param anchor table|nil
local function ShowDeathLogRowTooltip(row, anchor)
    if not row.death then
        return
    end

    GrimUITooltip.ShowStandardizedTooltip(anchor or row, {
        death = row.death,
    }, row.tooltipOptions.showPredictionString, row.tooltipOptions.showIdentity, row.tooltipOptions.showFullCombos)
end

local function HideDeathLogTooltip()
    GameTooltip:Hide()
end

---@param tooltipOptions GrimLogTooltipOptions
---@return boolean
local function HasHoverColumns(tooltipOptions)
    return type(tooltipOptions.hoverColumns) == "table"
end

---@param row table
---@param column GrimDeathLogColumn
---@return table
local function CreateColumnTooltipTarget(row, column)
    local target = CreateFrame("Button", nil, row)
    target:SetPoint("TOPLEFT", row, "TOPLEFT", column.x, 0)
    target:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", column.x, 0)
    target:SetWidth(column.width)
    target:EnableMouse(true)
    target:SetScript("OnEnter", function(self)
        ShowDeathLogRowTooltip(row, self)
    end)
    target:SetScript("OnLeave", HideDeathLogTooltip)
    return target
end

---@param row table
---@param tooltipOptions GrimLogTooltipOptions
local function ApplyDeathLogRowTooltipScripts(row, tooltipOptions)
    if HasHoverColumns(tooltipOptions) then
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        return
    end

    row:SetScript("OnEnter", function(self)
        ShowDeathLogRowTooltip(self)
    end)
    row:SetScript("OnLeave", HideDeathLogTooltip)
end

---@param row table
---@param column GrimDeathLogColumn
---@param fontObject string
---@param tooltipOptions GrimLogTooltipOptions
local function CreateDeathLogColumnCell(row, column, fontObject, tooltipOptions)
    local cell = row:CreateFontString(nil, "OVERLAY", fontObject)
    cell:SetPoint("LEFT", row, "LEFT", column.x, 0)
    cell:SetWidth(column.width)
    cell:SetJustifyH(column.justifyH or "LEFT")
    cell:SetWordWrap(false)
    cell:SetNonSpaceWrap(false)
    row[column.key] = cell

    if HasHoverColumns(tooltipOptions) and tooltipOptions.hoverColumns[column.key] == true then
        local target = CreateColumnTooltipTarget(row, column)
        row.tooltipTargets[column.key] = target
        row[column.key .. "TooltipTarget"] = target
    end
end

---@param frame table
---@param options GrimDeathLogCreateOptions
function GrimUIDeathLogList.CreateDeathLogList(frame, options)
    local columns = options.columns or {}
    local rowHeight = options.rowHeight or 18
    local rowCount = options.rowCount or 0
    local rowLeft = options.rowLeft or 0
    local rowTop = options.rowTop or 0
    local rowRight = options.rowRight or 0
    local tooltipOptions = options.tooltipOptions or {}
    local fontObject = options.fontObject or "GameFontHighlightSmall"

    frame.rows = {}
    frame.logColumns = columns
    frame.logRowHeight = rowHeight
    frame.logTooltipOptions = tooltipOptions
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end

    for rowIndex = 1, rowCount do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", rowLeft, rowTop - ((rowIndex - 1) * rowHeight))
        row:SetPoint("RIGHT", frame, "RIGHT", rowRight, 0)
        row.tooltipOptions = tooltipOptions
        row.tooltipTargets = {}
        if row.SetClipsChildren then
            row:SetClipsChildren(true)
        end

        ApplyDeathLogRowTooltipScripts(row, tooltipOptions)

        for _, column in ipairs(columns) do
            CreateDeathLogColumnCell(row, column, fontObject, tooltipOptions)
        end

        frame.rows[rowIndex] = row
    end
end

---@param row table
---@param columns GrimDeathLogColumn[]
local function ClearDeathLogRow(row, columns)
    row.death = nil
    for _, column in ipairs(columns) do
        local cell = row[column.key]
        if cell then
            cell:SetText("")
        end
    end
    row:Hide()
end

---@param deaths table[]
---@param rowIndex integer
---@param offset integer
---@param reverseOrder boolean
---@return integer
local function GetDeathLogRowDataIndex(deaths, rowIndex, offset, reverseOrder)
    if reverseOrder then
        return #deaths - offset - rowIndex + 1
    end

    return offset + rowIndex
end

---@param row table
---@param columns GrimDeathLogColumn[]
---@param item GrimDeathLogDisplayEntry
---@param items GrimDeathLogDisplayEntry[]
---@param dataIndex integer
---@param columnContext GrimDeathLogColumnContext
local function PopulateDeathLogRow(row, columns, item, items, dataIndex, columnContext)
    local rowContext = {
        showRank = columnContext.showRank == true,
        rank = (#items - dataIndex) + 1,
    }

    row.death = item.death
    for _, column in ipairs(columns) do
        local cell = row[column.key]
        if cell then
            cell:SetText(GetDeathLogItemValue(item, column.key, rowContext))
            cell:SetTextColor(item.color[1], item.color[2], item.color[3])
        end
    end
    row:Show()
end

---@param frame table
---@param items (GrimDeath|GrimDeathLogDisplayEntry)[]
---@param options GrimDeathLogRefreshOptions
function GrimUIDeathLogList.RefreshDeathLogRows(frame, items, options)
    if not frame or not frame.rows then
        return
    end

    items = items or EMPTY_DEATHS
    options = options or {}

    local columns = options.columns or frame.logColumns or {}
    local offset = options.offset or 0
    local maxRows = options.maxRows or #frame.rows
    local reverseOrder = options.reverseOrder ~= false
    local columnContext = options.columnContext or {}

    for rowIndex, row in ipairs(frame.rows) do
        if rowIndex > maxRows then
            ClearDeathLogRow(row, columns)
        else
            local dataIndex = GetDeathLogRowDataIndex(items, rowIndex, offset, reverseOrder)
            local item = items[dataIndex]

            if item then
                PopulateDeathLogRow(row, columns, NormalizeDeathLogItem(item), items, dataIndex, columnContext)
            else
                ClearDeathLogRow(row, columns)
            end
        end
    end
end

return GrimUIDeathLogList
