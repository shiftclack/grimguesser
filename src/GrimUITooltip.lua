local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimLogic = ns.GrimLogic
local GrimUITooltip = ns.GrimUITooltip or {}
ns.GrimUITooltip = GrimUITooltip
local TOOLTIP_WHITE = { 1, 1, 1 }
local TOOLTIP_GREEN = { 0.12, 1.0, 0.0 }
local TOOLTIP_YELLOW = { 1, 0.82, 0 }
local GAME_INFO_CALLOUT_TITLE_COLOR = { 1, 0.82, 0 }
local GAME_INFO_CALLOUT_BODY_COLOR = { 1, 1, 1 }
local GAME_INFO_CALLOUT_BACKGROUND_COLOR = { 0.75, 0.9, 1.0, 0.95 }
local GAME_INFO_CALLOUT_BORDER_COLOR = { 1, 0.95, 0.2, 1.0 }

---@class GrimTooltipDetail
---@field label any
---@field value any
---@field suffixColon boolean|nil
---@field allowEmptyValue boolean|nil
---@field leftColor number[]|nil
---@field rightColor number[]|nil

---@class GrimTooltipContext
---@field death GrimDeath|nil
---@field prediction GrimPrediction|GrimPredictionElements|nil
---@field streak number|nil

---@class GrimResolvedTooltipContext
---@field death GrimDeath|nil
---@field prediction GrimPrediction|GrimPredictionElements|nil
---@field streak integer

---@class GrimLogTooltipOptions
---@field showPredictionString boolean
---@field showIdentity boolean
---@field showFullCombos boolean
---@field hoverColumns table<string, boolean>

---@alias GrimGameInfoResolvableWidget table|fun():table
---@alias GrimOptionalGameInfoResolvableWidget GrimGameInfoResolvableWidget|nil

---@class GrimGameInfoCalloutOptions
---@field owner GrimOptionalGameInfoResolvableWidget
---@field relativeTo GrimOptionalGameInfoResolvableWidget
---@field point string|nil
---@field relativePoint string|nil
---@field xOffset number|nil
---@field yOffset number|nil
---@field shouldShow fun():boolean|nil
---@field callout GrimOptionalGameInfoResolvableWidget
---@field lines string[]|fun():string[]

---@type GrimLogTooltipOptions
GrimUITooltip.COLLAPSED_LOG_TOOLTIP_OPTIONS = {
    showPredictionString = false,
    showIdentity = false,
    showFullCombos = true,
    hoverColumns = {
        awardedPoints = true,
    },
}

---@type GrimLogTooltipOptions
GrimUITooltip.LOG_WINDOW_TOOLTIP_OPTIONS = {
    showPredictionString = true,
    showIdentity = true,
    showFullCombos = true,
    hoverColumns = {
        awardedPoints = true,
    },
}

---@type GrimLogTooltipOptions
GrimUITooltip.MAIN_LOG_TOOLTIP_OPTIONS = {
    showPredictionString = false,
    showIdentity = false,
    showFullCombos = true,
    hoverColumns = {
        awardedPoints = true,
    },
}

---@param details GrimTooltipDetail[]
local function AddTooltipDetailLines(details)
    for _, detail in ipairs(details) do
        local label = tostring(detail.label or "")
        if detail.suffixColon ~= false then
            label = label .. ":"
        end
        local value = GrimUI.GetTooltipFieldValue(detail.value, detail.allowEmptyValue)
        local leftColor = detail.leftColor or TOOLTIP_WHITE
        local rightColor = detail.rightColor or TOOLTIP_WHITE

        GameTooltip:AddDoubleLine(
            label,
            value,
            leftColor[1], leftColor[2], leftColor[3],
            rightColor[1], rightColor[2], rightColor[3]
        )
    end
end

---@param callout table
---@param lines string[]
local function AddGameInfoCalloutLines(callout, lines)
    local titleColor = GAME_INFO_CALLOUT_TITLE_COLOR
    local bodyColor = GAME_INFO_CALLOUT_BODY_COLOR

    callout:ClearLines()

    for index, line in ipairs(lines) do
        if index == 1 then
            callout:AddLine(line, titleColor[1], titleColor[2], titleColor[3], true)
        else
            callout:AddLine(line, bodyColor[1], bodyColor[2], bodyColor[3], true)
        end
    end
end

---@param lines string[]|fun():string[]
---@return string[]
local function ResolveGameInfoCalloutLines(lines)
    if type(lines) == "function" then
        return lines()
    end
    return lines
end

