local LogicContext = require("tests.support_logic_context")
local UIHarness = require("tests.support_ui_harness")
local FixtureFactory = require("tests.support_fixtures")

---@return table
local function Create()
    local loadedLogic = LogicContext.Create({ zoneText = "Test UI Zone" })
    local GrimLogic = loadedLogic.GrimLogic
    local Fixtures = FixtureFactory.Create(loadedLogic.GrimConstants, loadedLogic.GrimDatabase)
    local SCORE_RULES = loadedLogic.GrimConstants.SCORING

    ---@return string
    local function buildLevelPointsSummary()
        local visibleRanges = {}

        for index = 1, #SCORE_RULES.levelRanges - 1 do
            visibleRanges[#visibleRanges + 1] = tostring(SCORE_RULES.levelRanges[index])
        end

        return "Level ranges can be locked as "
            .. table.concat(visibleRanges, ", ")
            .. ", and "
            .. tostring(SCORE_RULES.levelRanges[#SCORE_RULES.levelRanges])
            .. "."
    end

    ---@param prediction GrimPrediction
    ---@return string
    local function formatPredictionPreview(prediction)
        local elements = GrimLogic.GetPredictionElements(prediction) or {}
        local score = GrimLogic.ScorePreview(
            elements,
            GrimLogic.GetPreviewStreak()
        )

        return string.format(
            "%d base / %d combos = %d total",
            score.basePoints,
            score.combinationCount,
            score.awardedPoints
        )
    end

    ---@param death GrimDeath
    ---@return table<string, string>
    local function formatStoredDeathScore(death)
        local basePoints = GrimLogic.GetStoredDeathBasePoints(death)
        local sameZoneBonusPoints = GrimLogic.GetStoredDeathSameZoneBonusPoints(death)
        local comboMultiplier = GrimLogic.GetStoredDeathComboMultiplierValue(death)
        local streakMultiplier = GrimLogic.GetStoredDeathStreakMultiplierValue(death)
        local comboSum = GrimLogic.GetStoredDeathMultiplierValue(death)
        local awardedPoints = GrimLogic.GetStoredDeathAwardedPoints(death)
        return {
            basePoints = tostring(basePoints),
            comboMultiplier = "x" .. tostring(comboMultiplier),
            streakMultiplier = "x" .. tostring(streakMultiplier),
            comboSum = "x" .. tostring(comboSum),
            sameZoneBonusPoints = tostring(sameZoneBonusPoints),
            awardedPoints = tostring(awardedPoints),
            formula = string.format("%d x%d = %d", basePoints + sameZoneBonusPoints, comboSum, awardedPoints),
        }
    end

    ---@param state table|nil
    ---@param options table|nil
    ---@return table
    local function createUIContext(state, options)
        -- Each UI test gets a fresh harness so frame state, globals, and printed messages cannot bleed across cases.
        local ui = UIHarness.Create({
            state = state,
            faction = options and options.faction or nil,
            hardcoreDeathChatType = options and options.hardcoreDeathChatType or nil,
            hardcoreDeathsJoined = options and options.hardcoreDeathsJoined,
            formatLargeNumber = options and options.formatLargeNumber or nil,
            version = options and options.version or nil,
        })

        return {
            env = ui.env,
            ns = ui.ns,
            GrimUI = ui.GrimUI,
            GrimUIAutocomplete = ui.GrimUIAutocomplete,
            GrimUIDeathLogList = ui.GrimUIDeathLogList,
            GrimUIDebug = ui.GrimUIDebug,
            GrimUIDemo = ui.GrimUIDemo,
            GrimUIHelp = ui.GrimUIHelp,
            GrimUILog = ui.GrimUILog,
            GrimUIMain = ui.GrimUIMain,
            GrimUIMainCollapsed = ui.GrimUIMainCollapsed,
            GrimUIMainPrediction = ui.GrimUIMainPrediction,
            GrimUIMainRecentDeaths = ui.GrimUIMainRecentDeaths,
            GrimUIRefresh = ui.GrimUIRefresh,
            GrimUITooltip = ui.GrimUITooltip,
            GrimConstants = ui.GrimConstants,
            GrimDatabase = ui.GrimDatabase,
            GrimLogic = ui.GrimLogic,
            GrimMainFrame = ui.GrimMainFrame,
            GrimDebug = ui.GrimDebug,
            GrimLog = ui.GrimLog,
            printedMessages = ui.printedMessages,
            sendChatMessage = ui.sendChatMessage,
            cvars = ui.cvars,
            libDBIcon = ui.libDBIcon,
            setCVar = ui.setCVar,
            joinedChannels = ui.joinedChannels,
            joinPermanentChannel = ui.joinPermanentChannel,
            pressEscape = ui.pressEscape,
            findRegionText = ui.findRegionText,
            findDropdownButtonByText = ui.findDropdownButtonByText,
        }
    end

    return {
        Fixtures = Fixtures,
        ns = loadedLogic.ns,
        GrimConstants = loadedLogic.GrimConstants,
        GrimDatabase = loadedLogic.GrimDatabase,
        GrimLogic = GrimLogic,
        createUIContext = createUIContext,
        buildLevelPointsSummary = buildLevelPointsSummary,
        formatPredictionPreview = formatPredictionPreview,
        formatStoredDeathScore = formatStoredDeathScore,
    }
end

return { Create = Create }
