local _, ns = ...
---@cast ns GrimNamespace

local GrimLogic = ns.GrimLogic or {}
local GrimConstants = ns.GrimConstants
local GrimDatabase = ns.GrimDatabase
ns.GrimLogic = GrimLogic
local SCORE_RULES = GrimConstants.SCORING
local STORAGE_RULES = GrimConstants.STORAGE

---@class GrimAddDeathOptions: GrimScoreOptions
---@field maxRecentDeaths integer
---@field maxDeathHistory integer
---@field maxSuccessfullyPredictedDeaths integer
---@field playerZone string

---@class GrimScoreResult
---@field levelMatched boolean
---@field sourceMatched boolean
---@field zoneMatched boolean
---@field matched boolean
---@field perfectMatch boolean
---@field basePoints integer
---@field selectedElementCount integer
---@field matchedElementCount integer
---@field combinationCount integer
---@field selectedElements table[]
---@field matchedElements table[]
---@field sameZoneBonusPoints integer
---@field comboBonus integer
---@field streakBonus integer
---@field totalMultiplier integer
---@field awardedPoints integer
---@field sameZoneBonusApplied boolean
---@field winningEntries table[]

---@class GrimDisplayState
---@field deaths GrimDeath[]
---@field totalPoints integer
---@field currentPredictionStreak integer
---@field longestPredictionStreak integer
---@field lockedPrediction GrimPrediction|nil
---@field draftPrediction GrimPrediction|nil
---@field lastPrediction GrimPrediction|nil

---@param database GrimCharacterState
---@param evaluation GrimScoreResult
---@return integer
local function ApplyPredictionStreak(database, evaluation)
    if evaluation.matched then
        local nextStreak = GrimDatabase.GetCorrectPredictionStreak(database) + 1
        GrimDatabase.SetCorrectPredictionStreak(database, nextStreak)
        if nextStreak > GrimDatabase.GetLongestPredictionStreak(database) then
            GrimDatabase.SetLongestPredictionStreak(database, nextStreak)
        end
        return nextStreak
    end

    GrimDatabase.SetCorrectPredictionStreak(database, 0)
    return 0
end

---@param deaths GrimDeath[]
---@param limit integer
local function TrimDeathsToLimit(deaths, limit)
    while #deaths > limit do
        table.remove(deaths, 1)
    end
end

---@param death GrimDeath
---@return integer
local function GetSuccessfulPredictionRetentionPoints(death)
    local elements = GrimLogic.GetPredictionElements(death.prediction)
    return GrimLogic.ScoreStoredDeath(elements, death, SCORE_RULES.previewStreak).awardedPoints
end

---@param deaths GrimDeath[]
---@param limit integer
local function TrimSuccessfulPredictedDeathsToLimit(deaths, limit)
    while #deaths > limit do
        local lowestIndex = 1
        local lowestRetentionPoints = GetSuccessfulPredictionRetentionPoints(deaths[lowestIndex])
        local lowestTimestamp = tonumber(deaths[lowestIndex].timestamp) or 0

        for index = 2, #deaths do
            local death = deaths[index]
            local retentionPoints = GetSuccessfulPredictionRetentionPoints(death)
            local timestamp = tonumber(death.timestamp) or 0

            -- Successful-prediction retention is based on the strength of the
            -- matched prediction itself at the baseline preview streak, not the
            -- final awarded total. That keeps streak inflation from pushing out
            -- stronger predictions that happened to occur earlier in a run.
            if retentionPoints < lowestRetentionPoints
                or (retentionPoints == lowestRetentionPoints and timestamp < lowestTimestamp) then
                lowestIndex = index
                lowestRetentionPoints = retentionPoints
                lowestTimestamp = timestamp
            end
        end

        table.remove(deaths, lowestIndex)
    end
end

---@param database GrimCharacterState
local function ResetPredictionStreak(database)
    GrimDatabase.SetCorrectPredictionStreak(database, 0)
end

---@param database GrimCharacterState
---@param prediction GrimPrediction|GrimPredictionElements|nil
---@return GrimPrediction|nil
function GrimLogic.ApplyLockedPrediction(database, prediction)
    if not database then
        error("database is required", 2)
    end

    if prediction == nil then
        return nil
    end

    prediction = GrimLogic.NormalizePrediction(prediction)

    local previousPrediction = GrimDatabase.GetLockedPrediction(database) or GrimDatabase.GetLastPrediction(database)
    if previousPrediction and not GrimLogic.ArePredictionsEquivalent(previousPrediction, prediction) then
        ResetPredictionStreak(database)
    end

    GrimDatabase.SetLockedPrediction(database, prediction)
    GrimDatabase.SetLastPrediction(database, prediction)
    GrimDatabase.SetDraftPrediction(database, prediction)

    return prediction
