local assert = require("luassert")
describe("Minimap integration", function()
    local spy = require("luassert.spy")
    local match = require("luassert.match")
    local AddonLoader = require("tests.support_addon_loader")

    local FORMATTED_SCORE_STUB_VALUES = {
        [1234] = "1,234",
        [12345] = "12,345",
    }

    ---@param value number
    ---@return string
    local function formatScoreStub(value)
        return FORMATTED_SCORE_STUB_VALUES[value] or tostring(value)
    end

    ---@param env table
    ---@return nil
    local function initializeEnvironment(env)
        env.GrimCharacterState = nil
        env.FormatLargeNumber = formatScoreStub
        env.strtrim = function(text)
            return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
        end
    end

    local function createButton(dataObject)
        local button = {
            dataObject = dataObject,
            icon = {
                texturePath = dataObject.icon,
            },
            scripts = {},
        }

        function button:GetScript(eventName)
            return self.scripts[eventName]
        end

        button.scripts.OnClick = dataObject.OnClick
        return button
    end

    ---@param env table
    ---@return table
    local function createLibStubs(env)
        local state = {}

        local libDataBroker = {}

        function libDataBroker.NewDataObject(_, name, dataObject)
            state.lastDataObjectName = name
            state.lastDataObject = dataObject
            return dataObject
        end

        local libDBIcon = {}
        state.libDBIcon = libDBIcon

        ---@param _ table
        ---@param _name string
        ---@param dataObject table
        ---@return nil
        libDBIcon.Register = spy.new(function(_, _name, dataObject)
            state.button = createButton(dataObject)
        end)

        libDBIcon.Refresh = spy.new()

        ---@return nil
        libDBIcon.Hide = spy.new(function()
            if state.button then
                state.button.hidden = true
            end
        end)

        ---@return nil
        libDBIcon.Show = spy.new(function()
            if state.button then
                state.button.hidden = false
            end
        end)

        function libDBIcon.GetMinimapButton()
            return state.button
        end

        ---@param libraryName string
        ---@param silent boolean|nil
        ---@return LibDataBrokerApi|LibDBIconApi|nil
        ---@overload fun(libraryName: "LibDataBroker-1.1", silent?: boolean): LibDataBrokerApi
        ---@overload fun(libraryName: "LibDBIcon-1.0", silent?: boolean): LibDBIconApi
        env.LibStub = function(libraryName, silent)
            local libraries = {
                ["LibDataBroker-1.1"] = libDataBroker,
                ["LibDBIcon-1.0"] = libDBIcon,
            }

            local library = libraries[libraryName]
            if library ~= nil then
                return library
            end

            if not silent then
                error("Unknown library: " .. tostring(libraryName))
            end

            return nil
        end

        return state
    end

    local function loadMinimapModule()
        local loader = AddonLoader.Create()
        initializeEnvironment(loader.env)
        local state = createLibStubs(loader.env)
        state.env = loader.env
        local module = loader:LoadThrough("GrimUIMinimap")
        return module, state, loader.ns
    end

    local function createFrame(options)
        options = options or {}

        local frame = {
            shown = options.shown == true,
            isCollapsed = options.isCollapsed == true,
            scripts = {},
        }

        function frame:SetScript(eventName, callback)
            self.scripts[eventName] = callback
        end

        function frame:GetScript(eventName)
            return self.scripts[eventName]
        end

        function frame:IsShown()
            return self.shown == true
        end

        function frame:Show()
            self.shown = true
            local onShow = self:GetScript("OnShow")
            if onShow then
                onShow(self)
            end
        end

        function frame:Hide()
            self.shown = false
            local onHide = self:GetScript("OnHide")
            if onHide then
                onHide(self)
            end
        end

        function frame:Raise()
            self.raised = true
        end

        local function createChild()
            return {
                hidden = false,
                Hide = function(self)
                    self.hidden = true
                end,
            }
        end

        frame.logFrame = createChild()
        frame.helpFrame = createChild()

        return frame
    end

    local minimap
    local state
    local ns

    before_each(function()
        minimap, state, ns = loadMinimapModule()
    end)

    describe("availability and defaults", function()
        it("reports the bundled minimap feature as enabled", function()
            assert.equals(true, minimap.IsEnabled(), "minimap module should stay enabled when its bundled libraries are present")
        end)

        it("creates default minimap settings", function()
            local database = {}

            ns.GrimDatabase.GetMinimapSettings(database)

            assert.is_table(database.minimap, "database model should create a minimap settings table")
            assert.equals(false, database.minimap.hide, "database model should leave the minimap icon visible by default")
        end)
    end)

    describe("launcher initialization", function()
        it("registers once and refreshes on reinitialization", function()
            local libDBIcon = state.libDBIcon
            local frame = createFrame()
            local firstDatabase = {}
            local secondDatabase = {
                minimap = {
                    hide = true,
                },
            }

            minimap.Initialize(frame, firstDatabase)
            assert.spy(libDBIcon.Register).was_called(1)
            assert.spy(libDBIcon.Register).was_called_with(
                match.is_ref(libDBIcon), "GrimGuesser", match.is_ref(state.lastDataObject), match.is_ref(firstDatabase.minimap)
            )
            assert.spy(libDBIcon.Refresh).was_not_called()
            assert.spy(libDBIcon.Show).was_called(1)
            assert.spy(libDBIcon.Show).was_called_with(match.is_ref(libDBIcon), "GrimGuesser")
            assert.equals(false, state.button.hidden, "initialization should leave the minimap button visible")
            assert.is_not_nil(state.button, "initialization should create the minimap button through LibDBIcon")
            assert.equals("data source", state.lastDataObject.type, "initialization should expose the broker as a data source for Titan-style displays")
            assert.equals("Grim Guesser", state.lastDataObject.label, "initialization should expose the launcher label for broker displays")
            assert.equals("0", state.lastDataObject.text, "initialization should expose the current score text for broker displays")
            assert.equals("0", state.lastDataObject.value, "initialization should expose the current score value for broker displays")
            assert.equals(
                "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01",
                state.button.icon.texturePath,
                "initialization should use the configured minimap icon asset"
            )

            local secondFrame = createFrame()
            minimap.Initialize(secondFrame, secondDatabase)
            assert.spy(libDBIcon.Register).was_called(1)
            assert.spy(libDBIcon.Refresh).was_called(1)
            assert.spy(libDBIcon.Refresh).was_called_with(match.is_ref(libDBIcon), "GrimGuesser", match.is_ref(secondDatabase.minimap))
        end)

        it("refreshes launcher text from the current score", function()
            local frame = createFrame()
            local database = {
                totalPoints = 1234,
            }

            minimap.Initialize(frame, database)
            assert.equals("1,234", state.lastDataObject.text, "initialization should seed the broker text from the current score")
            assert.equals("1,234", state.lastDataObject.value, "initialization should seed the broker value from the current score")

            database.totalPoints = 12345
            minimap.RefreshLauncherText(frame, database)
            assert.equals("12,345", state.lastDataObject.text, "refresh should update the broker text from the live database score")
            assert.equals("12,345", state.lastDataObject.value, "refresh should update the broker value from the live database score")
        end)
    end)

    describe("visibility", function()
        it("persists and applies minimap icon visibility", function()
            local libDBIcon = state.libDBIcon
            local frame = createFrame()
            local database = {}

            minimap.Initialize(frame, database)
            libDBIcon.Show:clear()
            minimap.SetHidden(frame, database, true)
            assert.equals(true, database.minimap.hide, "hiding the minimap icon should persist the hidden state")
            assert.spy(libDBIcon.Hide).was_called(1)
            assert.spy(libDBIcon.Hide).was_called_with(match.is_ref(libDBIcon), "GrimGuesser")
            assert.spy(libDBIcon.Show).was_not_called()
            assert.equals(true, state.button.hidden, "hiding the minimap icon should hide the button")

            minimap.SetHidden(frame, database, false)
            assert.equals(false, database.minimap.hide, "showing the minimap icon should persist the visible state")
            assert.spy(libDBIcon.Show).was_called(1)
            assert.spy(libDBIcon.Show).was_called_with(match.is_ref(libDBIcon), "GrimGuesser")
            assert.spy(libDBIcon.Hide).was_called(1)
            assert.equals(false, state.button.hidden, "showing the minimap icon should show the button")
        end)
    end)

    describe("controller behavior", function()
        it("preserves collapsed state when opening the main window", function()
            local frame = createFrame({
                shown = false,
                isCollapsed = true,
            })
            local database = {
                hidden = true,
                logWindowShown = true,
            }
            local mockUI = {
                ApplyDesiredLogWindowState = spy.new(),
            }
            frame:SetScript("OnShow", function(self)
                mockUI.ApplyDesiredLogWindowState(self, database)
            end)

            minimap.Toggle(frame, database)

            assert.equals(true, frame:IsShown(), "opening from the minimap should show the main window")
            assert.equals(false, database.hidden, "opening from the minimap should persist the main window as visible")
            assert.equals(true, frame.isCollapsed, "opening from the minimap should preserve the collapsed main window state")
            assert.spy(mockUI.ApplyDesiredLogWindowState).was_called(1)
            assert.spy(mockUI.ApplyDesiredLogWindowState).was_called_with(match.is_ref(frame), match.is_ref(database))
            assert.equals(true, frame.raised, "opening from the minimap should raise the main window")
        end)

        it("uses the initialized button callback", function()
            local frame = createFrame({
                shown = false,
            })
            local database = {
                hidden = true,
            }

            minimap.Initialize(frame, database)
            state.button:GetScript("OnClick")()

            assert.equals(true, frame:IsShown(), "minimap button click should show the main window through the registered callback")
            assert.equals(false, database.hidden, "minimap button click should persist the main window as visible")
        end)

        it("uses the most recent initialization target", function()
            local firstFrame = createFrame({
                shown = false,
            })
            local firstDatabase = {
                hidden = true,
            }
            local secondFrame = createFrame({
                shown = false,
            })
            local secondDatabase = {
                hidden = true,
            }

            minimap.Initialize(firstFrame, firstDatabase)
            minimap.Initialize(secondFrame, secondDatabase)
            state.button:GetScript("OnClick")()

            assert.equals(false, firstFrame:IsShown(), "reinitialized minimap button should not keep toggling the original frame")
            assert.equals(true, firstDatabase.hidden, "reinitialized minimap button should not mutate the original database")
            assert.equals(true, secondFrame:IsShown(), "reinitialized minimap button should toggle the current frame")
            assert.equals(false, secondDatabase.hidden, "reinitialized minimap button should mutate the current database")
        end)

        it("hides an open main window", function()
            local frame = createFrame({
                shown = true,
            })
            local database = {
                hidden = false,
            }

            minimap.Toggle(frame, database)

            assert.equals(false, frame:IsShown(), "clicking the minimap button while open should hide the main window")
            assert.equals(true, database.hidden, "hiding from the minimap should persist the main window as hidden")
        end)
    end)

    describe("tooltip", function()
        it("shows the current prediction and score", function()
            local frame = createFrame()
            local database = {
                totalPoints = 1234,
                lockedPrediction = {
                    elements = {
                        levelRange = "20-29",
                        source = "hogger",
                        zone = "elwynn forest",
                    },
                },
            }
            local tooltip = {
                lines = {},
            }

            function tooltip:AddLine(text)
                self.lines[#self.lines + 1] = text
            end

            minimap.Initialize(frame, database)
            state.lastDataObject.OnTooltipShow(tooltip)

            assert.equals("Grim Guesser", tooltip.lines[1], "tooltip should start with the addon name")
            assert.equals("Level 20-29, source Hogger, or zone Elwynn Forest.", tooltip.lines[2], "tooltip should show the current locked prediction text")
            assert.equals("Score: 1,234", tooltip.lines[3], "tooltip should show the current running score")
        end)
    end)
end)
