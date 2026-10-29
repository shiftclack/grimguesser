-- where scoring happens
-- keep it simple
--
-- we want to keep scoring logic explicit and top-down to make it easier to reason about
-- we prefer one clear procedural flow over abstractions, even if that means a longer function
-- with higher branching complexity.
--
-- the api should be stable and not excessively backwards compatible
-- it should accept normalized prediction elements
-- internal score summaries should use one canonical set of field names
-- Keep any DebugScore() calls here
--
-- luacheck: ignore 561

local _, ns = ...
---@cast ns GrimNamespace

local GrimLogic = ns.GrimLogic or {}
local GrimDebug = ns.GrimDebug
local GrimConstants = ns.GrimConstants
ns.GrimLogic = GrimLogic
local SCORE_RULES = GrimConstants.SCORING
local PREDICTION_PREVIEW_KEY_ORDER = { "levelRange", "source", "zone" }
local PREDICTION_PREVIEW_KEY_LABELS = {
    levelRange = "Level",
    source = "Source",
    zone = "Zone",
}
local GetPredictionElementBonus

---@class GrimScoreOptions
---@field playerZone string|nil

---@class GrimComboDetailEntry
---@field key string
---@field keys string[]
---@field label string
---@field multiplier integer
---@field displayMultiplier string

---@class GrimComboDetails
---@field predictionText string
---@field basePoints integer
---@field sameZoneBonusPoints integer
---@field comboMultiplier integer
---@field streakMultiplier integer
---@field comboSum integer
---@field displayComboSum string
---@field awardedPoints integer
---@field matched boolean
---@field perfectMatch boolean
---@field combos GrimComboDetailEntry[]

---@param elements GrimPredictionElements
---@param key string
---@return string
local function GetPredictionElementValueLabel(elements, key)
    if key == "levelRange" then
        return elements.levelRange and ("Level " .. tostring(elements.levelRange)) or "Level"
    end

    if key == "source" then
        return GrimLogic.ToDisplayText(elements.source) or "Source"
    end

    if key == "zone" then
        return GrimLogic.ToDisplayText(elements.zone) or "Zone"
    end

    return tostring(key)
end

local function DebugScore(...)
    GrimDebug.Log(...)
end

---@param streakCount integer
---@return integer
local function CalculateStreakBonus(streakCount)
    if streakCount <= 0 then
        return 0
    end

    local uncappedBonus = math.max(streakCount - 1, 0) * SCORE_RULES.streakBonusStep
    return math.min(uncappedBonus, SCORE_RULES.maxStreakBonus)
end

-- Internal test seam for the pure streak rule; production scoring uses ScoreCommon.
GrimLogic._CalculateStreakBonus = CalculateStreakBonus

---@param key string
---@param points integer
---@return table
local function CreateScoringEntry(key, points)
    return {
        key = key,
        points = points,
    }
end

---@class GrimPredictionMatchState
---@field levelMatched boolean
---@field sourceMatched boolean
---@field zoneMatched boolean
---@field hasLevelPrediction boolean
---@field hasSourcePrediction boolean
---@field hasZonePrediction boolean

---@return GrimPredictionMatchState
local function CreateEmptyMatchState()
    return {
        levelMatched = false,
        sourceMatched = false,
        zoneMatched = false,
        hasLevelPrediction = false,
        hasSourcePrediction = false,
        hasZonePrediction = false,
    }
end

---@param selectedElementCount integer
---@param selectedElements table[]
---@param matchState GrimPredictionMatchState
---@return GrimScoreResult
local function CreateEmptyScoreResult(selectedElementCount, selectedElements, matchState)
    return {
        levelMatched = matchState.levelMatched,
        sourceMatched = matchState.sourceMatched,
        zoneMatched = matchState.zoneMatched,
        matched = false,
        perfectMatch = false,
        basePoints = 0,
        selectedElementCount = selectedElementCount,
        matchedElementCount = 0,
        combinationCount = 0,
        selectedElements = selectedElements,
        matchedElements = {},
        sameZoneBonusPoints = 0,
        comboBonus = 0,
        streakBonus = 0,
        totalMultiplier = 0,
        awardedPoints = 0,
        sameZoneBonusApplied = false,
        winningEntries = {},
    }
end

local function GetPredictionPreviewKeyLabel(key)
    return PREDICTION_PREVIEW_KEY_LABELS[key] or tostring(key)
end