---@param value GrimOptionalGameInfoResolvableWidget
---@return table|nil
local function ResolveGameInfoCalloutValue(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

---@param details GrimComboDetailEntry[]
---@return table<string, boolean>
local function BuildMatchedComboLookup(details)
    local lookup = {}

    for _, entry in ipairs(details) do
        lookup[entry.key] = true
    end

    return lookup
end

---@param entry GrimComboDetailEntry
---@param matched boolean
---@return GrimTooltipDetail
local function BuildComboTooltipDetail(entry, matched)
    return {
        label = entry.label,
        value = entry.displayMultiplier,
        leftColor = matched and TOOLTIP_GREEN or nil,
        rightColor = matched and TOOLTIP_GREEN or nil,
    }
end

---@param multiplier number|string|nil
---@return boolean
local function ShouldSurfaceTooltipMultiplier(multiplier)
    return (tonumber(multiplier) or 0) > 1
end

---@param summary GrimComboDetails
---@param matchedLookup table<string, boolean>
---@return GrimTooltipDetail[]
local function BuildComboTooltipDetailsFromSummary(summary, matchedLookup)
    local details = {}

    for _, entry in ipairs(summary.combos) do
        if ShouldSurfaceTooltipMultiplier(entry.multiplier) then
            details[#details + 1] = BuildComboTooltipDetail(
                entry,
                matchedLookup[entry.key] == true
            )
        end
    end

    return details
end

---@param details GrimTooltipDetail[]
---@param death GrimDeath
local function AddDeathIdentityDetails(details, death)
    details[#details + 1] = {
        label = "Level",
        value = death.level,
    }
    details[#details + 1] = {
        label = "Date",
        value = GrimUI.GetStoredDeathDateTime(death),
    }
    details[#details + 1] = {
        label = "Source",
        value = death.sourceName,
    }
    details[#details + 1] = {
        label = "Location",
        value = death.zone,
    }
end

---@param details GrimTooltipDetail[]
---@param showDivider boolean
---@param predictionText string
local function AddPredictionTextDetails(details, showDivider, predictionText)
    if showDivider == true then
        details[#details + 1] = {
            label = "---------",
            value = "",
            suffixColon = false,
            allowEmptyValue = true,
        }
    end

    details[#details + 1] = {
        label = predictionText,
        value = "",
        suffixColon = false,
        allowEmptyValue = true,
    }
end

---@param prediction GrimPrediction|GrimPredictionElements|nil
---@param death GrimDeath|nil
---@param streak integer
---@return GrimComboDetails
---@return table<string, boolean>
local function ResolveTooltipSummaries(prediction, death, streak)
    if death ~= nil then
        local matchedSummary = GrimLogic.GetComboDetails(prediction, death, streak)
        return matchedSummary, BuildMatchedComboLookup(matchedSummary.combos)
    end

    local previewSummary = GrimLogic.GetComboDetails(prediction, nil, streak)
    return previewSummary, {}
end

---@param context GrimTooltipContext
---@return GrimResolvedTooltipContext
local function GetTooltipContext(context)
    local death = context.death
    local prediction = context.prediction
    local streak = context.streak

    if prediction == nil and death ~= nil then
        prediction = death.prediction
    end

    if streak == nil then
        if death ~= nil then
            streak = tonumber(death.predictionStreak) or 0
        else
            streak = GrimLogic.GetPreviewStreak()
        end
    end

    return {
        death = death,
        prediction = prediction,
        streak = streak,
    }
end

---@param scoreSummary GrimComboDetails
---@param displayTotalMultiplier string
---@param death GrimDeath|nil
---@return string
local function GetTooltipScoreDisplay(scoreSummary, displayTotalMultiplier, death)
    if displayTotalMultiplier == "-" then
        return tostring(scoreSummary.awardedPoints)
    end

    local leftHandPoints = scoreSummary.basePoints
    if death ~= nil then
        leftHandPoints = (tonumber(leftHandPoints) or 0) + (tonumber(scoreSummary.sameZoneBonusPoints) or 0)
    end

    return string.format(
        "%s %s = %s",
        leftHandPoints,
        displayTotalMultiplier,
        scoreSummary.awardedPoints
    )
end

---@param context GrimResolvedTooltipContext
---@param showPredictionString boolean
---@param showIdentity boolean
---@param showFullCombos boolean
---@return GrimTooltipDetail[]
local function BuildStandardizedTooltipDetails(context, showPredictionString, showIdentity, showFullCombos)
    local details = {}
    local prediction = context.prediction
    local death = context.death
    local streak = context.streak
    local summary, matchedLookup = ResolveTooltipSummaries(prediction, death, streak)
    local displayStreakMultiplier = GrimUI.GetMultiplierDisplay(summary.streakMultiplier)
    local displayTotalMultiplier = GrimUI.GetMultiplierDisplay(summary.comboSum)

    if showPredictionString == true then
        AddPredictionTextDetails(details, false, summary.predictionText)
    end

    if death ~= nil and showIdentity == true then
        AddDeathIdentityDetails(details, death)
    end

    details[#details + 1] = {
        label = "Base points",
        value = summary.basePoints,
    }

    if death ~= nil and (tonumber(summary.sameZoneBonusPoints) or 0) > 0 then
        details[#details + 1] = {
            label = "Same zone",
            value = summary.sameZoneBonusPoints,
            leftColor = TOOLTIP_GREEN,
            rightColor = TOOLTIP_GREEN,
        }
    end

    if ShouldSurfaceTooltipMultiplier(summary.streakMultiplier) then
        details[#details + 1] = {
            label = "Streak",
            value = displayStreakMultiplier,
            leftColor = TOOLTIP_GREEN,
            rightColor = TOOLTIP_GREEN,
        }
    end

    if showFullCombos == true then
        local comboDetails = BuildComboTooltipDetailsFromSummary(summary, matchedLookup)
        for _, detail in ipairs(comboDetails) do
            details[#details + 1] = detail
        end
    end

    details[#details + 1] = {
        label = "Score",
        value = GetTooltipScoreDisplay(summary, displayTotalMultiplier, death),
        leftColor = TOOLTIP_YELLOW,
        rightColor = TOOLTIP_YELLOW,
    }

    return details
end

---@param anchor table
---@param context GrimTooltipContext
---@param showPredictionString boolean
---@param showIdentity boolean
---@param showFullCombos boolean
function GrimUITooltip.ShowStandardizedTooltip(anchor, context, showPredictionString, showIdentity, showFullCombos)
    GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR")
    AddTooltipDetailLines(
        BuildStandardizedTooltipDetails(
            GetTooltipContext(context),
            showPredictionString == true,
            showIdentity == true,
            showFullCombos == true
        )
    )
    GameTooltip:Show()
end

---@param callout table
local function ApplyGameInfoCalloutStyle(callout)
    callout:SetFrameStrata("TOOLTIP")
    if callout.SetBackdropColor then
        callout:SetBackdropColor(
            GAME_INFO_CALLOUT_BACKGROUND_COLOR[1],
            GAME_INFO_CALLOUT_BACKGROUND_COLOR[2],
            GAME_INFO_CALLOUT_BACKGROUND_COLOR[3],
            GAME_INFO_CALLOUT_BACKGROUND_COLOR[4]
        )
    end
    if callout.SetBackdropBorderColor then
        callout:SetBackdropBorderColor(
            GAME_INFO_CALLOUT_BORDER_COLOR[1],
            GAME_INFO_CALLOUT_BORDER_COLOR[2],
            GAME_INFO_CALLOUT_BORDER_COLOR[3],
            GAME_INFO_CALLOUT_BORDER_COLOR[4]
        )
    end
end

---@param callout table
---@param lines string[]|fun():string[]
local function SetGameInfoCalloutLines(callout, lines)
    AddGameInfoCalloutLines(callout, ResolveGameInfoCalloutLines(lines))
end

---@param name string
---@param parentFrame table
---@return table
function GrimUITooltip.CreateGameInfoCallout(name, parentFrame)
    local callout = CreateFrame("GameTooltip", name, parentFrame, "GameTooltipTemplate")
    ApplyGameInfoCalloutStyle(callout)
    callout:Hide()
    return callout
end

---@param callout GrimOptionalGameInfoResolvableWidget
function GrimUITooltip.HideGameInfoCallout(callout)
    callout = ResolveGameInfoCalloutValue(callout)

    if callout then
        callout:Hide()
    end
end

---@param callout GrimOptionalGameInfoResolvableWidget
---@param lines string[]|fun():string[]
---@param options GrimGameInfoCalloutOptions
local function ShowGameInfoCallout(callout, lines, options)
    callout = ResolveGameInfoCalloutValue(callout)
    local owner = ResolveGameInfoCalloutValue(options.owner) or ResolveGameInfoCalloutValue(options.relativeTo)
    local relativeTo = ResolveGameInfoCalloutValue(options.relativeTo) or owner

    if not callout or not owner or not relativeTo then
        return
    end

    callout:SetOwner(owner, "ANCHOR_NONE")
    callout:ClearAllPoints()
    callout:SetPoint(
        options.point or "BOTTOMRIGHT",
        relativeTo,
        options.relativePoint or "TOPRIGHT",
        options.xOffset or 0,
        options.yOffset or 10
    )
    SetGameInfoCalloutLines(callout, lines)
    callout:Show()
end

---@param region table
---@param options GrimGameInfoCalloutOptions
function GrimUITooltip.AttachGameInfoCallout(region, options)
    if region.EnableMouse then
        region:EnableMouse(true)
    end

    region:SetScript("OnEnter", function()
        if options.shouldShow and options.shouldShow() ~= true then
            return
        end

        ShowGameInfoCallout(
            options.callout,
            options.lines,
            options
        )
    end)
    region:SetScript("OnLeave", function()
        GrimUITooltip.HideGameInfoCallout(options.callout)
    end)
end

return GrimUITooltip
