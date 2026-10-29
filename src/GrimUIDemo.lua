local _, ns = ...
---@cast ns GrimNamespace

local GrimUIDemo = ns.GrimUIDemo or {}
ns.GrimUIDemo = GrimUIDemo

local DEMO_DEFAULT_SERVER = "Doomhowl"
local DEMO_DEFAULT_CAUSE_TYPE = "HARDCORE_CAUSEOFDEATH_CREATURE"
local DEMO_ATTRACT_MODE_TEXT = table.concat({
    "Welcome to Grim Guesser",
    "Press START GAME to begin",
}, "\n")

---@class GrimIntroDemoRawDeath
---@field time string
---@field timestamp integer
---@field name string
---@field level integer
---@field sourceName string
---@field zone string
---@field causeType string|nil
---@field server string|nil
---@field sourceMessage string|nil

---@class GrimIntroDemoDeathEvent: GrimDeathEvent
---@field time string

---@type GrimPrediction
local DEMO_PREDICTION_ALLY = {
    elements = {
        levelRange = "10-19",
        source = "defias trapper",
        zone = "westfall",
    },
}

---@type GrimIntroDemoRawDeath[]
local DEMO_SCRIPT_DEATHS_ALLY = {
    {
        time = "19:41",
        timestamp = 1941,
        name = "Mudtooth",
        level = 24,
        sourceName = "Skeletal Raider",
        zone = "Duskwood",
    },
    {
        time = "19:44",
        timestamp = 1944,
        name = "Haymaker",
        level = 15,
        sourceName = "Defias Rogue Wizard",
        zone = "Elwynn Forest",
    },
    {
        time = "19:44",
        timestamp = 1944,
        name = "Copperkeg",
        level = 12,
        sourceName = "Wild Grell",
        zone = "Bashal'Aran",
    },
    {
        time = "20:09",
        timestamp = 2009,
        name = "Lantern",
        level = 13,
        sourceName = "Defias Bandit",
        zone = "Westfall",
    },
    {
        time = "20:48",
        timestamp = 2048,
        name = "Flashlight",
        level = 20,
        sourceName = "Defias Trapper",
        zone = "Westfall",
    },
    {
        time = "19:47",
        timestamp = 1947,
        name = "Stitchesjr",
        level = 20,
        sourceName = "Defias Squallshaper",
        zone = "The Deadmines",
    },
    {
        time = "19:51",
        timestamp = 1951,
        name = "Grizzik",
        level = 33,
        sourceName = "Dark Iron Saboteur",
        zone = "Wetlands",
    },
    {
        time = "19:55",
        timestamp = 1955,
        name = "Westpie",
        level = 10,
        sourceName = "Kobold Miner",
        zone = "Fargodeep Mine",
    },
    {
        time = "19:58",
        timestamp = 1958,
        name = "Dustyboots",
        level = 18,
        sourceName = "Falling",
        zone = "Lakeshire",
        causeType = "HARDCORE_CAUSEOFDEATH_FALL",
    },
    {
        time = "20:01",
        timestamp = 2001,
        name = "Blinktank",
        level = 13,
        sourceName = "Hogger",
        zone = "Forest's Edge",
    },
    {
        time = "20:34",
        timestamp = 2034,
        name = "Stonewake",
        level = 20,
        sourceName = "Defias Pillager",
        zone = "Westfall",
    },
    {
        time = "20:40",
        timestamp = 2040,
        name = "Nettle",
        level = 10,
        sourceName = "Kobold Miner",
        zone = "Elwynn",
    },
    {
        time = "20:44",
        timestamp = 2044,
        name = "Goldsprocket",
        level = 24,
        sourceName = "Murloc Tidehunter",
        zone = "Westfall",
    },
    {
        time = "20:46",
        timestamp = 2046,
        name = "Arcaneonly",
        level = 11,
        sourceName = "Hogger",
        zone = "Forest's Edge",
    },
    {
        time = "20:53",
        timestamp = 2053,
        name = "Redledger",
        level = 27,
        sourceName = "Nightbane Dark Runner",
        zone = "Duskwood",
    },
    {
        time = "20:57",
        timestamp = 2057,
        name = "Grendel",
        level = 60,
        sourceName = "Firelord",
        zone = "Molten Core",
    },
    {
        time = "21:02",
        timestamp = 2102,
        name = "Gravebloom",
        level = 57,
        sourceName = "Scholomance Dark Summoner",
        zone = "Scholomance",
    },
}

---@type GrimPrediction
local DEMO_PREDICTION_HORDE = {
    elements = {
        levelRange = "10-19",
        source = "kolkar wrangler",
        zone = "the barrens",
    },
}