---@param elements GrimPredictionElements
---@return string[]
local function GetSelectedPredictionKeys(elements)
    local selectedKeys = {}

    for _, key in ipairs(PREDICTION_PREVIEW_KEY_ORDER) do
        if elements[key] ~= nil then
            selectedKeys[#selectedKeys + 1] = key
        end
    end

    return selectedKeys
end

---@param elements GrimPredictionElements
---@param keys string[]
---@return GrimPredictionElements
local function CreatePredictionSubsetElements(elements, keys)
    local subsetElements = {}

    for _, key in ipairs(keys) do
        subsetElements[key] = elements[key]
    end

    return subsetElements
end

---@param elements GrimPredictionElements
---@param keys string[]
---@return GrimPredictionPayoutPreviewRow
local function BuildPredictionPreviewRow(elements, keys)
    local labels = {}

    for index, key in ipairs(keys) do
        labels[index] = GetPredictionPreviewKeyLabel(key)
    end

    local awardedPoints = GrimLogic.ScorePreview(
        CreatePredictionSubsetElements(elements, keys),
        0
    ).awardedPoints

    return {
        matchCount = #keys,
        keys = keys,
        label = table.concat(labels, " + "),
        awardedPoints = awardedPoints,
        text = string.format(
            "%d match: %s = %d points",
            #keys,
            table.concat(labels, " + "),
            awardedPoints
        ),
    }
end

---@param levelRange string|nil
---@return integer|nil
local function GetPreviewLevelForRange(levelRange)
    if levelRange == nil or levelRange == "" then
        return nil
    end

    if levelRange == "60" then
        return 60
    end

    local minLevel = string.match(levelRange, "^(%d+)%-%d+$")
    return tonumber(minLevel)
end

---@param elements GrimPredictionElements
---@return GrimDeath
local function BuildPreviewDeathFromElements(elements)
    return {
        level = GetPreviewLevelForRange(elements.levelRange),
        sourceName = elements.source,
        zone = elements.zone,
    }
end

---@param death GrimDeath|GrimDeathEvent
---@param matched boolean
---@param options GrimScoreOptions
---@return boolean
local function IsSameZoneBonusApplied(death, matched, options)
    if matched ~= true then
        return false
    end

    if death.sameZoneBonusApplied ~= nil then
        return death.sameZoneBonusApplied == true
    end

    if options.playerZone == nil then
        return false
    end

    return GrimLogic._NormalizeComparableText(death.zone) == GrimLogic._NormalizeComparableText(options.playerZone)
end

---@param death GrimDeath|GrimDeathEvent
---@param matched boolean
---@param options GrimScoreOptions
---@return integer
local function GetSameZoneBonusPoints(death, matched, options)
    if IsSameZoneBonusApplied(death, matched, options) then
        return SCORE_RULES.sameZoneFixedBonusPoints
    end

    return 0
end

---@return GrimScoreResult
local function ScoreCommon(elements, death, streakCount, options)
    local resolvedElements = elements or {}
    local resolvedStreakCount = tonumber(streakCount) or 0
    local resolvedOptions = options or {}
    local selectedElements = {}

    DebugScore("scoring starts: --------------------")
    DebugScore(
        "scoring input",
        "streak=", resolvedStreakCount,
        "levelRange=", resolvedElements.levelRange,
        "source=", resolvedElements.source,
        "zone=", resolvedElements.zone,
        "deathLevel=", death and death.level or nil,
        "deathSource=", death and death.sourceName or nil,
        "deathZone=", death and death.zone or nil,
        "playerZone=", resolvedOptions.playerZone,
        "storedSameZoneBonusApplied=", death and death.sameZoneBonusApplied or nil
    )

    if resolvedElements.levelRange ~= nil then
        local previewLevelPoints = GrimLogic.GetLevelPointsForRange(resolvedElements.levelRange)
        selectedElements[#selectedElements + 1] = CreateScoringEntry(
            "levelRange",
            previewLevelPoints
        )
        DebugScore(
            "selected levelRange",
            "basePoints=", previewLevelPoints
        )
    end

    if resolvedElements.source ~= nil then
        selectedElements[#selectedElements + 1] = CreateScoringEntry(
            "source",
            SCORE_RULES.fixedElementPoints.source
        )
        DebugScore("selected source", "basePoints=", SCORE_RULES.fixedElementPoints.source)
    end

    if resolvedElements.zone ~= nil then
        selectedElements[#selectedElements + 1] = CreateScoringEntry(
            "zone",
            SCORE_RULES.fixedElementPoints.zone
        )
        DebugScore("selected zone", "basePoints=", SCORE_RULES.fixedElementPoints.zone)
    end

    local selectedElementCount = #selectedElements
    if death == nil then
        DebugScore("scoring aborted: death missing")
        DebugScore("scoring ends: --------------------")
        return CreateEmptyScoreResult(selectedElementCount, selectedElements, CreateEmptyMatchState())
    end

    local matchState = GrimLogic._GetPredictionMatchState(resolvedElements, death)
    local matchedElements = {}
    local basePoints = 0

    if matchState.levelMatched then
        local levelPoints = GrimLogic.GetLevelPointsForLevel(death.level)
        basePoints = basePoints + levelPoints
        matchedElements[#matchedElements + 1] = CreateScoringEntry(
            "levelRange",
            levelPoints
        )
        DebugScore("matched levelRange", "basePoints=", levelPoints)
    end

    if matchState.sourceMatched then
        local sourcePoints = SCORE_RULES.fixedElementPoints.source
        basePoints = basePoints + sourcePoints
        matchedElements[#matchedElements + 1] = CreateScoringEntry(
            "source",
            sourcePoints
        )
        DebugScore("matched source", "basePoints=", sourcePoints)
    end

    if matchState.zoneMatched then
        local zonePoints = SCORE_RULES.fixedElementPoints.zone
        basePoints = basePoints + zonePoints
        matchedElements[#matchedElements + 1] = CreateScoringEntry(
            "zone",
            zonePoints
        )
        DebugScore("matched zone", "basePoints=", zonePoints)
    end

    local matchedElementCount = #matchedElements
    local matched = matchedElementCount > 0
    local perfectMatch = selectedElementCount > 0 and GrimLogic._IsPredictionMatched(matchState)
    local sameZoneBonusApplied = IsSameZoneBonusApplied(death, matched, resolvedOptions)
    local sameZonePoints = GetSameZoneBonusPoints(death, matched, resolvedOptions)

    DebugScore(
        "match state",
        "selected=", selectedElementCount,
        "matched=", matchedElementCount,
        "levelMatched=", matchState.levelMatched,
        "sourceMatched=", matchState.sourceMatched,
        "zoneMatched=", matchState.zoneMatched,
        "perfectMatch=", perfectMatch,
        "sameZoneBonusApplied=", sameZoneBonusApplied,
        "sameZonePoints=", sameZonePoints
    )

    if not matched then
        DebugScore("score summary", "basePoints=0", "comboBonus=0", "streakBonus=0", "awardedPoints=0")
        DebugScore("scoring ends: --------------------")

        local emptyResult = CreateEmptyScoreResult(selectedElementCount, selectedElements, matchState)
        emptyResult.perfectMatch = perfectMatch
        return emptyResult
    end

    local comboBonus = GetPredictionElementBonus(matchedElementCount)
    local streakBonus = CalculateStreakBonus(resolvedStreakCount)
    local totalMultiplier = math.max(comboBonus + streakBonus, 1)
    local awardedPoints = (basePoints + sameZonePoints) * totalMultiplier

    DebugScore(
        "score summary",
        "basePoints=", basePoints,
        "sameZonePoints=", sameZonePoints,
        "comboBonus=", comboBonus,
        "streakBonus=", streakBonus,
        "totalMultiplier=", totalMultiplier,
        "awardedPoints=", awardedPoints
    )
    DebugScore("scoring ends: --------------------")

    return {
        levelMatched = matchState.levelMatched,
        sourceMatched = matchState.sourceMatched,
        zoneMatched = matchState.zoneMatched,
        matched = true,
        perfectMatch = perfectMatch,
        basePoints = basePoints,
        selectedElementCount = selectedElementCount,
        matchedElementCount = matchedElementCount,
        combinationCount = 1,
        selectedElements = selectedElements,
        matchedElements = matchedElements,
        sameZoneBonusPoints = sameZonePoints,
        comboBonus = comboBonus,
        streakBonus = streakBonus,
        totalMultiplier = totalMultiplier,
        awardedPoints = awardedPoints,
        sameZoneBonusApplied = sameZoneBonusApplied,
        winningEntries = matchedElements,
    }
end

---@param elements GrimPredictionElements|nil
---@param death GrimDeathEvent|nil
---@param streakCount integer|nil
---@param options GrimScoreOptions|nil
---@return GrimScoreResult
function GrimLogic.ScoreDeathEvent(elements, death, streakCount, options)
    return ScoreCommon(elements, death, streakCount, options)
end

---@param elements GrimPredictionElements|nil
---@param death GrimDeath|nil
---@param streakCount integer|nil
---@param options GrimScoreOptions|nil
---@return GrimScoreResult
function GrimLogic.ScoreStoredDeath(elements, death, streakCount, options)
    return ScoreCommon(elements, death, streakCount, options)
end

function GrimLogic.ScorePreview(elements, streakCount)
    local resolvedElements = elements or {}
    local previewDeath = BuildPreviewDeathFromElements(resolvedElements)
    return ScoreCommon(resolvedElements, previewDeath, streakCount)
end

function GrimLogic.EvaluatePrediction(prediction, death)
    if not prediction or not death then
        return CreateEmptyScoreResult(0, {}, CreateEmptyMatchState())
    end

    local elements = GrimLogic.GetPredictionElements(prediction) or {}
    return GrimLogic.ScoreDeathEvent(elements, death, SCORE_RULES.previewStreak)
end

function GetPredictionElementBonus(matchCount)
    local resolvedCount = tonumber(matchCount) or 0
    if resolvedCount <= 0 then
        return 0
    end

    return SCORE_RULES.predictionElementBonusByCount[resolvedCount] or 0
end

function GrimLogic.GetPreviewStreak()
    return SCORE_RULES.previewStreak
end

function GrimLogic.GetPredictionPayoutPreviewRows(prediction)
    local elements = GrimLogic.GetPredictionElements(prediction) or {}
    local selectedKeys = GetSelectedPredictionKeys(elements)
    local rows = {}

    if #selectedKeys <= 0 then
        return rows
    end

    for index = 1, #selectedKeys do
        rows[#rows + 1] = BuildPredictionPreviewRow(elements, {
            selectedKeys[index],
        })
    end

    if #selectedKeys >= 2 then
        for leftIndex = 1, #selectedKeys - 1 do
            for rightIndex = leftIndex + 1, #selectedKeys do
                rows[#rows + 1] = BuildPredictionPreviewRow(elements, {
                    selectedKeys[leftIndex],
                    selectedKeys[rightIndex],
                })
            end
        end
    end

    if #selectedKeys >= 3 then
        rows[#rows + 1] = BuildPredictionPreviewRow(elements, {
            selectedKeys[1],
            selectedKeys[2],
            selectedKeys[3],
        })
    end

    return rows
