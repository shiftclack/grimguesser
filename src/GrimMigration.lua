---@diagnostic disable: inject-field
local _, ns = ...
---@cast ns GrimNamespace

local GrimMigration = ns.GrimMigration or {}
ns.GrimMigration = GrimMigration

GrimMigration.CURRENT_VERSION = 1

---@type table<integer, fun(database: GrimCharacterState)>
local migrations = {
    [1] = function(_)
    end,
}

---@param database table
---@param targetVersion integer
---@param versionMigrations table<integer, fun(database: table)>
---@return table
function GrimMigration.ApplyVersions(database, targetVersion, versionMigrations)
    local version = database.databaseVersion

    while version < targetVersion do
        local nextVersion = version + 1
        versionMigrations[nextVersion](database)
        database.databaseVersion = nextVersion
        version = nextVersion
    end

    return database
end

---@param database GrimCharacterState
---@return GrimCharacterState
function GrimMigration.Apply(database)
    GrimMigration.ApplyVersions(database, GrimMigration.CURRENT_VERSION, migrations)
    return database
end

return GrimMigration