end

---@param database GrimCharacterState
function GrimLogic.ClearLockedPrediction(database)
    if not database then
        error("database is required", 2)
    end

    GrimDatabase.SetLastPrediction(
        database,
        GrimDatabase.GetLockedPrediction(database) or GrimDatabase.GetLastPrediction(database)
    )
    GrimDatabase.SetDraftPrediction(
        database,
        GrimDatabase.GetLockedPrediction(database) or GrimDatabase.GetDraftPrediction(database)
    )
    GrimDatabase.SetLockedPrediction(database, nil)
end

---@param database GrimCharacterState
---@param prediction GrimPrediction|GrimPredictionElements|nil
---@return GrimPrediction|nil
function GrimLogic.UpdateDraftPrediction(database, prediction)
    if not database then
        error("database is required", 2)
    end

    if prediction == nil then
        return nil
    end

    prediction = GrimLogic.NormalizePrediction(prediction)

    if GrimLogic.GetSelectedPredictionCount(prediction) <= 0 then
        GrimDatabase.SetDraftPrediction(database, nil)
        return nil
    end

    GrimDatabase.SetDraftPrediction(database, prediction)
    return prediction
end

---@param database GrimCharacterState
---@return GrimDisplayState
function GrimLogic.GetDisplayState(database)
    return {
        deaths = GrimDatabase.GetRecentDeaths(database),
        totalPoints = GrimDatabase.GetTotalPoints(database),
        currentPredictionStreak = GrimDatabase.GetCorrectPredictionStreak(database),
        longestPredictionStreak = GrimDatabase.GetLongestPredictionStreak(database),
        lockedPrediction = GrimDatabase.GetLockedPrediction(database),
        draftPrediction = GrimDatabase.GetDraftPrediction(database),
        lastPrediction = GrimDatabase.GetLastPrediction(database),
    }
end

---@param database GrimCharacterState
---@param death GrimDeathEvent
---@param options GrimAddDeathOptions|nil
---@return boolean added
---@return GrimScoreResult|nil score
function GrimLogic.AddDeathToDatabase(database, death, options)
    if not database then
        error("database is required", 2)
    end

    options = options or {}
    local recentDeaths = GrimDatabase.GetRecentDeaths(database)
    local deathHistory = GrimDatabase.GetDeathHistory(database)
    local successfulDeaths = GrimDatabase.GetSuccessfullyPredictedDeaths(database)
    local lockedPrediction = GrimDatabase.GetLockedPrediction(database)

    local maxRecentDeaths = options.maxRecentDeaths or STORAGE_RULES.maxRecentDeaths
    local maxDeathHistory = options.maxDeathHistory or STORAGE_RULES.maxDeathHistory
    local maxSuccessfullyPredictedDeaths = options.maxSuccessfullyPredictedDeaths or STORAGE_RULES.maxSuccessfullyPredictedDeaths

    -- First score the prediction with the preview streak so we can decide
    -- whether this death extends or breaks the live streak.
    local evaluation = GrimLogic.EvaluatePrediction(lockedPrediction, death)
    local predictionStreak = ApplyPredictionStreak(database, evaluation)
    local elements = GrimLogic.GetPredictionElements(lockedPrediction)
    local score = GrimLogic.ScoreDeathEvent(elements, death, predictionStreak, options)
    local sameZoneBonusApplied = score.sameZoneBonusApplied == true

    local recentDeath = GrimLogic._CreateStoredDeathEntry(
        death,
        lockedPrediction,
        score,
        predictionStreak,
        true,
        sameZoneBonusApplied
    )
    local historyDeath = GrimLogic._CreateStoredDeathEntry(
        death,
        lockedPrediction,
        score,
        predictionStreak,
        false,
        sameZoneBonusApplied
    )

    -- Recent deaths drives the main window; deathHistory feeds the scrollable log.
    table.insert(recentDeaths, recentDeath)
    table.insert(deathHistory, historyDeath)
    if score.matched == true then
        table.insert(successfulDeaths, historyDeath)
    end
    GrimDatabase.SetTotalPoints(
        database,
        GrimDatabase.GetTotalPoints(database) + GrimLogic.GetStoredDeathAwardedPoints(recentDeath)
    )

    -- Trim oldest entries so SavedVariables stay bounded.
    TrimDeathsToLimit(recentDeaths, maxRecentDeaths)
    TrimDeathsToLimit(deathHistory, maxDeathHistory)
    TrimSuccessfulPredictedDeathsToLimit(successfulDeaths, maxSuccessfullyPredictedDeaths)

    return true, score
end

return GrimLogic
