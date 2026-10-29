---@class GrimParser
---@field BuildPatternFromFormat fun(formatString: string|nil): string|nil
---@field GetBlizzardDeathPatterns fun(): GrimParserPattern[]
---@field Initialize fun()
---@field ParseBlizzardDeathMessage fun(message: string): GrimParsedDeathEvent|nil
local _, ns = ...
---@cast ns GrimNamespace

local GrimParser = {}
ns.GrimParser = GrimParser

---@class GrimParserPattern
---@field name string
---@field pattern string
---@field captureRoles table<integer, string|nil>

---@class GrimParsedDeathEvent
---@field name string
---@field level integer
---@field causeType string
---@field sourceName string|nil
---@field zone string|nil
---@field server string|nil
---@field sourceMessage string
---@field isBlizzardVerified boolean

local unpack = unpack

local CAPTURE_ROLES_BY_CAUSE_TYPE = {
    HARDCORE_CAUSEOFDEATH_CREATURE = { "name", "sourceName", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_DROWNING = { "name", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_FALLING = { "name", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_FATIGUE = { "name", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_FIRE = { "name", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_LAVA = { "name", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_NONE = { "name", "level" },
    HARDCORE_CAUSEOFDEATH_PLAYER = { "name", "sourceName", "zone", "level" },
    HARDCORE_CAUSEOFDEATH_PVP = { "name", "sourceName", "zone", "level" },
}

local SOURCE_NAME_BY_CAUSE_TYPE = {
    HARDCORE_CAUSEOFDEATH_DROWNING = "Drowning",
    HARDCORE_CAUSEOFDEATH_FALLING = "Falling",
    HARDCORE_CAUSEOFDEATH_FATIGUE = "Fatigue",
    HARDCORE_CAUSEOFDEATH_FIRE = "Burning",
    HARDCORE_CAUSEOFDEATH_LAVA = "Burning",
}

local NORMALIZED_CAUSE_TYPE_BY_CAUSE_TYPE = {
    HARDCORE_CAUSEOFDEATH_PLAYER = "HARDCORE_CAUSEOFDEATH_PVP",
}

-- Blizzard death format globals do not change during normal play, so we cache the
-- compiled matcher lists instead of rebuilding them on every death event parse.
---@type GrimParserPattern[]|nil
local cachedDefaultPatterns = nil

---@param message string
---@return string|nil
local function SanitizeDeathMessage(message)
    if not message or message == "" then
        return nil
    end

    local sanitizedMessage = message
    sanitizedMessage = string.gsub(sanitizedMessage, "|H.-|h(.-)|h", "%1")
    sanitizedMessage = string.gsub(sanitizedMessage, "|c%x%x%x%x%x%x%x%x", "")
    sanitizedMessage = string.gsub(sanitizedMessage, "|r", "")

    return sanitizedMessage
end

---@param text string
---@return string|nil
local function StripLeadingArticle(text)
    if text == "" then
        return nil
    end

    local stripped = text
    stripped = string.gsub(stripped, "^%[(.-)%]$", "%1")
    stripped = string.gsub(stripped, "^a%s+", "", 1)
    stripped = string.gsub(stripped, "^an%s+", "", 1)
    stripped = string.gsub(stripped, "^the%s+", "", 1)

    return stripped ~= "" and stripped or nil
end

---@param text string
---@return string
local function EscapePattern(text)
    local escaped = string.gsub(text, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    return escaped
end

---@param formatString string|nil
---@return string|nil
function GrimParser.BuildPatternFromFormat(formatString)
    if not formatString or formatString == "" then
        return nil
    end

    local visibleFormatString = SanitizeDeathMessage(formatString)
    if not visibleFormatString then
        return nil
    end

    local pattern = EscapePattern(visibleFormatString)
    pattern = string.gsub(pattern, "%%%%%d+%$s", "(.+)")
    pattern = string.gsub(pattern, "%%%%%d+%$d", "(%%d+)")
    pattern = string.gsub(pattern, "%%%%s", "(.+)")
    pattern = string.gsub(pattern, "%%%%d", "(%%d+)")

    return "^" .. pattern .. "$"
end

---@param rolesByArgumentIndex table<integer, string>
---@param sequentialArgumentIndex integer
---@param ordinaryKind string
---@return integer
local function GetOrdinaryPlaceholderArgumentIndex(rolesByArgumentIndex, sequentialArgumentIndex, ordinaryKind)
    for candidateIndex = sequentialArgumentIndex, #rolesByArgumentIndex do
        local role = rolesByArgumentIndex[candidateIndex]
        local roleMatchesKind = (ordinaryKind == "d" and role == "level")
            or (ordinaryKind == "s" and role ~= "level")
        if roleMatchesKind then
            return candidateIndex
        end
    end

    return sequentialArgumentIndex
end

---@param formatString string
---@param causeType string
---@return table<integer, string|nil>
local function BuildCaptureRolesFromFormat(formatString, causeType)
    local rolesByArgumentIndex = CAPTURE_ROLES_BY_CAUSE_TYPE[causeType] or {}
    local captureRoles = {}
    local sequentialArgumentIndex = 1
    local searchStart = 1
    local visibleFormatString = SanitizeDeathMessage(formatString)

    if not visibleFormatString then
        return captureRoles
    end

    while true do
        local placeholderStart, placeholderEnd = string.find(visibleFormatString, "%", searchStart, true)
        if not placeholderStart then
            break
        end

        local placeholderText = string.sub(visibleFormatString, placeholderEnd + 1)
        local positionalIndex, positionalKind = string.match(placeholderText, "^(%d+)%$([sd])")
        local argumentIndex = nil
        local consumedLength = nil

        if positionalKind then
            argumentIndex = tonumber(positionalIndex)
            consumedLength = string.len(positionalIndex) + 2
        else
            local ordinaryKind = string.match(placeholderText, "^([sd])")
            if ordinaryKind then
                argumentIndex = GetOrdinaryPlaceholderArgumentIndex(
                    rolesByArgumentIndex,
                    sequentialArgumentIndex,
                    ordinaryKind
                )
                sequentialArgumentIndex = argumentIndex + 1
                consumedLength = 1
            end
        end

        if argumentIndex then
            captureRoles[#captureRoles + 1] = rolesByArgumentIndex[argumentIndex]
        end

        searchStart = placeholderEnd + (consumedLength or 1) + 1
    end

    return captureRoles
end

---@return GrimParserPattern[]
function GrimParser.GetBlizzardDeathPatterns()
    if cachedDefaultPatterns ~= nil then
        return cachedDefaultPatterns
    end

    local patterns = {}

    for globalName, globalValue in pairs(_G) do
        if type(globalName) == "string"
            and type(globalValue) == "string"
            and string.match(globalName, "^HARDCORE_CAUSEOFDEATH_") then
            local pattern = GrimParser.BuildPatternFromFormat(globalValue)
            if pattern then
                table.insert(patterns, {
                    name = globalName,
                    pattern = pattern,
                    captureRoles = BuildCaptureRolesFromFormat(globalValue, globalName),
                })
            end
        end
    end

    table.sort(patterns, function(left, right)
        return left.name < right.name
    end)

    -- Parsing sits directly on the death chat hot path, so caching the
    -- compiled pattern table keeps repeated death messages from paying the
    -- global scan and pattern-build cost each time.
    cachedDefaultPatterns = patterns

    return patterns
end

---@param ... any
---@return integer|nil
local function ExtractFirstLevel(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local level = tonumber(value)
        if level then
            return level
        end
    end

    return nil
end

---@param ... any
---@return string|nil
local function ExtractFirstName(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "string" and not tonumber(value) then
            return value
        end
    end

    return nil
end

---@param parsedDeath table
---@param role string|nil
---@param value any
local function AssignCapturedValue(parsedDeath, role, value)
    if role == "level" then
        parsedDeath.level = tonumber(value)
    elseif role == "name" then
        parsedDeath.name = value ~= "" and value or nil
    elseif role == "sourceName" then
        parsedDeath.sourceName = StripLeadingArticle(value)
    elseif role == "zone" then
        parsedDeath.zone = value ~= "" and value or nil
    end
end

---@param message string
---@param matcher GrimParserPattern
---@param captures table
---@return GrimParsedDeathEvent|nil
local function BuildParsedDeathFromCaptures(message, matcher, captures)
    local parsedDeath = {}

    for index, value in ipairs(captures) do
        AssignCapturedValue(parsedDeath, matcher.captureRoles[index], value)
    end

    local level = parsedDeath.level or ExtractFirstLevel(unpack(captures))
    local name = parsedDeath.name or ExtractFirstName(unpack(captures))

    if not name or not level then
        return nil
    end

    return {
        name = name,
        level = level,
        causeType = NORMALIZED_CAUSE_TYPE_BY_CAUSE_TYPE[matcher.name] or matcher.name,
        sourceName = parsedDeath.sourceName or SOURCE_NAME_BY_CAUSE_TYPE[matcher.name],
        zone = parsedDeath.zone,
        sourceMessage = message,
        isBlizzardVerified = true,
    }
end

---@param message string
---@return GrimParsedDeathEvent|nil
function GrimParser.ParseBlizzardDeathMessage(message)
    if not message then
        return nil
    end

    local sanitizedMessage = SanitizeDeathMessage(message)
    if not sanitizedMessage then
        return nil
    end

    for _, matcher in ipairs(GrimParser.GetBlizzardDeathPatterns()) do
        local captures = { string.match(sanitizedMessage, matcher.pattern) }
        if captures[1] then
            return BuildParsedDeathFromCaptures(sanitizedMessage, matcher, captures)
        end
    end

    return nil
end

function GrimParser.Initialize()
    GrimParser.GetBlizzardDeathPatterns()
end

return GrimParser
