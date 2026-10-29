local assert = require("luassert")
local LogicContext = require("tests.support_logic_context")

describe("SavedVariables migrations", function()
    local GrimMigration

    before_each(function()
        GrimMigration = LogicContext.Create().GrimMigration
    end)

    describe("Apply", function()
        it("upgrades a version-zero database to the current version", function()
            local database = {
                databaseVersion = 0,
            }
            local returnedDatabase = GrimMigration.Apply(database)

            assert.is_table(returnedDatabase, "migration should still return a database table")
            assert.equals(database, returnedDatabase, "migration should preserve table identity")
            assert.equals(
                GrimMigration.CURRENT_VERSION,
                database.databaseVersion,
                "production migration should stamp a version zero database with the current version"
            )
        end)
    end)

    describe("ApplyVersions", function()
        it("runs pending migrations in version order", function()
            local database = {
                databaseVersion = 0,
                applied = {},
            }
            local testMigrations = {
                [1] = function(state)
                    table.insert(state.applied, "one")
                    state.firstValue = "ready"
                end,
                [2] = function(state)
                    table.insert(state.applied, "two")
                    state.sawFirstValue = state.firstValue
                end,
                [3] = function(state)
                    table.insert(state.applied, "three")
                end,
            }

            local returnedDatabase = GrimMigration.ApplyVersions(database, 3, testMigrations)

            assert.equals(database, returnedDatabase, "migration should return the existing database table")
            assert.equals("one,two,three", table.concat(database.applied, ","), "migrations should run in version order")
            assert.equals("ready", database.sawFirstValue, "each migration should see changes from earlier migrations")
            assert.equals(3, database.databaseVersion, "migration should advance the database to the target version")
        end)

        it("skips completed migrations", function()
            local database = {
                databaseVersion = 1,
                applied = {},
            }
            local testMigrations = {
                [1] = function()
                    error("completed migration should not run")
                end,
                [2] = function(state)
                    table.insert(state.applied, "two")
                end,
                [3] = function(state)
                    table.insert(state.applied, "three")
                end,
            }

            GrimMigration.ApplyVersions(database, 3, testMigrations)

            assert.equals("two,three", table.concat(database.applied, ","), "migration should skip completed versions")
            assert.equals(3, database.databaseVersion, "migration should apply every remaining version")
        end)

        it("leaves a database at the target version unchanged", function()
            local database = {
                databaseVersion = 2,
                marker = "unchanged",
            }
            local testMigrations = {
                [1] = function()
                    error("completed migration should not run")
                end,
                [2] = function()
                    error("current migration should not rerun")
                end,
            }

            local returnedDatabase = GrimMigration.ApplyVersions(database, 2, testMigrations)

            assert.equals(database, returnedDatabase, "current database migration should preserve table identity")
            assert.equals(2, database.databaseVersion, "current database migration should preserve its version")
            assert.equals("unchanged", database.marker, "current database migration should not change stored data")
        end)

        it("preserves a database newer than the target version", function()
            local database = {
                databaseVersion = 3,
                marker = "unchanged",
            }

            local returnedDatabase = GrimMigration.ApplyVersions(database, 2, {})

            assert.equals(database, returnedDatabase, "migration should preserve a newer database table")
            assert.equals(3, database.databaseVersion, "migration should not downgrade a newer database")
            assert.equals("unchanged", database.marker, "migration should not rewrite data from a newer database")
        end)

        it("records only successful migrations when a migration fails", function()
            local database = {
                databaseVersion = 0,
            }
            local testMigrations = {
                [1] = function(state)
                    state.firstMigrationRan = true
                end,
                [2] = function(state)
                    state.failedMigrationStarted = true
                    error("expected migration failure")
                end,
            }

            local succeeded, migrationError = pcall(function()
                GrimMigration.ApplyVersions(database, 2, testMigrations)
            end)

            assert.is_false(succeeded, "migration errors should propagate to the caller")
            local errorMessage = assert.is_string(migrationError, "migration should preserve the original error")
            assert.matches("expected migration failure", errorMessage, 1, true, "migration should preserve the original error")
            assert.is_true(database.firstMigrationRan, "successful migrations should remain applied")
            assert.equals(1, database.databaseVersion, "migration should record only completed versions")
            assert.is_true(database.failedMigrationStarted, "failed migrations should not roll back partial changes")
        end)
    end)
end)
