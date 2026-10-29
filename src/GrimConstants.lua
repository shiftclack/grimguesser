local _, ns = ...
---@cast ns GrimNamespace

local GrimConstants = {
    -- CI replaces 0.0.0 with the version git tag when published
    VERSION = "0.0.0",
    HELP = {
        -- url displayed in help
        downloadUrl = "https://github.com/shiftclack/grimguesser/releases",
    },
    ANNOUNCEMENTS = {
        levelUpFrequency = 10,
    },
    STORAGE = {
        -- Number of recent death entries kept for the short "latest deaths" style views.
        maxRecentDeaths = 5,
        -- Maximum number of parsed death records retained in the full saved history.
        maxDeathHistory = 500,
        -- Maximum number of correctly predicted deaths remembered for stats or review.
        maxSuccessfullyPredictedDeaths = 500,
    },
    SCORING = {
        -- Default streak value shown before the player has built up any real streak bonus.
        previewStreak = 2,
        -- Additional points awarded each time the correct-prediction streak increases by one step.
        streakBonusStep = 2,
        maxStreakBonus = 10,
        fixedElementPoints = {
            -- Points awarded for correctly predicting the death source (if there was no correct level prediction)
            source = 25,
            -- Points awarded for correctly predicting the death zone (if there was no correct level prediction)
            zone = 25,
        },
        -- Extra fixed points awarded when a scored death happens in the player's current zone.
        sameZoneFixedBonusPoints = 50,
        predictionElementBonusByCount = {
            -- Bonus for matching exactly one prediction element.
            [1] = 0,
            -- Bonus for matching exactly two prediction elements in the same prediction.
            [2] = 5,
            -- Bonus for matching all three prediction elements in the same prediction.
            [3] = 15,
        },
        pointColorThresholds = {
            -- Minimum score treated as the baseline/common display color.
            common = 9,
            -- Minimum score treated as the uncommon display color tier.
            uncommon = 99,
            -- Minimum score treated as the rare display color tier.
            rare = 999,
        },
        levelRanges = {
            -- Ordered list of selectable level buckets used by predictions and scoring lookup.
            "10-19",
            "20-29",
            "30-39",
            "40-49",
            "50-59",
            "60",
        },
        levelPointMode = "fixedRange", -- fixedRange or exactLevel
        fixedLevelRangePoints = {
            -- Used when levelPointMode is set to "fixedRange".
            ["10-19"] = 2,
            ["20-29"] = 50,
            ["30-39"] = 200,
            ["40-49"] = 300,
            ["50-59"] = 400,
            ["60"] = 500,
        },
    },
    DEMO = {
        -- controls how long to pause between deaths
        -- min/max of 1 is good for attract mode
        minDelaySeconds = 1,
        maxDelaySeconds = 1,
        -- Minimum time to display "Waiting for first death..."
        waitingForFirstDeathMinDurationSeconds = 4,
        -- Time to display "Click HELP if you are missing deaths"
        waitingForFirstDeathHelpTextDelaySeconds = 120,
    },
}

ns.GrimConstants = GrimConstants

return GrimConstants
