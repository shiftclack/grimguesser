---@meta

---@class GrimNamespace
---@field GrimAnnouncements table
---@field GrimCommands table
---@field GrimConstants table
---@field GrimDatabase table
---@field GrimDebug table
---@field GrimDebugState table
---@field GrimDemo table
---@field GrimLogic table
---@field GrimMigration table
---@field GrimParser table
---@field GrimSettings table
---@field GrimSetup table
---@field GrimStats GrimStats
---@field GrimUI table
---@field GrimUIAutocomplete table
---@field GrimUIDeathLogList table
---@field GrimUIDebug table
---@field GrimUIDemo table
---@field GrimUIHelp table
---@field GrimUILog table
---@field GrimUIMain table
---@field GrimUIMainCollapsed table
---@field GrimUIMainPrediction table
---@field GrimUIMainRecentDeaths table
---@field GrimUIRefresh table
---@field GrimUISettings table
---@field GrimUISetup table
---@field GrimUITooltip table
---@field GrimUIMinimap table
---@field GrimUIMode table

---@class ColorInfo
---@field r number
---@field g number
---@field b number

---@class RaidWarningFrame
---@field UnregisterEvent fun(self: RaidWarningFrame, eventName: string)

---@class MinimapTooltip
---@field AddLine fun(self: MinimapTooltip, text: string, red: number|nil, green: number|nil, blue: number|nil, wrap: boolean|nil)

---@class MinimapLauncher
---@field type string
---@field label string
---@field text string
---@field value string
---@field suffix string
---@field icon string
---@field OnClick fun()
---@field OnTooltipShow fun(tooltip: MinimapTooltip|nil)

---@class LibDataBrokerApi
---@field NewDataObject fun(self: LibDataBrokerApi, name: string, dataObject: MinimapLauncher): MinimapLauncher

---@class LibDBIconApi
---@field Hide fun(self: LibDBIconApi, name: string)
---@field Show fun(self: LibDBIconApi, name: string)
---@field Refresh fun(self: LibDBIconApi, name: string, database: GrimMinimapSettings)
---@field Register fun(self: LibDBIconApi, name: string, dataObject: MinimapLauncher, database: GrimMinimapSettings)

---@class SettingsCategory
---@field ID number|string|nil
---@field name string|nil

---@class SettingsApi
---@field RegisterCanvasLayoutCategory fun(frame: table, name: string): SettingsCategory
---@field RegisterAddOnCategory fun(category: SettingsCategory): SettingsCategory

---@type table<integer, ColorInfo>
ITEM_QUALITY_COLORS = {}

---@type string[]
UISpecialFrames = {}

---@type SettingsApi
Settings = {
    RegisterCanvasLayoutCategory = function(_, name)
        return {
            name = name,
        }
    end,
    RegisterAddOnCategory = function(category)
        return category
    end,
}

---@type fun(unit: string): string
UnitFactionGroup = function(_)
    return "Alliance"
end

---@overload fun(libraryName: "LibDataBroker-1.1", silent: boolean|nil): LibDataBrokerApi|nil
---@overload fun(libraryName: "LibDBIcon-1.0", silent: boolean|nil): LibDBIconApi|nil
---@type fun(libraryName: string, silent: boolean|nil): table|nil
LibStub = function(_, _)
    return nil
end
