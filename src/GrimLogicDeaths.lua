local _, ns = ...
---@cast ns GrimNamespace

local GrimLogic = ns.GrimLogic or {}
ns.GrimLogic = GrimLogic

---@class GrimDeathEvent
---@field timestamp integer
---@field name string
---@field level integer
---@field causeType string
---@field sourceName string
---@field zone string
---@field server string
---@field sourceMessage string
---@field isBlizzardVerified boolean

---@param death GrimDeath
---@return GrimScoreResult
local function GetStoredDeathScore(death)
    local elements = GrimLogic.GetPredictionElements(death.prediction) or {}
    return GrimLogic.ScoreStoredDeath(elements, death, tonumber(death.predictionStreak) or 0)
end

---@param death GrimDeathEvent
---@param prediction GrimPrediction|GrimPredictionElements|nil
---@param score GrimScoreResult
---@param predictionStreak integer
---@param includeComputedScores boolean
---@param sameZoneBonusApplied boolean
---@return GrimDeath
local function CreateStoredDeathEntry(death, prediction, score, predictionStreak, includeComputedScores, sameZoneBonusApplied)
    local entry = {
        timestamp = death.timestamp,
        name = death.name,
        level = death.level,
        causeType = death.causeType,
        sourceName = death.sourceName,
        zone = death.zone,
        server = death.server,
        sourceMessage = death.sourceMessage,
        matchedPrediction = score.matched,
        predictionStreak = predictionStreak,
        streakMultiplier = score.streakBonus,
        sameZoneBonusApplied = sameZoneBonusApplied == true,
        prediction = GrimLogic.NormalizePrediction(prediction),
    }

    if includeComputedScores then
        entry.points = score.basePoints
        entry.awardedPoints = score.awardedPoints
    end

    return entry
end

---@param parsedDeath GrimParsedDeathEvent
---@return GrimDeathEvent
function GrimLogic.NormalizeDeathEvent(parsedDeath)
    return {
        timestamp = time(),
        name = parsedDeath.name,
        level = parsedDeath.level,
        causeType = parsedDeath.causeType,
        sourceName = parsedDeath.sourceName,
        zone = parsedDeath.zone,
        server = parsedDeath.server or GetRealmName(),
        sourceMessage = parsedDeath.sourceMessage,
        isBlizzardVerified = true,
    }
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathBasePoints(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.basePoints
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathMultiplierValue(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.totalMultiplier
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathComboMultiplierValue(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.comboBonus
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathStreakMultiplierValue(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.streakBonus
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathAwardedPoints(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.awardedPoints
end

---@param death GrimDeath
---@return integer
function GrimLogic.GetStoredDeathSameZoneBonusPoints(death)
    if not death then
        return 0
    end

    local score = GetStoredDeathScore(death)
    return score.sameZoneBonusPoints
end

---@param death GrimDeath
function GrimLogic.GetStoredDeathComboDetails(death)
    if not death then
        return GrimLogic.GetComboDetails(nil, nil, 0)
    end

    return GrimLogic.GetComboDetails(
        death.prediction,
        death,
        tonumber(death.predictionStreak) or 0
    )
end

GrimLogic._CreateStoredDeathEntry = CreateStoredDeathEntry

return GrimLogic
