local assert = require("luassert")
describe("Intro demo", function()
    local UITestContext = require("tests.support_ui_test_context")
    local testContext
    local Fixtures
    local createUIContext
    local formatStoredDeathScore

    before_each(function()
        testContext = UITestContext.Create()
        Fixtures = testContext.Fixtures
        createUIContext = testContext.createUIContext
        formatStoredDeathScore = testContext.formatStoredDeathScore
    end)

    local function getIntroDemoState(GrimMainFrame)
        local introDemoController = GrimMainFrame and GrimMainFrame.introDemoController or nil
        if introDemoController then
            return introDemoController.demoState
        end

        return nil
    end

    local function advanceDemoPlayback(GrimMainFrame)
        GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, 10)
        return getIntroDemoState(GrimMainFrame)
    end

    describe("entry and exit", function()
        it("starts the intro demo from the help button", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            assert.is_not_nil(GrimMainFrame.helpFrame.demoButton, "help frame should create a demo button")
            assert.equals("DEMO", GrimMainFrame.helpFrame.demoButton:GetText(), "help demo button should use the demo label")

            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.logFrame:Show()
            GrimMainFrame.introDemoController:Dismiss()
            GrimMainFrame.helpFrame.demoButton:GetScript("OnClick")()

            assert.is_false(GrimMainFrame.helpFrame:IsShown(), "clicking the help demo button should close the help window")
            assert.is_not_nil(getIntroDemoState(GrimMainFrame), "clicking the help demo button should activate the intro demo mode")
            assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "clicking the help demo button should relabel the lock button to start game")
            assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "clicking the help demo button should restart the scripted demo from zero score")
            assert.is_false(GrimMainFrame.logFrame:IsShown(), "clicking the help demo button should close the log window")
            assert.is_false(GrimMainFrame.helpButton:IsEnabled(), "clicking the help demo button should disable the help button in demo mode")
            assert.is_false(GrimMainFrame.bottomLogButton:IsEnabled(), "clicking the help demo button should disable the log button in demo mode")
        end)

        it("dismisses the intro demo from the lock button", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()

            GrimMainFrame.lockButton:GetScript("OnClick")()

            assert.is_nil(getIntroDemoState(GrimMainFrame), "clicking the end demo lock button should end intro demo mode")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "clicking the end demo lock button should restore the normal lock label")
            assert.is_false(GrimMainFrame.introDemoAttractPanel:IsShown(), "clicking the end demo lock button should hide the marquee panel")
            assert.is_true(GrimMainFrame.helpButton:IsEnabled(), "clicking the end demo lock button should restore help outside demo mode")
            assert.is_false(GrimMainFrame.bottomLogButton:IsEnabled(), "clicking the end demo lock button should keep log locked before first run completes")
        end)

        it("keeps help closed after the demo ends", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.introDemoController:Show()

            assert.is_false(GrimMainFrame.helpFrame:IsShown(), "starting the intro demo should close the help window")

            GrimMainFrame.introDemoController:Dismiss()

            assert.is_false(GrimMainFrame.helpFrame:IsShown(), "ending the intro demo should keep the help window closed")
        end)
    end)

    describe("rendered state", function()
        describe("main-window refresh", function()
            local GrimMainFrame
            local GrimLog

            before_each(function()
                local context = createUIContext(Fixtures.uiDatabase({
                    totalPoints = 17,
                    correctPredictionStreak = 0,
                    longestPredictionStreak = 1,
                    recentDeaths = {
                        Fixtures.storedDeath({
                            timestamp = 100,
                            name = "Realdeath",
                            level = 11,
                            sourceName = "Murloc",
                            points = 0,
                            multiplierValue = 0,
                            awardedPoints = 0,
                            matchedPrediction = false,
                            prediction = false,
                            predictionStreak = false,
                        }),
                    },
                }))
                GrimMainFrame = context.GrimMainFrame
                GrimLog = context.GrimLog

                GrimMainFrame:Show()
                GrimMainFrame.introDemoController:Show()
            end)

            it("closes auxiliary windows", function()
                assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "intro demo should close the help window")
                assert.equals(false, GrimLog:IsShown(), "intro demo should close the log window")
            end)

            it("renders demo score, death, and prediction state", function()
                assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "intro demo should start at zero score before the higher-value hits land")
                assert.equals("0", GrimMainFrame.currentStreakValue:GetText(), "intro demo should start with no active streak")
                assert.equals("0", GrimMainFrame.longestStreakValue:GetText(), "intro demo should start with no completed streak")
                assert.equals(nil, GrimMainFrame.deathRows[1].name, "intro demo should not create the removed name column")
                assert.equals("Skeletal Raider", GrimMainFrame.deathRows[1].sourceName:GetText(), "intro demo should immediately show the first scripted death source")
                assert.equals(nil, GrimMainFrame.deathRows[1].pointsTooltipTarget, "intro demo should omit the removed base points hover target")
                assert.equals("0", GrimMainFrame.deathRows[1].awardedPoints:GetText(), "intro demo should keep the opening miss at zero total points")
                assert.is_string(GrimMainFrame.lockedPredictionValue:GetText(), "intro demo should show the example locked prediction")
                assert.matches(
                    "Level 10-19, source Defias Trapper, or zone Westfall",
                    GrimMainFrame.lockedPredictionValue:GetText(),
                    1,
                    true,
                    "intro demo should show the example locked prediction"
                )
            end)

            it("displays the demo marquee", function()
                assert.equals(true, GrimMainFrame.introDemoAttractPanel:IsShown(), "intro demo should show the arcade marquee panel")
                assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "intro demo should hide the shared notification prompt while demo mode is visible")
                assert.equals(
                    "Welcome to Grim Guesser\nPress START GAME to begin",
                    GrimMainFrame.introDemoAttractPanel.text:GetText(),
                    "intro demo should show the marquee instructions"
                )
            end)

            it("disables normal controls while leaving start enabled", function()
                assert.is_truthy(GrimMainFrame.lockButton:IsEnabled(), "intro demo should keep the lock button enabled for dismissing demo mode")
                assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "intro demo should relabel the lock button as start game")
                assert.equals(false, GrimMainFrame.pauseButton:IsEnabled(), "intro demo should keep the pause button disabled")
                assert.equals(false, GrimMainFrame.levelRangeButtons[1]:IsEnabled(), "intro demo should disable the placeholder level button")
                assert.equals(false, GrimMainFrame.levelRangeButtons[2]:IsEnabled(), "intro demo should disable the active prediction level button")
                assert.equals(false, GrimMainFrame.levelRangeButtons[3]:IsEnabled(), "intro demo should disable inactive prediction level buttons")
                assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "intro demo should disable the source input")
                assert.equals(false, GrimMainFrame.zoneEditBox:IsEnabled(), "intro demo should disable the location input")
                assert.equals(false, GrimMainFrame.helpButton:IsEnabled(), "intro demo should disable the help button")
                assert.equals(false, GrimMainFrame.bottomLogButton:IsEnabled(), "intro demo should disable the log button")
            end)
        end)

        it("uses Horde demo data", function()
            local context = createUIContext(nil, {
                faction = "Horde",
            })
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()

            assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "horde intro demo should start at zero score")
            assert.equals("Twilight Acolyte", GrimMainFrame.deathRows[1].sourceName:GetText(), "horde intro demo should use the horde scripted deaths")
            assert.equals("0", GrimMainFrame.deathRows[1].awardedPoints:GetText(), "horde intro demo should open on a miss before the later streak")
            assert.is_string(GrimMainFrame.lockedPredictionValue:GetText(), "horde intro demo should use the selected horde prediction")
            assert.matches(
                "Level 10-19, source Kolkar Wrangler, or zone The Barrens",
                GrimMainFrame.lockedPredictionValue:GetText(),
                1,
                true,
                "horde intro demo should use the selected horde prediction"
            )
            assert.equals(true, GrimMainFrame.introDemoAttractPanel:IsShown(), "horde intro demo should still show the marquee panel")
        end)

        it("hides the waiting-for-first-death prompt", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.setupFrame:Show()
            GrimMainFrame.waitingPromptText:Show()
            GrimMainFrame.waitingPromptDots:Show()
            GrimMainFrame.waitingPromptHelpText:Show()

            GrimMainFrame.introDemoController:Show()

            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "intro demo should not show the setup window")
            assert.equals(false, GrimMainFrame.waitingPromptText:IsShown(), "intro demo should not show the waiting prompt text")
            assert.equals(false, GrimMainFrame.waitingPromptDots:IsShown(), "intro demo should not show the waiting prompt dots")
            assert.equals(false, GrimMainFrame.waitingPromptHelpText:IsShown(), "intro demo should not show the waiting prompt help text")
        end)
    end)

    describe("playback", function()
        it("advances and loops the scripted playback", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()

            local demoState = advanceDemoPlayback(GrimMainFrame)
            if demoState == nil then
                error("demo playback should return demo state")
            end

            local secondDeath = demoState.recentDeaths[2]
            if secondDeath == nil then
                error("demo playback should append the second scripted death")
            end

            assert.equals("Defias Rogue Wizard", GrimMainFrame.deathRows[2].sourceName:GetText(), "demo playback should append the next scripted death")
            assert.equals(
                formatStoredDeathScore(secondDeath).awardedPoints,
                GrimMainFrame.deathRows[2].awardedPoints:GetText(),
                "demo playback should hit the white-quality prediction on the second death"
            )

            demoState = advanceDemoPlayback(GrimMainFrame)
            if demoState == nil then
                error("demo playback should keep returning demo state")
            end

            local thirdDeath = demoState.recentDeaths[3]
            if thirdDeath == nil then
                error("demo playback should append the third scripted death")
            end

            assert.equals("Wild Grell", GrimMainFrame.deathRows[3].sourceName:GetText(), "demo playback should continue through the static list")
            assert.equals(
                formatStoredDeathScore(thirdDeath).awardedPoints,
                GrimMainFrame.deathRows[3].awardedPoints:GetText(),
                "demo playback should surface the green-quality streak hit"
            )
            assert.equals("2", GrimMainFrame.currentStreakValue:GetText(), "demo playback should update the current streak during consecutive matches")
            assert.equals("2", GrimMainFrame.longestStreakValue:GetText(), "demo playback should raise the longest streak after the early two-hit run")

            assert.equals("Skeletal Raider", GrimMainFrame.deathRows[1].sourceName:GetText(), "demo playback should redisplay the first scripted death after the sequence ends")
        end)
    end)
end)
