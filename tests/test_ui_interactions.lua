local assert = require("luassert")
describe("UI interactions", function()
    local UITestContext = require("tests.support_ui_test_context")
    local testContext
    local GrimLogic
    local Fixtures
    local createUIContext
    local formatStoredDeathScore
    local TOOLTIP_WHITE
    local TOOLTIP_GREEN
    local TOOLTIP_YELLOW
    local GrimConstants
    local SCORE_RULES
    local WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS
    local WAITING_FOR_FIRST_DEATH_HELP_TEXT_DELAY_SECONDS
    local env

    before_each(function()
        testContext = UITestContext.Create()
        GrimLogic = testContext.GrimLogic
        Fixtures = testContext.Fixtures
        env = nil
        createUIContext = function(...)
            local context = testContext.createUIContext(...)
            env = context.env
            return context
        end
        formatStoredDeathScore = testContext.formatStoredDeathScore
        TOOLTIP_WHITE = { 1, 1, 1 }
        TOOLTIP_GREEN = { 0.12, 1.0, 0.0 }
        TOOLTIP_YELLOW = { 1, 0.82, 0 }
        GrimConstants = testContext.GrimConstants
        SCORE_RULES = GrimConstants.SCORING
        WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS = GrimConstants.DEMO.waitingForFirstDeathMinDurationSeconds
        WAITING_FOR_FIRST_DEATH_HELP_TEXT_DELAY_SECONDS =
            GrimConstants.DEMO.waitingForFirstDeathHelpTextDelaySeconds
    end)

    ---@param value number
    ---@return string
    local function formatRefreshScoreStub(value)
        if value == 1234 then
            return "1,234"
        end

        return tostring(value)
    end

    local function showSetupWindow(GrimMainFrame)
        GrimMainFrame.__testNs.GrimUISetup.Show(GrimMainFrame.setupFrame, GrimMainFrame)
    end

    local function findTooltipLineIndex(label)
        for index, line in ipairs(env.GameTooltip.lines or {}) do
            if line.left == label then
                return index
            end
        end

        return nil
    end

    local function assertTooltipLineExists(label, message)
        assert.is_not_nil(findTooltipLineIndex(label), message)
    end

    local function assertTooltipLineOrder(firstLabel, secondLabel, message)
        local firstIndex = findTooltipLineIndex(firstLabel)
        local secondIndex = findTooltipLineIndex(secondLabel)
        assert.is_not_nil(firstIndex, message .. " (missing " .. firstLabel .. ")")
        assert.is_not_nil(secondIndex, message .. " (missing " .. secondLabel .. ")")
        if firstIndex ~= nil and secondIndex ~= nil then
            assert.is_truthy(firstIndex < secondIndex, message)
        end
    end

    local function assertTooltipLineColor(line, expectedColor, message)
        assert.is_not_nil(line, message .. " (missing line)")
        assert.is_not_nil(line.leftColor, message .. " (missing left color)")
        assert.is_not_nil(line.rightColor, message .. " (missing right color)")
        if line and line.leftColor and line.rightColor and expectedColor then
            assert.equals(expectedColor[1], line.leftColor[1], message .. " (left red)")
            assert.equals(expectedColor[2], line.leftColor[2], message .. " (left green)")
            assert.equals(expectedColor[3], line.leftColor[3], message .. " (left blue)")
            assert.equals(expectedColor[1], line.rightColor[1], message .. " (right red)")
            assert.equals(expectedColor[2], line.rightColor[2], message .. " (right green)")
            assert.equals(expectedColor[3], line.rightColor[3], message .. " (right blue)")
        end
    end

    local function hoverDeathLogCell(row, columnKey)
        local target = row and row.tooltipTargets and row.tooltipTargets[columnKey]
        assert.is_not_nil(target, "expected tooltip target for column " .. tostring(columnKey))
        local onEnter = target and target:GetScript("OnEnter")
        assert.is_function(onEnter, "expected OnEnter handler for column " .. tostring(columnKey))
        onEnter(target)
    end

    local function leaveDeathLogCell(row, columnKey)
        local target = row and row.tooltipTargets and row.tooltipTargets[columnKey]
        assert.is_not_nil(target, "expected tooltip target for column " .. tostring(columnKey))
        local onLeave = target and target:GetScript("OnLeave")
        assert.is_function(onLeave, "expected OnLeave handler for column " .. tostring(columnKey))
        onLeave(target)
    end

    local function assertNoDeathLogCellTooltipTarget(row, columnKey, message)
        local target = row and row.tooltipTargets and row.tooltipTargets[columnKey] or nil
        assert.equals(nil, target, message)
    end

    local function hoverRegion(region)
        assert.is_not_nil(region, "expected hover region")
        local onEnter = region:GetScript("OnEnter")
        assert.is_function(onEnter, "expected OnEnter handler")
        onEnter(region)
    end

    local function leaveRegion(region)
        assert.is_not_nil(region, "expected hover region")
        local onLeave = region:GetScript("OnLeave")
        assert.is_function(onLeave, "expected OnLeave handler")
        onLeave(region)
    end

    local function waitForGameInfoCallout(frame)
        local onUpdate = frame and frame:GetScript("OnUpdate")
        local attempts = 0

        while frame and frame.gameInfoCallout and frame.gameInfoCallout:IsShown() ~= true and attempts < 10 do
            if type(onUpdate) ~= "function" then
                break
            end

            onUpdate(frame, 0.02)
            attempts = attempts + 1
        end
    end

    local function hoverRegionAndWaitForGameInfoCallout(frame, region)
        hoverRegion(region)
        waitForGameInfoCallout(frame)
        assert.equals(true, frame.gameInfoCallout:IsShown(), "hovering should show the game info callout")
        assert.is_truthy(
            frame.gameInfoCallout.lines
                and frame.gameInfoCallout.lines[1]
                and type(frame.gameInfoCallout.lines[1].left) == "string"
                and frame.gameInfoCallout.lines[1].left ~= "",
            "game info callout should render a non-empty first line"
        )
        return frame.gameInfoCallout.lines[1].left
    end

    local function getAutocompleteTargetValue(list)
        assert(type(list) == "table" and #list > 0, "autocomplete list must not be empty")
        return list[1], string.lower(list[1])
    end

    describe("refresh and tooltips", function()
        describe("full refresh", function()
            local fullPredictionDeath
            local fullPredictionScore
            local context
            local GrimMainFrame
            local GrimDebug
            local GrimLog
            local historySourceWidth

            before_each(function()
                fullPredictionDeath = Fixtures.storedDeath({
                    timestamp = 100,
                    points = 999,
                    multiplierValue = 9,
                    awardedPoints = 8991,
                    sameZoneBonusApplied = true,
                })
                fullPredictionScore = formatStoredDeathScore(fullPredictionDeath)
                context = createUIContext(Fixtures.uiDatabase({
                    totalPoints = 1234,
                    recentDeaths = {
                        fullPredictionDeath,
                    },
                    deathHistory = {
                        Fixtures.storedDeath({
                            timestamp = 90,
                            name = "Alamo",
                            level = 11,
                            sourceName = "Defias",
                            zone = "Westfall",
                            matchedPrediction = false,
                            prediction = false,
                            predictionStreak = false,
                            points = 0,
                            multiplierValue = 0,
                            awardedPoints = 0,
                        }),
                        fullPredictionDeath,
                    },
                    successfullyPredictedDeaths = {
                        Fixtures.storedDeath({
                            timestamp = 99,
                            name = "Leeroy",
                            sourceName = "Drowning",
                            points = 2,
                            multiplierValue = 1,
                            awardedPoints = 2,
                            prediction = {
                                elements = {
                                    levelRange = "10-19",
                                },
                                lockedAt = 98,
                            },
                        }),
                        fullPredictionDeath,
                    },
                }), {
                    formatLargeNumber = formatRefreshScoreStub,
                })
                GrimMainFrame = context.GrimMainFrame
                GrimDebug = context.GrimDebug
                GrimLog = context.GrimLog
                historySourceWidth = context.GrimUI.HISTORY_LOG_COLUMNS[2].width

                GrimMainFrame:RefreshDeaths()
                GrimMainFrame:RefreshLockedPrediction()
                GrimMainFrame:RefreshCollapsedSummary(env.GrimCharacterState.recentDeaths[1])
                GrimDebug:RefreshLatestDeathDetails(
                    env.GrimCharacterState.recentDeaths[1],
                    GrimLogic.GetDisplayState(env.GrimCharacterState)
                )
                GrimLog:RefreshHistory()
            end)

            it("refreshes recent-death rows and the expanded summary", function()
                assert.equals(nil, GrimMainFrame.deathRows[1].name, "recent death rows should not create the removed name column")
                assert.equals("12", GrimMainFrame.deathRows[1].level:GetText(), "recent death rows should display the latest death level")
                assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "recent death rows should display the latest death source")
                assert.equals("Elwynn Forest", GrimMainFrame.deathRows[1].zone:GetText(), "recent death rows should display the latest death location")
                assert.equals(nil, GrimMainFrame.deathRows[1].pointsTooltipTarget, "recent death rows should not create the removed base points hover target")
                assert.equals(nil, GrimMainFrame.deathRows[1].multiplier, "recent death rows should not create the removed combo column")
                assert.equals(nil, GrimMainFrame.deathRows[1].streakMultiplier, "recent death rows should not create the removed streak column")
                assert.equals(fullPredictionScore.awardedPoints, GrimMainFrame.deathRows[1].awardedPoints:GetText(), "recent death rows should display total points in the points column")
                assert.equals("1,234", GrimMainFrame.totalPointsValue:GetText(), "main window should show the running score with comma separators")
                assert.equals("2", GrimMainFrame.currentStreakValue:GetText(), "main window should show the current streak")
                assert.equals("5", GrimMainFrame.longestStreakValue:GetText(), "main window should show the longest streak")
                assert.is_string(GrimMainFrame.lockedPredictionValue:GetText(), "locked prediction summary should reflect the stored prediction")
                assert.matches(
                    "Level 20-29, source Hogger, or zone Elwynn Forest",
                    GrimMainFrame.lockedPredictionValue:GetText(),
                    1,
                    true,
                    "locked prediction summary should reflect the stored prediction"
                )
            end)

            it("refreshes collapsed-death rows and summary", function()
                assert.equals(nil, GrimMainFrame.collapsedLogFrame.rows[1].name, "collapsed death log should not create the removed name column")
                assert.equals(context.GrimUI.GetStoredDeathTime(fullPredictionDeath), GrimMainFrame.collapsedLogFrame.rows[1].time:GetText(), "collapsed death log should show the latest time")
                assert.equals("Hogger", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "collapsed death log should show the latest source")
                assert.equals("12", GrimMainFrame.collapsedLogFrame.rows[1].level:GetText(), "collapsed death log should show the latest level")
                assert.equals("Elwynn Forest", GrimMainFrame.collapsedLogFrame.rows[1].zone:GetText(), "collapsed death log should show the latest zone")
                assert.equals(fullPredictionScore.awardedPoints, GrimMainFrame.collapsedLogFrame.rows[1].awardedPoints:GetText(), "collapsed death log should show the latest points")
                assert.equals("1,234", GrimMainFrame.collapsedPointsValue:GetText(), "collapsed score should show the running total with comma separators")
            end)

            it("renders the recent-death score tooltip", function()
                assert.equals(nil, GrimMainFrame.deathRows[1]:GetScript("OnEnter"), "recent death rows should not show tooltips from whole-row hover")
                hoverDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")
                assert.equals(4, #env.GameTooltip.lines, "hovering a recent death score cell should show the compact scoring tooltip")
                assert.equals("Base points:", env.GameTooltip.lines[1].left, "recent death row tooltip should start with base points in compact mode")
                assertTooltipLineColor(env.GameTooltip.lines[1], TOOLTIP_WHITE, "recent death row tooltip should keep base points white")
                assert.equals("Same zone:", env.GameTooltip.lines[2].left, "recent death row tooltip should include the same-zone row")
                assert.equals(fullPredictionScore.sameZoneBonusPoints, env.GameTooltip.lines[2].right, "recent death row tooltip should show the applied same-zone bonus")
                assertTooltipLineColor(env.GameTooltip.lines[2], TOOLTIP_GREEN, "recent death row tooltip should keep the same-zone row green")
                assert.is_nil(findTooltipLineIndex("Name:"), "recent death row tooltip should omit identity rows in compact mode")
                assert.is_nil(findTooltipLineIndex("Location:"), "recent death row tooltip should omit location rows in compact mode")
                assert.is_nil(findTooltipLineIndex("---------"), "recent death row tooltip should omit the divider in compact mode")
                assert.is_nil(findTooltipLineIndex("Level 10-19, source Hogger, or zone Elwynn Forest."), "recent death row tooltip should omit the prediction text in compact mode")
                assert.is_nil(findTooltipLineIndex("Streak:"), "recent death row tooltip should omit the streak row when the streak bonus is zero")
                assert.equals("Level 10-19 + Hogger + Elwynn Forest:", env.GameTooltip.lines[3].left, "recent death row tooltip should include only the best combo row")
                assertTooltipLineColor(env.GameTooltip.lines[3], TOOLTIP_GREEN, "recent death row tooltip should keep successful combos green")
                assert.is_nil(findTooltipLineIndex("Total:"), "recent death row tooltip should omit the total multiplier row in compact mode")
                assert.equals("Score:", env.GameTooltip.lines[4].left, "recent death row tooltip should include the final score row")
                assert.equals(fullPredictionScore.formula, env.GameTooltip.lines[4].right, "recent death row tooltip should show base plus same-zone points in the score formula")
                assertTooltipLineColor(env.GameTooltip.lines[4], TOOLTIP_YELLOW, "recent death row tooltip should keep the score row yellow")
                leaveDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")
                assert.equals(false, env.GameTooltip.visible, "leaving a recent death score cell should hide the tooltip")
            end)

            it("renders the collapsed-log score tooltip", function()
                assert.equals(nil, GrimMainFrame.collapsedLogFrame.rows[1]:GetScript("OnEnter"), "collapsed death log rows should not show tooltips from whole-row hover")
                assertNoDeathLogCellTooltipTarget(GrimMainFrame.collapsedLogFrame.rows[1], "time", "collapsed death log should not create a time-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimMainFrame.collapsedLogFrame.rows[1], "level", "collapsed death log should not create a level-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimMainFrame.collapsedLogFrame.rows[1], "name", "collapsed death log should not create a name-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimMainFrame.collapsedLogFrame.rows[1], "sourceName", "collapsed death log should not create a source-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimMainFrame.collapsedLogFrame.rows[1], "zone", "collapsed death log should not create a location-column tooltip target")
                hoverDeathLogCell(GrimMainFrame.collapsedLogFrame.rows[1], "awardedPoints")
                assert.equals("Base points:", env.GameTooltip.lines[1].left, "collapsed death log points hover should start with scoring in compact mode")
                assert.is_nil(findTooltipLineIndex("Name:"), "collapsed death log points hover should omit identity rows in compact mode")
                assert.is_nil(findTooltipLineIndex("Location:"), "collapsed death log points hover should omit location rows in compact mode")
                assert.is_nil(findTooltipLineIndex("Level 10-19, source Hogger, or zone Elwynn Forest."), "collapsed death log points hover should omit the prediction text in compact mode")
                assertTooltipLineOrder("Base points:", "Same zone:", "collapsed death log points hover should place same-zone bonus after base points")
                leaveDeathLogCell(GrimMainFrame.collapsedLogFrame.rows[1], "awardedPoints")
                assert.equals(false, env.GameTooltip.visible, "leaving a collapsed death log points cell should hide the tooltip")
            end)

            it("refreshes debug identity and score details", function()
                assert.equals("Drakedog", GrimDebug.detailValues.name:GetText(), "debug window should show the latest name")
                assert.equals(tostring(env.GrimCharacterState.totalPoints), GrimDebug.detailValues.totalPoints:GetText(), "debug window should show the latest total points")
                assert.equals(
                    tostring(env.GrimCharacterState.correctPredictionStreak),
                    GrimDebug.detailValues.currentPredictionStreak:GetText(),
                    "debug window should show the latest current streak"
                )
                assert.equals(
                    tostring(env.GrimCharacterState.longestPredictionStreak),
                    GrimDebug.detailValues.longestPredictionStreak:GetText(),
                    "debug window should show the latest longest streak"
                )
                assert.equals("1", GrimDebug.detailValues.predictionStreak:GetText(), "debug window should show the streak used for the latest death score")
                assert.equals(fullPredictionScore.basePoints, GrimDebug.detailValues.basePoints:GetText(), "debug window should show the latest base points")
                assert.equals(fullPredictionScore.comboMultiplier, GrimDebug.detailValues.comboMultiplier:GetText(), "debug window should show the latest combo bonus")
                assert.equals(fullPredictionScore.streakMultiplier, GrimDebug.detailValues.streakMultiplier:GetText(), "debug window should show the latest streak bonus")
                assert.equals(fullPredictionScore.comboSum, GrimDebug.detailValues.multiplier:GetText(), "debug window should show the formatted combo total")
                assert.equals(fullPredictionScore.awardedPoints, GrimDebug.detailValues.awardedPoints:GetText(), "debug window should show awarded points")
            end)

            it("refreshes debug prediction, formula, and source details", function()
                assert.equals("Hogger", GrimMainFrame.sourceEditBox:GetText(), "refresh should populate the source edit box from locked prediction")
                assert.equals("Elwynn Forest", GrimMainFrame.zoneEditBox:GetText(), "refresh should populate the zone edit box from locked prediction")
                assert.is_string(GrimDebug.detailValues.lockedPrediction:GetText(), "debug window should show the latest locked prediction")
                assert.matches(
                    "Level 20-29, source Hogger, or zone Elwynn Forest",
                    GrimDebug.detailValues.lockedPrediction:GetText(),
                    1,
                    true,
                    "debug window should show the latest locked prediction"
                )
                assert.equals(fullPredictionScore.formula, GrimDebug.detailValues.pointFormula:GetText(), "debug window should show the latest score formula")
                assert.is_string(GrimDebug.detailValues.comboDetails:GetText(), "debug window should show the winning combo label")
                assert.matches(
                    "Level 10-19 + Hogger + Elwynn Forest",
                    GrimDebug.detailValues.comboDetails:GetText(),
                    1,
                    true,
                    "debug window should show the winning combo label"
                )
                assert.equals(
                    fullPredictionDeath.sourceMessage,
                    GrimDebug.detailValues.sourceMessage:GetText(),
                    "debug window should show the latest raw message in the copyable edit box"
                )
                assert.equals(nil, GrimDebug.detailValues.timestamp, "debug window should remove the old timestamp field")
                assert.equals(nil, GrimDebug.detailValues.causeType, "debug window should remove the old cause type field")
            end)

            it("refreshes successful-history rows", function()
                assert.equals("Source", GrimLog.columnHeaders.sourceName:GetText(), "successful history should show the source column label")
                assert.equals(nil, GrimLog.columnHeaders.level, "successful history should omit the level column header")
                assert.equals(historySourceWidth, GrimLog.rows[1].sourceName:GetWidth(), "successful history should give the source column the scrollbar-aware width")
                assert.equals("Hogger", GrimLog.rows[1].sourceName:GetText(), "successful history should show the death source")
                assert.equals(nil, GrimLog.rows[1].level, "successful history should not create death level cells")
                assert.equals(fullPredictionScore.awardedPoints, GrimLog.rows[1].awardedPoints:GetText(), "history log should recalculate stale persisted totals from the saved prediction")
                assert.equals(nil, GrimLog.rows[1]:GetScript("OnEnter"), "history log rows should not show tooltips from whole-row hover")
                assertNoDeathLogCellTooltipTarget(GrimLog.rows[1], "time", "history log should not create a time-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimLog.rows[1], "sourceName", "history log should not create a source-column tooltip target")
                assertNoDeathLogCellTooltipTarget(GrimLog.rows[1], "level", "history log should not create a level-column tooltip target")
            end)

            it("renders the successful-history score tooltip", function()
                hoverDeathLogCell(GrimLog.rows[1], "awardedPoints")
                assert.equals("Level 10-19, source Hogger, or zone Elwynn Forest.", env.GameTooltip.lines[1].left, "history log points hover should start with the prediction text")
                assert.equals("", env.GameTooltip.lines[1].right, "history log points hover prediction text should keep the right column blank")
                assert.is_nil(findTooltipLineIndex("Name:"), "history log points hover should omit the dead player name")
                assert.is_nil(findTooltipLineIndex("---------"), "history log points hover should omit the old prediction divider")
                assert.equals("Level:", env.GameTooltip.lines[2].left, "history log points hover should show identity rows when requested")
                assert.equals("Date:", env.GameTooltip.lines[3].left, "history log points hover should show the death date below level")
                assert.equals("January 01, 1970 10:05", env.GameTooltip.lines[3].right, "history log points hover should show the full death date and time")
                assertTooltipLineOrder("Level:", "Date:", "history log points hover should place the death date below level")
                assertTooltipLineOrder("Date:", "Source:", "history log points hover should place the source below the death date")
                assertTooltipLineExists("Base points:", "history log points hover should show the base points after the identity rows")
                assertTooltipLineOrder("Location:", "Base points:", "history log points hover should place base points after the identity rows")
                assertTooltipLineExists("Same zone:", "history log points hover should include the same-zone row for real deaths")
                assertTooltipLineOrder("Base points:", "Same zone:", "history log points hover should place same-zone bonus after base points")
                do
                    local basePointsIndex = findTooltipLineIndex("Base points:")
                    assert.is_not_nil(basePointsIndex, "history log points hover should include the base points row")
                    if basePointsIndex ~= nil then
                        assertTooltipLineColor(
                            env.GameTooltip.lines[basePointsIndex],
                            TOOLTIP_WHITE,
                            "history log points hover should keep base points white"
                        )
                    end
                end
                do
                    local comboIndex = findTooltipLineIndex("Level 10-19 + Hogger + Elwynn Forest:")
                    assert.is_not_nil(comboIndex, "history log points hover should include the best successful combo row")
                    if comboIndex ~= nil then
                        assertTooltipLineColor(
                            env.GameTooltip.lines[comboIndex],
                            TOOLTIP_GREEN,
                            "history log points hover should keep successful combos green"
                        )
                    end
                end
                assert.is_nil(findTooltipLineIndex("Combos:"), "history log points hover should omit the combos section label")
                assert.is_nil(findTooltipLineIndex("Total:"), "history log points hover should omit the total multiplier row")
                assert.is_nil(findTooltipLineIndex("Streak:"), "history log points hover should omit the streak row when the streak bonus is zero")
                do
                    local sameZoneIndex = findTooltipLineIndex("Same zone:")
                    assert.is_not_nil(sameZoneIndex, "history log points hover should include the same-zone row")
                    if sameZoneIndex ~= nil then
                        assert.equals(
                            fullPredictionScore.sameZoneBonusPoints,
                            env.GameTooltip.lines[sameZoneIndex].right,
                            "history log points hover should show the applied same-zone bonus"
                        )
                        assertTooltipLineColor(
                            env.GameTooltip.lines[sameZoneIndex],
                            TOOLTIP_GREEN,
                            "history log points hover should keep the same-zone row green"
                        )
                    end
                end
                assertTooltipLineOrder("Same zone:", "Level 10-19 + Hogger + Elwynn Forest:", "history log points hover should place the best combo after same-zone bonus when streak is omitted")
                assertTooltipLineExists("Score:", "history log points hover should show the final score row at the bottom")
                assertTooltipLineOrder("Level 10-19 + Hogger + Elwynn Forest:", "Score:", "history log points hover should show the final score row after the combo row")
                do
                    local totalIndex = findTooltipLineIndex("Total:")
                    local scoreIndex = findTooltipLineIndex("Score:")
                    assert.is_nil(totalIndex, "history log points hover should omit the total row")
                    assert.is_not_nil(scoreIndex, "history log points hover should include the score row")
                    if scoreIndex ~= nil then
                        assert.equals(
                            fullPredictionScore.formula,
                            env.GameTooltip.lines[scoreIndex].right,
                            "history log points hover should show base plus same-zone points in the score formula"
                        )
                        assertTooltipLineColor(
                            env.GameTooltip.lines[scoreIndex],
                            TOOLTIP_YELLOW,
                            "history log points hover should keep the score row yellow"
                        )
                    end
                end
                leaveDeathLogCell(GrimLog.rows[1], "awardedPoints")
                assert.equals(false, env.GameTooltip.visible, "leaving a history log points cell should hide the tooltip")
            end)

            it("switches to the all-history view", function()
                assert.equals("Drowning", GrimLog.rows[2].sourceName:GetText(), "history log should default to the successful prediction source list")
                assert.equals("SHOW ALL", GrimLog.filterButton:GetText(), "history log should default the filter button to the alternate view action")

                GrimLog.filterButton:GetScript("OnClick")()

                assert.equals(false, env.GrimCharacterState.historySuccessfulOnly, "history filter should persist all-history mode when toggled off")
                assert.equals("All Predictions", GrimLog.logSubtitle:GetText(), "history filter should restore the all-deaths subtitle")
                assert.equals("SHOW SUCCESS ONLY", GrimLog.filterButton:GetText(), "history filter should offer the success-only action while unfiltered")
                assert.equals("Time", GrimLog.columnHeaders.time:GetText(), "all-history mode should restore the time column label")
                assert.equals("Source", GrimLog.columnHeaders.sourceName:GetText(), "all-history mode should use the source column label")
                assert.equals(nil, GrimLog.columnHeaders.level, "all-history mode should omit the level column header")
                assert.equals(historySourceWidth, GrimLog.rows[1].sourceName:GetWidth(), "all-history mode should keep the scrollbar-aware source column width")
                assert.equals("Hogger", GrimLog.rows[1].sourceName:GetText(), "all-history mode should show the newest history source first")
                assert.equals(nil, GrimLog.rows[1].level, "all-history mode should not create level cells")
                assert.equals("Defias", GrimLog.rows[2].sourceName:GetText(), "all-history mode should include older sources underneath")
            end)

            it("switches back to the successful-history view", function()
                GrimLog.filterButton:GetScript("OnClick")()

                GrimLog.filterButton:GetScript("OnClick")()

                assert.equals(true, env.GrimCharacterState.historySuccessfulOnly, "history filter should persist success-only mode when toggled back on")
                assert.equals("Successful Predictions", GrimLog.logSubtitle:GetText(), "history filter should relabel the window for success-only mode")
                assert.equals("SHOW ALL", GrimLog.filterButton:GetText(), "history filter should restore the all-deaths action while filtered")
                assert.equals("Rank", GrimLog.columnHeaders.time:GetText(), "success-only history should relabel the time column as rank")
                assert.equals("Source", GrimLog.columnHeaders.sourceName:GetText(), "success-only history should show the source column label")
                assert.equals(nil, GrimLog.columnHeaders.level, "success-only history should omit the level column label")
                assert.equals(historySourceWidth, GrimLog.rows[1].sourceName:GetWidth(), "success-only history should use the scrollbar-aware source column after toggling back")
                assert.equals("#1", GrimLog.rows[1].time:GetText(), "success-only history should show the highest-scoring death as rank one")
                assert.equals("#2", GrimLog.rows[2].time:GetText(), "success-only history should show lower-scoring deaths with later ranks")
                assert.equals("Hogger", GrimLog.rows[1].sourceName:GetText(), "success-only history should show the highest-scoring death source")
                assert.equals(nil, GrimLog.rows[1].level, "success-only history should not create level cells")
                assert.equals("Drowning", GrimLog.rows[2].sourceName:GetText(), "success-only history should sort lower-scoring death sources underneath higher-scoring ones")
            end)
        end)

        it("uses green for positive streak tooltip rows", function()
            local streakDeath = Fixtures.storedDeath({
                timestamp = 100,
                predictionStreak = 2,
                sameZoneBonusApplied = true,
            })
            local context = createUIContext(Fixtures.uiDatabase({
                recentDeaths = {
                    streakDeath,
                },
                deathHistory = {
                    streakDeath,
                },
                successfullyPredictedDeaths = {
                    streakDeath,
                },
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            hoverDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")

            do
                local streakIndex = findTooltipLineIndex("Streak:")
                assert.is_not_nil(streakIndex, "positive-streak tooltip should include the streak row")
                if streakIndex ~= nil then
                    assertTooltipLineColor(
                        env.GameTooltip.lines[streakIndex],
                        TOOLTIP_GREEN,
                        "positive-streak tooltip should keep the streak row green"
                    )
                end
            end

            leaveDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")
        end)

        it("uses the preview streak for prediction-only tooltips", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI
            local anchor = env.CreateFrame("Frame", nil, env.UIParent)
            local prediction = Fixtures.prediction({
                levelRange = "10-19",
            })
            local previewSummary = GrimLogic.GetComboDetails(prediction, nil, GrimLogic.GetPreviewStreak())

            context.GrimUITooltip.ShowStandardizedTooltip(anchor, {
                prediction = prediction,
            }, false, false, false)

            do
                local streakIndex = findTooltipLineIndex("Streak:")
                assert.is_not_nil(streakIndex, "prediction-only tooltip should include the preview streak row by default")
                if streakIndex ~= nil then
                    assert.equals(
                        GrimUI.GetMultiplierDisplay(previewSummary.streakMultiplier),
                        env.GameTooltip.lines[streakIndex].right,
                        "prediction-only tooltip should use the configured preview streak value"
                    )
                    assertTooltipLineColor(
                        env.GameTooltip.lines[streakIndex],
                        TOOLTIP_GREEN,
                        "prediction-only tooltip should keep the preview streak row green"
                    )
                end
            end

            env.GameTooltip:Hide()
        end)

        it("hides low-value multiplier tooltip rows", function()
            local context = createUIContext()
            local anchor = env.CreateFrame("Frame", nil, env.UIParent)
            local prediction = Fixtures.prediction({
                levelRange = false,
                source = "hogger",
                zone = false,
                zoneLabel = false,
            })
            local death = Fixtures.death({
                sourceName = "Hogger",
                zone = "Westfall",
            })

            context.GrimUITooltip.ShowStandardizedTooltip(anchor, {
                prediction = prediction,
                death = death,
                streak = 1,
            }, false, false, true)

            assert.is_nil(findTooltipLineIndex("Streak:"), "tooltips should hide a streak row when the multiplier is x0 or x1")
            assert.is_nil(findTooltipLineIndex("Hogger:"), "tooltips should hide combo rows when the multiplier is x0 or x1")
            assert.is_nil(findTooltipLineIndex("Total:"), "tooltips should omit the total multiplier row")
            assertTooltipLineExists("Score:", "tooltips should still show the score row")

            env.GameTooltip:Hide()
        end)

        it("prefers intro demo state over live database state during refresh", function()
            local demoDeath = Fixtures.storedDeath({
                timestamp = 500,
                name = "Demohunter",
                level = 34,
                sourceName = "Burning Blade Cultist",
                zone = "Desolace",
                prediction = Fixtures.prediction({
                    levelRange = "30-39",
                    source = "burning blade cultist",
                    zone = "desolace",
                }),
                predictionStreak = 3,
            })
            local demoPrediction = Fixtures.prediction({
                levelRange = "30-39",
                source = "burning blade cultist",
                zone = "desolace",
            })

            local context = createUIContext(Fixtures.uiDatabase({
                totalPoints = 999,
                correctPredictionStreak = 8,
                longestPredictionStreak = 12,
                lockedPrediction = Fixtures.prediction({
                    levelRange = "60",
                    source = "hogger",
                    zone = "elwynn forest",
                }),
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 400,
                        name = "Livedeath",
                        level = 60,
                        sourceName = "Hogger",
                        zone = "Elwynn Forest",
                    }),
                },
                deathHistory = {
                    Fixtures.storedDeath({
                        timestamp = 400,
                        name = "Livedeath",
                        level = 60,
                        sourceName = "Hogger",
                        zone = "Elwynn Forest",
                    }),
                },
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.introDemoController:Show()
            GrimMainFrame.introDemoController.demoState = Fixtures.introDemoState({
                recentDeaths = { demoDeath },
                totalPoints = 44,
                correctPredictionStreak = 3,
                longestPredictionStreak = 6,
                lockedPrediction = demoPrediction,
                draftPrediction = demoPrediction,
                lastPrediction = demoPrediction,
                deathHistory = {},
                successfullyPredictedDeaths = {},
            })

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()
            GrimMainFrame:RefreshCollapsedSummary()

            assert.equals(nil, GrimMainFrame.deathRows[1].name, "demo refresh should not create the removed name column")
            assert.equals("34", GrimMainFrame.deathRows[1].level:GetText(), "demo refresh should prefer the demo death level")
            assert.equals("Burning Blade Cultist", GrimMainFrame.deathRows[1].sourceName:GetText(), "demo refresh should prefer the demo death source")
            assert.equals("Desolace", GrimMainFrame.deathRows[1].zone:GetText(), "demo refresh should prefer the demo death zone")
            assert.equals("44", GrimMainFrame.totalPointsValue:GetText(), "demo refresh should prefer the demo total points")
            assert.equals("3", GrimMainFrame.currentStreakValue:GetText(), "demo refresh should prefer the demo current streak")
            assert.equals("6", GrimMainFrame.longestStreakValue:GetText(), "demo refresh should prefer the demo longest streak")
            assert.is_string(GrimMainFrame.lockedPredictionValue:GetText(), "demo refresh should prefer the demo locked prediction")
            assert.matches(
                "Level 30-39, source Burning Blade Cultist, or zone Desolace",
                GrimMainFrame.lockedPredictionValue:GetText(),
                1,
                true,
                "demo refresh should prefer the demo locked prediction"
            )
            assert.equals("Burning Blade Cultist", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "demo refresh should prefer the demo collapsed death log")
            assert.equals("44", GrimMainFrame.collapsedPointsValue:GetText(), "demo refresh should prefer the demo collapsed score")
        end)
    end)

    describe("prediction state", function()
        it("restores a locked prediction after reload", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = Fixtures.prediction({
                    levelRange = "20-29",
                }),
                lastPrediction = Fixtures.prediction({
                    levelRange = "30-39",
                    source = "defias",
                    zone = "westfall",
                }),
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("20-29", GrimMainFrame.selectedLevelRange, "refresh should restore the locked level range selection after reload")
            assert.equals("Hogger", GrimMainFrame.sourceEditBox:GetText(), "refresh should restore the locked source text after reload")
            assert.equals("Elwynn Forest", GrimMainFrame.zoneEditBox:GetText(), "refresh should restore the locked zone text after reload")
            assert.equals("LOCKED IN", GrimMainFrame.lockButton:GetText(), "refresh should restore the locked button label after reload")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "refresh should keep the lock button disabled while a prediction is locked")
            assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "refresh should keep the source input locked after reload")
            assert.equals(false, GrimMainFrame.zoneEditBox:IsEnabled(), "refresh should keep the zone input locked after reload")
            assert.is_truthy(GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "refresh should keep the selected level range visually active after reload")
            assert.equals(false, GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "refresh should keep other level ranges disabled while locked")
            assert.is_truthy(GrimMainFrame.pauseButton:IsEnabled(), "refresh should keep pause enabled while a prediction is locked")
        end)

        it("restores the saved draft after the lock is cleared", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = Fixtures.prediction({
                    levelRange = "20-29",
                }),
                lastPrediction = Fixtures.prediction({
                    levelRange = "30-39",
                    source = "defias",
                    zone = "westfall",
                }),
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshLockedPrediction()
            env.GrimCharacterState.lockedPrediction = nil
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("30-39", GrimMainFrame.selectedLevelRange, "refresh should restore the last unlocked level range when no prediction is locked")
            assert.equals("Defias", GrimMainFrame.sourceEditBox:GetText(), "refresh should restore the last unlocked source text")
            assert.equals("Westfall", GrimMainFrame.zoneEditBox:GetText(), "refresh should restore the last unlocked zone text")
            assert.equals("Prediction not locked in yet.", GrimMainFrame.lockedPredictionValue:GetText(), "refresh should keep the summary tied to the currently locked prediction")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "refresh should restore the unlocked button label")
            assert.is_truthy(GrimMainFrame.lockButton:IsEnabled(), "refresh should re-enable locking when a draft prediction was restored")
            assert.is_truthy(GrimMainFrame.sourceEditBox:IsEnabled(), "refresh should unlock the source input when nothing is locked")
            assert.is_truthy(GrimMainFrame.zoneEditBox:IsEnabled(), "refresh should unlock the zone input when nothing is locked")
            assert.equals(false, GrimMainFrame.levelRangeButtons[4]:IsEnabled(), "refresh should keep the restored draft level range selected")
            assert.is_truthy(GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "refresh should re-enable other level ranges when unlocked")
            assert.equals(false, GrimMainFrame.pauseButton:IsEnabled(), "refresh should disable pause when nothing is locked")
        end)

        it("restores locked inputs and pause controls", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = Fixtures.prediction({
                    levelRange = "30-39",
                    source = "burning blade cultist",
                    zone = "desolace",
                }),
                lastPrediction = Fixtures.prediction({
                    levelRange = "20-29",
                    source = "defias pillager",
                    zone = "westfall",
                }),
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("30-39", GrimMainFrame.selectedLevelRange, "refresh should restore the locked level range")
            assert.equals("Burning Blade Cultist", GrimMainFrame.sourceEditBox:GetText(), "refresh should populate the source input from the locked prediction")
            assert.equals("Desolace", GrimMainFrame.zoneEditBox:GetText(), "refresh should populate the zone input from the locked prediction")
            assert.is_truthy(GrimMainFrame.levelRangeButtons[4]:IsEnabled(), "refresh should keep the locked level range visually active")
            assert.equals(false, GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "refresh should keep other level ranges disabled while locked")
            assert.equals("LOCKED IN", GrimMainFrame.lockButton:GetText(), "refresh should keep the locked button label")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "refresh should disable lock while a prediction is locked")
            assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "refresh should disable the source input while locked")
            assert.equals(false, GrimMainFrame.zoneEditBox:IsEnabled(), "refresh should disable the zone input while locked")
            assert.is_truthy(GrimMainFrame.pauseButton:IsEnabled(), "refresh should enable pause while a prediction is locked")
        end)

        it("restores editable inputs after unlocking", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = Fixtures.prediction({
                    levelRange = "30-39",
                    source = "burning blade cultist",
                    zone = "desolace",
                }),
                lastPrediction = Fixtures.prediction({
                    levelRange = "20-29",
                    source = "defias pillager",
                    zone = "westfall",
                }),
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshLockedPrediction()
            env.GrimCharacterState.lockedPrediction = nil
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("20-29", GrimMainFrame.selectedLevelRange, "refresh should restore the last level range when nothing is locked")
            assert.equals("Defias Pillager", GrimMainFrame.sourceEditBox:GetText(), "refresh should populate the source input from the last draft prediction")
            assert.equals("Westfall", GrimMainFrame.zoneEditBox:GetText(), "refresh should populate the zone input from the last draft prediction")
            assert.equals(false, GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "refresh should keep the restored level range selected")
            assert.is_truthy(GrimMainFrame.levelRangeButtons[4]:IsEnabled(), "refresh should re-enable other level ranges once unlocked")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "refresh should restore the unlocked button label")
            assert.is_truthy(GrimMainFrame.lockButton:IsEnabled(), "refresh should enable lock when a restorable prediction exists")
            assert.is_truthy(GrimMainFrame.sourceEditBox:IsEnabled(), "refresh should re-enable the source input when unlocked")
            assert.is_truthy(GrimMainFrame.zoneEditBox:IsEnabled(), "refresh should re-enable the zone input when unlocked")
            assert.equals(false, GrimMainFrame.pauseButton:IsEnabled(), "refresh should disable pause when no prediction is locked")
        end)

        it("handles an empty locked-prediction state", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = false,
                lastPrediction = false,
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("Prediction not locked in yet.", GrimMainFrame.lockedPredictionValue:GetText(), "empty refresh should keep the unlocked prediction summary")
            assert.equals("", GrimMainFrame.sourceEditBox:GetText(), "empty refresh should clear the source input")
            assert.equals("", GrimMainFrame.zoneEditBox:GetText(), "empty refresh should clear the zone input")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "empty refresh should keep the lock button label unlocked")
            assert.equals(false, GrimMainFrame.pauseButton:IsEnabled(), "empty refresh should disable the pause button")
        end)

        it("replaces the main death log with the empty prediction prompt", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Promptcheck",
                        level = 12,
                        sourceName = "Hogger",
                        zone = "Elwynn Forest",
                    }),
                },
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals(true, GrimMainFrame.emptyPredictionPrompt:IsShown(), "main window should show the empty-prediction prompt when nothing is selected")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "main window should hide recent death rows until a prediction exists")
            assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "hidden prompt rows should retain current death source")

            GrimMainFrame.levelRangeButtons[2]:GetScript("OnClick")(GrimMainFrame.levelRangeButtons[2])

            assert.equals(true, GrimMainFrame.emptyPredictionPrompt:IsShown(), "selecting a prediction should keep the empty-prediction prompt visible before lock-in")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "selecting a prediction should keep recent death rows hidden before lock-in")
            assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "selecting a prediction should not clear hidden death rows")

            GrimMainFrame.lockButton:GetScript("OnClick")()

            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "locking in a prediction should hide the empty-prediction prompt")
            assert.equals(true, GrimMainFrame.deathRows[1]:IsShown(), "locking in a prediction should show recent death rows again")
            assert.equals(true, env.GrimCharacterState.hasSeenFirstRun, "locking in a prediction should persist the first-run flag")
            assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "recent deaths should return once a prediction is selected")
        end)

        it("persists unlocked drafts across refreshes", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.levelRangeButtons[4]:GetScript("OnClick")(GrimMainFrame.levelRangeButtons[4])
            GrimMainFrame.sourceEditBox:SetText("defias")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            GrimMainFrame.zoneEditBox:SetText("westfall")
            GrimMainFrame.zoneEditBox:GetScript("OnTextChanged")(GrimMainFrame.zoneEditBox, true)

            assert.equals("30-39", env.GrimCharacterState.draftPrediction.elements.levelRange, "editing a draft should store the selected level range")
            assert.equals("defias", env.GrimCharacterState.draftPrediction.elements.source, "editing a draft should store the normalized source")
            assert.equals("westfall", env.GrimCharacterState.draftPrediction.elements.zone, "editing a draft should store the normalized zone")

            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("30-39", GrimMainFrame.selectedLevelRange, "refresh should keep the live draft level range")
            assert.equals("Defias", GrimMainFrame.sourceEditBox:GetText(), "refresh should keep the live draft source text")
            assert.equals("Westfall", GrimMainFrame.zoneEditBox:GetText(), "refresh should keep the live draft zone text")

            GrimMainFrame.levelRangeButtons[1]:GetScript("OnClick")(GrimMainFrame.levelRangeButtons[1])
            GrimMainFrame.sourceEditBox:SetText("")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            GrimMainFrame.zoneEditBox:SetText("")
            GrimMainFrame.zoneEditBox:GetScript("OnTextChanged")(GrimMainFrame.zoneEditBox, true)

            assert.equals(nil, env.GrimCharacterState.draftPrediction, "clearing every draft input should clear the stored draft")

            GrimMainFrame:RefreshLockedPrediction()

            assert.equals("None", GrimMainFrame.selectedLevelRange, "refresh should keep the cleared level range")
            assert.equals("", GrimMainFrame.sourceEditBox:GetText(), "refresh should keep the cleared source text")
            assert.equals("", GrimMainFrame.zoneEditBox:GetText(), "refresh should keep the cleared zone text")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "refresh should keep locking disabled when the draft is empty")
        end)
    end)

    describe("setup", function()
        it("shows both incomplete setup items", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals(nil, GrimMainFrame.configPromptFrame, "incomplete setup should not create an inline setup prompt")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "incomplete setup should not show from refresh alone")

            showSetupWindow(GrimMainFrame)

            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "incomplete setup should show the setup window")
            assert.equals(true, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "incomplete setup should obscure the main window")
            assert.equals("SETUP", GrimMainFrame.setupFrame.title:GetText(), "setup window should use the setup title")
            assert.equals(true, GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:IsShown(), "incomplete setup should show the enable button")
            assert.equals(true, GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:IsEnabled(), "disabled death announcements should leave enable clickable")
            assert.equals(true, GrimMainFrame.setupFrame.joinHardcoreDeathsButton:IsShown(), "incomplete setup should show the join button")
            assert.equals(true, GrimMainFrame.setupFrame.joinHardcoreDeathsButton:IsEnabled(), "missing hardcore deaths channel should leave join clickable")
            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "setup window should hide the first-run prompt")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "setup window should disable locking predictions")
            assert.equals(false, GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "setup window should disable level buttons")
            assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "setup window should disable source input")
            assert.equals(false, GrimMainFrame.zoneEditBox:IsEnabled(), "setup window should disable zone input")
        end)

        it("blocks setup closing for new characters", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenIntroDemo = false,
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)

            assert.is_not_nil(GrimMainFrame.setupFrame.CloseButton, "setup window should expose the template close button")
            assert.equals(false, GrimMainFrame.setupFrame.CloseButton:IsEnabled(), "new characters should not be able to close setup with X")

            GrimMainFrame.setupFrame.CloseButton:Click()

            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "setup X should keep setup visible before Grim Guesser has started")
            assert.equals(true, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "blocked setup X should keep the setup backdrop visible")
        end)

        it("blocks setup closing before the first prediction", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenIntroDemo = true,
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "1",
                hardcoreDeathsJoined = true,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)

            assert.equals(false, GrimMainFrame.setupFrame.CloseButton:IsEnabled(), "setup X should stay disabled until the first prediction is made")

            GrimMainFrame.setupFrame.CloseButton:Click()

            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "setup X should not close setup after demo but before first prediction")
            assert.equals(true, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "blocked setup X after demo should keep the backdrop visible")
        end)

        it("closes setup for Grim Guesser players", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenIntroDemo = true,
                hasSeenFirstRun = true,
            }), {
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)

            assert.equals(true, GrimMainFrame.setupFrame.CloseButton:IsEnabled(), "Grim Guesser players should be able to close setup with X")

            GrimMainFrame.setupFrame.CloseButton:Click()

            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "setup X should close setup once Grim Guesser has started")
            assert.equals(false, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "setup X should clear the backdrop when setup closes")
        end)

        it("enables only the death-announcement setup item", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)
            GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:Click()

            assert.spy(context.setCVar).was_called(1)
            assert.spy(context.setCVar).was_called_with("hardcoreDeathChatType", "1")
            assert.spy(context.joinPermanentChannel).was_not_called()
            assert.equals("1", context.cvars.hardcoreDeathChatType, "clicking enable should enable game death announcements")
            assert.equals(false, context.joinedChannels.HardcoreDeaths, "clicking enable should leave the channel unjoined")
            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "remaining channel setup should keep the setup window visible")
            assert.equals(false, GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:IsEnabled(), "completed death announcements should disable enable")
            assert.equals("ENABLED", GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:GetText(), "completed death announcements should show the completed label")
            assert.equals(true, GrimMainFrame.setupFrame.joinHardcoreDeathsButton:IsEnabled(), "missing channel should keep join clickable")
            assert.equals("JOIN", GrimMainFrame.setupFrame.joinHardcoreDeathsButton:GetText(), "missing channel should keep the join action label")
            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "partially complete setup should not advance to first-run prompt")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "partially complete setup should keep prediction locking disabled")
        end)

        it("joins only the HardcoreDeaths setup item", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)
            GrimMainFrame.setupFrame.joinHardcoreDeathsButton:Click()

            assert.spy(context.joinPermanentChannel).was_called(1)
            assert.spy(context.joinPermanentChannel).was_called_with("HardcoreDeaths")
            assert.spy(context.setCVar).was_not_called()
            assert.equals(true, context.joinedChannels.HardcoreDeaths, "clicking join should join the HardcoreDeaths channel")
            assert.equals("0", context.cvars.hardcoreDeathChatType, "clicking join should leave death announcements disabled")
            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "remaining death announcement setup should keep the setup window visible")
            assert.equals(true, GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:IsEnabled(), "disabled death announcements should keep enable clickable")
            assert.equals("ENABLE", GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:GetText(), "disabled death announcements should keep the enable action label")
            assert.equals(false, GrimMainFrame.setupFrame.joinHardcoreDeathsButton:IsEnabled(), "completed channel setup should disable join")
            assert.equals("JOINED", GrimMainFrame.setupFrame.joinHardcoreDeathsButton:GetText(), "completed channel setup should show the completed label")
            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "partially complete setup should not advance to first-run prompt")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "partially complete setup should keep prediction locking disabled")
        end)

        it("shows precompleted death-announcement setup", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "1",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            showSetupWindow(GrimMainFrame)

            assert.equals(true, GrimMainFrame.setupFrame:IsShown(), "one incomplete item should keep the setup window visible")
            assert.equals(false, GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:IsEnabled(), "enabled death announcements should disable enable")
            assert.equals("ENABLED", GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:GetText(), "enabled death announcements should show the completed label")
            assert.equals(true, GrimMainFrame.setupFrame.joinHardcoreDeathsButton:IsEnabled(), "missing channel should keep join clickable")
            assert.equals("JOIN", GrimMainFrame.setupFrame.joinHardcoreDeathsButton:GetText(), "missing channel should keep the join action label")
            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "one incomplete item should hide first-run prompt")
        end)

        it("advances to prediction after setup completes", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }), {
                hardcoreDeathChatType = "1",
                hardcoreDeathsJoined = true,
            })
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "completed setup should hide the setup window")
            assert.equals(false, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "completed setup should hide the main-window backdrop")
            assert.equals(true, GrimMainFrame.emptyPredictionPrompt:IsShown(), "completed setup should advance to the first-run prompt")
            assert.equals(true, GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "completed setup should unlock level buttons")
            assert.equals(true, GrimMainFrame.sourceEditBox:IsEnabled(), "completed setup should unlock source input")
            assert.equals(true, GrimMainFrame.zoneEditBox:IsEnabled(), "completed setup should unlock zone input")
        end)

        it("hides the first-run prompt for returning players", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Veterancheck",
                        level = 12,
                        sourceName = "Hogger",
                        zone = "Elwynn Forest",
                    }),
                },
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "returning players should not see the first-run prompt")
            assert.equals(true, GrimMainFrame.deathRows[1]:IsShown(), "returning players should keep the recent death log visible")
            assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "returning players should still see recent deaths")
        end)
    end)

    describe("waiting state and history", function()
        it("uses the shared prompt pane for waiting notifications", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
                recentDeaths = {},
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "empty recent deaths should hide the centered prompt while dots animate separately")
            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "empty recent deaths should show the waiting prompt base text")
            assert.equals(true, GrimMainFrame.waitingPromptDots:IsShown(), "empty recent deaths should show the waiting prompt dots")
            assert.equals(false, GrimMainFrame.waitingPromptHelpText:IsShown(), "empty recent deaths should hide the help hint before the timer completes")
            assert.equals(
                "Waiting for first death",
                GrimMainFrame.waitingPromptText:GetText(),
                "empty recent deaths should show the waiting message base text"
            )
            assert.equals(
                "",
                GrimMainFrame.waitingPromptDots:GetText(),
                "empty recent deaths should start the waiting message with no dots"
            )
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "empty recent deaths should keep the main death log hidden")

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(
                ".",
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should add the first dot after one second"
            )

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(
                "..",
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should add a second dot after two seconds"
            )

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(
                "...",
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should add a third dot after three seconds"
            )

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(
                "",
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should loop back to no dots after four seconds"
            )

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, WAITING_FOR_FIRST_DEATH_HELP_TEXT_DELAY_SECONDS - 4)
            assert.equals(
                "Waiting for first death",
                GrimMainFrame.waitingPromptText:GetText(),
                "waiting message should keep the base text in place when the help hint appears"
            )
            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "waiting message should keep showing the base text when the help hint appears")
            assert.equals(true, GrimMainFrame.waitingPromptDots:IsShown(), "waiting message should keep the animated dots visible when the help hint appears")
            assert.equals(
                string.rep(".", WAITING_FOR_FIRST_DEATH_HELP_TEXT_DELAY_SECONDS % 4),
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should keep the dots aligned when the help hint appears"
            )
            assert.equals(
                "Click HELP if you are missing deaths",
                GrimMainFrame.waitingPromptHelpText:GetText(),
                "waiting message should add the help hint after the minimum duration"
            )
            assert.equals(true, GrimMainFrame.waitingPromptHelpText:IsShown(), "waiting message should show the separate help hint after the minimum duration")

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(
                string.rep(".", (WAITING_FOR_FIRST_DEATH_HELP_TEXT_DELAY_SECONDS + 1) % 4),
                GrimMainFrame.waitingPromptDots:GetText(),
                "waiting message should keep animating the dots after the help hint appears"
            )
            assert.equals(true, GrimMainFrame.waitingPromptHelpText:IsShown(), "waiting message should keep the help hint visible while the dots continue")
        end)

        it("restores waiting notifications after minimize", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
                recentDeaths = {},
            }))
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "waiting prompt should start visible before minimizing")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(false, GrimMainFrame.waitingPromptText:IsShown(), "collapsed refresh should hide the expanded waiting prompt")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)

            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "expanding should restore the waiting prompt base text")
            assert.equals(true, GrimMainFrame.waitingPromptDots:IsShown(), "expanding should restore the waiting prompt dots")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "expanding should keep empty death rows hidden while waiting")
        end)

        it("keeps waiting notifications visible for their minimum duration", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
                recentDeaths = {},
            }))
            local GrimMainFrame = context.GrimMainFrame
            local incomingDeath = Fixtures.storedDeath({
                timestamp = 100,
                name = "Soonenough",
                level = 14,
                sourceName = "Defias Trapper",
                zone = "Westfall",
            })

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 2)
            env.GrimCharacterState.recentDeaths = { incomingDeath }
            GrimMainFrame:RefreshDeaths()

            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "incoming deaths should keep the waiting prompt visible until the minimum duration completes")
            assert.equals("..", GrimMainFrame.waitingPromptDots:GetText(), "incoming deaths should preserve the current waiting animation state")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "incoming deaths should stay hidden while the waiting prompt minimum duration is still active")
            assert.equals("Defias Trapper", GrimMainFrame.deathRows[1].sourceName:GetText(), "incoming deaths should populate hidden rows while waiting")

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS - 3)
            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "incoming deaths should still wait until the minimum duration before revealing the log")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "incoming deaths should remain hidden before the minimum duration completes")
            assert.equals("Defias Trapper", GrimMainFrame.deathRows[1].sourceName:GetText(), "waiting rows should keep populated death data before reveal")
            assert.equals(false, GrimMainFrame.waitingPromptHelpText:IsShown(), "incoming deaths should not show the no-deaths help prompt while a death is already ready")

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 1)
            assert.equals(false, GrimMainFrame.waitingPromptText:IsShown(), "incoming deaths should stop the waiting prompt after the minimum duration")
            assert.equals(false, GrimMainFrame.waitingPromptDots:IsShown(), "incoming deaths should hide the animated dots after the minimum duration")
            assert.equals(false, GrimMainFrame.waitingPromptHelpText:IsShown(), "incoming deaths should keep the no-deaths help prompt hidden once the death log appears")
            assert.equals(true, GrimMainFrame.deathRows[1]:IsShown(), "incoming deaths should appear once the waiting prompt minimum duration completes")
            assert.equals("Defias Trapper", GrimMainFrame.deathRows[1].sourceName:GetText(), "incoming deaths should render after the waiting prompt minimum duration completes")
        end)

        it("uses timestamps to break equal-score history ties", function()
            local context = createUIContext(Fixtures.uiDatabase({
                deathHistory = {},
                successfullyPredictedDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 300,
                        name = "Laterdeath",
                        level = 12,
                        sourceName = "Later Source",
                        zone = "Elwynn Forest",
                        prediction = {
                            elements = {
                                levelRange = "10-19",
                            },
                            lockedAt = 200,
                        },
                        predictionStreak = 1,
                    }),
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Earlierdeath",
                        level = 12,
                        sourceName = "Earlier Source",
                        zone = "Elwynn Forest",
                        prediction = {
                            elements = {
                                levelRange = "10-19",
                            },
                            lockedAt = 50,
                        },
                        predictionStreak = 1,
                    }),
                },
            }))
            local GrimLog = context.GrimLog

            GrimLog.showSuccessfulOnly = true
            GrimLog:RefreshHistory()

            assert.equals("Successful Predictions", GrimLog.logSubtitle:GetText(), "success-only refresh should keep the success subtitle")
            assert.equals("SHOW ALL", GrimLog.filterButton:GetText(), "success-only refresh should offer the all-history action")
            assert.equals("Rank", GrimLog.columnHeaders.time:GetText(), "success-only refresh should relabel the first column as rank")
            assert.equals(nil, GrimLog.columnHeaders.level, "success-only refresh should omit the level column")
            assert.equals("#1", GrimLog.rows[1].time:GetText(), "success-only refresh should show the first visible row as rank one")
            assert.equals("#2", GrimLog.rows[2].time:GetText(), "success-only refresh should show the second visible row as rank two")
            assert.equals("Later Source", GrimLog.rows[1].sourceName:GetText(), "success-only refresh should show the later equal-score death source first after reverse rendering")
            assert.equals(nil, GrimLog.rows[1].level, "success-only refresh should not create level cells")
            assert.equals("Earlier Source", GrimLog.rows[2].sourceName:GetText(), "success-only refresh should place the earlier equal-score death source underneath after reverse rendering")
        end)
    end)

    describe("controls and game-info callouts", function()
        it("handles prediction buttons", function()
            local context = createUIContext({})
            local GrimMainFrame = context.GrimMainFrame
            local GrimUI = context.GrimUI
            local findDropdownButtonByText = context.findDropdownButtonByText
            local targetZone, targetZoneInput = getAutocompleteTargetValue(context.GrimUIAutocomplete.ZoneList)

            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "lock button should start disabled with no prediction")
            GrimMainFrame.levelRangeButtons[2]:GetScript("OnClick")(GrimMainFrame.levelRangeButtons[2])
            assert.is_truthy(GrimMainFrame.lockButton:IsEnabled(), "selecting a level range should enable the lock button")

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("hog")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "typing in source should show the suggestion dropdown")
            assert.equals("Hogger", GrimMainFrame.dropdown.buttons[1].text:GetText(), "source dropdown should show the matching source")
            GrimMainFrame.dropdown.buttons[1]:GetScript("OnClick")()
            assert.equals("Hogger", GrimMainFrame.sourceEditBox:GetText(), "clicking a source suggestion should fill the source edit box")
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "clicking a source suggestion should hide the dropdown")
            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("a")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "broad source input should still show suggestions")
            GrimMainFrame.sourceEditBox:SetText("def")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            local defiasButton = findDropdownButtonByText(GrimMainFrame.dropdown, "Defias Trapper")
            assert.is_truthy(defiasButton, "Defias Trapper suggestion should be present in the source dropdown")
            ---@diagnostic disable-next-line: need-check-nil
            defiasButton:GetScript("OnClick")()
            assert.equals("Defias Trapper", GrimMainFrame.sourceEditBox:GetText(), "clicking a source suggestion should still fill the source edit box")

            GrimMainFrame.zoneEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.zoneEditBox)
            GrimMainFrame.zoneEditBox:SetText(targetZoneInput)
            GrimMainFrame.zoneEditBox:GetScript("OnTextChanged")(GrimMainFrame.zoneEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "typing in zone should show the suggestion dropdown")
            local zoneButton = findDropdownButtonByText(GrimMainFrame.dropdown, targetZone)
            assert.is_truthy(zoneButton, "zone dropdown should include the matching zone")
            ---@diagnostic disable-next-line: need-check-nil
            zoneButton:GetScript("OnClick")()
            assert.equals(targetZone, GrimMainFrame.zoneEditBox:GetText(), "clicking a zone suggestion should fill the zone edit box")
            GrimMainFrame.lockButton:GetScript("OnClick")()
            assert.is_truthy(env.GrimCharacterState.lockedPrediction, "locking in should save the prediction")
            assert.equals("10-19", env.GrimCharacterState.lockedPrediction.elements.levelRange, "locking in should store the selected level range")
            assert.equals("defias trapper", env.GrimCharacterState.lockedPrediction.elements.source, "locking in should store the normalized source")
            assert.equals(targetZoneInput, env.GrimCharacterState.lockedPrediction.elements.zone, "locking in should store the normalized zone")
            assert.equals(24680, env.GrimCharacterState.lockedPrediction.lockedAt, "locking in should use the current timestamp")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "locking in should gray out the lock button")
            assert.equals("LOCKED IN", GrimMainFrame.lockButton:GetText(), "locking in should rename the lock button")
            assert.equals(true, GrimMainFrame.bottomLogButton:IsEnabled(), "locking in should enable the log button after first run completes")
            assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "locking in should make the source edit box uneditable")
            assert.equals(false, GrimMainFrame.zoneEditBox:IsEnabled(), "locking in should make the zone edit box uneditable")
            assert.equals(
                GrimUI.COLORS.predictionInputLocked[1],
                GrimMainFrame.sourceEditBox.textColor[1],
                "locking in should gray out the source text"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputLocked[2],
                GrimMainFrame.sourceEditBox.textColor[2],
                "locking in should gray out the source text color channels"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputLocked[1],
                GrimMainFrame.zoneEditBox.textColor[1],
                "locking in should gray out the location text"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputLocked[2],
                GrimMainFrame.zoneEditBox.textColor[2],
                "locking in should gray out the location text color channels"
            )
            assert.is_truthy(GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "locking in should keep the selected level range visually active")
            assert.equals(false, GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "locking in should make other level range buttons unchangeable")
            assert.is_truthy(GrimMainFrame.pauseButton:IsEnabled(), "pause button should enable after locking in")

            GrimMainFrame.pauseButton:GetScript("OnClick")()
            assert.equals(nil, env.GrimCharacterState.lockedPrediction, "pause should clear the locked prediction")
            assert.equals("Defias Trapper", GrimMainFrame.sourceEditBox:GetText(), "pause should preserve the source edit box value")
            assert.equals(targetZone, GrimMainFrame.zoneEditBox:GetText(), "pause should preserve the zone edit box value")
            assert.is_truthy(GrimMainFrame.sourceEditBox:IsEnabled(), "pause should make the source edit box editable again")
            assert.is_truthy(GrimMainFrame.zoneEditBox:IsEnabled(), "pause should make the zone edit box editable again")
            assert.equals(
                GrimUI.COLORS.predictionInputActive[1],
                GrimMainFrame.sourceEditBox.textColor[1],
                "pause should restore the source text color"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputActive[2],
                GrimMainFrame.sourceEditBox.textColor[2],
                "pause should restore the source text color channels"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputActive[1],
                GrimMainFrame.zoneEditBox.textColor[1],
                "pause should restore the location text color"
            )
            assert.equals(
                GrimUI.COLORS.predictionInputActive[2],
                GrimMainFrame.zoneEditBox.textColor[2],
                "pause should restore the location text color channels"
            )
            assert.equals(false, GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "pause should keep the selected level button as the current selection")
            assert.is_truthy(GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "pause should make other level range buttons usable again")
            assert.equals(false, GrimMainFrame.pauseButton:IsEnabled(), "pause button should disable after clearing the prediction")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "pause should restore the lock button label")
            env.GrimCharacterState.correctPredictionStreak = 4
            GrimMainFrame.sourceEditBox:SetText("Hogger")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            GrimMainFrame.lockButton:GetScript("OnClick")()
            assert.equals(0, env.GrimCharacterState.correctPredictionStreak, "locking in a different prediction should reset the streak")
        end)

        it("shows expected text for prediction controls", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local noneLevelPointsText = "0 points"
            local levelPointsText = tostring(GrimLogic.GetLevelPointsForRange("10-19")) .. " points"
            local sourcePointsText = tostring(SCORE_RULES.fixedElementPoints.source) .. " points"
            local zonePointsText = tostring(SCORE_RULES.fixedElementPoints.zone) .. " points"
            GrimMainFrame:Show()

            assert.equals(
                true,
                GrimMainFrame.levelRangeButtons[1]:GetMotionScriptsWhileDisabled(),
                "level range buttons should show tooltip motion scripts while disabled"
            )
            assert.equals(
                noneLevelPointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.levelRangeButtons[1]),
                "hovering the none level range should show zero points"
            )
            leaveRegion(GrimMainFrame.levelRangeButtons[1])
            assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "leaving the none level range button should hide the game info callout")

            assert.equals(
                levelPointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.levelRangeButtons[2]),
                "hovering the first level range should show its points"
            )
            leaveRegion(GrimMainFrame.levelRangeButtons[2])
            assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "leaving a level range button should hide the game info callout")

            assert.equals(
                sourcePointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.sourceEditBox),
                "hovering the source input should show source points"
            )
            leaveRegion(GrimMainFrame.sourceEditBox)

            assert.equals(
                sourcePointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.sourceLabel),
                "hovering the source label should show source points"
            )
            leaveRegion(GrimMainFrame.sourceLabel)

            assert.equals(
                zonePointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.zoneEditBox),
                "hovering the zone input should show zone points"
            )
            leaveRegion(GrimMainFrame.zoneEditBox)

            assert.equals(
                zonePointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.zoneLabel),
                "hovering the zone label should show zone points"
            )
            leaveRegion(GrimMainFrame.zoneLabel)
        end)

        it("anchors the current prediction summary below location", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local layout = context.GrimUI.LAYOUT

            local titlePoint, titleRelativeTo, titleRelativePoint, titleXOffset, titleYOffset = GrimMainFrame.currentPredictionLabel:GetPoint(1)
            assert.equals("TOPLEFT", titlePoint, "current prediction label should anchor from its top left")
            assert.equals(GrimMainFrame, titleRelativeTo, "current prediction label should anchor to the main frame")
            assert.equals("TOPLEFT", titleRelativePoint, "current prediction label should use the main frame origin")
            assert.equals(layout.predictionLabelX, titleXOffset, "current prediction label should keep the label column alignment")
            assert.equals(
                layout.predictionZoneRowY + (layout.predictionZoneRowY - layout.predictionSourceRowY),
                titleYOffset,
                "current prediction label should keep the same absolute row position"
            )

            local valuePoint, valueRelativeTo, valueRelativePoint, valueXOffset, valueYOffset = GrimMainFrame.lockedPredictionValue:GetPoint(1)
            assert.equals("TOPLEFT", valuePoint, "current prediction text should anchor from its top left")
            assert.equals(GrimMainFrame.currentPredictionLabel, valueRelativeTo, "current prediction text should anchor below its label")
            assert.equals("BOTTOMLEFT", valueRelativePoint, "current prediction text should align to the label's bottom left")
            assert.equals(0, valueXOffset, "current prediction text should stay left aligned with its label")
            assert.equals(-6, valueYOffset, "current prediction text should preserve the existing label-to-text spacing")

            assert.equals(nil, GrimMainFrame.currentPredictionBonusSummary, "main frame should not show a visible bonus multiplier summary")
        end)

        it("shows expected text for labels and bottom buttons", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            GrimMainFrame:Show()

            local helpText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.helpButton)
            assert.is_string(helpText, "hovering help should show help-oriented callout text")
            assert.matches("information", helpText, 1, true, "hovering help should show help-oriented callout text")
            leaveRegion(GrimMainFrame.helpButton)

            local logText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.bottomLogButton)
            assert.is_string(logText, "hovering log should show log-oriented callout text")
            assert.matches("log", logText, 1, true, "hovering log should show log-oriented callout text")
            leaveRegion(GrimMainFrame.bottomLogButton)

            local pauseText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.pauseButton)
            assert.is_string(pauseText, "hovering pause should show pause-oriented callout text")
            assert.matches("Pause", pauseText, 1, true, "hovering pause should show pause-oriented callout text")
            leaveRegion(GrimMainFrame.pauseButton)

            local lockText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.lockButton)
            assert.is_string(lockText, "hovering lock in should show lock-action callout text")
            assert.matches("game", lockText, 1, true, "hovering lock in should show lock-action callout text")
            leaveRegion(GrimMainFrame.lockButton)

            local currentPredictionLabelText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.currentPredictionLabel)
            assert.is_string(currentPredictionLabelText, "hovering the current prediction label should show the bonus multipliers callout")
            assert.matches(
                "Bonus Multipliers",
                currentPredictionLabelText,
                1,
                true,
                "hovering the current prediction label should show the bonus multipliers callout"
            )
            assert.equals(1, #GrimMainFrame.gameInfoCallout.lines, "empty current prediction hover should only show the title line")
            leaveRegion(GrimMainFrame.currentPredictionLabel)

            local currentPredictionValueText = hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.lockedPredictionValue)
            assert.is_string(currentPredictionValueText, "hovering the current prediction text should show the bonus multipliers callout")
            assert.matches(
                "Bonus Multipliers",
                currentPredictionValueText,
                1,
                true,
                "hovering the current prediction text should show the bonus multipliers callout"
            )
            assert.equals(1, #GrimMainFrame.gameInfoCallout.lines, "empty current prediction text hover should only show the title line")
            leaveRegion(GrimMainFrame.lockedPredictionValue)
        end)

        it("uses draft and locked predictions for hover payout previews", function()
            local context = createUIContext(Fixtures.uiDatabase({
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }))
            local GrimMainFrame = context.GrimMainFrame
            GrimMainFrame:Show()

            GrimMainFrame.levelRangeButtons[2]:GetScript("OnClick")(GrimMainFrame.levelRangeButtons[2])
            GrimMainFrame.sourceEditBox:SetText("Benny")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            GrimMainFrame.zoneEditBox:SetText("Westfall")
            GrimMainFrame.zoneEditBox:GetScript("OnTextChanged")(GrimMainFrame.zoneEditBox, true)
            local expectedDraftRows = GrimLogic.GetPredictionPayoutPreviewRows(Fixtures.prediction({
                levelRange = "10-19",
                source = "benny",
                zone = "westfall",
            }))

            hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.currentPredictionLabel)
            assert.equals(8, #GrimMainFrame.gameInfoCallout.lines, "draft prediction hover should show the title plus every possible payout row")
            assert.equals(expectedDraftRows[1].text, GrimMainFrame.gameInfoCallout.lines[2].left, "draft hover should show the level-only payout")
            assert.equals(expectedDraftRows[2].text, GrimMainFrame.gameInfoCallout.lines[3].left, "draft hover should show the source-only payout")
            assert.equals(expectedDraftRows[3].text, GrimMainFrame.gameInfoCallout.lines[4].left, "draft hover should show the zone-only payout")
            assert.equals(expectedDraftRows[4].text, GrimMainFrame.gameInfoCallout.lines[5].left, "draft hover should show the level-plus-source payout")
            assert.equals(expectedDraftRows[5].text, GrimMainFrame.gameInfoCallout.lines[6].left, "draft hover should show the level-plus-zone payout")
            assert.equals(expectedDraftRows[6].text, GrimMainFrame.gameInfoCallout.lines[7].left, "draft hover should show the source-plus-zone payout")
            assert.equals(expectedDraftRows[7].text, GrimMainFrame.gameInfoCallout.lines[8].left, "draft hover should show the full-match payout")
            leaveRegion(GrimMainFrame.currentPredictionLabel)

            env.GrimCharacterState.lockedPrediction = Fixtures.prediction({
                levelRange = "20-29",
                source = false,
                zone = false,
            })
            env.GrimCharacterState.draftPrediction = Fixtures.prediction({
                levelRange = false,
                source = "benny",
                zone = "westfall",
            })
            local expectedLockedRows = GrimLogic.GetPredictionPayoutPreviewRows(env.GrimCharacterState.lockedPrediction)
            GrimMainFrame:RefreshLockedPrediction()

            hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.lockedPredictionValue)
            assert.equals(2, #GrimMainFrame.gameInfoCallout.lines, "locked prediction hover should override the draft and show only its possible payout rows")
            assert.equals(expectedLockedRows[1].text, GrimMainFrame.gameInfoCallout.lines[2].left, "locked prediction hover should use the locked payout preview")
            leaveRegion(GrimMainFrame.lockedPredictionValue)
        end)

        it("supports intro demo and hides with the window", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local sourcePointsText = tostring(SCORE_RULES.fixedElementPoints.source) .. " points"

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()

            assert.equals(
                sourcePointsText,
                hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.sourceEditBox),
                "intro demo hover should keep the same source points text"
            )

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "collapsing the window should hide the game info callout")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            hoverRegionAndWaitForGameInfoCallout(GrimMainFrame, GrimMainFrame.lockButton)

            GrimMainFrame:Hide()
            assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "hiding the main window should hide the game info callout")
        end)
    end)

    describe("log rendering and cache behavior", function()
        it("shows only total points for zero-score deaths", function()
            local context = createUIContext(Fixtures.uiDatabase({
                totalPoints = 0,
                recentDeaths = {
                    Fixtures.storedDeath({
                        points = 0,
                        multiplierValue = 0,
                        awardedPoints = 0,
                        matchedPrediction = false,
                        prediction = false,
                        predictionStreak = false,
                    }),
                },
                deathHistory = {},
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshCollapsedSummary(env.GrimCharacterState.recentDeaths[1])

            assert.equals(nil, GrimMainFrame.deathRows[1].pointsTooltipTarget, "recent death rows should omit the removed base points hover target")
            assert.equals(nil, GrimMainFrame.deathRows[1].multiplier, "recent death rows should omit the removed combo column")
            assert.equals(nil, GrimMainFrame.deathRows[1].streakMultiplier, "recent death rows should omit the removed streak column")
            assert.equals("0", GrimMainFrame.deathRows[1].awardedPoints:GetText(), "recent death rows should show zero total points in the points column")
            assert.equals("Hogger", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "collapsed death log should still render zero-score deaths")
            assert.equals("0", GrimMainFrame.collapsedPointsValue:GetText(), "collapsed score should still show zero totals")

            assert.equals(nil, GrimMainFrame.deathRows[1]:GetScript("OnEnter"), "zero-score recent death rows should still avoid whole-row tooltips")
            hoverDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")
            do
                local streakIndex = findTooltipLineIndex("Streak:")
                local sameZoneIndex = findTooltipLineIndex("Same zone:")
                local totalIndex = findTooltipLineIndex("Total:")
                local scoreIndex = findTooltipLineIndex("Score:")
                assert.is_nil(sameZoneIndex, "zero-score tooltip should omit the same-zone row when there is no bonus")
                assert.is_nil(streakIndex, "zero-score tooltip should omit the streak row when there is no streak bonus")
                assert.is_nil(totalIndex, "zero-score tooltip should omit the total row")
                assert.is_not_nil(scoreIndex, "zero-score tooltip should include the score row")
                if scoreIndex ~= nil then
                    assert.equals("0", env.GameTooltip.lines[scoreIndex].right, "zero-score tooltip should collapse the score formula to the awarded points when the multiplier is zero")
                end
            end
            leaveDeathLogCell(GrimMainFrame.deathRows[1], "awardedPoints")
        end)

        it("places newest collapsed death rows at the bottom", function()
            local context = createUIContext(Fixtures.uiDatabase({
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 90,
                        name = "Alamo",
                        level = 11,
                        sourceName = "Defias",
                        zone = "Westfall",
                        matchedPrediction = false,
                        prediction = false,
                        predictionStreak = false,
                        points = 0,
                        multiplierValue = 0,
                        awardedPoints = 0,
                    }),
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Drakedog",
                        level = 12,
                        sourceName = "Hogger",
                        zone = "Elwynn Forest",
                    }),
                },
                deathHistory = {},
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshCollapsedSummary()

            assert.equals("Defias", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "collapsed death log should keep older recent deaths above newer ones")
            assert.equals("Hogger", GrimMainFrame.collapsedLogFrame.rows[2].sourceName:GetText(), "collapsed death log should keep the newest stored recent death at the bottom")
        end)

        it("supports custom columns in flexible death logs", function()
            local context = createUIContext()

            local flexibleLog = env.CreateFrame("Frame", nil, env.UIParent)
            local customColumns = {
                { key = "name", label = "Name", x = 8, width = 80 },
                { key = "awardedPoints", label = "Total", x = 96, width = 40 },
            }
            local newestDeath = Fixtures.storedDeath({
                timestamp = 200,
                name = "Greymist",
                awardedPoints = 7,
                points = 7,
                multiplierValue = 1,
            })
            local olderDeath = Fixtures.storedDeath({
                timestamp = 150,
                name = "Alamo",
                awardedPoints = 0,
                points = 0,
                multiplierValue = 0,
                matchedPrediction = false,
                prediction = false,
                predictionStreak = false,
            })

            context.GrimUIDeathLogList.CreateDeathLogList(flexibleLog, {
                columns = customColumns,
                rowCount = 2,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = {
                    showPredictionString = true,
                    showIdentity = true,
                    showFullCombos = true,
                },
            })
            context.GrimUIDeathLogList.RefreshDeathLogRows(flexibleLog, {
                olderDeath,
                newestDeath,
            }, {
                columns = customColumns,
                reverseOrder = true,
            })

            assert.equals(2, #flexibleLog.rows, "flexible death log should create the requested number of rows")
            assert.equals("Greymist", flexibleLog.rows[1].name:GetText(), "flexible death log should render the newest row first when requested")
            assert.equals(
                tostring(GrimLogic.GetStoredDeathAwardedPoints(newestDeath)),
                flexibleLog.rows[1].awardedPoints:GetText(),
                "flexible death log should render computed column values"
            )
            assert.equals("Alamo", flexibleLog.rows[2].name:GetText(), "flexible death log should continue rendering older rows underneath")

            flexibleLog.rows[1]:GetScript("OnEnter")(flexibleLog.rows[1])
            assert.equals("Level 10-19, source Hogger, or zone Elwynn Forest.", env.GameTooltip.lines[1].left, "flexible death log should reuse the history tooltip behavior")
            assert.is_nil(findTooltipLineIndex("Name:"), "flexible death log should omit the dead player name from the tooltip")
            assert.equals("Level:", env.GameTooltip.lines[2].left, "flexible death log should reuse identity rows in the tooltip")
            flexibleLog.rows[1]:GetScript("OnLeave")()
            assert.equals(false, env.GameTooltip.visible, "leaving a flexible death log row should hide the tooltip")
        end)

        it("supports forward ordering and clears unused death-log rows", function()
            local context = createUIContext()

            local flexibleLog = env.CreateFrame("Frame", nil, env.UIParent)
            local customColumns = {
                { key = "name", label = "Name", x = 0, width = 80 },
                { key = "level", label = "Level", x = 84, width = 24 },
            }

            context.GrimUIDeathLogList.CreateDeathLogList(flexibleLog, {
                columns = customColumns,
                rowCount = 3,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = context.GrimUITooltip.MAIN_LOG_TOOLTIP_OPTIONS,
            })

            local deaths = {
                Fixtures.storedDeath({
                    timestamp = 10,
                    name = "Firstdeath",
                    level = 10,
                }),
                Fixtures.storedDeath({
                    timestamp = 20,
                    name = "Seconddeath",
                    level = 20,
                }),
                Fixtures.storedDeath({
                    timestamp = 30,
                    name = "Thirddeath",
                    level = 30,
                }),
            }

            context.GrimUIDeathLogList.RefreshDeathLogRows(flexibleLog, deaths, {
                columns = customColumns,
                offset = 1,
                reverseOrder = false,
            })

            assert.equals("Seconddeath", flexibleLog.rows[1].name:GetText(), "forward-ordered log should honor the provided offset")
            assert.equals("Thirddeath", flexibleLog.rows[2].name:GetText(), "forward-ordered log should continue into later rows")
            assert.equals(false, flexibleLog.rows[3]:IsShown(), "forward-ordered log should hide rows with no matching death")
            assert.equals("", flexibleLog.rows[3].name:GetText(), "forward-ordered log should clear text from unused rows")
        end)

        it("switches tooltip contexts for death-log lists", function()
            local context = createUIContext()

            local customColumns = {
                { key = "name", label = "Name", x = 0, width = 80 },
                { key = "sourceName", label = "Source", x = 84, width = 80 },
                { key = "awardedPoints", label = "Total", x = 168, width = 36 },
            }
            local death = Fixtures.storedDeath()

            local mainLog = env.CreateFrame("Frame", nil, env.UIParent)
            context.GrimUIDeathLogList.CreateDeathLogList(mainLog, {
                columns = customColumns,
                rowCount = 1,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = context.GrimUITooltip.MAIN_LOG_TOOLTIP_OPTIONS,
            })
            context.GrimUIDeathLogList.RefreshDeathLogRows(mainLog, {
                death,
            }, {
                columns = customColumns,
                reverseOrder = false,
            })

            assert.equals(nil, mainLog.rows[1]:GetScript("OnEnter"), "main log tooltip options should disable whole-row hover when metric-only targets are enabled")
            hoverDeathLogCell(mainLog.rows[1], "awardedPoints")
            assert.equals("Base points:", env.GameTooltip.lines[1].left, "main log tooltip options should start with scoring rows in compact mode")
            assert.is_nil(findTooltipLineIndex("Name:"), "main log tooltip options should omit identity rows in compact mode")
            assert.is_nil(findTooltipLineIndex("Level 10-19, source Hogger, or zone Elwynn Forest."), "main log tooltip options should omit prediction text in compact mode")
            leaveDeathLogCell(mainLog.rows[1], "awardedPoints")

            local logWindowLog = env.CreateFrame("Frame", nil, env.UIParent)
            context.GrimUIDeathLogList.CreateDeathLogList(logWindowLog, {
                columns = customColumns,
                rowCount = 1,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = context.GrimUITooltip.LOG_WINDOW_TOOLTIP_OPTIONS,
            })
            context.GrimUIDeathLogList.RefreshDeathLogRows(logWindowLog, {
                death,
            }, {
                columns = customColumns,
                reverseOrder = false,
            })

            assert.equals(nil, logWindowLog.rows[1]:GetScript("OnEnter"), "log window tooltip options should disable whole-row hover when points-only targets are enabled")
            assertNoDeathLogCellTooltipTarget(logWindowLog.rows[1], "name", "log window tooltip options should not create a name-column tooltip target")
            hoverDeathLogCell(logWindowLog.rows[1], "awardedPoints")
            assert.equals("Level 10-19, source Hogger, or zone Elwynn Forest.", env.GameTooltip.lines[1].left, "log window tooltip options should start with the prediction text")
            assert.is_nil(findTooltipLineIndex("Name:"), "log window tooltip options should omit the dead player name")
            assert.equals("Level:", env.GameTooltip.lines[2].left, "log window tooltip options should include level before base points")
            leaveDeathLogCell(logWindowLog.rows[1], "awardedPoints")

            local collapsedStyleLog = env.CreateFrame("Frame", nil, env.UIParent)
            context.GrimUIDeathLogList.CreateDeathLogList(collapsedStyleLog, {
                columns = customColumns,
                rowCount = 1,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = context.GrimUITooltip.COLLAPSED_LOG_TOOLTIP_OPTIONS,
            })
            context.GrimUIDeathLogList.RefreshDeathLogRows(collapsedStyleLog, {
                death,
            }, {
                columns = customColumns,
                reverseOrder = false,
            })

            assert.equals(nil, collapsedStyleLog.rows[1]:GetScript("OnEnter"), "collapsed log tooltip options should disable whole-row hover when points-only targets are enabled")
            assertNoDeathLogCellTooltipTarget(collapsedStyleLog.rows[1], "name", "collapsed log tooltip options should not create a name-column tooltip target")
            assertNoDeathLogCellTooltipTarget(collapsedStyleLog.rows[1], "sourceName", "collapsed log tooltip options should not create a source-column tooltip target")
            hoverDeathLogCell(collapsedStyleLog.rows[1], "awardedPoints")
            assert.equals("Base points:", env.GameTooltip.lines[1].left, "collapsed log tooltip options should start with scoring rows in compact mode")
            assert.is_nil(findTooltipLineIndex("Name:"), "collapsed log tooltip options should omit identity rows in compact mode")
            assert.is_nil(findTooltipLineIndex("Level 10-19, source Hogger, or zone Elwynn Forest."), "collapsed log tooltip options should omit prediction text in compact mode")
            leaveDeathLogCell(collapsedStyleLog.rows[1], "awardedPoints")

            local historyStyleLog = env.CreateFrame("Frame", nil, env.UIParent)
            context.GrimUIDeathLogList.CreateDeathLogList(historyStyleLog, {
                columns = customColumns,
                rowCount = 1,
                rowHeight = 18,
                rowLeft = 0,
                rowTop = 0,
                rowRight = 0,
                tooltipOptions = {
                    showPredictionString = true,
                    showIdentity = true,
                    showFullCombos = true,
                },
            })
            context.GrimUIDeathLogList.RefreshDeathLogRows(historyStyleLog, {
                death,
            }, {
                columns = customColumns,
                reverseOrder = false,
            })

            assert.is_function(historyStyleLog.rows[1]:GetScript("OnEnter"), "history tooltip options should keep whole-row hover enabled")
            assertNoDeathLogCellTooltipTarget(historyStyleLog.rows[1], "awardedPoints", "history tooltip options should not create a points-column tooltip target")
            historyStyleLog.rows[1]:GetScript("OnEnter")(historyStyleLog.rows[1])
            assert.equals("Level 10-19, source Hogger, or zone Elwynn Forest.", env.GameTooltip.lines[1].left, "history tooltip options should start with the prediction text")
            assert.is_nil(findTooltipLineIndex("Name:"), "history tooltip options should omit the dead player name")
            assert.equals("Level:", env.GameTooltip.lines[2].left, "history tooltip options should still include level before base points")
            historyStyleLog.rows[1]:GetScript("OnLeave")()
        end)

        it("reuses death-log display caches across refreshes", function()
            local recentOlder = Fixtures.storedDeath({
                timestamp = 100,
                name = "Recentolder",
            })
            local recentNewer = Fixtures.storedDeath({
                timestamp = 200,
                name = "Recentnewer",
            })
            local historyOnly = Fixtures.storedDeath({
                timestamp = 90,
                name = "Historyonly",
                matchedPrediction = false,
                prediction = false,
                predictionStreak = false,
                points = 0,
                awardedPoints = 0,
            })
            local sharedSuccess = Fixtures.storedDeath({
                timestamp = 300,
                name = "Sharedsuccess",
            })
            local context = createUIContext(Fixtures.uiDatabase({
                recentDeaths = {
                    recentOlder,
                    recentNewer,
                },
                deathHistory = {
                    historyOnly,
                    sharedSuccess,
                },
                successfullyPredictedDeaths = {
                    sharedSuccess,
                },
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog
            local displayCache = GrimMainFrame.displayCache

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshCollapsedSummary()
            GrimLog.showSuccessfulOnly = false
            GrimLog:RefreshHistory()
            GrimLog.showSuccessfulOnly = true
            GrimLog:RefreshHistory()

            local recentViewEntries = displayCache.recentView.orderedEntries
            local historyViewEntries = displayCache.historyView.orderedEntries
            local successfulViewEntries = displayCache.successfulView.orderedEntries
            local recentOlderEntry = displayCache.entriesByDeath[recentOlder]
            local sharedSuccessEntry = displayCache.entriesByDeath[sharedSuccess]
            local historyOnlyEntry = displayCache.entriesByDeath[historyOnly]

            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshCollapsedSummary()
            GrimLog.showSuccessfulOnly = false
            GrimLog:RefreshHistory()
            GrimLog.showSuccessfulOnly = true
            GrimLog:RefreshHistory()

            assert.equals(recentViewEntries, displayCache.recentView.orderedEntries, "recent log should reuse the cached ordered entries on repeated refresh")
            assert.equals(historyViewEntries, displayCache.historyView.orderedEntries, "all-history log should reuse the cached ordered entries on repeated refresh")
            assert.equals(successfulViewEntries, displayCache.successfulView.orderedEntries, "success-only log should reuse the cached ordered entries on repeated refresh")
            assert.equals(recentOlderEntry, displayCache.entriesByDeath[recentOlder], "recent log should reuse the cached shared entry for existing deaths")
            assert.equals(sharedSuccessEntry, displayCache.entriesByDeath[sharedSuccess], "success-only log should reuse the cached shared entry for existing deaths")
            assert.equals(historyOnlyEntry, displayCache.entriesByDeath[historyOnly], "all-history log should reuse the cached shared entry for existing deaths")
        end)

        it("keeps shared death-log entries cached for the session", function()
            local recentRemoved = Fixtures.storedDeath({
                timestamp = 100,
                name = "Recentremoved",
            })
            local recentKept = Fixtures.storedDeath({
                timestamp = 200,
                name = "Recentkept",
            })
            local recentNewest = Fixtures.storedDeath({
                timestamp = 300,
                name = "Recentnewest",
            })
            local historyOnly = Fixtures.storedDeath({
                timestamp = 90,
                name = "Historyonly",
                matchedPrediction = false,
                prediction = false,
                predictionStreak = false,
                points = 0,
                awardedPoints = 0,
            })
            local sharedSuccess = Fixtures.storedDeath({
                timestamp = 400,
                name = "Sharedsuccess",
            })
            local context = createUIContext(Fixtures.uiDatabase({
                recentDeaths = {
                    recentRemoved,
                    recentKept,
                },
                deathHistory = {
                    historyOnly,
                    sharedSuccess,
                },
                successfullyPredictedDeaths = {
                    sharedSuccess,
                },
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog
            local displayCache = GrimMainFrame.displayCache

            GrimMainFrame:RefreshDeaths()
            GrimLog.showSuccessfulOnly = false
            GrimLog:RefreshHistory()
            GrimLog.showSuccessfulOnly = true
            GrimLog:RefreshHistory()

            assert.is_not_nil(displayCache.entriesByDeath[recentRemoved], "recent cache should create an entry for the oldest recent death before trimming")
            assert.is_not_nil(displayCache.entriesByDeath[historyOnly], "history cache should create an entry for all-history-only deaths")
            assert.is_not_nil(displayCache.entriesByDeath[sharedSuccess], "history and success views should share the same cached death entry")

            env.GrimCharacterState.recentDeaths = {
                recentKept,
                recentNewest,
            }
            GrimMainFrame:RefreshDeaths()

            assert.is_not_nil(displayCache.entriesByDeath[recentRemoved], "recent cache should keep trimmed entries in the shared session cache")
            assert.is_not_nil(displayCache.entriesByDeath[recentKept], "recent cache should keep entries still visible in the recent log")
            assert.is_not_nil(displayCache.entriesByDeath[recentNewest], "recent cache should add entries appended to the recent log")

            env.GrimCharacterState.deathHistory = {
                sharedSuccess,
            }
            GrimLog.showSuccessfulOnly = false
            GrimLog:RefreshHistory()

            assert.is_not_nil(displayCache.entriesByDeath[historyOnly], "all-history cache should keep removed entries in the shared session cache")
            assert.is_not_nil(displayCache.entriesByDeath[sharedSuccess], "shared success entries should remain cached while the success view still references them")

            env.GrimCharacterState.deathHistory = {}
            GrimLog.showSuccessfulOnly = false
            GrimLog:RefreshHistory()
            assert.is_not_nil(displayCache.entriesByDeath[sharedSuccess], "shared success entries should stay cached even after leaving all-history when success-only still references them")

            env.GrimCharacterState.successfullyPredictedDeaths = {}
            GrimLog.showSuccessfulOnly = true
            GrimLog:RefreshHistory()

            assert.is_not_nil(displayCache.entriesByDeath[sharedSuccess], "shared success entries should stay cached for the rest of the session")
            assert.equals(nil, displayCache.historyView.orderedEntries[1], "all-history view should rebuild from the current source list after removals")
            assert.equals(nil, displayCache.successfulView.orderedEntries[1], "success-only view should rebuild from the current source list after removals")
        end)
    end)
end)