end

---@param prediction GrimPrediction|GrimPredictionElements|nil
---@param death GrimDeath|nil
---@param streak integer|nil
---@return GrimComboDetails
function GrimLogic.GetComboDetails(prediction, death, streak)
    local elements = GrimLogic.GetPredictionElements(prediction) or {}
    local score = death and GrimLogic.ScoreStoredDeath(elements, death, streak)
        or GrimLogic.ScorePreview(elements, streak)
    ---@type GrimComboDetailEntry[]
    local combos = {}

    if score.matched and #score.winningEntries > 0 then
        local labels = {}
        local keys = {}

        for index, entry in ipairs(score.winningEntries) do
            keys[index] = entry.key
            labels[index] = GetPredictionElementValueLabel(elements, entry.key)
        end

        combos[1] = {
            key = table.concat(keys, ","),
            keys = keys,
            label = table.concat(labels, " + "),
            multiplier = score.comboBonus,
            displayMultiplier = GrimLogic.FormatMultiplier(score.comboBonus),
        }
    end

    return {
        predictionText = GrimLogic.FormatLockedPrediction(prediction),
        basePoints = score.basePoints,
        sameZoneBonusPoints = score.sameZoneBonusPoints,
        comboMultiplier = score.comboBonus,
        streakMultiplier = score.streakBonus,
        comboSum = score.totalMultiplier,
        displayComboSum = GrimLogic.FormatMultiplier(score.totalMultiplier),
        awardedPoints = score.awardedPoints,
        matched = score.matched,
        perfectMatch = score.perfectMatch,
        combos = combos,
    }
end

function GrimLogic.FormatMultiplier(multiplier)
    return "x" .. tostring(multiplier or 0)
end

function GrimLogic.GetPointColorQuality(points)
    local awardedPoints = tonumber(points) or 0

    if awardedPoints <= 0 then
        return 0
    end

    if awardedPoints <= SCORE_RULES.pointColorThresholds.common then
        return 1
    end

    if awardedPoints <= SCORE_RULES.pointColorThresholds.uncommon then
        return 2
    end

    if awardedPoints <= SCORE_RULES.pointColorThresholds.rare then
        return 3
    end

    return 4
end

return GrimLogic
