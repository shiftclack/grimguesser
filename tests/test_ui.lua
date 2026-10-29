local assert = require("luassert")
describe("UI state and modes", function()
    local UITestContext = require("tests.support_ui_test_context")
    local testContext
    local Fixtures
    local createUIContext
    local env

    before_each(function()
        testContext = UITestContext.Create()
        Fixtures = testContext.Fixtures
        env = nil
        createUIContext = function(...)
            local context = testContext.createUIContext(...)
            env = context.env
            return context
        end
    end)

    local function buildModeDisplayState(options)
        options = options or {}
        return {
            deaths = options.deaths or {},
            lockedPrediction = options.lockedPrediction,
        }
    end

    local function setFakeIntroDemoActive(frame)
        frame.introDemoController = {
            IsActive = function()
                return true
            end,
        }
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

    describe("module surface and formatting", function()
        it("exposes core UI modules", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI

            assert.is_function(context.GrimUIAutocomplete.GetSourceSuggestions, "autocomplete UI should expose source suggestions")
            assert.is_function(context.GrimUIAutocomplete.CreateSuggestionDropdown, "autocomplete UI should expose dropdown creation")
            assert.is_function(GrimUI.SetWindowCollapsed, "UI module should expose SetWindowCollapsed")
            assert.is_function(context.GrimUIDeathLogList.CreateDeathLogList, "death log list UI should expose the flexible list builder")
            assert.is_function(context.GrimUIDeathLogList.RefreshDeathLogRows, "death log list UI should expose the flexible list refresher")
            assert.is_function(context.GrimUIDebug.CreateDebugWindow, "debug UI should expose debug window creation")
            assert.is_function(context.GrimUIDemo.GetIntroDemoPrediction, "demo UI should expose intro prediction data")
            assert.is_function(context.GrimUIHelp.CreateHelpWindow, "help UI should expose help window creation")
            assert.is_function(context.GrimUILog.CreateHistoryWindow, "history UI should expose history window creation")
            assert.is_function(context.GrimUIMain.Initialize, "main UI should expose Initialize")
            assert.is_function(context.GrimUIMainCollapsed.CreateMainCollapsedSection, "collapsed main UI should expose section creation")
            assert.is_function(context.GrimUIMainPrediction.CreateMainPredictionSection, "prediction main UI should expose section creation")
            assert.is_function(context.GrimUIMainRecentDeaths.CreateMainRecentDeathsSection, "recent deaths main UI should expose section creation")
            assert.is_function(context.GrimUIRefresh.AttachRefreshMethods, "refresh UI should expose refresh attachment")
            assert.is_function(context.GrimUITooltip.ShowStandardizedTooltip, "tooltip UI should expose standardized tooltip display")
        end)

        it("exposes stored-death formatting APIs", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI

            assert.is_function(GrimUI.GetStoredDeathTime, "UI module should expose stored death time formatting")
            assert.is_function(GrimUI.GetStoredDeathDate, "UI module should expose stored death date formatting")
            assert.is_function(GrimUI.GetStoredDeathDateTime, "UI module should expose stored death date/time formatting")
        end)

        it("exposes setup APIs", function()
            local context = createUIContext()
            local GrimSetup = context.ns.GrimSetup
            local GrimUISetup = context.ns.GrimUISetup

            assert.is_function(GrimSetup.GetState, "setup controller should expose GetState")
            assert.is_function(GrimSetup.ShouldShowOnMainWindowOpen, "setup controller should expose first-open eligibility")
            assert.is_function(GrimSetup.EnableDeathAnnouncements, "setup controller should expose death announcement action")
            assert.is_function(GrimSetup.JoinHardcoreDeathsChannel, "setup controller should expose channel join action")
            assert.is_function(GrimUISetup.ShowOnMainWindowOpen, "setup UI should expose first-open show behavior")
            assert.is_function(GrimUISetup.Show, "setup UI should expose manual show behavior")
            assert.is_function(GrimUISetup.Refresh, "setup UI should expose refresh behavior")
            assert.is_function(GrimUISetup.CreateWindow, "setup UI should expose setup window creation")
        end)

        it("exposes mode-resolution APIs", function()
            local context = createUIContext()
            local GrimUIMode = context.ns.GrimUIMode

            assert.is_function(GrimUIMode.Resolve, "UI mode resolver should expose Resolve")
            assert.is_function(GrimUIMode.IsDemoMode, "UI mode resolver should expose demo mode predicate")
            assert.is_function(GrimUIMode.IsCollapsedMode, "UI mode resolver should expose collapsed mode predicate")
            assert.is_function(GrimUIMode.IsNormalMode, "UI mode resolver should expose normal mode predicate")
            assert.is_function(GrimUIMode.HasModal, "UI mode resolver should expose modal predicate")
            assert.is_function(GrimUIMode.IsSetupModal, "UI mode resolver should expose setup modal predicate")
            assert.is_function(GrimUIMode.IsHelpModal, "UI mode resolver should expose help modal predicate")
        end)

        it("formats stored death timestamps", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI
            local timestampOnlyDeath = Fixtures.storedDeath({
                timestamp = 12345,
            })

            assert.equals(
                env.date("%H:%M", 12345),
                GrimUI.GetStoredDeathTime(timestampOnlyDeath),
                "stored death time should be derived from the timestamp"
            )
            assert.equals(
                env.date("%B %d, %Y", 12345),
                GrimUI.GetStoredDeathDate(timestampOnlyDeath),
                "stored death date should be derived from the timestamp"
            )
            assert.equals(
                env.date("%B %d, %Y", 12345) .. " " .. env.date("%H:%M", 12345),
                GrimUI.GetStoredDeathDateTime(timestampOnlyDeath),
                "stored death date time should be derived from the timestamp"
            )

            local missingTimestampDeath = Fixtures.storedDeath({
                timestamp = false,
            })
            assert.equals(
                env.date("%H:%M", 0),
                GrimUI.GetStoredDeathTime(missingTimestampDeath),
                "stored death time should display the epoch fallback when the timestamp is missing"
            )
            assert.equals(
                env.date("%B %d, %Y", 0),
                GrimUI.GetStoredDeathDate(missingTimestampDeath),
                "stored death date should display the epoch fallback when the timestamp is missing"
            )
            assert.equals(
                env.date("%B %d, %Y", 0) .. " " .. env.date("%H:%M", 0),
                GrimUI.GetStoredDeathDateTime(missingTimestampDeath),
                "stored death date time should display the epoch fallback when the timestamp is missing"
            )
        end)
    end)

    describe("mode resolution", function()
        it("prioritizes setup", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local GrimUIMode = context.ns.GrimUIMode

            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.setupFrame:Show()
            setFakeIntroDemoActive(GrimMainFrame)

            local mode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)

            assert.equals("demo", mode.mode, "setup should preserve the underlying intro demo mode")
            assert.equals("setup", mode.modal, "setup should take modal priority over help")
            assert.equals(true, GrimUIMode.IsDemoMode(mode), "setup over demo should report demo mode through predicate")
            assert.equals(true, GrimUIMode.HasModal(mode), "setup should report modal state through predicate")
            assert.equals(true, GrimUIMode.IsSetupModal(mode), "setup should report setup modal through predicate")
            assert.equals(false, GrimUIMode.IsHelpModal(mode), "setup should not report help modal through predicate")
            assert.equals(nil, mode.prompt, "setup mode should suppress normal prompts")
            assert.equals(true, mode.inputsLocked, "setup mode should lock prediction inputs")
            assert.equals(true, mode.mainBlocked, "setup mode should block the main window")
            assert.equals(true, mode.showRecentDeathRows, "setup mode should keep expanded death row data visible-ready")
            assert.equals(false, mode.showWaitingHelp, "setup mode should hide waiting help")
        end)

        it("prioritizes intro demo before collapsed state and prompts", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimUI = context.GrimUI
            local GrimUIMode = context.ns.GrimUIMode

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            setFakeIntroDemoActive(GrimMainFrame)

            local mode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)

            assert.equals("demo", mode.mode, "intro demo should take priority over collapsed and first-run prompt state")
            assert.equals(nil, mode.modal, "intro demo without overlay should not report a modal")
            assert.equals(true, GrimUIMode.IsDemoMode(mode), "intro demo should report demo mode through predicate")
            assert.equals(false, GrimUIMode.HasModal(mode), "intro demo should not report modal state through predicate")
            assert.equals(nil, mode.prompt, "intro demo should suppress normal prompts")
            assert.equals(true, mode.inputsLocked, "intro demo should lock prediction inputs")
            assert.equals(false, mode.mainBlocked, "intro demo should keep the main window available for ending the demo")
            assert.equals(true, mode.showRecentDeathRows, "intro demo should show demo death rows")
            assert.equals(false, mode.showWaitingHelp, "intro demo should hide waiting help")
        end)

        it("handles collapsed mode", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local GrimUI = context.GrimUI
            local GrimUIMode = context.ns.GrimUIMode

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)

            local mode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)

            assert.equals("collapsed", mode.mode, "collapsed mode should suppress expanded prompt behavior")
            assert.equals(nil, mode.modal, "collapsed mode should not report a modal")
            assert.equals(true, GrimUIMode.IsCollapsedMode(mode), "collapsed mode should report through predicate")
            assert.equals(false, GrimUIMode.HasModal(mode), "collapsed mode should not report modal state through predicate")
            assert.equals(nil, mode.prompt, "collapsed mode should not show expanded prompts")
            assert.equals(false, mode.inputsLocked, "collapsed mode should inherit unlocked prediction inputs")
            assert.equals(false, mode.mainBlocked, "collapsed mode should not block the main window")
            assert.equals(true, mode.showRecentDeathRows, "collapsed mode should keep expanded death row data visible-ready")
            assert.equals(false, mode.showWaitingHelp, "collapsed mode should hide waiting help")
        end)

        it("resolves the first-run prompt", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimUIMode = context.ns.GrimUIMode

            local firstRunMode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)
            assert.equals("normal", firstRunMode.mode, "first-run prompt should stay in normal mode")
            assert.equals(nil, firstRunMode.modal, "first-run prompt should not report a modal")
            assert.equals(true, GrimUIMode.IsNormalMode(firstRunMode), "first-run prompt should report normal mode through predicate")
            assert.equals(false, GrimUIMode.HasModal(firstRunMode), "first-run prompt should not report modal state through predicate")
            assert.equals("firstRun", firstRunMode.prompt, "normal mode should surface the first-run prompt")
            assert.equals(false, firstRunMode.inputsLocked, "first-run prompt should leave prediction inputs unlocked")
            assert.equals(false, firstRunMode.mainBlocked, "first-run prompt should not block the main window")
            assert.equals(false, firstRunMode.showRecentDeathRows, "first-run prompt should hide expanded death rows")
            assert.equals(false, firstRunMode.showWaitingHelp, "first-run prompt should hide waiting help")
        end)

        it("delays waiting help until its threshold", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimUIMode = context.ns.GrimUIMode
            local waitingMode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)
            assert.equals("normal", waitingMode.mode, "waiting prompt should stay in normal mode")
            assert.equals(nil, waitingMode.modal, "waiting prompt should not report a modal")
            assert.equals("waiting", waitingMode.prompt, "normal mode should surface waiting prompt with no deaths")
            assert.equals(false, waitingMode.inputsLocked, "waiting prompt should leave prediction inputs unlocked")
            assert.equals(false, waitingMode.mainBlocked, "waiting prompt should not block the main window")
            assert.equals(false, waitingMode.showRecentDeathRows, "waiting prompt should hide expanded death rows")
            assert.equals(false, waitingMode.showWaitingHelp, "waiting help should wait for the configured delay")

            GrimMainFrame.waitingPromptDisplayDuration = context.GrimConstants.DEMO.waitingForFirstDeathHelpTextDelaySeconds
            local waitingHelpMode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)
            assert.equals(false, waitingHelpMode.showRecentDeathRows, "waiting help should keep expanded death rows hidden")
            assert.equals(true, waitingHelpMode.showWaitingHelp, "waiting help should show after the configured delay")
        end)

        it("locks inputs and shows rows for a locked prediction", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimUIMode = context.ns.GrimUIMode

            local lockedMode = GrimUIMode.Resolve(
                GrimMainFrame,
                buildModeDisplayState({
                    deaths = {
                        Fixtures.storedDeath(),
                    },
                    lockedPrediction = Fixtures.prediction(),
                }),
                env.GrimCharacterState
            )
            assert.equals("normal", lockedMode.mode, "locked prediction should stay in normal mode")
            assert.equals(nil, lockedMode.modal, "locked prediction should not report a modal")
            assert.equals(nil, lockedMode.prompt, "locked prediction should suppress prompts")
            assert.equals(true, lockedMode.inputsLocked, "locked prediction should lock inputs")
            assert.equals(false, lockedMode.mainBlocked, "locked prediction should not block the main window")
            assert.equals(true, lockedMode.showRecentDeathRows, "normal locked mode should show death rows")
            assert.equals(false, lockedMode.showWaitingHelp, "locked prediction should hide waiting help")
        end)

        it("handles the help modal", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = false,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimUIMode = context.ns.GrimUIMode

            GrimMainFrame.helpFrame:Show()

            local mode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)

            assert.equals("normal", mode.mode, "help should preserve the underlying normal mode")
            assert.equals("help", mode.modal, "help should report the help modal")
            assert.equals(true, GrimUIMode.IsNormalMode(mode), "help should report normal mode through predicate")
            assert.equals(true, GrimUIMode.HasModal(mode), "help should report modal state through predicate")
            assert.equals(true, GrimUIMode.IsHelpModal(mode), "help should report help modal through predicate")
            assert.equals(false, GrimUIMode.IsSetupModal(mode), "help should not report setup modal through predicate")
            assert.equals(nil, mode.prompt, "help modal should suppress normal prompts")
            assert.equals(true, mode.inputsLocked, "help modal should lock prediction inputs")
            assert.equals(true, mode.mainBlocked, "help modal should block the main window")
            assert.equals(true, mode.showRecentDeathRows, "help modal should keep expanded death row data visible-ready")
            assert.equals(false, mode.showWaitingHelp, "help modal should hide waiting help")

            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()

            local githubMode = GrimUIMode.Resolve(GrimMainFrame, buildModeDisplayState(), env.GrimCharacterState)

            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "GitHub link dialog should replace help while it is open")
            assert.equals("normal", githubMode.mode, "GitHub link dialog should preserve the underlying normal mode")
            assert.equals("help", githubMode.modal, "GitHub link dialog should reuse the help modal state")
            assert.equals(
                true,
                GrimUIMode.IsHelpModal(githubMode),
                "GitHub link dialog should report through the help modal predicate"
            )
            assert.equals(true, githubMode.inputsLocked, "GitHub link dialog should lock prediction inputs")
            assert.equals(true, githubMode.mainBlocked, "GitHub link dialog should block the main window")
        end)
    end)

    describe("initialization and restoration", function()
        describe("initialized frame structure", function()
            local context
            local GrimMainFrame
            local GrimDebug
            local GrimLog
            local layout

            before_each(function()
                context = createUIContext()
                GrimMainFrame = context.GrimMainFrame
                GrimDebug = context.GrimDebug
                GrimLog = context.GrimLog
                layout = context.GrimUI.LAYOUT
            end)

            it("returns and sizes top-level frames", function()
                assert.is_truthy(GrimMainFrame, "Initialize should return the main frame")
                assert.is_truthy(GrimDebug, "Initialize should return the debug frame")
                assert.is_truthy(GrimLog, "Initialize should return the history log frame")
                assert.equals(layout.expandedWindowWidth, GrimMainFrame:GetWidth(), "main frame should use the compact expanded width")
                assert.equals(layout.mainWindowHeight, GrimMainFrame:GetHeight(), "main frame should use the reduced expanded height")
                assert.equals(layout.logWindowWidth, GrimLog:GetWidth(), "history log should use the compact log width")
                assert.equals(layout.logWindowHeight, GrimLog:GetHeight(), "history log should use the reduced expanded height")
                assert.equals(GrimMainFrame.frameStrata, GrimLog.frameStrata, "history log should share the main frame strata")
                assert.equals(GrimMainFrame:GetFrameLevel(), GrimLog:GetFrameLevel(), "history log should share the main frame level")
                assert.equals(false, GrimLog.toplevel, "history log should not use special top-level z ordering")
                assert.equals(false, GrimLog:IsShown(), "history log should start hidden by default")
            end)

            it("configures history-window dragging and visibility", function()
                assert.is_truthy(GrimLog.dragHandle, "history log should create a titlebar drag handle")
                assert.equals(
                    layout.titlebarDragLeftInset,
                    select(4, GrimLog.dragHandle:GetPoint(1)),
                    "history log titlebar should use the shared left drag inset"
                )
                assert.equals(
                    -layout.titlebarDragRightInset,
                    select(4, GrimLog.dragHandle:GetPoint(2)),
                    "history log titlebar should use the shared right drag inset"
                )
                assert.equals(
                    layout.titlebarDragHeight,
                    GrimLog.dragHandle:GetHeight(),
                    "history log titlebar should use the shared drag height"
                )
                assert.is_truthy(#GrimMainFrame.deathRows > 0, "main frame should create recent death rows")
                assert.is_truthy(#GrimLog.rows > 0, "log frame should create history rows")
                assert.equals(layout.deathLogRowHeight, GrimLog.logRowHeight, "history log should use compact record spacing")
                assert.equals(layout.deathLogRowHeight, GrimLog.rows[1]:GetHeight(), "history log rows should use compact record spacing")
                assert.is_truthy(GrimLog.filterButton, "log frame should create a history filter button")
                assert.equals("SHOW ALL", GrimLog.filterButton:GetText(), "history filter button should default to the all-history action")
                assert.equals(
                    layout.compactButtonHeight,
                    GrimLog.filterButton:GetHeight(),
                    "history filter should use the compact button height"
                )
                assert.equals(
                    -(layout.outsideGutter + layout.scrollbarInset),
                    select(4, GrimLog.scrollFrame:GetPoint(2)),
                    "history scrollbar should clear the window inlay"
                )
                assert.equals(
                    layout.deathLogHeaderY - layout.deathLogFrameY,
                    layout.logVerticalSpacing,
                    "history log should share the main log vertical spacing"
                )
                assert.equals(
                    layout.historySubtitleY,
                    select(5, GrimLog.logSubtitle:GetPoint(1)),
                    "history subtitle should use the shared subtitle position"
                )
                assert.equals(
                    layout.historyLogHeaderY,
                    select(5, GrimLog.columnHeaders.time:GetPoint(1)),
                    "history column headers should leave room beneath the subtitle"
                )
                assert.equals(
                    layout.historySubtitleHeaderSpacing,
                    select(5, GrimLog.logSubtitle:GetPoint(1)) - select(5, GrimLog.columnHeaders.time:GetPoint(1)),
                    "history subtitle-to-header spacing should include extra breathing room"
                )
                assert.equals(
                    layout.logVerticalSpacing,
                    select(5, GrimLog.columnHeaders.time:GetPoint(1)) - select(5, GrimLog.rows[1]:GetPoint(1)),
                    "history header-to-row spacing should match the main log spacing"
                )
            end)

            it("lays out history rows, headers, and scrollbar", function()
                assert.equals("RIGHT", GrimLog.columnHeaders.awardedPoints.justifyH, "history log should right justify the points header")
                assert.equals("RIGHT", GrimLog.rows[1].awardedPoints.justifyH, "history log should right justify points cells")
                assert.equals(
                    select(4, GrimLog.rows[1]:GetPoint(1)) + select(4, GrimLog.rows[1].awardedPoints:GetPoint(1)),
                    select(4, GrimLog.columnHeaders.awardedPoints:GetPoint(1)),
                    "history log points header should align with the points column"
                )
                assert.equals(
                    layout.logWindowWidth - layout.outsideGutter - layout.historyScrollbarGap - layout.scrollbarInset - 1,
                    select(4, GrimLog.columnHeaders.awardedPoints:GetPoint(1))
                        + GrimLog.columnHeaders.awardedPoints:GetWidth(),
                    "history log points header should leave reduced room for the scrollbar"
                )
                assert.equals(
                    layout.logWindowWidth - layout.outsideGutter - layout.historyScrollbarGap - layout.scrollbarInset - 1,
                    select(4, GrimLog.rows[1]:GetPoint(1))
                        + select(4, GrimLog.rows[1].awardedPoints:GetPoint(1))
                        + GrimLog.rows[1].awardedPoints:GetWidth(),
                    "history log points cells should leave reduced room for the scrollbar"
                )
            end)

            it("exposes main-window child controllers and actions", function()
                assert.is_truthy(GrimMainFrame.helpFrame, "main frame should keep a reference to the help frame")
                assert.is_truthy(GrimMainFrame.githubLinkFrame, "main frame should keep a reference to the GitHub link dialog")
                assert.is_truthy(GrimMainFrame.helpButton, "main frame should keep a reference to the help button")
                assert.is_truthy(GrimMainFrame.helpFrame.backdropOverlay, "help window should create a main-window backdrop overlay")
                assert.is_truthy(GrimMainFrame.helpFrame.titlebarDragHandle, "help window should create a titlebar drag handle")
                assert.is_truthy(GrimMainFrame.githubLinkFrame.backdropOverlay, "GitHub link dialog should create a main-window backdrop overlay")
                assert.is_truthy(GrimMainFrame.githubLinkFrame.titlebarDragHandle, "GitHub link dialog should create a titlebar drag handle")
                assert.equals(
                    layout.titlebarDragLeftInset,
                    select(4, GrimMainFrame.helpFrame.titlebarDragHandle:GetPoint(1)),
                    "help titlebar should use the shared left drag inset"
                )
                assert.equals(
                    layout.titlebarDragHeight,
                    GrimMainFrame.helpFrame.titlebarDragHandle:GetHeight(),
                    "help titlebar should use the shared drag height"
                )
                assert.is_truthy(GrimMainFrame.introDemoController, "main frame should keep a reference to the intro demo controller")
                assert.is_truthy(GrimMainFrame.lockButton, "main frame should keep a reference to the lock button")
                assert.is_truthy(GrimMainFrame.pauseButton, "main frame should keep a reference to the pause button")
                assert.is_truthy(GrimMainFrame.bottomLogButton, "main frame should keep a reference to the bottom log button")
                assert.is_truthy(GrimMainFrame.gameInfoCallout, "main frame should keep a reference to the game info callout")
                assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "game info callout should start hidden")
            end)

            it("creates recent-death rows and cells", function()
                assert.is_truthy(GrimMainFrame.recentDeathsFrame, "main frame should create the reusable recent deaths frame")
                assert.equals(GrimLog.logRowHeight, GrimMainFrame.recentDeathsFrame.logRowHeight, "main log should use the history log record spacing")
                assert.equals(GrimLog.rows[1]:GetHeight(), GrimMainFrame.deathRows[1]:GetHeight(), "main log rows should match history log row height")
                assert.equals(layout.outsideGutter, select(4, GrimMainFrame.recentDeathsFrame:GetPoint(1)), "main log should use the outside gutter")
                assert.equals(layout.deathLogFrameY, select(5, GrimMainFrame.recentDeathsFrame:GetPoint(1)), "main log should sit close beneath the column headers")
                assert.equals(
                    5 * layout.deathLogRowHeight,
                    GrimMainFrame.recentDeathsFrame:GetHeight(),
                    "main log frame should fit exactly five compact rows"
                )
                assert.is_truthy(GrimMainFrame.deathRows[1].time, "main frame should create the recent death time cell")
                assert.is_truthy(GrimMainFrame.deathRows[1].sourceName, "main frame should create the recent death source cell")
                assert.is_truthy(GrimMainFrame.deathRows[1].level, "main frame should create the recent death level cell")
                assert.is_truthy(GrimMainFrame.deathRows[1].zone, "main frame should create the recent death location cell")
                assert.is_truthy(GrimMainFrame.deathRows[1].awardedPoints, "main frame should create the total points cell in recent death rows")
                assert.equals("RIGHT", GrimMainFrame.deathRows[1].awardedPoints.justifyH, "main frame should right justify recent death points")
            end)

            it("configures recent-death column dimensions and alignment", function()
                assert.equals(0, select(4, GrimMainFrame.deathRows[1].time:GetPoint(1)), "main frame should keep recent death time at the content edge")
                assert.equals(58, select(4, GrimMainFrame.deathRows[1].sourceName:GetPoint(1)), "main frame should compact the recent death source column")
                assert.equals(278, select(4, GrimMainFrame.deathRows[1].level:GetPoint(1)), "main frame should compact the recent death level column")
                assert.equals(328, select(4, GrimMainFrame.deathRows[1].zone:GetPoint(1)), "main frame should compact the recent death location column")
                assert.equals(530, select(4, GrimMainFrame.deathRows[1].awardedPoints:GetPoint(1)), "main frame should compact the recent death points column")
                assert.equals(290, GrimMainFrame.deathRows[1].sourceName:GetWidth(), "main frame should preserve the recent death source width")
                assert.equals(40, GrimMainFrame.deathRows[1].level:GetWidth(), "main frame should preserve the recent death level width")
                assert.equals(400, GrimMainFrame.deathRows[1].zone:GetWidth(), "main frame should preserve the recent death location width")
                assert.equals(46, GrimMainFrame.deathRows[1].awardedPoints:GetWidth(), "main frame should preserve the recent death points width")
                assert.equals(
                    layout.expandedWindowWidth - (layout.outsideGutter * 2),
                    select(4, GrimMainFrame.deathRows[1].awardedPoints:GetPoint(1)) + GrimMainFrame.deathRows[1].awardedPoints:GetWidth(),
                    "main frame should keep recent death points inside the compact right gutter"
                )
            end)

            it("preserves recent-death column order and omits unused cells", function()
                assert.is_truthy(
                    select(4, GrimMainFrame.deathRows[1].time:GetPoint(1))
                        < select(4, GrimMainFrame.deathRows[1].sourceName:GetPoint(1)),
                    "main frame should place source after time"
                )
                assert.is_truthy(
                    select(4, GrimMainFrame.deathRows[1].sourceName:GetPoint(1))
                        < select(4, GrimMainFrame.deathRows[1].level:GetPoint(1)),
                    "main frame should place level after source"
                )
                assert.is_truthy(
                    select(4, GrimMainFrame.deathRows[1].level:GetPoint(1))
                        < select(4, GrimMainFrame.deathRows[1].zone:GetPoint(1)),
                    "main frame should place location after level"
                )
                assert.is_truthy(
                    select(4, GrimMainFrame.deathRows[1].zone:GetPoint(1))
                        < select(4, GrimMainFrame.deathRows[1].awardedPoints:GetPoint(1)),
                    "main frame should place points after location"
                )
                assert.equals(nil, GrimMainFrame.deathRows[1].pointsTooltipTarget, "main frame should omit the base points hover target from recent death rows")
                assert.equals(nil, GrimMainFrame.deathRows[1].multiplier, "main frame should omit the combo cell from recent death rows")
                assert.equals(nil, GrimMainFrame.deathRows[1].streakMultiplier, "main frame should omit the streak cell from recent death rows")
            end)

            it("builds the collapsed log and resize controls", function()
                assert.is_truthy(GrimMainFrame.collapsedLogFrame, "main frame should create the collapsed death log frame")
                assert.is_truthy(#GrimMainFrame.collapsedLogFrame.rows > 0, "main frame should create collapsed death log rows")
                assert.equals(GrimLog.logRowHeight, GrimMainFrame.collapsedLogFrame.logRowHeight, "mini log should use the history log record spacing")
                assert.equals(GrimLog.rows[1]:GetHeight(), GrimMainFrame.collapsedLogFrame.rows[1]:GetHeight(), "mini log rows should match history log row height")
                assert.is_truthy(GrimMainFrame.collapsedLogFrame.rows[1].time, "main frame should create collapsed death time cells")
                assert.is_truthy(GrimMainFrame.collapsedLogFrame.rows[1].awardedPoints, "main frame should create collapsed death points cells")
                assert.equals(45, GrimMainFrame.collapsedLogFrame.rows[1].time:GetWidth(), "mini log should give the time column enough width for scaled fonts")
                assert.equals("RIGHT", GrimMainFrame.collapsedLogFrame.rows[1].awardedPoints.justifyH, "main frame should right justify collapsed death points")
                assert.is_truthy(#(GrimMainFrame.collapsedLogHeaders or {}) > 0, "main frame should create collapsed death log headers")
                assert.equals("Time", GrimMainFrame.collapsedLogHeaders[1]:GetText(), "mini log should show the time column header")
                assert.equals(45, GrimMainFrame.collapsedLogHeaders[1]:GetWidth(), "mini log should give the time header enough width for scaled fonts")
                assert.equals(
                    layout.collapsedLogHeaderY,
                    select(5, GrimMainFrame.collapsedLogHeaders[1]:GetPoint(1)),
                    "mini log headers should use the shared collapsed header position"
                )
                assert.equals(
                    layout.collapsedLogFrameY,
                    select(5, GrimMainFrame.collapsedLogFrame:GetPoint(1)),
                    "mini log rows should use the shared collapsed row position"
                )
                assert.equals(
                    layout.deathLogHeaderY - layout.deathLogFrameY,
                    select(5, GrimMainFrame.collapsedLogHeaders[1]:GetPoint(1)) - select(5, GrimMainFrame.collapsedLogFrame:GetPoint(1)),
                    "mini log header-to-row spacing should match the main log"
                )
                assert.is_truthy(GrimMainFrame.collapsedScoreDivider, "main frame should create the collapsed score divider")
                assert.equals(
                    layout.footerGutter,
                    select(5, GrimMainFrame.collapsedPointsValue:GetPoint(1)),
                    "collapsed score should use the footer gutter"
                )
                assert.is_truthy(GrimMainFrame.collapsedResizeHandle, "main frame should create the collapsed resize handle")
                assert.equals(
                    "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
                    GrimMainFrame.collapsedResizeHandle:GetNormalTexture(),
                    "main frame should use Blizzard chat resize art for the collapsed resize handle"
                )
            end)

            it("configures titlebar and log controls", function()
                assert.equals(nil, GrimMainFrame.minimizeButton.template, "main frame should use a plain button for Classic-compatible collapse art")
                assert.equals(nil, GrimMainFrame.minimizeButton:GetText(), "main frame collapse button should rely on Blizzard textures instead of text")
                assert.equals("LOG", GrimMainFrame.bottomLogButton:GetText(), "bottom log button should use the log label")
                assert.equals(false, GrimMainFrame.bottomLogButton:IsEnabled(), "bottom log button should start disabled before the first locked prediction")
            end)

            it("lays out level controls", function()
                assert.equals(64, GrimMainFrame.levelRangeButtons[1]:GetWidth(), "level range buttons should preserve their width")
                assert.equals(layout.compactButtonHeight, GrimMainFrame.levelRangeButtons[1]:GetHeight(), "level range buttons should preserve their height")
                assert.equals(layout.predictionControlX, select(4, GrimMainFrame.levelRangeButtons[1]:GetPoint(1)), "level range buttons should start closer to their label")
                assert.equals(
                    select(5, GrimMainFrame.levelRangeButtons[1]:GetPoint(1)),
                    select(5, GrimMainFrame.levelRangeLabel:GetPoint(1)),
                    "level range label should align with the level button row"
                )
                assert.equals(layout.compactButtonHeight, GrimMainFrame.levelRangeLabel:GetHeight(), "level range label should match the button row height")
                assert.equals("MIDDLE", GrimMainFrame.levelRangeLabel.justifyV, "level range label should be vertically centered")
                assert.equals(
                    68,
                    select(4, GrimMainFrame.levelRangeButtons[2]:GetPoint(1)) - select(4, GrimMainFrame.levelRangeButtons[1]:GetPoint(1)),
                    "level range buttons should use compact horizontal spacing"
                )
            end)

            it("lays out source and location inputs", function()
                assert.equals(180, GrimMainFrame.sourceEditBox:GetWidth(), "source edit box should preserve its width")
                assert.equals(layout.compactButtonHeight, GrimMainFrame.sourceEditBox:GetHeight(), "source edit box should preserve its height")
                assert.equals(
                    7,
                    select(4, GrimMainFrame.sourceEditBox:GetPoint(1)) - select(4, GrimMainFrame.levelRangeButtons[1]:GetPoint(1)),
                    "source edit box should account for its template border when aligning with buttons"
                )
                assert.equals(
                    7,
                    select(4, GrimMainFrame.zoneEditBox:GetPoint(1)) - select(4, GrimMainFrame.levelRangeButtons[1]:GetPoint(1)),
                    "location edit box should account for its template border when aligning with buttons"
                )
                assert.equals(
                    select(5, GrimMainFrame.sourceEditBox:GetPoint(1)),
                    select(5, GrimMainFrame.sourceLabel:GetPoint(1)),
                    "source label should align with the source edit box row"
                )
                assert.equals(
                    select(5, GrimMainFrame.zoneEditBox:GetPoint(1)),
                    select(5, GrimMainFrame.zoneLabel:GetPoint(1)),
                    "location label should align with the location edit box row"
                )
                assert.equals(layout.compactButtonHeight, GrimMainFrame.sourceLabel:GetHeight(), "source label should match the edit box row height")
                assert.equals(layout.compactButtonHeight, GrimMainFrame.zoneLabel:GetHeight(), "location label should match the edit box row height")
                assert.equals("MIDDLE", GrimMainFrame.sourceLabel.justifyV, "source label should be vertically centered")
                assert.equals("MIDDLE", GrimMainFrame.zoneLabel.justifyV, "location label should be vertically centered")
            end)

            it("lays out footer actions and score summary", function()
                assert.equals(layout.standardButtonWidth, GrimMainFrame.helpButton:GetWidth(), "help button should preserve its width")
                assert.equals(layout.standardButtonHeight, GrimMainFrame.helpButton:GetHeight(), "help button should preserve its height")
                assert.equals(100, GrimMainFrame.bottomLogButton:GetWidth(), "log button should preserve its width")
                assert.equals(layout.standardButtonHeight, GrimMainFrame.bottomLogButton:GetHeight(), "log button should preserve its height")
                assert.equals(layout.standardButtonWidth, GrimMainFrame.pauseButton:GetWidth(), "pause button should preserve its width")
                assert.equals(layout.standardButtonWidth, GrimMainFrame.lockButton:GetWidth(), "lock button should preserve its width")
                assert.equals("BOTTOMLEFT", select(1, GrimMainFrame.helpButton:GetPoint(1)), "bottom buttons should be anchored from the left edge")
                assert.equals(layout.predictionControlX, select(4, GrimMainFrame.helpButton:GetPoint(1)), "bottom buttons should start farther left")
                assert.equals(layout.footerGutter, select(5, GrimMainFrame.helpButton:GetPoint(1)), "bottom buttons should use the footer gutter")
                assert.equals(GrimMainFrame.helpButton, select(2, GrimMainFrame.bottomLogButton:GetPoint(1)), "log button should chain to help")
                assert.equals(layout.actionButtonGap, select(4, GrimMainFrame.bottomLogButton:GetPoint(1)), "log button should preserve the button gap")
                assert.equals(GrimMainFrame.bottomLogButton, select(2, GrimMainFrame.pauseButton:GetPoint(1)), "pause button should chain to log")
                assert.equals(layout.actionButtonGap, select(4, GrimMainFrame.pauseButton:GetPoint(1)), "pause button should preserve the button gap")
                assert.equals(GrimMainFrame.pauseButton, select(2, GrimMainFrame.lockButton:GetPoint(1)), "lock button should chain to pause")
                assert.equals(layout.actionButtonGap, select(4, GrimMainFrame.lockButton:GetPoint(1)), "lock button should preserve the button gap")
                assert.equals(
                    604,
                    select(4, GrimMainFrame.helpButton:GetPoint(1))
                        + GrimMainFrame.helpButton:GetWidth()
                        + layout.actionButtonGap
                        + GrimMainFrame.bottomLogButton:GetWidth()
                        + layout.actionButtonGap
                        + GrimMainFrame.pauseButton:GetWidth()
                        + layout.actionButtonGap
                        + GrimMainFrame.lockButton:GetWidth(),
                    "bottom buttons should fit within the compact expanded width"
                )
                assert.equals(layout.footerGutter, select(5, GrimLog.filterButton:GetPoint(1)), "history filter should use the footer gutter")
                assert.is_truthy(GrimMainFrame.sourceEditBox, "main frame should create the source edit box")
                assert.is_truthy(GrimMainFrame.zoneEditBox, "main frame should create the zone edit box")
            end)

            it("configures debug detail fields", function()
                assert.is_truthy(GrimDebug.detailLabels, "debug frame should keep references to detail labels")
                assert.equals("EditBox", GrimDebug.detailValues.sourceMessage.kind, "debug frame should use an edit box for the raw message")
                assert.equals(
                    GrimDebug:GetWidth() - (layout.outsideGutter * 2),
                    GrimDebug.detailValues.sourceMessage:GetWidth(),
                    "debug raw message should keep a gutter on both sides"
                )
                assert.equals(36, GrimDebug.detailValues.sourceMessage:GetHeight(), "debug raw message should be tall enough for two lines")
                assert.equals(true, GrimDebug.detailValues.sourceMessage.multiLine, "debug raw message should wrap across multiple lines")
                assert.equals(false, GrimDebug.detailValues.sourceMessage.autoFocus, "debug raw message should not steal focus on create")
                assert.equals(
                    select(5, GrimDebug.detailLabels.pointFormula:GetPoint(1)),
                    select(5, GrimDebug.detailLabels.comboDetails:GetPoint(1)),
                    "debug winning combo should move to the formula row"
                )
                assert.is_truthy(
                    select(4, GrimDebug.detailLabels.comboDetails:GetPoint(1))
                        > select(4, GrimDebug.detailLabels.pointFormula:GetPoint(1)),
                    "debug winning combo should sit to the right of the formula row"
                )
                assert.equals(
                    select(4, GrimDebug.detailValues.sourceMessage:GetPoint(1)),
                    select(4, GrimDebug.detailLabels.sourceMessage:GetPoint(1)),
                    "debug raw message label should align with the frame gutter"
                )
                assert.equals(
                    select(5, GrimDebug.detailValues.sourceMessage:GetPoint(1)) + 15,
                    select(5, GrimDebug.detailLabels.sourceMessage:GetPoint(1)),
                    "debug raw message label should sit above the edit box"
                )
            end)

            it("creates intro and waiting controls with their defaults", function()
                assert.is_truthy(GrimMainFrame.introDemoAttractPanel, "main frame should create the intro demo marquee panel")
                assert.is_truthy(GrimMainFrame.emptyPredictionPrompt, "main frame should create the empty-prediction prompt")
                assert.is_truthy(GrimMainFrame.waitingPromptText, "main frame should create the waiting prompt base text")
                assert.is_truthy(GrimMainFrame.waitingPromptDots, "main frame should create the waiting prompt dots")
                assert.is_truthy(GrimMainFrame.waitingPromptHelpText, "main frame should create the waiting prompt help text")
                assert.equals(false, GrimMainFrame.emptyPredictionPrompt:IsShown(), "empty-prediction prompt should start hidden")
            end)

            it("creates setup controls and their overlay", function()
                assert.is_truthy(GrimMainFrame.setupFrame, "main frame should create the standalone setup window")
                assert.is_truthy(GrimMainFrame.setupFrame.enableDeathAnnouncementsButton, "setup window should create the death announcement enable button")
                assert.is_truthy(GrimMainFrame.setupFrame.enableDeathAnnouncementsText, "setup window should create the death announcement enable text")
                assert.is_truthy(GrimMainFrame.setupFrame.joinHardcoreDeathsButton, "setup window should create the hardcore deaths channel join button")
                assert.is_truthy(GrimMainFrame.setupFrame.joinHardcoreDeathsText, "setup window should create the hardcore deaths channel join text")
                assert.is_truthy(GrimMainFrame.setupFrame.backdropOverlay, "setup window should create a main-window backdrop overlay")
                assert.is_truthy(GrimMainFrame.setupFrame.titlebarDragHandle, "setup window should create a titlebar drag handle")
                assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "setup window should start hidden")
                assert.equals(false, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "setup backdrop should start hidden")
                assert.equals(true, GrimMainFrame.setupFrame.backdropOverlay.allPoints, "setup backdrop should cover the main window")
                assert.equals(true, GrimMainFrame.setupFrame.backdropOverlay.mouseEnabled, "setup backdrop should block main window clicks")
                assert.equals("LeftButton", GrimMainFrame.setupFrame.backdropOverlay.dragButton, "setup backdrop should preserve main-window dragging")
                assert.is_truthy(GrimMainFrame.setupFrame.backdropOverlay:GetScript("OnDragStart"), "setup backdrop should start main-window dragging")
                assert.is_truthy(GrimMainFrame.setupFrame.backdropOverlay:GetScript("OnDragStop"), "setup backdrop should stop main-window dragging")
                assert.equals("LeftButton", GrimMainFrame.setupFrame.titlebarDragHandle.dragButton, "setup titlebar should preserve main-window dragging")
                assert.is_truthy(GrimMainFrame.setupFrame.titlebarDragHandle:GetScript("OnDragStart"), "setup titlebar should start main-window dragging")
                assert.is_truthy(GrimMainFrame.setupFrame.titlebarDragHandle:GetScript("OnDragStop"), "setup titlebar should stop main-window dragging")
                assert.equals(
                    true,
                    GrimMainFrame.setupFrame.backdropOverlay:GetFrameLevel() > GrimMainFrame:GetFrameLevel(),
                    "setup backdrop should sit above main window contents"
                )
                assert.equals(0.58, GrimMainFrame.setupFrame.backdropOverlay.texture.colorTexture[4], "setup backdrop should obscure the main window")
            end)

            it("configures the help modal overlay", function()
                assert.equals(369, GrimMainFrame.helpFrame:GetHeight(), "help window should use the shorter modal height")
                assert.equals(GrimMainFrame, select(2, GrimMainFrame.helpFrame:GetPoint(1)), "help window should be centered on the main window")
                assert.equals(0, select(4, GrimMainFrame.helpFrame:GetPoint(1)), "help window should not offset horizontally from the main window")
                assert.equals(0, select(5, GrimMainFrame.helpFrame:GetPoint(1)), "help window should not offset vertically from the main window")
                assert.equals(false, GrimMainFrame.helpFrame.movable, "help window should not be movable")
                assert.equals(nil, GrimMainFrame.helpFrame.dragButton, "help window should not register itself for dragging")
                assert.equals(false, GrimMainFrame.helpFrame.backdropOverlay:IsShown(), "help backdrop should start hidden")
                assert.equals(true, GrimMainFrame.helpFrame.backdropOverlay.allPoints, "help backdrop should cover the main window")
                assert.equals(true, GrimMainFrame.helpFrame.backdropOverlay.mouseEnabled, "help backdrop should block main window clicks")
                assert.equals("LeftButton", GrimMainFrame.helpFrame.backdropOverlay.dragButton, "help backdrop should preserve main-window dragging")
                assert.is_truthy(GrimMainFrame.helpFrame.backdropOverlay:GetScript("OnDragStart"), "help backdrop should start main-window dragging")
                assert.is_truthy(GrimMainFrame.helpFrame.backdropOverlay:GetScript("OnDragStop"), "help backdrop should stop main-window dragging")
                assert.equals("LeftButton", GrimMainFrame.helpFrame.titlebarDragHandle.dragButton, "help titlebar should preserve main-window dragging")
                assert.is_truthy(GrimMainFrame.helpFrame.titlebarDragHandle:GetScript("OnDragStart"), "help titlebar should start main-window dragging")
                assert.is_truthy(GrimMainFrame.helpFrame.titlebarDragHandle:GetScript("OnDragStop"), "help titlebar should stop main-window dragging")
                assert.equals(
                    true,
                    GrimMainFrame.helpFrame.backdropOverlay:GetFrameLevel() > GrimMainFrame:GetFrameLevel(),
                    "help backdrop should sit above main window contents"
                )
                assert.equals(0.58, GrimMainFrame.helpFrame.backdropOverlay.texture.colorTexture[4], "help backdrop should obscure the main window")
            end)

            it("configures the GitHub link modal overlay", function()
                assert.equals(430, GrimMainFrame.githubLinkFrame:GetWidth(), "GitHub link dialog should use the setup-style modal width")
                assert.equals(112, GrimMainFrame.githubLinkFrame:GetHeight(), "GitHub link dialog should be compact")
                assert.equals("GitHub Link", GrimMainFrame.githubLinkFrame.title:GetText(), "GitHub link dialog should use the requested title")
                assert.equals(
                    GrimMainFrame,
                    select(2, GrimMainFrame.githubLinkFrame:GetPoint(1)),
                    "GitHub link dialog should be centered on the main window"
                )
                assert.equals(0, select(4, GrimMainFrame.githubLinkFrame:GetPoint(1)), "GitHub link dialog should not offset horizontally")
                assert.equals(0, select(5, GrimMainFrame.githubLinkFrame:GetPoint(1)), "GitHub link dialog should not offset vertically")
                assert.equals(false, GrimMainFrame.githubLinkFrame.movable, "GitHub link dialog should not be movable")
                assert.equals(nil, GrimMainFrame.githubLinkFrame.dragButton, "GitHub link dialog should not register itself for dragging")
                assert.equals(false, GrimMainFrame.githubLinkFrame.backdropOverlay:IsShown(), "GitHub link backdrop should start hidden")
                assert.equals(true, GrimMainFrame.githubLinkFrame.backdropOverlay.allPoints, "GitHub link backdrop should cover the main window")
                assert.equals(true, GrimMainFrame.githubLinkFrame.backdropOverlay.mouseEnabled, "GitHub link backdrop should block main window clicks")
                assert.equals(
                    "LeftButton",
                    GrimMainFrame.githubLinkFrame.backdropOverlay.dragButton,
                    "GitHub link backdrop should preserve main-window dragging"
                )
                assert.is_truthy(
                    GrimMainFrame.githubLinkFrame.backdropOverlay:GetScript("OnDragStart"),
                    "GitHub link backdrop should start main-window dragging"
                )
                assert.is_truthy(
                    GrimMainFrame.githubLinkFrame.backdropOverlay:GetScript("OnDragStop"),
                    "GitHub link backdrop should stop main-window dragging"
                )
                assert.equals(
                    "LeftButton",
                    GrimMainFrame.githubLinkFrame.titlebarDragHandle.dragButton,
                    "GitHub link titlebar should preserve main-window dragging"
                )
                assert.is_truthy(
                    GrimMainFrame.githubLinkFrame.titlebarDragHandle:GetScript("OnDragStart"),
                    "GitHub link titlebar should start main-window dragging"
                )
                assert.is_truthy(
                    GrimMainFrame.githubLinkFrame.titlebarDragHandle:GetScript("OnDragStop"),
                    "GitHub link titlebar should stop main-window dragging"
                )
                assert.equals(
                    true,
                    GrimMainFrame.githubLinkFrame.backdropOverlay:GetFrameLevel() > GrimMainFrame:GetFrameLevel(),
                    "GitHub link backdrop should sit above main window contents"
                )
                assert.equals(
                    0.58,
                    GrimMainFrame.githubLinkFrame.backdropOverlay.texture.colorTexture[4],
                    "GitHub link backdrop should obscure the main window"
                )
            end)

            it("configures the setup window", function()
                assert.equals("SETUP", GrimMainFrame.setupFrame.title:GetText(), "setup window should use the setup title")
                assert.equals("Let's make sure you're set up!", GrimMainFrame.setupFrame.subtitle:GetText(), "setup window should introduce setup")
                assert.equals("GameFontNormal", GrimMainFrame.setupFrame.subtitle.template, "setup subtitle should match row text size")
                assert.equals(GrimMainFrame, select(2, GrimMainFrame.setupFrame:GetPoint(1)), "setup window should be centered on the main window")
                assert.equals(0, select(4, GrimMainFrame.setupFrame:GetPoint(1)), "setup window should not offset horizontally from the main window")
                assert.equals(0, select(5, GrimMainFrame.setupFrame:GetPoint(1)), "setup window should not offset vertically from the main window")
                assert.equals(false, GrimMainFrame.setupFrame.movable, "setup window should not be movable")
                assert.equals(nil, GrimMainFrame.setupFrame.dragButton, "setup window should not register for dragging")
            end)

            it("configures setup actions and removes obsolete controls", function()
                assert.equals(nil, GrimMainFrame.configPromptFrame, "main frame should not create an inline setup prompt")
                assert.equals(nil, GrimMainFrame.configPromptTitle, "main frame should not create an inline setup title")
                assert.equals(nil, GrimMainFrame.deathAnnouncementsCheckbox, "config walkthrough should not create a death announcement checkbox")
                assert.equals(nil, GrimMainFrame.hardcoreDeathsChannelCheckbox, "config walkthrough should not create a channel checkbox")
                assert.equals("GameMenuButtonTemplate", GrimMainFrame.setupFrame.enableDeathAnnouncementsButton.template, "death announcement action should use a real button template")
                assert.equals("ENABLE", GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:GetText(), "death announcement button should use the enable label")
                assert.equals("Hardcore death announcements", GrimMainFrame.setupFrame.enableDeathAnnouncementsText:GetText(), "death announcement text should explain the action")
                assert.equals("GameMenuButtonTemplate", GrimMainFrame.setupFrame.joinHardcoreDeathsButton.template, "channel action should use a real button template")
                assert.equals("JOIN", GrimMainFrame.setupFrame.joinHardcoreDeathsButton:GetText(), "channel button should use the join label")
                assert.equals("The HardcoreDeaths channel", GrimMainFrame.setupFrame.joinHardcoreDeathsText:GetText(), "channel text should explain the action")
            end)

            it("lays out intro, waiting, and score prompts", function()
                assert.equals(
                    "Make your prediction",
                    GrimMainFrame.emptyPredictionPrompt:GetText(),
                    "empty-prediction prompt should guide the player to choose a prediction"
                )
                assert.equals(false, GrimMainFrame.introDemoAttractPanel:IsShown(), "intro demo marquee should start hidden outside demo mode")
                assert.equals(284, select(4, GrimMainFrame.introDemoAttractPanel:GetPoint(1)), "intro demo marquee should fit the compact expanded width")
                assert.equals(314, GrimMainFrame.introDemoAttractPanel:GetWidth(), "intro demo marquee should preserve its width")
                assert.equals(
                    "Welcome to Grim Guesser\nPress START GAME to begin",
                    GrimMainFrame.introDemoAttractPanel.text:GetText(),
                    "intro demo marquee should use the arcade attract text"
                )
                assert.equals("CENTER", select(1, GrimMainFrame.waitingPromptText:GetPoint(1)), "waiting prompt text should anchor from the center")
                assert.equals("CENTER", select(3, GrimMainFrame.waitingPromptText:GetPoint(1)), "waiting prompt text should stay centered in the pane")
                assert.equals("LEFT", select(1, GrimMainFrame.waitingPromptDots:GetPoint(1)), "waiting prompt dots should anchor from the left")
                assert.equals("RIGHT", select(3, GrimMainFrame.waitingPromptDots:GetPoint(1)), "waiting prompt dots should attach to the text's right edge")
                assert.equals("TOP", select(1, GrimMainFrame.waitingPromptHelpText:GetPoint(1)), "waiting prompt help text should anchor from the top")
                assert.equals("BOTTOM", select(3, GrimMainFrame.waitingPromptHelpText:GetPoint(1)), "waiting prompt help text should attach below the waiting text")
                assert.equals(
                    layout.deathLogDividerY - (layout.outsideGutter - layout.footerGutter),
                    layout.scoreSummaryY,
                    "expanded score summary should use the tighter footer spacing from the mini log"
                )
                assert.equals(
                    layout.scoreSummaryY,
                    select(5, GrimMainFrame.totalPointsValue:GetPoint(1)),
                    "expanded score summary should sit close beneath the death log divider"
                )
                assert.is_truthy(GrimMainFrame.currentStreakValue, "main frame should create the current streak value")
                assert.is_truthy(GrimMainFrame.dropdown, "main frame should create the shared suggestion dropdown")
            end)

            it("registers clipping and escape-close behavior", function()
                assert.equals(true, GrimMainFrame.collapsedLogFrame.clipsChildren, "collapsed death log should clip child rows during resize")
                assert.equals(true, GrimMainFrame.collapsedLogFrame.rows[1].clipsChildren, "collapsed death log rows should clip cell text to the row bounds")
                assert.equals("GrimFrame", env.UISpecialFrames[1], "main frame should register with the WoW escape-close list")
            end)
        end)

        it("uses an independent environment for each context", function()
            local firstContext = createUIContext()
            rawset(firstContext.env.Settings, "transientValue", "first context")

            local secondContext = createUIContext()

            assert.equals(false, firstContext.env == secondContext.env, "each UI context should receive its own environment")
            assert.equals(
                nil,
                rawget(secondContext.env.Settings, "transientValue"),
                "a later UI context should receive pristine mutable WoW globals"
            )
            assert.equals(
                false,
                firstContext.GrimMainFrame == secondContext.GrimMainFrame,
                "a later UI context should receive newly loaded addon modules"
            )
        end)

        it("restores the saved history filter", function()
            local context = createUIContext(Fixtures.uiDatabase({
                historySuccessfulOnly = false,
            }))
            local GrimLog = context.GrimLog

            assert.equals(false, GrimLog.showSuccessfulOnly, "history log should restore the saved all-history mode")
            assert.equals("All Predictions", GrimLog.logSubtitle:GetText(), "history log should restore the saved subtitle")
            assert.equals("SHOW SUCCESS ONLY", GrimLog.filterButton:GetText(), "history log should restore the saved filter action")
            assert.equals("Time", GrimLog.columnHeaders.time:GetText(), "history log should restore the time column label for all-history mode")
            assert.equals("Source", GrimLog.columnHeaders.sourceName:GetText(), "history log should use the source column label for all-history mode")
            assert.equals(nil, GrimLog.columnHeaders.level, "history log should omit the level column for all-history mode")
        end)
    end)

    describe("window and modal behavior", function()
        it("closes the main window on escape", function()
            local context = createUIContext({})
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local pressEscape = context.pressEscape
            GrimMainFrame:Show()

            assert.is_truthy(pressEscape(), "escape should report that it closed a special frame")
            assert.equals(false, GrimMainFrame:IsShown(), "escape should close the main window")

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()
            assert.is_truthy(pressEscape(), "escape should still close the main window when the demo is visible")
            assert.equals(false, GrimMainFrame:IsShown(), "escape should close the main window when the demo is visible")

            GrimMainFrame:Show()
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(nil, env.UISpecialFrames[1], "collapsed main window should be removed from the WoW escape-close list")
            assert.equals(false, pressEscape(), "escape should not close the collapsed main window")
            assert.is_truthy(GrimMainFrame:IsShown(), "collapsed main window should remain visible after escape")
        end)

        it("renders help text", function()
            local context = createUIContext()
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local findRegionText = context.findRegionText
            local layout = GrimUI.LAYOUT

            local helpText = findRegionText(GrimMainFrame.helpFrame, "Grim Guesser is a")
            assert.is_truthy(helpText, "help frame should contain the main help text")
            assert.equals(
                -(layout.outsideGutter + layout.scrollbarInset),
                select(4, GrimMainFrame.helpFrame.scrollFrame:GetPoint(2)),
                "help scrollbar should clear the window inlay"
            )
            assert.equals(
                GrimMainFrame.helpFrame:GetWidth()
                    - (layout.outsideGutter * 2)
                    - layout.scrollbarWidth
                    - layout.scrollbarInset,
                GrimMainFrame.helpFrame.helpText:GetWidth(),
                "help text should leave room for the scrollbar"
            )
            assert.equals(
                GrimMainFrame.helpFrame.helpText:GetWidth(),
                GrimMainFrame.helpFrame.scrollContent:GetWidth(),
                "help scroll content should match the scrollbar-aware text width"
            )
            assert.equals(false, GrimMainFrame.githubLinkFrame:IsShown(), "GitHub link dialog should start hidden")
            assert.equals(
                "InputBoxTemplate",
                GrimMainFrame.githubLinkFrame.urlBox.template,
                "GitHub link dialog should use the WoW input box template"
            )
            assert.equals(
                context.GrimUIHelp.GetDownloadUrl(),
                GrimMainFrame.githubLinkFrame.urlBox:GetText(),
                "GitHub link field should contain the releases URL"
            )
            assert.equals("OK", GrimMainFrame.githubLinkFrame.okButton:GetText(), "GitHub link dialog should have an OK button")
            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "clicking the download link should replace the help window")
            assert.is_truthy(GrimMainFrame.githubLinkFrame:IsShown(), "clicking the download link should open the GitHub link dialog")
            assert.is_truthy(
                GrimMainFrame.githubLinkFrame.backdropOverlay:IsShown(),
                "GitHub link dialog should show the main-window backdrop"
            )
            assert.is_truthy(GrimMainFrame.githubLinkFrame.urlBox.hasFocus, "clicking the download link should focus the URL field")
            assert.is_truthy(GrimMainFrame.githubLinkFrame.urlBox.highlightRange, "clicking the download link should select the URL text")

            GrimMainFrame.githubLinkFrame.urlBox:SetText("temporary user edit")
            assert.equals("temporary user edit", GrimMainFrame.githubLinkFrame.urlBox:GetText(), "GitHub link field should allow user edits")
            GrimMainFrame.githubLinkFrame.okButton:GetScript("OnClick")()
            assert.equals(false, GrimMainFrame.githubLinkFrame:IsShown(), "OK should close the GitHub link dialog")
            assert.equals(false, GrimMainFrame.githubLinkFrame.backdropOverlay:IsShown(), "OK should hide the GitHub link backdrop")
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "OK should leave the help window closed")

            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()
            assert.equals(
                context.GrimUIHelp.GetDownloadUrl(),
                GrimMainFrame.githubLinkFrame.urlBox:GetText(),
                "GitHub link field should reset to the canonical URL each open"
            )
            GrimMainFrame.githubLinkFrame.CloseButton:GetScript("OnClick")()
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "titlebar close should leave the help window closed")
        end)

        it("renders the unreleased version and copyright year in help text", function()
            local context = createUIContext(nil, { version = "0.0.0" })

            assert.matches(
                "Grim Guesser unreleased version © 2026",
                context.GrimMainFrame.helpFrame.helpText:GetText(),
                1,
                false,
                "help text should label the placeholder version as unreleased and include the copyright year"
            )
        end)

        it("renders the release version and copyright year in help text", function()
            local context = createUIContext(nil, { version = "1.2.3" })

            assert.matches(
                "Grim Guesser version 1%.2%.3 © 2026",
                context.GrimMainFrame.helpFrame.helpText:GetText(),
                1,
                false,
                "help text should include the release version and copyright year"
            )
        end)

        it("attributes the software to its author", function()
            local context = createUIContext(nil, { version = "1.2.3" })
            local author = "\083\104\105\102\116\099\108\097\099\107"

            assert.matches(
                author,
                context.GrimMainFrame.helpFrame.helpText:GetText(),
                1,
                false,
                "addon should be attributed to the author"
            )
        end)

        it("handles help modal behavior", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                logWindowShown = true,
                lockedPrediction = false,
                draftPrediction = false,
                lastPrediction = false,
            }))
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            GrimMainFrame:Show()
            GrimLog:Show()
            GrimMainFrame:RefreshLockedPrediction()
            assert.equals(true, GrimMainFrame.sourceEditBox:IsEnabled(), "test should start with editable prediction input")

            GrimMainFrame.helpFrame:Show()

            assert.equals(true, GrimMainFrame.helpFrame.backdropOverlay:IsShown(), "help backdrop should show when help is shown")
            assert.equals(true, GrimLog:IsShown(), "help should allow the log window to remain open")
            assert.equals(true, env.GrimCharacterState.logWindowShown, "help should not change the saved log preference")
            assert.equals(false, GrimMainFrame.lockButton:IsEnabled(), "help modal should disable locking predictions")
            assert.equals(false, GrimMainFrame.sourceEditBox:IsEnabled(), "help modal should disable source input")

            GrimMainFrame.helpFrame:Hide()
            assert.equals(false, GrimMainFrame.helpFrame.backdropOverlay:IsShown(), "help backdrop should hide when help is hidden")
            assert.equals(true, GrimMainFrame.sourceEditBox:IsEnabled(), "closing help should restore source input")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(true, GrimMainFrame.isCollapsed, "test should start help from the mini-log state")
            assert.equals(false, GrimLog:IsShown(), "collapsing should hide the expanded log before help opens")

            GrimMainFrame.helpFrame:Show()

            assert.equals(false, GrimMainFrame.isCollapsed, "showing help from the mini-log should expand the main window")
            assert.equals(false, env.GrimCharacterState.collapsed, "showing help should persist the expanded main window")
            assert.equals(true, GrimMainFrame.helpFrame:IsShown(), "showing help from the mini-log should keep help visible")
            assert.equals(true, GrimMainFrame.helpFrame.backdropOverlay:IsShown(), "expanded help should show the backdrop")
            assert.equals(true, GrimLog:IsShown(), "expanding for help should restore the desired log window")
            assert.equals(true, env.GrimCharacterState.logWindowShown, "expanding for help should keep the saved log preference")

            local lockedContext = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                lockedPrediction = Fixtures.prediction(),
            }))
            local LockedGrimguesser = lockedContext.GrimMainFrame

            LockedGrimguesser:RefreshLockedPrediction()
            assert.equals(true, LockedGrimguesser.pauseButton:IsEnabled(), "test should start with an enabled pause action")

            LockedGrimguesser.helpFrame:Show()
            assert.equals(false, LockedGrimguesser.pauseButton:IsEnabled(), "help modal should disable the pause action")

            LockedGrimguesser.helpFrame:Hide()
            assert.equals(true, LockedGrimguesser.pauseButton:IsEnabled(), "closing help should restore pause action state")
        end)

        it("collapses the main window", function()
            local context = createUIContext({
                hasSeenFirstRun = true,
            })
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local GrimDebug = context.GrimDebug
            local GrimLog = context.GrimLog
            GrimMainFrame.helpFrame:Show()
            GrimLog:Show()
            GrimDebug:Show()
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(true, env.GrimCharacterState.collapsed, "collapsed mode should persist state to SavedVariables")
            assert.equals("Interface\\Buttons\\UI-PlusButton-UP", GrimMainFrame.minimizeButton:GetNormalTexture(), "collapsed mode should flip the titlebar button art")
            assert.equals("Interface\\Buttons\\UI-PlusButton-Hilight", GrimMainFrame.minimizeButton:GetHighlightTexture(), "collapsed mode should use Blizzard highlight art")
            assert.is_truthy(GrimMainFrame.collapsedLogHeaders[1]:IsShown(), "collapsed log headers should show in collapsed mode")
            assert.is_truthy(GrimMainFrame.collapsedScoreDivider:IsShown(), "collapsed score divider should show in collapsed mode")
            assert.is_truthy(GrimMainFrame.collapsedPointsValue:IsShown(), "collapsed score should show in collapsed mode")
            assert.equals(false, GrimMainFrame.lockButton:IsShown(), "prediction controls should hide in collapsed mode")
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "collapsed mode should close the help window")
            assert.equals(false, GrimLog:IsShown(), "collapsed mode should close the log window")
            assert.is_truthy(GrimDebug:IsShown(), "collapsed mode should keep the debug window open")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(false, env.GrimCharacterState.collapsed, "expanded mode should persist state to SavedVariables")
            assert.equals("Interface\\Buttons\\UI-MinusButton-UP", GrimMainFrame.minimizeButton:GetNormalTexture(), "expanded mode should restore the titlebar button art")
            assert.equals("Interface\\Buttons\\UI-MinusButton-Hilight", GrimMainFrame.minimizeButton:GetHighlightTexture(), "expanded mode should restore Blizzard highlight art")
            assert.is_truthy(GrimMainFrame.lockButton:IsShown(), "prediction controls should return in expanded mode")
            assert.equals(false, GrimMainFrame.collapsedLogFrame:IsShown(), "expanded mode should hide the collapsed death log frame")
            assert.equals(false, GrimMainFrame.collapsedScoreDivider:IsShown(), "expanded mode should hide the collapsed score divider")
            assert.equals(false, GrimMainFrame.introDemoAttractPanel:IsShown(), "expanded mode should keep the intro marquee hidden outside demo mode")
            assert.is_truthy(GrimMainFrame.helpFrame:IsShown(), "expanded mode should reopen the help window if it was open before collapsing")
            assert.is_truthy(GrimLog:IsShown(), "expanded mode should reopen the log window if it was open before collapsing")
            assert.equals("LOCKED IN", GrimMainFrame.lockButton:GetText(), "restored help modal should keep prediction inputs locked")
            GrimMainFrame.helpFrame:Hide()
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "closing restored help should restore the normal lock button label")

            GrimLog:Hide()
            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()
            assert.is_truthy(GrimMainFrame.githubLinkFrame:IsShown(), "test should start with the GitHub link dialog open")
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(false, GrimMainFrame.githubLinkFrame:IsShown(), "collapsed mode should close the GitHub link dialog")
            assert.equals(
                false,
                GrimMainFrame.helpFrame:IsShown(),
                "collapsed mode should leave help closed after closing the GitHub link dialog"
            )
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(
                false,
                GrimMainFrame.helpFrame:IsShown(),
                "expanded mode should not reopen help after collapsing from the GitHub link dialog"
            )

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(
                false,
                GrimMainFrame.helpFrame:IsShown(),
                "expanded mode should keep the help window closed if it was closed before collapsing"
            )
            assert.equals(
                false,
                GrimLog:IsShown(),
                "expanded mode should keep the log window closed if it was closed before collapsing"
            )

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimMainFrame:GetScript("OnMouseUp")(GrimMainFrame, "LeftButton")
            assert.equals(false, GrimMainFrame.isCollapsed, "clicking the collapsed main window should expand it")
            assert.equals(false, env.GrimCharacterState.collapsed, "clicking the collapsed main window should persist the expanded state")
        end)

        it("expands the main window when a collapsed death row is clicked", function()
            local context = createUIContext(Fixtures.uiDatabase({
                recentDeaths = {
                    Fixtures.storedDeath(),
                },
            }))
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:RefreshDeaths()
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimMainFrame.collapsedLogFrame.rows[1]:GetScript("OnMouseUp")(GrimMainFrame.collapsedLogFrame.rows[1], "LeftButton")

            assert.equals(false, GrimMainFrame.isCollapsed, "clicking a collapsed death log row should expand the main window")
            assert.equals(false, env.GrimCharacterState.collapsed, "clicking a collapsed death log row should persist the expanded state")
        end)

        it("handles the bottom log button", function()
            local context = createUIContext({
                hasSeenFirstRun = true,
            })
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog
            local onClick = GrimMainFrame.bottomLogButton:GetScript("OnClick")

            assert.equals("LOG", GrimMainFrame.bottomLogButton:GetText(), "bottom log button should start with the log label")

            onClick()
            assert.is_truthy(GrimLog:IsShown(), "bottom log button should show the log window while expanded")

            onClick()
            assert.equals(false, GrimLog:IsShown(), "bottom log button should hide the log window while expanded")

            GrimLog:Show()
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(false, GrimLog:IsShown(), "collapsed mode should still hide the log window initially")

            onClick()
            assert.is_truthy(GrimLog:IsShown(), "bottom log button should show the log window while collapsed")
            assert.equals(
                true,
                GrimMainFrame.collapsedWindowStates.logFrame,
                "bottom log button should remember the log window state while collapsed"
            )

            onClick()
            assert.equals(false, GrimLog:IsShown(), "bottom log button should hide the log window while collapsed")
            assert.equals(
                false,
                GrimMainFrame.collapsedWindowStates.logFrame,
                "bottom log button should clear the remembered log window state while collapsed"
            )
        end)

        it("uses the game-info callout for the minimize button", function()
            local context = createUIContext({})
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.minimizeButton:GetScript("OnEnter")(GrimMainFrame.minimizeButton)
            waitForGameInfoCallout(GrimMainFrame)

            assert.equals(true, GrimMainFrame.gameInfoCallout:IsShown(), "hovering the minimize button should show the game info callout")
            assert.equals(
                "Show the mini log",
                GrimMainFrame.gameInfoCallout.lines[1].left,
                "minimize button should use the mini-log game info callout text"
            )

            GrimMainFrame.minimizeButton:GetScript("OnLeave")()
            assert.equals(false, GrimMainFrame.gameInfoCallout:IsShown(), "leaving the minimize button should hide the game info callout")
        end)

        it("reopens the desired log window when the main window shows or expands", function()
            local context = createUIContext(Fixtures.uiDatabase({
                logWindowShown = true,
            }))
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            GrimMainFrame:Hide()
            GrimUI.ApplyDesiredLogWindowState(GrimMainFrame, env.GrimCharacterState)
            assert.equals(false, GrimLog:IsShown(), "desired log state should stay hidden while the main window is hidden")

            GrimMainFrame:Show()
            GrimUI.ApplyDesiredLogWindowState(GrimMainFrame, env.GrimCharacterState)
            assert.is_truthy(GrimLog:IsShown(), "desired log state should open the log when the main window opens")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(false, GrimLog:IsShown(), "collapsing should still hide the log window")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.is_truthy(GrimLog:IsShown(), "expanding should reopen the log when the desired state is open")

            GrimUI.SetLogWindowShown(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(false, env.GrimCharacterState.logWindowShown, "changing the log toggle should persist the desired closed state")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(false, GrimLog:IsShown(), "expanding should keep the log hidden when the desired state is closed")
        end)

        it("uses resolved demo mode for auxiliary window refresh", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
                logWindowShown = true,
            }))
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            GrimMainFrame:Show()
            GrimLog:Show()
            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()

            GrimMainFrame.introDemoController:Show()
            GrimMainFrame:RefreshAuxiliaryWindowState()

            assert.equals(false, GrimMainFrame.bottomLogButton:IsEnabled(), "demo mode should disable the log button through auxiliary refresh")
            assert.equals(false, GrimMainFrame.helpButton:IsEnabled(), "demo mode should disable the help button through auxiliary refresh")
            assert.equals(false, GrimLog:IsShown(), "demo mode should close the log window through auxiliary refresh")
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "demo mode should close the help window through auxiliary refresh")
            assert.equals(false, GrimMainFrame.githubLinkFrame:IsShown(), "demo mode should close the GitHub link dialog")
            assert.equals(false, GrimMainFrame.collapsedWindowStates.logFrame, "demo mode should clear remembered log state")
            assert.equals(false, GrimMainFrame.collapsedWindowStates.helpFrame, "demo mode should clear remembered help state")

            GrimMainFrame.introDemoController:Dismiss()
            GrimMainFrame:RefreshAuxiliaryWindowState()

            assert.equals(true, GrimMainFrame.bottomLogButton:IsEnabled(), "normal mode should re-enable the log button after demo")
            assert.equals(true, GrimMainFrame.helpButton:IsEnabled(), "normal mode should re-enable the help button after demo")
            assert.equals(true, GrimLog:IsShown(), "normal mode should restore the desired log window state")
        end)

        it("closes the GitHub link dialog with the main window", function()
            local context = createUIContext(Fixtures.uiDatabase({
                hasSeenFirstRun = true,
            }))
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.helpFrame:Show()
            GrimMainFrame.helpFrame.downloadLink:GetScript("OnClick")()

            assert.is_truthy(GrimMainFrame.githubLinkFrame:IsShown(), "test should start with the GitHub link dialog open")

            GrimMainFrame:Hide()

            assert.equals(false, GrimMainFrame.githubLinkFrame:IsShown(), "hiding the main window should close the GitHub link dialog")
            assert.equals(false, GrimMainFrame.helpFrame:IsShown(), "hiding the main window should leave help closed")
        end)

        it("follows setup-window visibility for the setup tint", function()
            local context = createUIContext({})
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.setupFrame:Show()
            assert.equals(
                true,
                GrimMainFrame.setupFrame.backdropOverlay:IsShown(),
                "setup backdrop should show when the setup window is shown directly"
            )

            GrimMainFrame.setupFrame:Hide()
            assert.equals(
                false,
                GrimMainFrame.setupFrame.backdropOverlay:IsShown(),
                "setup backdrop should hide when the setup window is hidden directly"
            )
            assert.equals(false, GrimMainFrame.setupActive, "hiding setup should restore main window interaction state")
        end)
    end)

    describe("positioning and layout", function()
        it("remembers the collapsed window position", function()
            local context = createUIContext({})
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", 120, -60)
            GrimUI.SaveWindowPosition(GrimMainFrame, env.GrimCharacterState, false)

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.is_not_nil(GrimMainFrame.points[1], "collapsing without a saved minimized anchor should keep a window anchor")

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", -240, 90)
            GrimMainFrame:GetScript("OnDragStop")(GrimMainFrame)
            assert.is_not_nil(env.GrimCharacterState.collapsedWindowPosition, "dragging while minimized should save the minimized position")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.is_not_nil(GrimMainFrame.points[1], "expanding should restore an expanded window anchor")

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", 360, -180)
            GrimMainFrame:GetScript("OnDragStop")(GrimMainFrame)
            assert.is_not_nil(env.GrimCharacterState.windowPosition, "dragging while expanded should update the expanded position")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.is_not_nil(GrimMainFrame.points[1], "collapsing again should restore a minimized window anchor")
        end)

        it("moves the main window from the log titlebar", function()
            local context = createUIContext({})
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            GrimLog.dragHandle:GetScript("OnDragStart")()
            assert.is_truthy(GrimMainFrame.startedMoving, "dragging the log titlebar should start moving the main window")

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", 210, -110)
            GrimLog.dragHandle:GetScript("OnDragStop")()
            assert.is_truthy(GrimMainFrame.stoppedMoving, "releasing the log titlebar should stop moving the main window")
            assert.is_not_nil(env.GrimCharacterState.windowPosition, "dragging from the log titlebar should save the main window position")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", -150, 55)
            GrimLog.dragHandle:GetScript("OnDragStop")()
            assert.is_not_nil(env.GrimCharacterState.collapsedWindowPosition, "dragging from the log titlebar while minimized should save the minimized position")
        end)

        it("moves the main window from the setup titlebar", function()
            local context = createUIContext({})
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local setupTitlebar = GrimMainFrame.setupFrame.titlebarDragHandle

            setupTitlebar:GetScript("OnDragStart")()
            assert.is_truthy(GrimMainFrame.startedMoving, "dragging the setup titlebar should start moving the main window")

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", 180, -95)
            setupTitlebar:GetScript("OnDragStop")()
            assert.is_truthy(GrimMainFrame.stoppedMoving, "releasing the setup titlebar should stop moving the main window")
            assert.is_not_nil(env.GrimCharacterState.windowPosition, "dragging from the setup titlebar should save the main window position")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", -120, 40)
            setupTitlebar:GetScript("OnDragStop")()
            assert.is_not_nil(
                env.GrimCharacterState.collapsedWindowPosition,
                "dragging from the setup titlebar while minimized should save the minimized position"
            )
        end)

        it("moves the main window from the help modal", function()
            local context = createUIContext({})
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame
            local helpTitlebar = GrimMainFrame.helpFrame.titlebarDragHandle
            local helpBackdrop = GrimMainFrame.helpFrame.backdropOverlay

            helpTitlebar:GetScript("OnDragStart")()
            assert.is_truthy(GrimMainFrame.startedMoving, "dragging the help titlebar should start moving the main window")

            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", 160, -80)
            helpTitlebar:GetScript("OnDragStop")()
            assert.is_truthy(GrimMainFrame.stoppedMoving, "releasing the help titlebar should stop moving the main window")
            assert.is_not_nil(env.GrimCharacterState.windowPosition, "dragging from the help titlebar should save the main window position")

            GrimMainFrame.startedMoving = false
            GrimMainFrame.stoppedMoving = false
            helpBackdrop:GetScript("OnDragStart")()
            assert.is_truthy(GrimMainFrame.startedMoving, "dragging the help backdrop should start moving the main window")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            GrimMainFrame:ClearAllPoints()
            GrimMainFrame:SetPoint("CENTER", env.UIParent, "CENTER", -90, 35)
            helpBackdrop:GetScript("OnDragStop")()
            assert.is_truthy(GrimMainFrame.stoppedMoving, "releasing the help backdrop should stop moving the main window")
            assert.is_not_nil(
                env.GrimCharacterState.collapsedWindowPosition,
                "dragging from the help backdrop while minimized should save the minimized position"
            )
        end)

        it("resizes and restores the collapsed window height", function()
            local recentDeaths = {
                Fixtures.storedDeath({
                    timestamp = 100,
                    name = "One",
                    sourceName = "Source One",
                }),
                Fixtures.storedDeath({
                    timestamp = 101,
                    name = "Two",
                    sourceName = "Source Two",
                }),
                Fixtures.storedDeath({
                    timestamp = 102,
                    name = "Three",
                    sourceName = "Source Three",
                }),
                Fixtures.storedDeath({
                    timestamp = 103,
                    name = "Four",
                    sourceName = "Source Four",
                }),
                Fixtures.storedDeath({
                    timestamp = 104,
                    name = "Five",
                    sourceName = "Source Five",
                }),
            }

            local context = createUIContext({
                recentDeaths = recentDeaths,
                deathHistory = recentDeaths,
            })
            local GrimUI = context.GrimUI
            local GrimMainFrame = context.GrimMainFrame

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(350, GrimMainFrame:GetWidth(), "collapsed mode should keep the fixed collapsed width before resizing")
            assert.equals(165, GrimMainFrame:GetHeight(), "collapsed mode should start with the default collapsed height")
            assert.equals(true, GrimMainFrame.collapsedResizeHandle:IsShown(), "collapsed mode should show the resize handle")
            assert.is_truthy(GrimMainFrame.collapsedLogFrame.rows[5]:IsShown(), "default collapsed height should show five visible rows")
            assert.equals("Source One", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "default collapsed height should keep the oldest visible row at the top")
            assert.equals("Source Five", GrimMainFrame.collapsedLogFrame.rows[5].sourceName:GetText(), "default collapsed height should keep the newest visible row at the bottom")

            GrimMainFrame:SetSize(410, 98)

            assert.equals(350, GrimMainFrame:GetWidth(), "collapsed resize should keep the width fixed")
            assert.equals(100, GrimMainFrame:GetHeight(), "collapsed resize should allow shrinking to the one-row height")
            assert.equals(100, env.GrimCharacterState.collapsedWindowHeight, "collapsed resize should persist the new height")
            assert.is_truthy(GrimMainFrame.collapsedLogFrame.rows[1]:IsShown(), "collapsed resize should keep the newest row visible")
            assert.equals("Source Five", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "collapsed resize should keep the newest death in the visible row")
            assert.equals(false, GrimMainFrame.collapsedLogFrame.rows[2]:IsShown(), "collapsed resize should hide rows beyond the one-row limit")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)
            assert.equals(false, GrimMainFrame.collapsedResizeHandle:IsShown(), "expanded mode should hide the resize handle")

            GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
            assert.equals(100, GrimMainFrame:GetHeight(), "re-collapsing should restore the persisted collapsed height")
            assert.equals(false, GrimMainFrame.collapsedLogFrame.rows[2]:IsShown(), "restored one-row height should still limit the collapsed list")
        end)
    end)
end)
