---@class GrimSettingsDatabaseApi
---@field GetShowInCombat fun(database: GrimCharacterState): boolean
---@field SetShowInCombat fun(database: GrimCharacterState, enabled: boolean): boolean
---@field GetGuildAnnouncementsEnabled fun(database: GrimCharacterState): boolean
---@field SetGuildAnnouncementsEnabled fun(database: GrimCharacterState, enabled: boolean): boolean
---@field GetAnnounceDeathToGuild fun(database: GrimCharacterState): boolean
---@field SetAnnounceDeathToGuild fun(database: GrimCharacterState, enabled: boolean): boolean
---@field GetAnnounceScoreOnLevelUp fun(database: GrimCharacterState): boolean
---@field SetAnnounceScoreOnLevelUp fun(database: GrimCharacterState, enabled: boolean): boolean
---@field GetMinimapHidden fun(database: GrimCharacterState): boolean

local _, ns = ...
---@cast ns GrimNamespace

local GrimSettings = ns.GrimSettings or {}
ns.GrimSettings = GrimSettings

---@type GrimCharacterState|nil
local activeDatabase = nil

---@type GrimSettingsDatabaseApi|nil
local activeDatabaseApi = nil

---@return GrimCharacterState
local function GetDatabase()
    local database = activeDatabase
    ---@cast database GrimCharacterState
    return database
end

---@return GrimSettingsDatabaseApi
local function GetDatabaseApi()
    local databaseApi = activeDatabaseApi
    ---@cast databaseApi GrimSettingsDatabaseApi
    return databaseApi
end

---@return boolean
function GrimSettings.GetShowInCombat()
    return GetDatabaseApi().GetShowInCombat(GetDatabase())
end

---@return boolean
function GrimSettings.GetGuildAnnouncementsEnabled()
    return GetDatabaseApi().GetGuildAnnouncementsEnabled(GetDatabase())
end

---@return boolean
function GrimSettings.GetDeathAnnouncementToGuild()
    return GetDatabaseApi().GetAnnounceDeathToGuild(GetDatabase())
end

---@return boolean
function GrimSettings.GetAnnounceScoreOnLevelUp()
    return GetDatabaseApi().GetAnnounceScoreOnLevelUp(GetDatabase())
end

---@return boolean
function GrimSettings.GetDisableMinimapIcon()
    return GetDatabaseApi().GetMinimapHidden(GetDatabase())
end

---@param database GrimCharacterState
---@param databaseApi GrimSettingsDatabaseApi
function GrimSettings.Initialize(database, databaseApi)
    activeDatabase = database
    activeDatabaseApi = databaseApi
end

---@param enabled boolean
---@return boolean
function GrimSettings.SetShowInCombat(enabled)
    return GetDatabaseApi().SetShowInCombat(GetDatabase(), enabled)
end

---@param enabled boolean
---@return boolean
function GrimSettings.SetGuildAnnouncementsEnabled(enabled)
    return GetDatabaseApi().SetGuildAnnouncementsEnabled(GetDatabase(), enabled)
end

---@param enabled boolean
---@return boolean
function GrimSettings.SetDeathAnnouncementToGuild(enabled)
    return GetDatabaseApi().SetAnnounceDeathToGuild(GetDatabase(), enabled)
end

---@param enabled boolean
---@return boolean
function GrimSettings.SetAnnounceScoreOnLevelUp(enabled)
    return GetDatabaseApi().SetAnnounceScoreOnLevelUp(GetDatabase(), enabled)
end

---@param disabled boolean
---@return boolean
function GrimSettings.SetDisableMinimapIcon(disabled)
    local GrimUIMinimap = ns.GrimUIMinimap
    return GrimUIMinimap.SetHidden(nil, GetDatabase(), disabled)
end

---@return boolean
function GrimSettings.ToggleShowInCombat()
    return GrimSettings.SetShowInCombat(not GrimSettings.GetShowInCombat())
end

return GrimSettings
