local assert = require("luassert")
describe("Addon controller", function()
    local match = require("luassert.match")
    local UIHarness = require("tests.support_ui_harness")
    local AddonLoader = require("tests.support_addon_loader")
    local FixtureFactory = require("tests.support_fixtures")
    local LogicHelperFactory = require("tests.support_logic_helpers")
    local LogicHelpers
    local supportLoader
    local GrimDatabase
    local GrimConstants
    local Fixtures
    local DATABASE_DEFAULTS
    local DEMO_RULES
    local env

    before_each(function()
        env = nil
        supportLoader = AddonLoader.Create()
        supportLoader:LoadThrough("GrimMigration")
        GrimDatabase = supportLoader.ns.GrimDatabase
        GrimConstants = supportLoader.ns.GrimConstants
        Fixtures = FixtureFactory.Create(GrimConstants, GrimDatabase)
        LogicHelpers = LogicHelperFactory.Create(GrimConstants.SCORING, Fixtures)
        DATABASE_DEFAULTS = GrimDatabase.DEFAULTS or {}
        DEMO_RULES = GrimConstants.DEMO or {}
    end)

    local function createAddonContext(options)
        local context = UIHarness.CreateAddon(options)
        env = context.env
        return context
    end

    ---@param value number
    ---@return string
    local function formatFiveDigitTestScore(value)
        if value == 12345 then
            return "12,345"
        end

        return tostring(value)
    end

    local function getDefault(key)
        return DATABASE_DEFAULTS[key]
    end

    local function getIntroDemoState(frame)
        local introDemoController = frame and frame.introDemoController or nil
        if introDemoController then
            return introDemoController.demoState
        end

        return nil
    end

    local function refreshUiFrames(context)
        context.GrimMainFrame = context.getMainFrame()
        context.GrimDebug = context.getDebugFrame()
        context.GrimLog = context.getLogFrame()
        ---@type fun(message: string)
        local slashHandler = context.env.SlashCmdList.GRIM
        context.runSlash = function(message)
            return slashHandler(message)
        end
        return context
    end

    local function createLoadedAddonContext(options)
        options = options or {}

        local context = createAddonContext({
            state = options.state,
            hardcoreDeathChatType = options.hardcoreDeathChatType,
            hardcoreDeathsJoined = options.hardcoreDeathsJoined,
            inGuild = options.inGuild,
            formatLargeNumber = options.formatLargeNumber,
        })
        local controller = context.controller
        local dispatchEvent = context.dispatchEvent

        if options.load ~= false then
            dispatchEvent(controller, "ADDON_LOADED", "GrimGuesser")
            refreshUiFrames(context)
        end

        if options.login == true then
            dispatchEvent(controller, "PLAYER_LOGIN")
            refreshUiFrames(context)
        end

        return context
    end

    describe("startup and persisted state", function()
        it("starts fresh without importing or modifying data", function()
            local context = createAddonContext()
            local legacyState = { totalPoints = 9876, hidden = true, minimap = { hide = true } }
            context.env.DeathpoolCharacterState = legacyState

            context.dispatchEvent(context.controller, "ADDON_LOADED", "Deathpool")
            assert.is_nil(context.env.GrimCharacterState, "the old addon identity should not initialize Grim Guesser")
            context.dispatchEvent(context.controller, "ADDON_LOADED", "GrimGuesser")

            local state = context.env.GrimCharacterState
            assert.equals(getDefault("totalPoints"), state.totalPoints, "the new addon should start with fresh points")
            assert.equals(getDefault("hidden"), state.hidden, "the new addon should use default visibility")
            assert.equals(state, context.controller.state, "the controller should bind the new SavedVariables global")
            assert.is_not.equal(legacyState, state, "the new state should be independent of legacy data")

            state.totalPoints = 42
            context.dispatchEvent(context.controller, "PLAYER_LOGOUT")
            local reloaded = createLoadedAddonContext({ state = state })
            assert.equals(42, reloaded.env.GrimCharacterState.totalPoints, "reload should retain the new addon score")
            assert.equals(legacyState, context.env.DeathpoolCharacterState, "legacy data should not be deleted or replaced")
            assert.same({ totalPoints = 9876, hidden = true, minimap = { hide = true } }, legacyState,
                "legacy data should not be normalized or modified")
        end)

        it("defers UI creation until addon load", function()
            local context = createAddonContext()

            assert.is_not_nil(context.controller, "addon bootstrap should create the controller frame immediately")
            assert.equals(nil, context.getMainFrame(), "main ui frame should not exist before ADDON_LOADED")
            assert.equals(nil, context.getDebugFrame(), "debug frame should not exist before ADDON_LOADED")
            assert.equals(nil, context.getLogFrame(), "log frame should not exist before ADDON_LOADED")
        end)

        it("persists main-window visibility through startup", function()
            local context = createLoadedAddonContext()
            local GrimMainFrame = context.GrimMainFrame
            local GrimDebug = context.GrimDebug
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            assert.is_not_nil(env.GrimCharacterState, "addon load should initialize SavedVariables")
            assert.equals(getDefault("hidden"), env.GrimCharacterState.hidden, "addon load should honor the configured hidden default")
            assert.equals(nil, env.GrimCharacterState.debugEnabled, "addon load should not persist debug mode to SavedVariables")
            assert.equals(false, context.ns.GrimDebugState.IsEnabled(), "addon load should start with debug mode disabled for the session")
            assert.equals(getDefault("logWindowShown"), env.GrimCharacterState.logWindowShown, "addon load should honor the configured log window default")
            assert.equals(false, GrimDebug:IsShown(), "addon load should keep the debug window hidden by default")

            assert.equals(true, dispatchEvent(controller, "PLAYER_LOGIN"), "dispatcher should fire registered login events")
            refreshUiFrames(context)
            assert.equals(env.GrimCharacterState.hidden ~= true, GrimMainFrame:IsShown(), "player login should apply the configured hidden default")
            assert.equals(false, context.GrimLog:IsShown(), "player login should keep the log window hidden during the intro demo")
            assert.equals(
                GrimMainFrame:IsShown() and env.GrimCharacterState.hasSeenIntroDemo ~= true,
                getIntroDemoState(GrimMainFrame) ~= nil,
                "player login should only start intro demo mode when the main window opens and the intro is still unseen"
            )
            assert.equals(
                GrimMainFrame:IsShown() and env.GrimCharacterState.hasSeenIntroDemo ~= true and "START GAME" or "LOCK IN",
                GrimMainFrame.lockButton:GetText(),
                "player login should only relabel the lock button when the intro is still unseen"
            )
            assert.equals(
                GrimMainFrame:IsShown() and env.GrimCharacterState.hasSeenIntroDemo ~= true,
                GrimMainFrame.lockButton:IsEnabled(),
                "player login should only enable the lock button as a dismiss action when the intro is still unseen"
            )
            assert.equals(false, GrimDebug:IsShown(), "player login should keep the debug window hidden while debug mode is off")

            GrimMainFrame:Show()
            assert.equals(false, env.GrimCharacterState.hidden, "showing the main window should persist it as visible")

            GrimMainFrame:Hide()
            assert.equals(true, env.GrimCharacterState.hidden, "hiding the main window should persist it as hidden")

            assert.equals(true, dispatchEvent(controller, "PLAYER_LOGIN"), "dispatcher should keep firing registered events after state changes")
            refreshUiFrames(context)
            assert.equals(false, GrimMainFrame:IsShown(), "player login should respect a previously hidden main window")
        end)

        it("reopens incomplete setup", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    collapsed = true,
                    hasSeenIntroDemo = true,
                }),
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            assert.equals(false, GrimMainFrame:IsShown(), "incomplete setup should not force open a saved-hidden main window")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "incomplete setup should not show before the main window opens")

            context.runSlash("show")
            assert.is_truthy(GrimMainFrame:IsShown(), "show command should open the main window")
            assert.equals(false, GrimMainFrame.isCollapsed, "first-open setup should expand the main window before showing setup")
            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "first main-window open should show incomplete setup")
            assert.equals(false, env.GrimCharacterState.hidden, "opening the main window should persist it as visible")
            assert.equals(false, env.GrimCharacterState.collapsed, "first-open setup should persist the expanded main window")

            GrimMainFrame.setupFrame:Hide()
            GrimMainFrame:Hide()
            context.runSlash("show")
            assert.is_truthy(GrimMainFrame:IsShown(), "show command should reopen the main window")
            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "incomplete setup should show again when the main window reopens")
        end)

        it("opens setup before normal gameplay", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    collapsed = false,
                    hasSeenIntroDemo = false,
                }),
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            context.runSlash("show")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "first main-window open should keep setup hidden during intro demo")
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "first main-window open should start intro demo before setup")
            assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "intro demo should relabel the lock button")

            GrimMainFrame.lockButton:GetScript("OnClick")()
            assert.equals(true, env.GrimCharacterState.hasSeenIntroDemo, "starting the game should persist intro demo completion")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "starting the game should end intro demo mode")
            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "starting the game should show incomplete setup")

            GrimMainFrame.setupFrame.enableDeathAnnouncementsButton:Click()
            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "partially complete setup should stay visible")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "partially complete setup should not restart the intro demo")

            GrimMainFrame.setupFrame.joinHardcoreDeathsButton:Click()
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "completed setup should hide the setup window")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "completed setup should reveal normal gameplay without restarting the demo")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "completed setup should leave the normal lock action visible")
        end)

        it("resumes intro demo before incomplete setup", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    collapsed = false,
                    hasSeenIntroDemo = false,
                }),
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            context.runSlash("show")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "intro demo should keep setup hidden before hiding")
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "first main-window open should start intro demo before hiding")
            local demoState = getIntroDemoState(GrimMainFrame)

            GrimMainFrame:Hide()
            assert.equals(false, GrimMainFrame:IsShown(), "hiding the main window should hide the main frame")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "hiding the main window should not open setup")
            assert.equals(false, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "hiding the main window should keep the setup backdrop hidden")
            assert.equals(demoState, getIntroDemoState(GrimMainFrame), "hiding the main window should suspend the active intro demo")
            assert.equals(false, env.GrimCharacterState.hasSeenIntroDemo, "hiding during intro demo should not mark it as seen")

            context.runSlash("show")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "incomplete setup should remain hidden while the resumed demo is active")
            assert.equals(demoState, getIntroDemoState(GrimMainFrame), "reopening the main window should resume the same intro demo")
            assert.equals(true, GrimMainFrame.introDemoAttractPanel:IsShown(), "reopening the main window should restore the demo callout")
        end)

        it("rebinds UI to the SavedVariables table on load", function()
            local savedDatabase = Fixtures.addonDatabase({
                hasSeenIntroDemo = true,
                lockedPrediction = Fixtures.prediction({
                    levelRange = "10-19",
                }),
                recentDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Saveddeath",
                        sourceName = "Savedsource",
                    }),
                },
                deathHistory = {
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Saveddeath",
                        sourceName = "Savedsource",
                        awardedPoints = 7,
                        points = 7,
                        predictionStreak = 1,
                    }),
                },
                successfullyPredictedDeaths = {
                    Fixtures.storedDeath({
                        timestamp = 100,
                        name = "Saveddeath",
                        sourceName = "Savedsource",
                        awardedPoints = 7,
                        points = 7,
                        predictionStreak = 1,
                    }),
                },
            })

            local context = createAddonContext()
            local controller = context.controller

            env.GrimCharacterState = savedDatabase
            context.dispatchEvent(controller, "ADDON_LOADED", "GrimGuesser")
            refreshUiFrames(context)

            local GrimMainFrame = context.GrimMainFrame

            assert.equals(savedDatabase, GrimMainFrame.state, "addon load should rebind the UI to the loaded SavedVariables table")
            assert.equals(nil, GrimMainFrame.deathRows[1].name, "addon load should not create the removed main-window name column")
            assert.equals("Savedsource", GrimMainFrame.deathRows[1].sourceName:GetText(), "addon load should populate recent deaths from the loaded SavedVariables table")
            assert.equals(
                "Savedsource",
                context.GrimLog.rows[1].sourceName:GetText(),
                "addon load should populate successful history rows with death sources from the loaded SavedVariables table"
            )
        end)

        it("does not persist a visible main window as hidden on reload", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            assert.is_truthy(GrimMainFrame:IsShown(), "startup should show the main window before the reload simulation")
            assert.equals(true, dispatchEvent(controller, "PLAYER_LOGOUT"), "logout should dispatch before the reload simulation")

            GrimMainFrame:Hide()
            assert.equals(
                false,
                env.GrimCharacterState.hidden,
                "shutdown-time hides should not persist the main window as hidden during reload"
            )

            local reloadedContext = createLoadedAddonContext({
                state = env.GrimCharacterState,
                login = true,
            })

            assert.is_truthy(
                reloadedContext.GrimMainFrame:IsShown(),
                "reload should restore the main window when it was visible before shutdown"
            )
        end)
    end)

    describe("debug and commands", function()
        it("registers all Grim Guesser aliases without the old command", function()
            local context = createLoadedAddonContext()
            assert.equals("/gg", env.SLASH_GRIM1)
            assert.equals("/grimguesser", env.SLASH_GRIM2)
            assert.equals("/hgg", env.SLASH_GRIM3)
            assert.is_nil(env.SLASH_DEATHPOOL1)
            assert.is_nil(env.SlashCmdList.DEATHPOOL)

            local handler = env.SlashCmdList.GRIM
            assert.is_function(handler, "all registered aliases should have a shared handler")
            handler("hide")
            assert.is_false(context.GrimMainFrame:IsShown(), "the shared handler should hide the window")
            handler("show")
            assert.is_true(context.GrimMainFrame:IsShown(), "the shared handler should show the window")
        end)

        it("prints debug logs only when debug mode is enabled", function()
            local context = createLoadedAddonContext()
            local chatMessages = context.chatMessages
            local debugApi = context.ns.GrimDebug

            assert.equals(0, #chatMessages, "addon load should not print chat announcements")

            debugApi.Log("hidden debug message")
            assert.equals(0, #chatMessages, "debug log should stay silent while debug mode is disabled")

            assert.is_function(env.SlashCmdList.GRIM, "slash command should register the global handler")
            assert.equals("/gg", env.SLASH_GRIM1, "slash command should register the expected alias")
            env.SlashCmdList.GRIM("debug")
            local messageCountAfterEnable = #chatMessages

            debugApi.Log("visible debug message")
            assert.is_string(chatMessages[#chatMessages], "debug log should print once debug mode is enabled")
            assert.matches("visible debug message", chatMessages[#chatMessages], 1, true, "debug log should print once debug mode is enabled")
            assert.equals(messageCountAfterEnable + 1, #chatMessages, "debug log should add one message while enabled")
        end)

        it("toggles the debug window and printing", function()
            local context = createLoadedAddonContext()
            local GrimDebug = context.GrimDebug
            local chatMessages = context.chatMessages

            env.SlashCmdList.GRIM("debug")
            assert.equals(true, context.ns.GrimDebugState.IsEnabled(), "debug command should enable shared debug mode")
            assert.equals(nil, env.GrimCharacterState.debugEnabled, "debug command should not write debug mode to SavedVariables")
            assert.equals(true, GrimDebug:IsShown(), "debug command should show the debug window while enabled")
            assert.is_truthy(string.find(chatMessages[#chatMessages], "enabled", 1, true), "debug command should print enable message")

            env.SlashCmdList.GRIM("debug")
            assert.equals(false, context.ns.GrimDebugState.IsEnabled(), "debug command should disable shared debug mode")
            assert.equals(nil, env.GrimCharacterState.debugEnabled, "debug command should keep SavedVariables free of debug mode state")
            assert.equals(false, GrimDebug:IsShown(), "debug command should hide the debug window while disabled")
            assert.is_truthy(string.find(chatMessages[#chatMessages], "disabled", 1, true), "debug command should announce disablement")
        end)

        it("clears legacy saved debug state on reload", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    debugEnabled = true,
                    hasSeenIntroDemo = true,
                }),
                login = true,
            })

            assert.equals(nil, env.GrimCharacterState.debugEnabled, "addon load should clear the legacy saved debug flag")
            assert.equals(false, context.ns.GrimDebugState.IsEnabled(), "legacy saved debug mode should not re-enable debug for the session")

            context.runSlash("debug")
            assert.equals(true, context.ns.GrimDebugState.IsEnabled(), "debug command should still enable runtime debug mode")

            local reloadedContext = createLoadedAddonContext({
                state = env.GrimCharacterState,
                login = true,
            })

            assert.equals(false, reloadedContext.getDebugFrame():IsShown(), "reload should bring the debug window back hidden")
            assert.equals(false, reloadedContext.ns.GrimDebugState.IsEnabled(), "reload should reset debug mode for the new session")
            assert.equals(nil, env.GrimCharacterState.debugEnabled, "reload should keep SavedVariables free of the debug flag")
        end)

        it("reports a demo-command error while collapsed", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    hasSeenIntroDemo = true,
                    collapsed = true,
                }),
            })
            local GrimMainFrame = context.GrimMainFrame
            local chatMessages = context.chatMessages

            GrimMainFrame.introDemoController:Dismiss()
            GrimMainFrame:Hide()

            context.runSlash("demo")
            assert.equals(true, GrimMainFrame.isCollapsed, "demo command should leave the main window collapsed")
            assert.equals(false, GrimMainFrame:IsShown(), "demo command should not show the main window while collapsed")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "demo command should not start the intro preview while collapsed")
            assert.is_string(chatMessages[#chatMessages], "demo command should explain that the window must be expanded first")
            assert.matches(
                "Expand the main window",
                chatMessages[#chatMessages],
                1,
                true,
                "demo command should explain that the window must be expanded first"
            )
        end)

        it("resets introduction flags from the intro command", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    hasSeenIntroDemo = true,
                    hasSeenFirstRun = true,
                }),
            })
            local chatMessages = context.chatMessages

            context.runSlash("resetintro")
            assert.is_string(chatMessages[#chatMessages], "resetintro command should require debug mode before it will run")
            assert.matches(
                "requires debug mode",
                chatMessages[#chatMessages],
                1,
                true,
                "resetintro command should require debug mode before it will run"
            )

            context.runSlash("debug")
            context.runSlash("resetintro")
            assert.equals(false, env.GrimCharacterState.hasSeenIntroDemo, "resetintro command should re-enable the intro demo")
            assert.equals(false, env.GrimCharacterState.hasSeenFirstRun, "resetintro command should re-enable the first-run prompt")
            assert.is_string(chatMessages[#chatMessages], "resetintro command should confirm that the introduction was enabled")
            assert.matches(
                "Introduction enabled",
                chatMessages[#chatMessages],
                1,
                true,
                "resetintro command should confirm that the introduction was enabled"
            )
        end)

        it("requires debug mode for the reset command", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    hasSeenFirstRun = true,
                    logWindowShown = true,
                    showInCombat = true,
                    collapsed = true,
                    totalPoints = 88,
                    recentDeaths = {
                        Fixtures.storedDeath({
                            timestamp = 100,
                            name = "Saveddeath",
                        }),
                    },
                }),
                login = true,
            })
            local chatMessages = context.chatMessages

            context.runSlash("reset")
            assert.is_string(chatMessages[#chatMessages], "reset command should require debug mode before it will run")
            assert.matches(
                "requires debug mode",
                chatMessages[#chatMessages],
                1,
                true,
                "reset command should require debug mode before it will run"
            )

            context.runSlash("debug")
            context.runSlash("reset")
            assert.equals(true, env.GrimCharacterState.hidden, "reset command should hide the main window when it runs")
        end)

        describe("slash command routing", function()
            it("toggles main-window visibility", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                    }),
                    login = true,
                })
                local GrimMainFrame = context.GrimMainFrame
                local GrimLog = context.GrimLog

                context.runSlash("  hide  ")
                assert.equals(false, GrimMainFrame:IsShown(), "hide command should hide the main window")
                assert.equals(true, env.GrimCharacterState.hidden, "hide command should persist the main window as hidden")

                context.runSlash("show")
                assert.is_truthy(GrimMainFrame:IsShown(), "show command should show the main window")
                assert.equals(false, env.GrimCharacterState.hidden, "show command should persist the main window as visible")

                context.runSlash("toggle")
                assert.equals(false, GrimMainFrame:IsShown(), "toggle command should hide the main window when it starts visible")

                context.runSlash("")
                assert.is_truthy(GrimMainFrame:IsShown(), "empty command should behave like toggle and show the main window")
                assert.equals(false, GrimLog:IsShown(), "showing the main window again should keep the default hidden log window closed")
            end)

            it("toggles the history window", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                    }),
                    login = true,
                })
                local GrimLog = context.GrimLog

                context.runSlash("log")
                assert.is_truthy(GrimLog:IsShown(), "log command should show the history window when it starts hidden")
                assert.equals(true, env.GrimCharacterState.logWindowShown, "log command should persist the desired open state")

                context.runSlash("log")
                assert.equals(false, GrimLog:IsShown(), "log command should hide the history window after it was opened")
                assert.equals(false, env.GrimCharacterState.logWindowShown, "log command should persist the desired closed state")
            end)

            it("opens setup from visible, collapsed, and hidden states", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                    }),
                    login = true,
                })
                local GrimMainFrame = context.GrimMainFrame

                context.runSlash("setup")
                assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "setup command should show the setup window")

                context.GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, true)
                context.runSlash("setup")
                assert.equals(false, GrimMainFrame.isCollapsed, "setup command should expand the main window before showing setup")
                assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "setup command should keep setup visible after expanding the main window")

                GrimMainFrame:Hide()
                assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "hiding the main window should close slash-opened setup")
                assert.equals(false, GrimMainFrame.setupFrame.backdropOverlay:IsShown(), "hiding the main window should clear slash-opened setup backdrop")
                context.runSlash("setup")
                assert.is_truthy(GrimMainFrame:IsShown(), "setup command should show the main window")
                assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "setup command should keep the setup window shown after showing main")
            end)

            it("toggles debug, combat, and minimap settings", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                        showInCombat = true,
                        minimap = {
                            hide = false,
                        },
                    }),
                    login = true,
                })
                local chatMessages = context.chatMessages

                context.runSlash("debug")
                assert.equals(true, context.ns.GrimDebugState.IsEnabled(), "debug command should reach the debug toggle branch")

                context.runSlash("showincombat")
                assert.equals(false, env.GrimCharacterState.showInCombat, "showincombat command should reach the combat setting branch")

                context.runSlash("minimap")
                assert.equals(true, env.GrimCharacterState.minimap.hide, "minimap command should hide the minimap icon")
                assert.is_string(chatMessages[#chatMessages], "minimap command should announce disablement")
                assert.matches("Minimap icon disabled", chatMessages[#chatMessages], 1, true, "minimap command should announce disablement")

                context.runSlash("minimap")
                assert.equals(false, env.GrimCharacterState.minimap.hide, "minimap command should show the minimap icon again")
                assert.is_string(chatMessages[#chatMessages], "minimap command should announce enablement")
                assert.matches("Minimap icon enabled", chatMessages[#chatMessages], 1, true, "minimap command should announce enablement")
            end)

            it("resets the main window and disables the mini log", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                        collapsed = true,
                        windowPosition = {
                            point = "BOTTOMRIGHT",
                            relativePoint = "BOTTOMRIGHT",
                            x = -75,
                            y = 125,
                        },
                    }),
                    login = true,
                })
                local GrimMainFrame = context.GrimMainFrame
                local chatMessages = context.chatMessages

                context.runSlash("resetui")

                assert.equals(false, GrimMainFrame.isCollapsed, "resetui command should disable the mini log")
                assert.equals(false, env.GrimCharacterState.collapsed, "resetui command should persist the expanded state")
                assert.equals(nil, env.GrimCharacterState.windowPosition, "resetui command should clear the saved main window position")
                assert.same({ "CENTER" }, GrimMainFrame.points[1], "resetui command should center the main window")
                assert.is_string(chatMessages[#chatMessages], "resetui command should announce completion")
                assert.matches("Main window position reset", chatMessages[#chatMessages], 1, true, "resetui command should announce completion")
            end)

            it("prints the compact summary", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                        deathHistory = {
                            Fixtures.storedDeath({
                                timestamp = 100,
                                sourceName = "Hogger",
                                zone = "Elwynn Forest",
                                level = 12,
                            }),
                            Fixtures.storedDeath({
                                timestamp = 200,
                                sourceName = "Murloc Forager",
                                zone = "Darkshore",
                                level = 22,
                            }),
                            Fixtures.storedDeath({
                                timestamp = 300,
                                sourceName = "Murloc Forager",
                                zone = "Darkshore",
                                level = 24,
                            }),
                        },
                    }),
                    login = true,
                })
                local chatMessages = context.chatMessages

                local messageCountBeforeSummary = #chatMessages
                context.runSlash("summary")
                assert.equals(messageCountBeforeSummary + 6, #chatMessages, "summary command should print a compact summary")
                assert.is_string(chatMessages[messageCountBeforeSummary + 1], "summary command should print sample size")
                assert.matches("Summary: 3 retained deaths", chatMessages[messageCountBeforeSummary + 1], 1, true, "summary command should print sample size")
                assert.is_string(chatMessages[messageCountBeforeSummary + 2], "summary command should print deadliest source")
                assert.matches("Murloc Forager", chatMessages[messageCountBeforeSummary + 2], 1, true, "summary command should print deadliest source")
                assert.is_string(chatMessages[messageCountBeforeSummary + 3], "summary command should print deadliest location")
                assert.matches("Darkshore", chatMessages[messageCountBeforeSummary + 3], 1, true, "summary command should print deadliest location")
                assert.is_string(chatMessages[messageCountBeforeSummary + 4], "summary command should print deadliest level")
                assert.matches("20-29", chatMessages[messageCountBeforeSummary + 4], 1, true, "summary command should print deadliest level")
                assert.is_string(chatMessages[messageCountBeforeSummary + 6], "summary command should print recent pattern")
                assert.matches("Darkshore repeated", chatMessages[messageCountBeforeSummary + 6], 1, true, "summary command should print recent pattern")
            end)

            it("opens the demo and lists commands in help", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                    }),
                    login = true,
                })
                local GrimMainFrame = context.GrimMainFrame
                local chatMessages = context.chatMessages

                context.runSlash("debug")

                context.runSlash("demo")
                assert.is_not_nil(getIntroDemoState(GrimMainFrame), "demo command should reach the intro demo branch")

                local messageCountBeforeHelp = #chatMessages
                context.runSlash("help")
                local sawIntroHelp = false
                local sawSetupHelp = false
                local sawSummaryHelp = false
                local sawResetUIHelp = false
                for messageIndex = messageCountBeforeHelp + 1, #chatMessages do
                    if string.find(chatMessages[messageIndex], "/grimguesser resetintro", 1, true) then
                        sawIntroHelp = true
                    end
                    if string.find(chatMessages[messageIndex], "/grimguesser setup", 1, true) then
                        sawSetupHelp = true
                    end
                    if string.find(chatMessages[messageIndex], "/grimguesser summary", 1, true) then
                        sawSummaryHelp = true
                    end
                    if string.find(chatMessages[messageIndex], "/grimguesser resetui", 1, true) then
                        sawResetUIHelp = true
                    end
                end
                assert.equals(true, sawIntroHelp, "help command should list the resetintro command")
                assert.equals(true, sawSetupHelp, "help command should list the setup command")
                assert.equals(true, sawSummaryHelp, "help command should list the summary command")
                assert.equals(true, sawResetUIHelp, "help command should list the resetui command")
            end)

            it("handles debugdeath and testdeath developer commands", function()
                local context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        hidden = false,
                        hasSeenIntroDemo = true,
                    }),
                    login = true,
                })
                local chatMessages = context.chatMessages

                context.runSlash("debug")

                local messageCountBeforeMissingDebugDeath = #chatMessages
                context.runSlash("debugdeath")
                assert.equals(messageCountBeforeMissingDebugDeath + 1, #chatMessages, "debugdeath with no payload should print usage")

                local messageCountBeforeBadDebugDeath = #chatMessages
                context.runSlash("debugdeath definitely not a death message")
                assert.equals(messageCountBeforeBadDebugDeath + 1, #chatMessages, "debugdeath with bad text should print the no-match message")

                local recentDeathCountBeforeTestDeath = #(env.GrimCharacterState.recentDeaths or {})
                context.runSlash("testdeath")
                assert.equals(
                    recentDeathCountBeforeTestDeath + 1,
                    #env.GrimCharacterState.recentDeaths,
                    "testdeath command should add a synthetic death row"
                )
                assert.equals(
                    "Defias Pillager",
                    env.GrimCharacterState.recentDeaths[#env.GrimCharacterState.recentDeaths].server,
                    "testdeath command should persist the current server on stored death rows"
                )
            end)
        end)
    end)

    describe("intro demo", function()
        it("starts and dismisses the intro demo on first show", function()
            local context = createLoadedAddonContext()
            local GrimMainFrame = context.GrimMainFrame

            assert.equals(getDefault("hasSeenIntroDemo"), env.GrimCharacterState.hasSeenIntroDemo, "addon load should honor the configured intro demo default")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "addon load should not enter intro demo mode before the main window opens")

            GrimMainFrame:Show()
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "first show should activate the intro demo")
            assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "first show should relabel the lock button to start game")
            assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "first show should begin the scripted demo at zero score")

            GrimMainFrame.lockButton:GetScript("OnClick")()
            assert.equals(true, env.GrimCharacterState.hasSeenIntroDemo, "dismissing the intro demo should persist completion")
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "dismissing the intro demo should restore live data")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "starting the game should skip setup when it is already complete")
            assert.equals("LOCK IN", GrimMainFrame.lockButton:GetText(), "dismissing the intro demo should restore the lock button label")
            assert.equals(false, context.GrimLog:IsShown(), "dismissing the intro demo should keep the default hidden log window closed")
            assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "dismissing the intro demo should return to the empty live score")
        end)

        it("reopens the intro preview from the demo command", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    hasSeenIntroDemo = true,
                }),
            })
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.introDemoController:Dismiss()
            GrimMainFrame:Hide()

            context.runSlash("demo")
            assert.equals(true, GrimMainFrame:IsShown(), "demo command should show the main window")
            assert.equals(false, env.GrimCharacterState.hidden, "demo command should persist the main window as visible")
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "demo command should restore the intro preview state")
            assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "demo command should relabel the lock button to start game")
            assert.equals("0", GrimMainFrame.totalPointsValue:GetText(), "demo command should restart the scripted demo from zero score")
            assert.equals(true, env.GrimCharacterState.hasSeenIntroDemo, "demo command should not reset the completion flag")
        end)

        it("opens incomplete setup after a replayed demo starts", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    hasSeenIntroDemo = true,
                }),
                hardcoreDeathChatType = "0",
                hardcoreDeathsJoined = false,
            })
            local GrimMainFrame = context.GrimMainFrame

            context.runSlash("demo")
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "demo command should start the replayed intro demo")
            assert.equals(false, GrimMainFrame.setupFrame:IsShown(), "replayed demo should hide incomplete setup while active")

            GrimMainFrame.lockButton:GetScript("OnClick")()
            assert.equals(nil, getIntroDemoState(GrimMainFrame), "starting the game should end the replayed demo")
            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "starting the game from a replayed demo should show incomplete setup")
        end)

        it("does not complete the intro demo when the main window hides", function()
            local context = createLoadedAddonContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame:Show()
            GrimMainFrame.introDemoController:Show()

            GrimMainFrame:Hide()

            assert.equals("START GAME", GrimMainFrame.lockButton:GetText(), "hiding the main window should preserve the demo action")
            assert.equals(true, getIntroDemoState(GrimMainFrame) ~= nil, "hiding the main window should preserve the intro demo")
            assert.equals(false, env.GrimCharacterState.hasSeenIntroDemo, "hiding the main window should not mark the intro demo as seen")
        end)
    end)

    describe("window state and combat", function()
        it("closes the log when the main window hides", function()
            local context = createLoadedAddonContext()
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            GrimMainFrame.collapsedWindowStates = {
                logFrame = true,
            }
            GrimLog:Show()
            GrimMainFrame:Show()

            GrimMainFrame:Hide()

            assert.equals(false, GrimLog:IsShown(), "hiding the main window should close the log window")
            assert.equals(
                false,
                env.GrimCharacterState.logWindowShown,
                "hiding the main window should preserve the desired hidden log window state"
            )
        end)

        it("closes the log without remembering its state when setup opens", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    logWindowShown = false,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local GrimLog = context.GrimLog

            context.runSlash("log")
            assert.is_truthy(GrimLog:IsShown(), "log command should show the log before setup opens")
            assert.equals(true, env.GrimCharacterState.logWindowShown, "log command should persist the desired open state")

            context.runSlash("setup")

            assert.is_truthy(GrimMainFrame.setupFrame:IsShown(), "setup command should show setup")
            assert.equals(false, GrimLog:IsShown(), "setup should close the log window")
            assert.equals(
                true,
                env.GrimCharacterState.logWindowShown,
                "setup should not persist a closed desired log state"
            )

            context.GrimUI.SetLogWindowShown(GrimMainFrame, env.GrimCharacterState, false)
            context.runSlash("log")

            assert.equals(true, env.GrimCharacterState.logWindowShown, "log command should still update desired log state")
            assert.equals(false, GrimLog:IsShown(), "setup should keep the log hidden when log is toggled open")
        end)

        it("restores an open log window after reload", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    collapsed = false,
                    logWindowShown = true,
                }),
                login = true,
            })

            assert.is_truthy(context.GrimMainFrame:IsShown(), "startup should show the main window when it is not hidden")
            assert.is_truthy(context.GrimLog:IsShown(), "startup should restore the log window when its saved preference is open")
        end)

        it("restores the saved history filter after reload", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    collapsed = false,
                    logWindowShown = true,
                    historySuccessfulOnly = false,
                    deathHistory = {
                        Fixtures.storedDeath({
                            timestamp = 100,
                            name = "Savedallhistory",
                            sourceName = "Savedallsource",
                        }),
                    },
                    successfullyPredictedDeaths = {
                        Fixtures.storedDeath({
                            timestamp = 101,
                            name = "Savedsuccess",
                        }),
                    },
                }),
                login = true,
            })

            assert.equals(false, context.GrimLog.showSuccessfulOnly, "startup should restore the saved all-history filter mode")
            assert.equals("All Predictions", context.GrimLog.logSubtitle:GetText(), "startup should restore the saved all-history subtitle")
            assert.equals("SHOW SUCCESS ONLY", context.GrimLog.filterButton:GetText(), "startup should restore the alternate filter action")
            assert.equals("Savedallsource", context.GrimLog.rows[1].sourceName:GetText(), "startup should restore all-history rows as sources when that mode was saved")
        end)

        it("restores the saved collapsed-window position", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = true,
                    hasSeenIntroDemo = true,
                    collapsed = true,
                    collapsedWindowHeight = 98,
                    collapsedWindowPosition = {
                        point = "CENTER",
                        relativePoint = "CENTER",
                        x = -180,
                        y = 72,
                    },
                }),
            })
            local GrimMainFrame = context.GrimMainFrame

            assert.equals(350, GrimMainFrame.width, "addon load should restore the minimized width")
            assert.equals(100, GrimMainFrame.height, "addon load should restore the minimized height")
            assert.equals(-180, GrimMainFrame.points[1][4], "addon load should restore the saved minimized x offset")
            assert.equals(72, GrimMainFrame.points[1][5], "addon load should restore the saved minimized y offset")
        end)

        it("restores recent deaths when expanding a reloaded collapsed window", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    hasSeenFirstRun = true,
                    collapsed = true,
                    recentDeaths = {
                        Fixtures.storedDeath({
                            name = "Reloadmini",
                            level = 19,
                            sourceName = "Murloc",
                            zone = "Westfall",
                        }),
                    },
                }),
            })
            local GrimMainFrame = context.GrimMainFrame

            assert.equals(true, GrimMainFrame.isCollapsed, "startup should restore the saved mini-log state")
            assert.equals(false, GrimMainFrame.recentDeathsFrame:IsShown(), "collapsed startup should hide the expanded recent death pane")
            assert.equals("Murloc", GrimMainFrame.deathRows[1].sourceName:GetText(), "collapsed startup should still populate expanded death row data")

            context.GrimUI.SetWindowCollapsed(GrimMainFrame, env.GrimCharacterState, false)

            assert.equals(false, GrimMainFrame.isCollapsed, "expanding the mini-log should restore the expanded state")
            assert.equals(true, GrimMainFrame.recentDeathsFrame:IsShown(), "expanding the mini-log should show the expanded recent death pane")
            assert.equals(true, GrimMainFrame.deathRows[1]:IsShown(), "expanding the mini-log should show populated death rows")
            assert.equals("Murloc", GrimMainFrame.deathRows[1].sourceName:GetText(), "expanded death rows should show saved recent deaths")
        end)

        it("defaults combat auto-minimize to enabled", function()
            createLoadedAddonContext()

            assert.equals(getDefault("showInCombat"), env.GrimCharacterState.showInCombat, "addon load should honor the configured show-in-combat default")
        end)

        it("collapses a visible expanded window on combat", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    collapsed = false,
                    showInCombat = false,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            assert.equals(false, GrimMainFrame.isCollapsed, "window should begin expanded for the show-in-combat test")
            assert.equals(true, dispatchEvent(controller, "PLAYER_REGEN_DISABLED"), "combat event should dispatch when registered")
            assert.equals(true, GrimMainFrame.isCollapsed, "entering combat should collapse the visible main window when show-in-combat is disabled")
            assert.equals(true, env.GrimCharacterState.collapsed, "entering combat should persist the collapsed state")
        end)

        it("keeps the window visible in combat when enabled", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    collapsed = false,
                    showInCombat = false,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local chatMessages = context.chatMessages
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            context.runSlash("showincombat")
            assert.equals(true, env.GrimCharacterState.showInCombat, "showincombat command should enable showing the window in combat")
            assert.is_string(chatMessages[#chatMessages], "showincombat should announce enablement")
            assert.matches("Show in combat enabled", chatMessages[#chatMessages], 1, true, "showincombat should announce enablement")

            assert.equals(true, dispatchEvent(controller, "PLAYER_REGEN_DISABLED"), "combat event should still dispatch after toggling the setting")
            assert.equals(false, GrimMainFrame.isCollapsed, "entering combat should not collapse the main window while show-in-combat is enabled")
        end)

        it("closes and persists main-window state on escape", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame

            assert.is_truthy(GrimMainFrame:IsShown(), "startup should show the main window before escape is pressed")
            assert.equals(true, context.pressEscape(), "escape should close the special main window")
            assert.equals(false, GrimMainFrame:IsShown(), "escape should hide the main window")
            assert.equals(true, env.GrimCharacterState.hidden, "escape should persist the main window as hidden")
        end)

        it("does not close a collapsed main window on escape", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    collapsed = true,
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame

            assert.is_truthy(GrimMainFrame:IsShown(), "startup should show the collapsed main window before escape is pressed")
            assert.equals(true, GrimMainFrame.isCollapsed, "startup should keep the main window collapsed for the escape exclusion test")
            assert.equals(false, context.pressEscape(), "escape should not close the collapsed main window")
            assert.is_truthy(GrimMainFrame:IsShown(), "escape should leave the collapsed main window visible")
            assert.equals(false, env.GrimCharacterState.hidden, "escape should not persist the collapsed main window as hidden")
        end)
    end)

    describe("guild announcements", function()
        it("announces final score on player death", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                    },
                }),
                formatLargeNumber = formatFiveDigitTestScore,
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller
            local sendChatMessage = context.sendChatMessage

            assert.equals("12,345", GrimMainFrame.totalPointsValue:GetText(), "startup should show the pre-death running score")
            assert.equals("12,345", GrimMainFrame.collapsedPointsValue:GetText(), "startup should show the pre-death collapsed score")

            assert.equals(true, dispatchEvent(controller, "PLAYER_DEAD"), "player death should dispatch when registered")
            assert.equals(12345, env.GrimCharacterState.totalPoints, "player death should preserve the stored final score")
            assert.equals("12,345", GrimMainFrame.totalPointsValue:GetText(), "player death should leave the main score visible")
            assert.equals("12,345", GrimMainFrame.collapsedPointsValue:GetText(), "player death should leave the collapsed score visible")
            assert.is_truthy(string.find(context.chatMessages[#context.chatMessages], "score", 1, true), "player death should print the final score")
            assert.spy(sendChatMessage).was_called(1)
            assert.spy(sendChatMessage).was_called_with(
                "[Grim Guesser] Final score: 12,345",
                "GUILD"
            )
        end)

        it("skips death announcements when death announcements are disabled", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                        announceScoreOnDeath = false,
                    },
                }),
                login = true,
            })
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            assert.equals(true, dispatchEvent(controller, "PLAYER_DEAD"), "player death should still dispatch when guild announcement is disabled")
            assert.is_truthy(string.find(context.chatMessages[#context.chatMessages], "score", 1, true), "player death should still print the final score when guild announcement is disabled")
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("skips death announcements when guild announcements are disabled", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    totalPoints = 12345,
                    announcements = {
                        enabled = false,
                        announceScoreOnDeath = true,
                    },
                }),
                login = true,
            })
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller

            assert.equals(true, dispatchEvent(controller, "PLAYER_DEAD"), "player death should still dispatch when announcements are disabled")
            assert.is_truthy(string.find(context.chatMessages[#context.chatMessages], "score", 1, true), "player death should still print the final score when announcements are disabled")
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("skips death announcements outside a guild", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                        announceScoreOnDeath = true,
                    },
                }),
                inGuild = false,
                login = true,
            })

            assert.equals(
                true,
                context.dispatchEvent(context.controller, "PLAYER_DEAD"),
                "player death should still dispatch when the player is not in a guild"
            )
            assert.is_truthy(
                string.find(context.chatMessages[#context.chatMessages], "score", 1, true),
                "player death should still print the final score when the player is not in a guild"
            )
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("announces score every ten levels", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                    },
                }),
                formatLargeNumber = formatFiveDigitTestScore,
            })
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller
            local sendChatMessage = context.sendChatMessage

            assert.equals(true, dispatchEvent(controller, "PLAYER_LEVEL_UP", 10), "player level up should dispatch when registered")
            assert.spy(sendChatMessage).was_called(1)
            assert.spy(sendChatMessage).was_called_with(
                "[Grim Guesser] HarnessPlayer has reached level 10! Their score is 12,345",
                "GUILD"
            )

            sendChatMessage:clear()
            dispatchEvent(controller, "PLAYER_LEVEL_UP", 60)
            assert.spy(sendChatMessage).was_called(1)
            assert.spy(sendChatMessage).was_called_with(
                "[Grim Guesser] HarnessPlayer has reached level 60! Their score is 12,345",
                "GUILD"
            )
        end)

        it("skips levels between scheduled announcements", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                    },
                }),
            })

            assert.equals(
                true,
                context.dispatchEvent(context.controller, "PLAYER_LEVEL_UP", 19),
                "non-announcement level ups should still dispatch"
            )
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("skips level announcements when guild announcements are disabled", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    totalPoints = 12345,
                    announcements = {
                        enabled = false,
                    },
                }),
            })

            assert.equals(
                true,
                context.dispatchEvent(context.controller, "PLAYER_LEVEL_UP", 10),
                "player level up should dispatch while guild announcements are disabled"
            )
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("skips level announcements when level-up announcements are disabled", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                        announceScoreOnLevelUp = false,
                    },
                }),
            })

            assert.equals(
                true,
                context.dispatchEvent(context.controller, "PLAYER_LEVEL_UP", 10),
                "player level up should dispatch while level-up announcements are disabled"
            )
            assert.spy(context.sendChatMessage).was_not_called()
        end)

        it("skips level announcements outside a guild", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    totalPoints = 12345,
                    announcements = {
                        enabled = true,
                        announceScoreOnLevelUp = true,
                    },
                }),
                inGuild = false,
            })

            assert.equals(
                true,
                context.dispatchEvent(context.controller, "PLAYER_LEVEL_UP", 10),
                "player level up should still dispatch when the player is not in a guild"
            )
            assert.spy(context.sendChatMessage).was_not_called()
        end)
    end)

    describe("settings", function()
        it("defaults death announcements to enabled", function()
            local context = createLoadedAddonContext()

            assert.equals(
                getDefault("announcements").enabled,
                env.GrimCharacterState.announcements.enabled,
                "addon load should honor the configured guild announcement default"
            )
            assert.equals(
                getDefault("announcements").announceScoreOnDeath,
                env.GrimCharacterState.announcements.announceScoreOnDeath,
                "addon load should honor the configured death announcement default"
            )

            assert.equals(
                getDefault("announcements").enabled,
                context.ns.GrimUISettings.guildAnnouncementsEnabledCheckbox:GetChecked(),
                "settings panel should show the configured guild announcement default"
            )
            assert.equals(
                getDefault("announcements").enabled,
                context.ns.GrimUISettings.announceDeathToGuildCheckbox:IsEnabled(),
                "settings panel should enable guild announcement options from the configured default"
            )
        end)

        it("registers settings and reflects saved state", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    announcements = {
                        enabled = true,
                        announceScoreOnDeath = true,
                        announceScoreOnLevelUp = false,
                    },
                    minimap = {
                        hide = true,
                    },
                    showInCombat = true,
                }),
            })

            local category = env.Settings.registeredAddOnCategories[#env.Settings.registeredAddOnCategories]
            ---@type GrimUISettingsPanelModule
            local settingsModule = context.ns.GrimUISettings
            local function getRelativeToAndXOffset(region)
                local _, relativeTo, _, x = region:GetPoint(1)
                return relativeTo, x
            end

            assert.is_not_nil(category, "settings panel should register an addon category")
            assert.is_not_nil(category.frame, "settings panel should register a category frame")
            assert.equals("Grim Guesser", category.frame.name, "settings panel should register the Grim Guesser category")
            assert.equals("Grim Guesser", category.name, "settings panel should register the full addon display name")

            category.frame:Show()
            assert.equals(
                true,
                settingsModule.guildAnnouncementsEnabledCheckbox:GetChecked(),
                "settings panel should reflect saved guild announcements enabled state"
            )
            assert.equals(
                true,
                settingsModule.announceDeathToGuildCheckbox:GetChecked(),
                "settings panel should reflect saved death announcement state"
            )
            assert.equals(
                true,
                settingsModule.announceDeathToGuildCheckbox:IsEnabled(),
                "settings panel should enable death announcements when guild announcements are enabled"
            )
            assert.equals(
                false,
                settingsModule.announceScoreOnLevelUpCheckbox:GetChecked(),
                "settings panel should reflect saved level-up announcement state"
            )
            assert.equals(
                true,
                settingsModule.announceScoreOnLevelUpCheckbox:IsEnabled(),
                "settings panel should enable level-up announcements when guild announcements are enabled"
            )
            assert.equals(
                "Announce score every " .. GrimConstants.ANNOUNCEMENTS.levelUpFrequency .. " levels",
                settingsModule.announceScoreOnLevelUpCheckbox.label:GetText(),
                "settings panel should build the level-up label from the announcement frequency constant"
            )
            local deathRelativeTo, deathX = getRelativeToAndXOffset(settingsModule.announceDeathToGuildCheckbox)
            assert.equals(
                settingsModule.guildAnnouncementsEnabledCheckbox,
                deathRelativeTo,
                "settings panel should anchor death announcements under the guild announcement master setting"
            )
            assert.equals(24, deathX, "settings panel should indent death announcements under the guild announcement master setting")

            local levelUpRelativeTo, levelUpX = getRelativeToAndXOffset(settingsModule.announceScoreOnLevelUpCheckbox)
            assert.equals(
                settingsModule.announceDeathToGuildCheckbox,
                levelUpRelativeTo,
                "settings panel should anchor level-up announcements under death announcements"
            )
            assert.equals(0, levelUpX, "settings panel should align level-up and death announcements")

            local minimapRelativeTo, minimapX = getRelativeToAndXOffset(settingsModule.disableMinimapIconCheckbox)
            assert.equals(
                settingsModule.announceScoreOnLevelUpCheckbox,
                minimapRelativeTo,
                "settings panel should place minimap settings after announcement settings"
            )
            assert.equals(-24, minimapX, "settings panel should return minimap settings to the top-level alignment")
            assert.equals(
                true,
                settingsModule.showInCombatCheckbox:GetChecked(),
                "settings panel should reflect saved show-in-combat state"
            )
            assert.equals(
                true,
                settingsModule.disableMinimapIconCheckbox:GetChecked(),
                "settings panel should reflect saved minimap icon state"
            )
        end)

        it("rebinds settings checkboxes to latest options", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    showInCombat = false,
                }),
            })

            ---@type GrimUISettingsPanelModule
            local settingsModule = context.ns.GrimUISettings
            local reboundState = Fixtures.addonDatabase({
                announcements = {
                    enabled = true,
                    announceScoreOnDeath = true,
                    announceScoreOnLevelUp = false,
                },
                minimap = {
                    hide = true,
                },
                showInCombat = true,
            })

            settingsModule.Initialize({
                GetDisableMinimapIcon = function()
                    return GrimDatabase.GetMinimapHidden(reboundState)
                end,
                GetDeathAnnouncementToGuild = function()
                    return GrimDatabase.GetAnnounceDeathToGuild(reboundState)
                end,
                GetGuildAnnouncementsEnabled = function()
                    return GrimDatabase.GetGuildAnnouncementsEnabled(reboundState)
                end,
                GetAnnounceScoreOnLevelUp = function()
                    return GrimDatabase.GetAnnounceScoreOnLevelUp(reboundState)
                end,
                GetShowInCombat = function()
                    return GrimDatabase.GetShowInCombat(reboundState)
                end,
                SetDisableMinimapIcon = function(disabled)
                    return GrimDatabase.SetMinimapHidden(reboundState, disabled)
                end,
                SetDeathAnnouncementToGuild = function(enabled)
                    return GrimDatabase.SetAnnounceDeathToGuild(reboundState, enabled)
                end,
                SetGuildAnnouncementsEnabled = function(enabled)
                    return GrimDatabase.SetGuildAnnouncementsEnabled(reboundState, enabled)
                end,
                SetAnnounceScoreOnLevelUp = function(enabled)
                    return GrimDatabase.SetAnnounceScoreOnLevelUp(reboundState, enabled)
                end,
                SetShowInCombat = function(enabled)
                    return GrimDatabase.SetShowInCombat(reboundState, enabled)
                end,
            })

            assert.equals(
                true,
                settingsModule.guildAnnouncementsEnabledCheckbox:GetChecked(),
                "settings initialize should refresh guild announcements enabled state from the latest options"
            )
            assert.equals(
                true,
                settingsModule.announceDeathToGuildCheckbox:GetChecked(),
                "settings initialize should refresh death announcement state from the latest options"
            )
            assert.equals(
                true,
                settingsModule.announceDeathToGuildCheckbox:IsEnabled(),
                "settings initialize should enable death announcements when latest options enable guild announcements"
            )
            assert.equals(
                false,
                settingsModule.announceScoreOnLevelUpCheckbox:GetChecked(),
                "settings initialize should refresh level-up announcement state from the latest options"
            )
            assert.equals(
                true,
                settingsModule.announceScoreOnLevelUpCheckbox:IsEnabled(),
                "settings initialize should enable level-up announcements when latest options enable guild announcements"
            )
            assert.equals(
                true,
                settingsModule.showInCombatCheckbox:GetChecked(),
                "settings initialize should refresh show-in-combat from the latest options"
            )
            assert.equals(
                true,
                settingsModule.disableMinimapIconCheckbox:GetChecked(),
                "settings initialize should refresh minimap icon state from the latest options"
            )
        end)

        describe("settings checkbox handlers", function()
            local context
            local settingsModule

            before_each(function()
                context = createLoadedAddonContext({
                    state = Fixtures.addonDatabase({
                        announcements = {
                            enabled = false,
                            announceScoreOnDeath = false,
                            announceScoreOnLevelUp = false,
                        },
                        minimap = {
                            hide = false,
                        },
                        showInCombat = false,
                    }),
                })

                ---@type GrimUISettingsPanelModule
                settingsModule = context.ns.GrimUISettings
                settingsModule.categoryFrame:Show()
            end)

            it("toggles the master guild-announcement setting", function()
                settingsModule.guildAnnouncementsEnabledCheckbox:SetChecked(true)
                settingsModule.guildAnnouncementsEnabledCheckbox:Click()
                assert.equals(
                    true,
                    env.GrimCharacterState.announcements.enabled,
                    "settings guild announcements checkbox should persist the enabled state"
                )
                assert.equals(
                    true,
                    settingsModule.announceDeathToGuildCheckbox:IsEnabled(),
                    "settings guild announcements checkbox should enable death announcement settings"
                )
                assert.equals(
                    true,
                    settingsModule.announceScoreOnLevelUpCheckbox:IsEnabled(),
                    "settings guild announcements checkbox should enable level-up announcement settings"
                )
                assert.equals(
                    false,
                    settingsModule.announceScoreOnLevelUpCheckbox:GetChecked(),
                    "enabling guild announcements should preserve the saved level-up announcement state"
                )
                settingsModule.guildAnnouncementsEnabledCheckbox:SetChecked(false)
                settingsModule.guildAnnouncementsEnabledCheckbox:Click()
                assert.equals(
                    false,
                    env.GrimCharacterState.announcements.enabled,
                    "settings guild announcements checkbox should persist the disabled state"
                )
                assert.equals(
                    false,
                    settingsModule.announceDeathToGuildCheckbox:IsEnabled(),
                    "settings guild announcements checkbox should disable death announcement settings"
                )
                assert.equals(
                    false,
                    settingsModule.announceScoreOnLevelUpCheckbox:IsEnabled(),
                    "settings guild announcements checkbox should disable level-up announcement settings"
                )
                assert.equals(
                    false,
                    settingsModule.announceScoreOnLevelUpCheckbox:GetChecked(),
                    "disabling guild announcements should preserve the saved level-up announcement state"
                )
                settingsModule.guildAnnouncementsEnabledCheckbox:SetChecked(true)
                settingsModule.guildAnnouncementsEnabledCheckbox:Click()
            end)

            it("toggles show-in-combat", function()
                settingsModule.showInCombatCheckbox:SetChecked(true)
                settingsModule.showInCombatCheckbox:Click()
                assert.equals(
                    true,
                    env.GrimCharacterState.showInCombat,
                    "settings show-in-combat checkbox should persist the enabled state"
                )

                settingsModule.showInCombatCheckbox:SetChecked(false)
                settingsModule.showInCombatCheckbox:Click()
                assert.equals(
                    false,
                    env.GrimCharacterState.showInCombat,
                    "settings show-in-combat checkbox should persist the disabled state"
                )
            end)

            it("toggles death announcements", function()
                settingsModule.guildAnnouncementsEnabledCheckbox:SetChecked(true)
                settingsModule.guildAnnouncementsEnabledCheckbox:Click()

                settingsModule.announceDeathToGuildCheckbox:SetChecked(true)
                settingsModule.announceDeathToGuildCheckbox:Click()
                assert.equals(
                    true,
                    env.GrimCharacterState.announcements.announceScoreOnDeath,
                    "settings death announcement checkbox should persist the enabled state"
                )

                settingsModule.announceDeathToGuildCheckbox:SetChecked(false)
                settingsModule.announceDeathToGuildCheckbox:Click()
                assert.equals(
                    false,
                    env.GrimCharacterState.announcements.announceScoreOnDeath,
                    "settings death announcement checkbox should persist the disabled state"
                )
            end)

            it("toggles level-up announcements", function()
                settingsModule.guildAnnouncementsEnabledCheckbox:SetChecked(true)
                settingsModule.guildAnnouncementsEnabledCheckbox:Click()

                settingsModule.announceScoreOnLevelUpCheckbox:SetChecked(true)
                settingsModule.announceScoreOnLevelUpCheckbox:Click()
                assert.equals(
                    true,
                    env.GrimCharacterState.announcements.announceScoreOnLevelUp,
                    "settings level-up announcement checkbox should persist the enabled state"
                )

                settingsModule.announceScoreOnLevelUpCheckbox:SetChecked(false)
                settingsModule.announceScoreOnLevelUpCheckbox:Click()
                assert.equals(
                    false,
                    env.GrimCharacterState.announcements.announceScoreOnLevelUp,
                    "settings level-up announcement checkbox should persist the disabled state"
                )
            end)

            it("toggles the minimap icon through LibDBIcon", function()
                local libDBIcon = context.libDBIcon
                libDBIcon.Hide:clear()
                libDBIcon.Show:clear()
                settingsModule.disableMinimapIconCheckbox:SetChecked(true)
                settingsModule.disableMinimapIconCheckbox:Click()
                assert.equals(
                    true,
                    env.GrimCharacterState.minimap.hide,
                    "settings minimap checkbox should persist the disabled state"
                )
                assert.spy(libDBIcon.Hide).was_called(1)
                assert.spy(libDBIcon.Hide).was_called_with(match.is_ref(libDBIcon), "GrimGuesser")
                assert.spy(libDBIcon.Show).was_not_called()

                settingsModule.disableMinimapIconCheckbox:SetChecked(false)
                settingsModule.disableMinimapIconCheckbox:Click()
                assert.equals(
                    false,
                    env.GrimCharacterState.minimap.hide,
                    "settings minimap checkbox should persist the enabled state"
                )
                assert.spy(libDBIcon.Show).was_called(1)
                assert.spy(libDBIcon.Show).was_called_with(match.is_ref(libDBIcon), "GrimGuesser")
                assert.spy(libDBIcon.Hide).was_called(1)
            end)
        end)
    end)

    describe("event routing", function()
        it("skips unregistered events", function()
            local context = createAddonContext()

            assert.equals(
                false,
                context.dispatchEvent(context.controller, "PLAYER_ENTERING_WORLD"),
                "dispatcher should ignore events that were never registered"
            )
        end)

        it("does not register native hardcore death alerts", function()
            local context = createLoadedAddonContext()

            assert.equals(
                false,
                context.dispatchEvent(context.controller, "HARDCORE_DEATHS", "[Ignored] drowned in Durotar! They were level 6"),
                "native hardcore death alerts should not dispatch through the addon frame"
            )
        end)

        it("ignores deaths from non-hardcoredeaths channels", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                }),
                login = true,
            })

            assert.equals(
                true,
                context.dispatchEvent(
                    context.controller,
                    "CHAT_MSG_CHANNEL",
                    "[Ignored] drowned in Durotar! They were level 6",
                    "Sender",
                    "",
                    "1. General - Durotar",
                    "",
                    "",
                    0,
                    1,
                    "General - Durotar"
                ),
                "channel chat messages should dispatch through the addon frame"
            )
            assert.equals(0, #env.GrimCharacterState.recentDeaths, "non-hardcoredeaths channels should not insert deaths")
        end)

        it("routes HardcoreDeaths messages through parser, logic, and UI", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    lockedPrediction = Fixtures.prediction({
                        levelRange = "10-19",
                        source = "hogger",
                        zone = "elwynn forest",
                    }),
                    lastPrediction = Fixtures.prediction({
                        levelRange = "10-19",
                        source = "hogger",
                        zone = "elwynn forest",
                    }),
                }),
                login = true,
            })
            local GrimMainFrame = context.GrimMainFrame
            local GrimDebug = context.GrimDebug
            local GrimLog = context.GrimLog
            local GrimLogic = context.ns.GrimLogic
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller
            local waitingPromptMinDuration = DEMO_RULES.waitingForFirstDeathMinDurationSeconds
            local rawMessage = "[Drakedog] has been slain by Hogger in Elwynn Forest! They were level 12"

            assert.equals(
                true,
                dispatchEvent(
                    controller,
                    "CHAT_MSG_CHANNEL",
                    rawMessage,
                    "Sender",
                    "",
                    "5. HardcoreDeaths",
                    "",
                    "",
                    0,
                    5,
                    "HardcoreDeaths"
                ),
                "HardcoreDeaths channel messages should dispatch through the addon frame"
            )
            assert.equals(1, #env.GrimCharacterState.recentDeaths, "death event should insert a recent death row")
            assert.equals(1, #env.GrimCharacterState.deathHistory, "death event should insert a history death row")
            assert.equals(1, #env.GrimCharacterState.successfullyPredictedDeaths, "death event should record successful predictions")

            local storedDeath = env.GrimCharacterState.recentDeaths[1]
            local historyDeath = env.GrimCharacterState.deathHistory[1]
            local awardedPoints = GrimLogic.GetStoredDeathAwardedPoints(storedDeath)
            local comboMultiplier = GrimLogic.GetStoredDeathComboMultiplierValue(storedDeath)
            local totalMultiplier = GrimLogic.GetStoredDeathMultiplierValue(storedDeath)
            local basePoints = GrimLogic.GetStoredDeathBasePoints(storedDeath)
            local formattedAwardedPoints = env.FormatLargeNumber(awardedPoints)

            assert.equals("Drakedog", storedDeath.name, "parser flow should persist the parsed player name")
            assert.equals(12, storedDeath.level, "parser flow should persist the parsed level")
            assert.equals("Hogger", storedDeath.sourceName, "parser flow should persist the parsed source")
            assert.equals("Elwynn Forest", storedDeath.zone, "parser flow should persist the parsed zone")
            assert.equals("Defias Pillager", storedDeath.server, "insert flow should persist the current server name")
            assert.equals(true, storedDeath.matchedPrediction, "evaluation flow should mark the stored death as matched")
            assert.equals(GrimLogic.GetStoredDeathBasePoints(storedDeath), storedDeath.points, "evaluation flow should persist the matched base points")
            assert.equals(awardedPoints, storedDeath.awardedPoints, "evaluation flow should persist the awarded points")
            assert.equals(awardedPoints, env.GrimCharacterState.totalPoints, "evaluation flow should roll awarded points into the total score")
            assert.equals(1, env.GrimCharacterState.correctPredictionStreak, "evaluation flow should increment the current streak")
            assert.equals(1, env.GrimCharacterState.longestPredictionStreak, "evaluation flow should update the longest streak")
            assert.equals(true, historyDeath.matchedPrediction, "history insert should keep the evaluation result")
            assert.equals("elwynn forest", historyDeath.prediction.elements.zone, "history insert should preserve the locked prediction")
            assert.equals(true, storedDeath.sameZoneBonusApplied, "same-zone deaths should persist the applied same-zone bonus flag")

            assert.equals(true, GrimMainFrame.waitingPromptText:IsShown(), "ui refresh should keep the waiting prompt visible until the minimum intro duration completes")
            assert.equals(false, GrimMainFrame.deathRows[1]:IsShown(), "ui refresh should keep the recent deaths list hidden during the waiting prompt minimum duration")

            ---@diagnostic disable-next-line: need-check-nil
            GrimMainFrame:GetScript("OnUpdate")(GrimMainFrame, waitingPromptMinDuration)
            assert.equals("Hogger", GrimMainFrame.deathRows[1].sourceName:GetText(), "ui refresh should show the parsed death in the recent deaths list after the waiting prompt minimum duration")
            assert.equals(nil, GrimMainFrame.deathRows[1].multiplier, "ui refresh should omit the removed main-window combo column")
            assert.equals(tostring(awardedPoints), GrimMainFrame.deathRows[1].awardedPoints:GetText(), "ui refresh should show the evaluated total points after the waiting prompt minimum duration")
            assert.equals(formattedAwardedPoints, GrimMainFrame.totalPointsValue:GetText(), "ui refresh should show the updated total score")
            assert.equals("1", GrimMainFrame.currentStreakValue:GetText(), "ui refresh should show the updated current streak")
            assert.equals("Hogger", GrimMainFrame.collapsedLogFrame.rows[1].sourceName:GetText(), "ui refresh should update the collapsed death log")
            assert.equals(tostring(awardedPoints), GrimMainFrame.collapsedLogFrame.rows[1].awardedPoints:GetText(), "ui refresh should update the collapsed death log points")
            assert.equals(formattedAwardedPoints, GrimMainFrame.collapsedPointsValue:GetText(), "ui refresh should update the collapsed score")
            assert.equals("Hogger", GrimLog.rows[1].sourceName:GetText(), "ui refresh should update the successful history log with the death source")
            assert.equals(tostring(awardedPoints), GrimLog.rows[1].awardedPoints:GetText(), "ui refresh should update history totals")
            assert.equals("Drakedog", GrimDebug.detailValues.name:GetText(), "ui refresh should update the debug detail view")
            assert.equals(tostring(awardedPoints), GrimDebug.detailValues.totalPoints:GetText(), "ui refresh should update debug total points")
            assert.equals("1", GrimDebug.detailValues.currentPredictionStreak:GetText(), "ui refresh should update debug current streak")
            assert.is_string(GrimDebug.detailValues.lockedPrediction:GetText(), "ui refresh should update the debug locked prediction summary")
            assert.matches(
                "Level 10-19, source Hogger, or zone Elwynn Forest",
                GrimDebug.detailValues.lockedPrediction:GetText(),
                1,
                true,
                "ui refresh should update the debug locked prediction summary"
            )
            assert.equals(tostring(basePoints), GrimDebug.detailValues.basePoints:GetText(), "ui refresh should update debug base points")
            assert.equals("x" .. tostring(comboMultiplier), GrimDebug.detailValues.comboMultiplier:GetText(), "ui refresh should update debug combo bonus")
            assert.equals("x" .. tostring(totalMultiplier), GrimDebug.detailValues.multiplier:GetText(), "ui refresh should update debug total multiplier")
            assert.equals(
                storedDeath.sourceMessage,
                GrimDebug.detailValues.sourceMessage:GetText(),
                "ui refresh should update the debug raw message edit box"
            )
            assert.equals(tostring(awardedPoints), GrimDebug.detailValues.awardedPoints:GetText(), "ui refresh should update debug awarded points")
        end)

        it("skips same-zone bonuses without a matching zone", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    lockedPrediction = Fixtures.prediction({
                        levelRange = false,
                        source = "hogger",
                        zone = false,
                        zoneLabel = false,
                    }),
                    lastPrediction = Fixtures.prediction({
                        levelRange = false,
                        source = "hogger",
                        zone = false,
                        zoneLabel = false,
                    }),
                }),
                login = true,
            })
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller
            local GrimLogic = context.ns.GrimLogic
            local sourcePoints = LogicHelpers.getExpectedBasePoints({ source = true })
            local expectedAwardedPoints = sourcePoints * LogicHelpers.getDisplayMultiplier(1, 1)
            local rawMessage = "[Drakedog] has been slain by Hogger in Westfall! They were level 12"

            assert.equals(
                true,
                dispatchEvent(
                    controller,
                    "CHAT_MSG_CHANNEL",
                    rawMessage,
                    "Sender",
                    "",
                    "5. HardcoreDeaths",
                    "",
                    "",
                    0,
                    5,
                    "HardcoreDeaths"
                ),
                "HardcoreDeaths channel messages should still dispatch when the death is outside the player's current zone"
            )

            local storedDeath = env.GrimCharacterState.recentDeaths[1]
            assert.equals(false, storedDeath.sameZoneBonusApplied, "different-zone deaths should not persist the same-zone bonus flag")
            assert.equals(
                0,
                GrimLogic.GetStoredDeathSameZoneBonusPoints(storedDeath),
                "different-zone deaths should not award same-zone bonus points"
            )
            assert.equals(
                expectedAwardedPoints,
                GrimLogic.GetStoredDeathAwardedPoints(storedDeath),
                "different-zone deaths should keep the normal awarded score"
            )
        end)

        it("applies same-zone bonuses without a zone prediction", function()
            local context = createLoadedAddonContext({
                state = Fixtures.addonDatabase({
                    hidden = false,
                    hasSeenIntroDemo = true,
                    lockedPrediction = Fixtures.prediction({
                        levelRange = false,
                        source = "hogger",
                        zone = false,
                        zoneLabel = false,
                    }),
                    lastPrediction = Fixtures.prediction({
                        levelRange = false,
                        source = "hogger",
                        zone = false,
                        zoneLabel = false,
                    }),
                }),
                login = true,
            })
            local dispatchEvent = context.dispatchEvent
            local controller = context.controller
            local GrimLogic = context.ns.GrimLogic
            local sourcePoints = LogicHelpers.getExpectedBasePoints({ source = true })
            local sameZonePoints = context.ns.GrimConstants.SCORING.sameZoneFixedBonusPoints
            local expectedMultiplier = LogicHelpers.getDisplayMultiplier(1, 1)
            local rawMessage = "[Drakedog] has been slain by Hogger in Elwynn Forest! They were level 12"

            assert.equals(
                true,
                dispatchEvent(
                    controller,
                    "CHAT_MSG_CHANNEL",
                    rawMessage,
                    "Sender",
                    "",
                    "5. HardcoreDeaths",
                    "",
                    "",
                    0,
                    5,
                    "HardcoreDeaths"
                ),
                "HardcoreDeaths channel messages should still dispatch when same-zone bonus comes from a non-zone prediction"
            )

            local storedDeath = env.GrimCharacterState.recentDeaths[1]
            assert.equals(true, storedDeath.sameZoneBonusApplied, "same-zone deaths should persist the bonus flag even without a zone prediction")
            assert.equals(
                sameZonePoints,
                GrimLogic.GetStoredDeathSameZoneBonusPoints(storedDeath),
                "same-zone deaths should award bonus points even when zone was not predicted"
            )
            assert.equals(
                (sourcePoints + sameZonePoints) * expectedMultiplier,
                GrimLogic.GetStoredDeathAwardedPoints(storedDeath),
                "same-zone bonus should add into the total for non-zone predictions"
            )
        end)
    end)
end)
