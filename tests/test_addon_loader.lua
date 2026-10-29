local assert = require("luassert")
describe("Addon loader", function()
    local AddonLoader = require("tests.support_addon_loader")
    local loader

    before_each(function()
        loader = AddonLoader.Create()
    end)

    describe("manifest", function()
        it("reads addon modules in manifest order", function()
            local moduleNames = loader:GetModuleNames()
            assert.equals("GrimConstants", moduleNames[1], "manifest should begin with the first addon module")
            assert.equals("GrimController", moduleNames[#moduleNames], "manifest should end with the addon controller")
            for _, moduleName in ipairs(moduleNames) do
                assert.is_nil(string.find(moduleName, "[/\\]"), "manifest should exclude bundled library paths")
            end
        end)
        it("returns a copy of manifest order", function()
            local moduleNames = loader:GetModuleNames()
            moduleNames[1] = "changed by caller"
            assert.equals("GrimConstants", loader:GetModuleNames()[1], "manifest access should not expose the loader's cached order")
        end)
    end)

    describe("module loading", function()
        it("caches modules and loads through the requested boundary", function()
            local constants = loader:Load("GrimConstants")
            assert.equals(constants, loader:Load("GrimConstants"), "exact loads should return the cached module")
            loader:LoadThrough("GrimLogic")
            assert.is_truthy(loader.ns.GrimDebug, "load-through should include earlier manifest modules")
            assert.is_truthy(loader.ns.GrimParser, "load-through should preserve manifest order")
            assert.is_nil(loader.ns.GrimMigration, "load-through should stop at the requested module")
        end)
    end)

    describe("namespace isolation", function()
        it("creates isolated addon namespaces", function()
            local secondLoader = AddonLoader.Create()
            assert.is_not.equal(loader.ns, secondLoader.ns, "fresh loaders should use isolated namespaces")
            assert.is_not.equal(loader.env, secondLoader.env, "fresh loaders should use isolated environments")
            assert.equals(loader.env, loader.env._G, "addon environments should expose themselves as _G")
        end)
    end)

    describe("environment isolation", function()
        it("exposes only the WoW-compatible standard library", function()
            local allowedGlobals = {
                "assert", "collectgarbage", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print",
                "rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "unpack",
                "xpcall", "coroutine", "math", "string", "table",
            }
            local unavailableGlobals = { "os", "io", "package", "debug", "require", "dofile", "loadfile" }

            for _, name in ipairs(allowedGlobals) do
                assert.is_truthy(loader.env[name], "addon environments should include WoW-compatible global " .. name)
            end
            for _, name in ipairs(unavailableGlobals) do
                assert.is_nil(loader.env[name], "addon environments should exclude unavailable global " .. name)
            end
        end)

        it("confines addon global writes to the loader environment", function()
            local fixtureLoader = AddonLoader.Create({
                addonName = "EnvironmentFixture",
                sourceDir = "./tests/fixtures",
            })
            local result = fixtureLoader:Load("addon_environment")

            assert.equals("EnvironmentFixture", result.addonName, "isolated chunks should still receive their addon name")
            assert.is_true(result.hasStandardType, "isolated chunks should receive the approved standard library")
            assert.equals("bare write", fixtureLoader.env.SandboxBareGlobal, "bare writes should stay in the addon environment")
            assert.equals("explicit write", fixtureLoader.env.SandboxExplicitGlobal, "_G writes should stay in the addon environment")
            assert.is_nil(rawget(_G, "SandboxBareGlobal"), "bare writes should not reach the process globals")
            assert.is_nil(rawget(_G, "SandboxExplicitGlobal"), "_G writes should not reach the process globals")
        end)
    end)

    describe("invalid requests", function()
        it("rejects unknown boundaries before loading any modules", function()
            local loadError = assert.has_error(function()
                loader:LoadThrough("MissingModule")
            end)
            local message = "unknown boundary errors should name the missing module"
            local errorMessage = assert.is_string(loadError, message)
            assert.matches("MissingModule", errorMessage, 1, true, message)
            assert.is_nil(next(loader.loaded), "unknown boundaries should fail before loading modules")
        end)
    end)
end)
