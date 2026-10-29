local AddonLoader = require("tests.support_addon_loader")

local LogicContext = {}

---@param options table|nil
---@return table
function LogicContext.Create(options)
    options = options or {}
    local loader = AddonLoader.Create()
    local env = loader.env

    env.wipe = function(values)
        for key in pairs(values) do
            values[key] = nil
        end

        return values
    end

    env.FormatLargeNumber = tostring
    env.strtrim = function(text)
        return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    env.GetZoneText = function()
        return options.zoneText or "Test Logic Zone"
    end
    env.date = os.date
    env.time = os.time

    loader:LoadThrough("GrimMigration")

    return {
        env = env,
        loader = loader,
        ns = loader.ns,
        GrimConstants = loader.ns.GrimConstants,
        GrimDatabase = loader.ns.GrimDatabase,
        GrimMigration = loader.ns.GrimMigration,
        GrimLogic = loader.ns.GrimLogic,
        GrimStats = loader.ns.GrimStats,
    }
end

return LogicContext
