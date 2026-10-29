local assert = require("luassert")
describe("Autocomplete UI", function()
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

    describe("suggestion sources", function()
        it("builds source and zone lists from current death history", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local findDropdownButtonByText = context.findDropdownButtonByText

            table.insert(env.GrimCharacterState.deathHistory, Fixtures.storedDeath({
                sourceName = "Zealous History Beast",
                zone = "Zephyr Canyon",
            }))

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("zealous")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(
                findDropdownButtonByText(GrimMainFrame.dropdown, "Zealous History Beast"),
                "source suggestions should query history added after UI initialization"
            )

            GrimMainFrame.zoneEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.zoneEditBox)
            GrimMainFrame.zoneEditBox:SetText("zephyr")
            GrimMainFrame.zoneEditBox:GetScript("OnTextChanged")(GrimMainFrame.zoneEditBox, true)
            assert.is_truthy(
                findDropdownButtonByText(GrimMainFrame.dropdown, "Zephyr Canyon"),
                "location suggestions should query history added after UI initialization"
            )
        end)

        it("merges history with defaults without duplicates", function()
            local context = createUIContext(Fixtures.addonDatabase({
                deathHistory = {
                    Fixtures.storedDeath({
                        sourceName = "Hogger",
                        zone = "Uldaman",
                    }),
                },
            }))
            local sourceSuggestions = context.GrimUIAutocomplete.GetSourceSuggestions(env.GrimCharacterState)
            local zoneSuggestions = context.GrimUIAutocomplete.GetZoneSuggestions(env.GrimCharacterState)
            local hoggerCount = 0
            local uldamanCount = 0

            for _, source in ipairs(sourceSuggestions) do
                if source == "Hogger" then
                    hoggerCount = hoggerCount + 1
                end
            end
            for _, zone in ipairs(zoneSuggestions) do
                if zone == "Uldaman" then
                    uldamanCount = uldamanCount + 1
                end
            end

            assert.equals(1, hoggerCount, "historical sources should not duplicate curated defaults")
            assert.equals(1, uldamanCount, "historical locations should not duplicate curated defaults")
        end)

        it("preserves curated highlighting for dynamic source suggestions", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame
            local findDropdownButtonByText = context.findDropdownButtonByText

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("vag")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)

            local vagashButton = findDropdownButtonByText(GrimMainFrame.dropdown, "Vagash")
            assert.is_truthy(vagashButton, "highlighted curated sources should remain in the dynamic list")
            assert.is_truthy(
                vagashButton and vagashButton.highlight:IsShown(),
                "dynamic source suggestions should preserve curated highlighting"
            )
        end)
    end)

    describe("matching and visibility", function()
        it("hides the dropdown for blank and unmatched input", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("hog")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "typing a matching source should show the dropdown")

            GrimMainFrame.sourceEditBox:SetText("")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "blank autocomplete input should hide the dropdown")

            GrimMainFrame.sourceEditBox:SetText("zzzz-no-match")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "unmatched autocomplete input should hide the dropdown")
        end)

        it("caps visible results at ten", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("r")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)

            local visibleCount = 0
            for _, button in ipairs(GrimMainFrame.dropdown.buttons or {}) do
                if button:IsShown() then
                    visibleCount = visibleCount + 1
                end
            end

            assert.equals(10, visibleCount, "autocomplete dropdown should cap visible matches at ten rows")
        end)
    end)

    describe("dismissal and selection", function()
        it("hides the dropdown on escape and focus loss", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("hog")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "matching autocomplete input should show the dropdown before escape")

            GrimMainFrame.sourceEditBox.hasFocus = true
            GrimMainFrame.sourceEditBox:GetScript("OnEscapePressed")(GrimMainFrame.sourceEditBox)
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "escape should hide the autocomplete dropdown")
            assert.equals(false, GrimMainFrame.sourceEditBox.hasFocus, "escape should clear focus from the active edit box")

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("hog")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "matching autocomplete input should show the dropdown before focus loss")

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusLost")(GrimMainFrame.sourceEditBox)
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "focus loss should hide the autocomplete dropdown")
        end)

        it("keeps the dropdown closed after programmatic selection", function()
            local context = createUIContext()
            local GrimMainFrame = context.GrimMainFrame

            GrimMainFrame.sourceEditBox:GetScript("OnEditFocusGained")(GrimMainFrame.sourceEditBox)
            GrimMainFrame.sourceEditBox:SetText("hog")
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, true)
            assert.is_truthy(GrimMainFrame.dropdown:IsShown(), "matching autocomplete input should show the dropdown before selection")

            GrimMainFrame.dropdown.buttons[1]:GetScript("OnClick")()
            GrimMainFrame.sourceEditBox:GetScript("OnTextChanged")(GrimMainFrame.sourceEditBox, false)

            assert.equals("Hogger", GrimMainFrame.sourceEditBox:GetText(), "one click should apply the chosen autocomplete value")
            assert.equals(false, GrimMainFrame.dropdown:IsShown(), "programmatic selection text changes should not reopen a single-result dropdown")
        end)
    end)
end)
