local assert = require("luassert")
describe("Death announcement parser", function()
    ---@diagnostic disable: need-check-nil
    ---@diagnostic disable: param-type-mismatch

    local AddonLoader = require("tests.support_addon_loader")

    ---@param globals table<string, any>
    ---@return GrimParser, table
    local function loadParserModule(globals)
        local loader = AddonLoader.Create()
        for key, value in pairs(globals) do
            loader.env[key] = value
        end
        return loader:Load("GrimParser"), loader.env
    end

    local OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS = {
        HARDCORE_CAUSEOFDEATH_CREATURE = "|Hplayer:%s|h[%s]|h has been slain by a %s in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_DROWNING = "|Hplayer:%s|h[%s]|h drowned to death in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_FALLING = "|Hplayer:%s|h[%s]|h fell to their death in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_FATIGUE = "|Hplayer:%s|h[%s]|h died of fatigue in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_FIRE = "|Hplayer:%s|h[%s]|h was burnt to death by fire in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_LAVA = "|Hplayer:%s|h[%s]|h was burnt to a crisp by lava in %s! They were level %d",
        HARDCORE_CAUSEOFDEATH_NONE = "|Hplayer:%s|h[%s]|h has died at level %d",
        HARDCORE_CAUSEOFDEATH_PVP = "|Hplayer:%s|h[%s]|h has been slain by %s in %s! They were level %d",
    }

    local GrimParser

    before_each(function()
        GrimParser = loadParserModule(OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS)
    end)
    local TestData = require("tests.fixtures.death_announcements")

    ---@param overrides table<string, any>
    ---@param callback fun(parser: GrimParser, env: table)
    local function withParserGlobals(overrides, callback)
        local parser, env = loadParserModule(overrides or {})
        callback(parser, env)
    end

    describe("observed announcements", function()
        it("parses creature deaths", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Drakedog] has been slain by a Kobold Vermin in Elwynn Forest! They were level 6"
            )

            assert.is_truthy(death, "observed Hardcore creature death should parse")
            assert.equals("Drakedog", death.name, "observed death should capture name")
            assert.equals(6, death.level, "observed death should capture level")
            assert.equals("Kobold Vermin", death.sourceName, "observed death should strip leading article from source")
            assert.equals("Elwynn Forest", death.zone, "observed death should capture zone")
            assert.equals("HARDCORE_CAUSEOFDEATH_CREATURE", death.causeType, "observed death should set creature cause type")
        end)

        it("parses falling deaths", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Ming] fell to their death in Cliffspring Falls! They were level 16"
            )

            assert.is_truthy(death, "observed Hardcore falling death should parse")
            assert.equals("Ming", death.name, "observed falling death should capture name")
            assert.equals(16, death.level, "observed falling death should capture level")
            assert.equals("Falling", death.sourceName, "observed falling death should normalize the source label")
            assert.equals("Cliffspring Falls", death.zone, "observed falling death should capture zone")
            assert.equals("HARDCORE_CAUSEOFDEATH_FALLING", death.causeType, "observed falling death should set the fall cause type")
        end)

        it("parses drowning deaths", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Ming] drowned to death in The Deadmines! They were level 18"
            )

            assert.is_truthy(death, "observed Hardcore drowning death should parse")
            assert.equals("Ming", death.name, "observed drowning death should capture name")
            assert.equals(18, death.level, "observed drowning death should capture level")
            assert.equals("Drowning", death.sourceName, "observed drowning death should normalize the source label")
            assert.equals("The Deadmines", death.zone, "observed drowning death should capture zone")
            assert.equals(
                "HARDCORE_CAUSEOFDEATH_DROWNING",
                death.causeType,
                "observed drowning death should set the drowning cause type"
            )
        end)

        it("rejects drowned-in messages", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Ming] drowned in The Deadmines! They were level 18"
            )

            assert.equals(nil, death, "drowned-in wording should not parse without an official matching format")
        end)

        it("strips named articles", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Drakedog] has been slain by the Hogger in Elwynn Forest! They were level 12"
            )

            assert.is_truthy(death, "observed death with named mob article should parse")
            assert.equals("Hogger", death.sourceName, "observed death should strip leading 'the' from source names")
        end)

        it("strips bracketed articles", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Drakedog] has been slain by [an Ancient Spider] in Tirisfal Glades! They were level 8"
            )

            assert.is_truthy(death, "observed death with bracketed article should parse")
            assert.equals("Ancient Spider", death.sourceName, "observed death should strip bracketed leading articles")
        end)
    end)

    describe("text sanitization", function()
        it("strips color and hyperlink markup", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "|cffff2020[Drakedog]|r has been slain by "
                    .. "|Hunit:Creature-0|h[a Kobold Miner]|h in Elwynn Forest! They were level 10"
            )

            assert.is_truthy(death, "parser should sanitize Blizzard color and hyperlink markup")
            assert.equals("Drakedog", death.name, "sanitized message should keep player name")
            assert.equals(
                "Kobold Miner",
                death.sourceName,
                "sanitized message should keep source name"
            )
        end)

        it("preserves sanitized source messages", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "|cffff2020[Drakedog]|r has been slain by "
                    .. "|Hunit:Creature-0|h[a Kobold Miner]|h in Elwynn Forest! They were level 10"
            )

            assert.is_string(death.sourceMessage, "parsed deaths should preserve the sanitized source message for debugging")
            assert.matches(
                "[Drakedog] has been slain by [a Kobold Miner] in Elwynn Forest! They were level 10",
                death.sourceMessage,
                1,
                true,
                "parsed deaths should preserve the sanitized source message for debugging"
            )
        end)
    end)

    describe("format patterns", function()
        it("builds localized format patterns", function()
            withParserGlobals({
                UNKNOWN = "Unknown",
                HARDCORE_CAUSEOFDEATH_FALLING = "%s died from falling at level %d",
                HARDCORE_CAUSEOFDEATH_UNKNOWN = "Level %d death",
            }, function(parser)
                local death = parser.ParseBlizzardDeathMessage("Alamo died from falling at level 12")

                assert.is_truthy(death, "generic Blizzard format string should parse")
                assert.equals("Alamo", death.name, "generic pattern should capture player name")
                assert.equals(12, death.level, "generic pattern should capture level")
                assert.equals("HARDCORE_CAUSEOFDEATH_FALLING", death.causeType, "generic pattern should preserve the format source")
                assert.equals("Falling", death.sourceName, "generic pattern should infer the environmental source from the cause type")
                assert.equals(nil, death.zone, "generic pattern should not invent a zone")
            end)
        end)

        it("converts official English format patterns", function()
            local cases = {
                {
                    name = "creature",
                    format = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_CREATURE,
                    pattern = "^%[(.+)%] has been slain by a (.+) in (.+)! They were level (%d+)$",
                    message = "[C] has been slain by a Kobold Vermin in Elwynn Forest! They were level 6",
                },
                {
                    name = "drowning",
                    format = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_DROWNING,
                    pattern = "^%[(.+)%] drowned to death in (.+)! They were level (%d+)$",
                    message = "[D] drowned to death in The Deadmines! They were level 18",
                },
                {
                    name = "falling",
                    format = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_FALLING,
                    pattern = "^%[(.+)%] fell to their death in (.+)! They were level (%d+)$",
                    message = "[F] fell to their death in Cliffspring Falls! They were level 16",
                },
                {
                    name = "lava",
                    format = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_LAVA,
                    pattern = "^%[(.+)%] was burnt to a crisp by lava in (.+)! They were level (%d+)$",
                    message = "[B] was burnt to a crisp by lava in Ironforge! They were level 13",
                },
                {
                    name = "pvp",
                    format = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_PVP,
                    pattern = "^%[(.+)%] has been slain by (.+) in (.+)! They were level (%d+)$",
                    message = "[S] has been slain by Playername in Theramore Isle! They were level 36",
                },
            }

            for _, case in ipairs(cases) do
                local pattern = GrimParser.BuildPatternFromFormat(case.format)

                assert.equals(case.pattern, pattern, case.name .. " official format should convert to the expected pattern")
                assert.is_not_nil(
                    string.match(case.message, pattern),
                    case.name .. " official pattern should match sanitized channel text"
                )
            end
        end)

        it("builds patterns from multiple placeholders", function()
            local pattern = GrimParser.BuildPatternFromFormat("%s was slain by %s at level %d")

            assert.is_truthy(pattern, "pattern builder should support multiple ordinary format placeholders")
            assert.is_not_nil(
                string.match("Drakedog was slain by Hogger at level 12", pattern),
                "multi-placeholder patterns should match the corresponding formatted text"
            )
        end)

        it("escapes literal pattern characters", function()
            local pattern = GrimParser.BuildPatternFromFormat("(%s) at level %d?")

            assert.is_truthy(pattern, "pattern builder should return a pattern for literal punctuation")
            assert.is_not_nil(
                string.match("(Drakedog) at level 12?", pattern),
                "pattern builder should escape literal punctuation before replacing placeholders"
            )
        end)
    end)

    describe("initialization and caching", function()
        it("filters and sorts Blizzard death patterns", function()
            withParserGlobals({
                HARDCORE_CAUSEOFDEATH_ZETA = "%s z %d",
                HARDCORE_CAUSEOFDEATH_ALPHA = "%s a %d",
                SOME_OTHER_GLOBAL = "%s ignored %d",
                HARDCORE_CAUSEOFDEATH_BAD = "",
            }, function(parser)
                local patterns = parser.GetBlizzardDeathPatterns()

                assert.equals(2, #patterns, "pattern list should only include non-empty Hardcore death formats")
                assert.equals("HARDCORE_CAUSEOFDEATH_ALPHA", patterns[1].name, "pattern list should sort by global name")
                assert.equals("HARDCORE_CAUSEOFDEATH_ZETA", patterns[2].name, "pattern list should keep later names after sorting")
            end)
        end)

        it("caches Blizzard globals until reload", function()
            withParserGlobals({
                HARDCORE_CAUSEOFDEATH_ALPHA = "%s a %d",
            }, function(parser, env)
                local firstPatterns = parser.GetBlizzardDeathPatterns()
                env.HARDCORE_CAUSEOFDEATH_ZETA = "%s z %d"
                local secondPatterns = parser.GetBlizzardDeathPatterns()

                assert.equals(secondPatterns, firstPatterns, "pattern cache should reuse the compiled list after the first scan")
                assert.equals(1, #secondPatterns, "cached pattern list should not rebuild until the parser module reloads")
            end)

            withParserGlobals({
                HARDCORE_CAUSEOFDEATH_ALPHA = "%s a %d",
                HARDCORE_CAUSEOFDEATH_ZETA = "%s z %d",
            }, function(parser)
                local rebuiltPatterns = parser.GetBlizzardDeathPatterns()

                assert.equals(2, #rebuiltPatterns, "reloading the parser should rebuild patterns from the current globals")
            end)
        end)

        it("builds default patterns during initialization", function()
            withParserGlobals({
                HARDCORE_CAUSEOFDEATH_CREATURE = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_CREATURE,
            }, function(parser, env)
                parser.Initialize()
                env.HARDCORE_CAUSEOFDEATH_ZETA = "%s z %d"

                local patterns = parser.GetBlizzardDeathPatterns()
                assert.equals(1, #patterns, "parser initialize should build the pattern cache before globals change")
                assert.equals(
                    "HARDCORE_CAUSEOFDEATH_CREATURE",
                    patterns[1].name,
                    "parser initialize should cache patterns from the original Hardcore death globals"
                )
            end)
        end)

        it("records compiled default pattern metadata", function()
            withParserGlobals({
                HARDCORE_CAUSEOFDEATH_CREATURE = OFFICIAL_ENGLISH_HARDCORE_DEATH_FORMATS.HARDCORE_CAUSEOFDEATH_CREATURE,
            }, function(parser)
                local patterns = parser.GetBlizzardDeathPatterns()
                local matcher = patterns[1]

                assert.equals(1, #patterns, "compiled pattern list should include the configured format")
                assert.equals("HARDCORE_CAUSEOFDEATH_CREATURE", matcher.name, "compiled matcher should preserve the format name")
                assert.equals(4, #matcher.captureRoles, "compiled matcher should include every capture role")
                assert.equals("name", matcher.captureRoles[1], "compiled matcher should assign the player name capture")
                assert.equals("sourceName", matcher.captureRoles[2], "compiled matcher should assign the death source capture")
                assert.equals("zone", matcher.captureRoles[3], "compiled matcher should assign the zone capture")
                assert.equals("level", matcher.captureRoles[4], "compiled matcher should assign the level capture")
                assert.equals(
                    "^%[(.+)%] has been slain by a (.+) in (.+)! They were level (%d+)$",
                    matcher.pattern,
                    "compiled matcher should preserve the generated Lua pattern"
                )
            end)
        end)
    end)

    describe("invalid input and fixtures", function()
        it("returns nil for blank messages", function()
            assert.equals(
                nil,
                GrimParser.ParseBlizzardDeathMessage(""),
                "blank messages should not parse"
            )
            assert.equals(
                nil,
                GrimParser.ParseBlizzardDeathMessage(nil),
                "nil messages should not parse"
            )
        end)

        it("returns nil for malformed observed messages", function()
            local death = GrimParser.ParseBlizzardDeathMessage(
                "[Drakedog] has been slain by Hogger! They were level 12"
            )

            assert.equals(nil, death, "observed messages missing the zone segment should not parse")
        end)

        it("returns nil for unknown messages", function()
            local death = GrimParser.ParseBlizzardDeathMessage("This is not a Hardcore death message")
            assert.equals(nil, death, "unknown message should not parse")
        end)

        it("parses fixture messages", function()
            for _, case in ipairs(TestData.parser_messages or {}) do
                local death = GrimParser.ParseBlizzardDeathMessage(case.rawMessage)
                local label = "fixture " .. tostring(case.id)

                if case.expectNil == true then
                    assert.equals(nil, death, label .. " should not parse")
                else
                    assert.is_truthy(death, label .. " should parse")
                    assert.equals(case.expected.name, death.name, label .. " should capture name")
                    assert.equals(case.expected.level, death.level, label .. " should capture level")
                    assert.equals(case.expected.sourceName, death.sourceName, label .. " should capture source")
                    assert.equals(case.expected.zone, death.zone, label .. " should capture zone")

                    -- The observed raw text alone does not reliably distinguish named mobs from player killers.
                    -- Keep fixture coverage on the parsed shape while the addon remains conservative here.
                    if case.category ~= "observed_pvp" then
                        assert.equals(
                            case.expected.causeType,
                            death.causeType,
                            label .. " should preserve cause type"
                        )
                    end

                    assert.equals(
                        case.expected.isBlizzardVerified,
                        death.isBlizzardVerified,
                        label .. " should mark Blizzard verification"
                    )

                    if case.sanitizedSourceMessage ~= nil then
                        assert.is_string(death.sourceMessage, label .. " should preserve the sanitized source message")
                        assert.matches(
                            case.sanitizedSourceMessage,
                            death.sourceMessage,
                            1,
                            true,
                            label .. " should preserve the sanitized source message"
                        )
                    end
                end
            end
        end)
    end)
end)