---@type GrimIntroDemoRawDeath[]
local DEMO_SCRIPT_DEATHS_HORDE = {
    {
        time = "19:01",
        timestamp = 1780240001,
        name = "Rascal",
        level = 26,
        sourceName = "Twilight Acolyte",
        zone = "Blackfathom Deeps",
    },
    {
        time = "19:03",
        timestamp = 1780240003,
        name = "Grenlokk",
        level = 18,
        sourceName = "Theramore Marine",
        zone = "Northwatch Hold",
    },
    {
        time = "19:04",
        timestamp = 1780240004,
        name = "Neverheals",
        level = 13,
        sourceName = "Falling",
        zone = "The Undercity",
        causeType = "HARDCORE_CAUSEOFDEATH_FALLING",
    },
    {
        time = "19:06",
        timestamp = 1780240006,
        name = "Moovin",
        level = 11,
        sourceName = "Wandering Barrens Giraffe",
        zone = "The Barrens",
    },
    {
        time = "19:07",
        timestamp = 1780240007,
        name = "Udders",
        level = 14,
        sourceName = "Kolkar Wrangler",
        zone = "The Barrens",
    },
    {
        time = "19:08",
        timestamp = 1780240008,
        name = "Bully",
        level = 14,
        sourceName = "Kolkar Wrangler",
        zone = "The Barrens",
    },
    {
        time = "19:09",
        timestamp = 1780240009,
        name = "Disctroll",
        level = 23,
        sourceName = "Drowning",
        zone = "The Merchant Coast",
        causeType = "HARDCORE_CAUSEOFDEATH_DROWNING",
    },
    {
        time = "19:10",
        timestamp = 1780240010,
        name = "Samuel",
        level = 19,
        sourceName = "Venture Co. Enforcer",
        zone = "Boulder Lode Mine",
    },
    {
        time = "19:11",
        timestamp = 1780240011,
        name = "Tacos",
        level = 7,
        sourceName = "Voidwalker Minion",
        zone = "Skull Rock",
    },
    {
        time = "19:12",
        timestamp = 1780240012,
        name = "Dinlocke",
        level = 22,
        sourceName = "Deviate Dreadfang",
        zone = "Wailing Caverns",
    },
    {
        time = "19:13",
        timestamp = 1780240013,
        name = "Gabaguk",
        level = 16,
        sourceName = "Dalaran Apprentice",
        zone = "Silverpine Forest",
    },
    {
        time = "19:14",
        timestamp = 1780240014,
        name = "Tulaint",
        level = 18,
        sourceName = "Kolkar Invader",
        zone = "The Barrens",
    },
    {
        time = "19:15",
        timestamp = 1780240015,
        name = "Haahno",
        level = 24,
        sourceName = "Kolkar Wrangler",
        zone = "The Barrens",
    },
    {
        time = "19:16",
        timestamp = 1780240016,
        name = "Springheeled",
        level = 34,
        sourceName = "Southshore Guard",
        zone = "Hillsbrad Foothills",
    },
    {
        time = "19:17",
        timestamp = 1780240017,
        name = "Warriorxvii",
        level = 60,
        sourceName = "Falling",
        zone = "Undercity",
        causeType = "HARDCORE_CAUSEOFDEATH_FALLING",
    },
}

---@return string
local function GetIntroDemoFaction()
    return _G.UnitFactionGroup("player")
end

---@return GrimPrediction
local function GetIntroDemoPredictionDefinition()
    if GetIntroDemoFaction() == "Horde" then
        return DEMO_PREDICTION_HORDE
    end

    return DEMO_PREDICTION_ALLY
end

---@return GrimIntroDemoRawDeath[]
local function GetIntroDemoScriptDefinition()
    if GetIntroDemoFaction() == "Horde" then
        return DEMO_SCRIPT_DEATHS_HORDE
    end

    return DEMO_SCRIPT_DEATHS_ALLY
end

---@param death GrimIntroDemoRawDeath|GrimIntroDemoDeathEvent
---@return string
local function BuildDemoSourceMessage(death)
    return string.format(
        "[%s] has been slain by %s in %s! They were level %d",
        tostring(death.name or "Unknown"),
        tostring(death.sourceName or "Unknown"),
        tostring(death.zone or "Unknown"),
        tonumber(death.level) or 0
    )
end

---@param rawDeath GrimIntroDemoRawDeath
---@return GrimIntroDemoDeathEvent
local function NormalizeDemoDeath(rawDeath)
    return {
        time = rawDeath.time,
        timestamp = rawDeath.timestamp,
        name = rawDeath.name,
        level = rawDeath.level,
        causeType = rawDeath.causeType or DEMO_DEFAULT_CAUSE_TYPE,
        sourceName = rawDeath.sourceName,
        zone = rawDeath.zone,
        server = rawDeath.server or DEMO_DEFAULT_SERVER,
        sourceMessage = rawDeath.sourceMessage or BuildDemoSourceMessage(rawDeath),
        isBlizzardVerified = true,
    }
end

---@return GrimPrediction
function GrimUIDemo.GetIntroDemoPrediction()
    local prediction = GetIntroDemoPredictionDefinition()

    return {
        elements = {
            levelRange = prediction.elements.levelRange,
            source = prediction.elements.source,
            zone = prediction.elements.zone,
        },
    }
end

---@return GrimIntroDemoDeathEvent[]
function GrimUIDemo.GetIntroDemoScriptDeaths()
    ---@type GrimIntroDemoDeathEvent[]
    local scriptDeaths = {}
    local rawScriptDeaths = GetIntroDemoScriptDefinition()

    for index, death in ipairs(rawScriptDeaths) do
        scriptDeaths[index] = NormalizeDemoDeath(death)
    end

    return scriptDeaths
end

---@return string
function GrimUIDemo.GetIntroDemoAttractModeText()
    return DEMO_ATTRACT_MODE_TEXT
end

return GrimUIDemo
