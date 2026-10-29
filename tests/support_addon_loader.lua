local AddonLoader = {}

local DEFAULT_ADDON_NAME = "GrimGuesser"
local DEFAULT_SOURCE_DIR = "./src"
local DEFAULT_TOC_NAME = "GrimGuesser_Vanilla.toc"
local WOW_STANDARD_GLOBAL_NAMES = {
    "assert",
    "collectgarbage",
    "error",
    "getmetatable",
    "ipairs",
    "next",
    "pairs",
    "pcall",
    "print",
    "rawequal",
    "rawget",
    "rawset",
    "select",
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "unpack",
    "xpcall",
    "coroutine",
    "math",
    "string",
    "table",
}

---@return table
local function createEnvironment()
    local environment = {}
    for _, name in ipairs(WOW_STANDARD_GLOBAL_NAMES) do
        environment[name] = rawget(_G, name)
    end
    environment._G = environment
    return environment
end

---@param sourceDir string
---@param moduleName string
---@return string
local function buildSourcePath(sourceDir, moduleName)
    return sourceDir .. "/" .. moduleName .. ".lua"
end

---@param tocPath string
---@return string[]
local function readModuleOrder(tocPath)
    local tocFile, openError = io.open(tocPath, "r")
    if not tocFile then
        error(openError)
    end

    local moduleOrder = {}
    for line in tocFile:lines() do
        local sourcePath = string.match(line, "^%s*([^#].-%.lua)%s*$")
        if sourcePath and not string.find(sourcePath, "[/\\]") then
            local moduleName = string.match(sourcePath, "^(.+)%.lua$")
            moduleOrder[#moduleOrder + 1] = moduleName
        end
    end
    tocFile:close()

    return moduleOrder
end

---@param self table
---@return string[]
local function getModuleOrder(self)
    if not self.moduleOrder then
        self.moduleOrder = readModuleOrder(self.tocPath)
    end

    return self.moduleOrder
end

---@param self table
---@param moduleName string
---@return any
local function loadModule(self, moduleName)
    if self.loaded[moduleName] then
        return self.results[moduleName]
    end

    local path = buildSourcePath(self.sourceDir, moduleName)
    local chunk, loadError = loadfile(path)
    if not chunk then
        error(loadError)
    end

    setfenv(chunk, self.env)
    local result = chunk(self.addonName, self.ns)
    self.loaded[moduleName] = true
    self.results[moduleName] = result

    return result
end

---@param self table
---@param targetModuleName string
---@return any
local function loadThrough(self, targetModuleName)
    local moduleOrder = getModuleOrder(self)
    local targetIndex = nil

    for index, moduleName in ipairs(moduleOrder) do
        if moduleName == targetModuleName then
            targetIndex = index
            break
        end
    end

    if not targetIndex then
        error("Module is not listed in " .. self.tocPath .. ": " .. tostring(targetModuleName))
    end

    for index = 1, targetIndex do
        self:Load(moduleOrder[index])
    end

    return self.results[targetModuleName]
end

---@param self table
---@return table
local function loadAll(self)
    local moduleOrder = getModuleOrder(self)

    for _, moduleName in ipairs(moduleOrder) do
        self:Load(moduleName)
    end

    return self.ns
end

---@param self table
---@return string[]
local function getModuleNames(self)
    local copy = {}
    for index, moduleName in ipairs(getModuleOrder(self)) do
        copy[index] = moduleName
    end

    return copy
end

---@param options table|nil
---@return table
function AddonLoader.Create(options)
    options = options or {}

    local sourceDir = options.sourceDir or os.getenv("GRIMGUESSER_TEST_SOURCE_DIR") or DEFAULT_SOURCE_DIR

    return {
        addonName = options.addonName or DEFAULT_ADDON_NAME,
        sourceDir = sourceDir,
        tocPath = options.tocPath or sourceDir .. "/" .. DEFAULT_TOC_NAME,
        env = createEnvironment(),
        ns = options.ns or {},
        loaded = {},
        results = {},
        Load = loadModule,
        LoadThrough = loadThrough,
        LoadAll = loadAll,
        GetModuleNames = getModuleNames,
    }
end

return AddonLoader
