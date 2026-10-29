local AddonLoader = require("tests.support_addon_loader")
local spy = require("luassert.spy")

local function createRegion(regionKind, name, parent, template)
    local region = {
        kind = regionKind,
        name = name,
        parent = parent,
        template = template,
        children = {},
        points = {},
        scripts = {},
        visible = true,
        enabled = true,
    }

    function region:SetSize(width, height)
        self.width = width
        self.height = height
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, width, height)
        end
    end

    function region:GetSize()
        return self.width, self.height
    end

    function region:GetWidth()
        return self.width or 0
    end

    function region:GetHeight()
        return self.height or 0
    end

    function region:SetWidth(width)
        self.width = width
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, self.width, self.height)
        end
    end

    function region:SetHeight(height)
        self.height = height
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, self.width, self.height)
        end
    end

    function region:SetPoint(...)
        self.points[#self.points + 1] = { ... }
    end

    function region:GetPoint(index)
        local point = self.points[index or 1]
        if not point then
            return nil
        end

        return unpack(point)
    end

    function region:ClearAllPoints()
        self.points = {}
    end

    function region:SetFrameStrata(value)
        self.frameStrata = value
    end

    function region:SetToplevel(value)
        self.toplevel = value
    end

    function region:SetMovable(value)
        self.movable = value
    end

    function region:SetResizable(value)
        self.resizable = value
    end

    function region:SetClipsChildren(value)
        self.clipsChildren = value
    end

    function region:SetMinResize(width, height)
        self.minResize = {
            width = width,
            height = height,
        }
    end

    function region:SetMaxResize(width, height)
        self.maxResize = {
            width = width,
            height = height,
        }
    end

    function region:EnableMouse(value)
        self.mouseEnabled = value
    end

    function region:SetMotionScriptsWhileDisabled(value)
        self.motionScriptsWhileDisabled = value == true
    end

    function region:GetMotionScriptsWhileDisabled()
        return self.motionScriptsWhileDisabled == true
    end

    function region:RegisterForDrag(button)
        self.dragButton = button
    end

    function region:RegisterEvent(eventName)
        self.registeredEvents = self.registeredEvents or {}
        self.registeredEvents[eventName] = true
    end

    function region:SetScript(eventName, handler)
        self.scripts[eventName] = handler
    end

    function region:GetScript(eventName)
        return self.scripts[eventName]
    end

    function region:Show()
        local wasShown = self.visible == true
        self.visible = true
        if not wasShown and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function region:Hide()
        local wasShown = self.visible == true
        self.visible = false
        if wasShown and self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end

    function region:IsShown()
        return self.visible == true
    end

    function region:GetName()
        return self.name
    end

    function region:GetParent()
        return self.parent
    end

    function region:SetText(text)
        self.text = text
    end

    function region:GetText()
        return self.text
    end

    function region:SetChecked(value)
        self.checked = value == true
    end

    function region:GetChecked()
        return self.checked == true
    end

    function region:SetTextColor(red, green, blue, alpha)
        self.textColor = { red, green, blue, alpha }
    end

    function region:SetOwner(owner, anchor)
        self.owner = owner
        self.anchor = anchor
        self.lines = {}
    end

    function region:ClearLines()
        self.lines = {}
    end

    function region:AddLine(text, red, green, blue, wrap)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = {
            left = text,
            right = nil,
            leftColor = red and { red, green, blue } or nil,
            rightColor = nil,
            wrap = wrap == true,
        }
    end

    function region:AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = {
            left = leftText,
            right = rightText,
            leftColor = leftR and { leftR, leftG, leftB } or nil,
            rightColor = rightR and { rightR, rightG, rightB } or nil,
        }
    end

    function region:SetNormalTexture(texture)
        self.normalTexture = texture
    end

    function region:GetNormalTexture()
        return self.normalTexture
    end

    function region:SetPushedTexture(texture)
        self.pushedTexture = texture
    end

    function region:GetPushedTexture()
        return self.pushedTexture
    end

    function region:SetDisabledTexture(texture)
        self.disabledTexture = texture
    end

    function region:GetDisabledTexture()
        return self.disabledTexture
    end

    function region:SetHighlightTexture(texture)
        self.highlightTexture = texture
    end

    function region:GetHighlightTexture()
        return self.highlightTexture
    end

    function region:SetNormalFontObject(fontObject)
        self.normalFontObject = fontObject
    end

    function region:SetHighlightFontObject(fontObject)
        self.highlightFontObject = fontObject
    end

    function region:SetJustifyH(value)
        self.justifyH = value
    end

    function region:SetJustifyV(value)
        self.justifyV = value
    end

    function region:SetWordWrap(value)
        self.wordWrap = value
    end

    function region:SetMultiLine(value)
        self.multiLine = value
    end

    function region:SetNonSpaceWrap(value)
        self.nonSpaceWrap = value
    end

    function region:SetTextInsets(left, right, top, bottom)
        self.textInsets = { left, right, top, bottom }
    end

    function region:SetColorTexture(red, green, blue, alpha)
        self.colorTexture = { red, green, blue, alpha }
    end

    function region:SetTexture(path)
        self.texturePath = path
    end

    function region:SetAutoFocus(value)
        self.autoFocus = value
    end

    function region:SetFontObject(value)
        self.fontObject = value
    end

    function region:SetCursorPosition(value)
        self.cursorPosition = value
    end

    function region:SetAllPoints()
        self.allPoints = true
    end

    function region:SetFocus()
        self.hasFocus = true
    end

    function region:ClearFocus()
        self.hasFocus = false
    end

    function region:HighlightText(startIndex, endIndex)
        self.highlightRange = { startIndex, endIndex }
    end

    function region:SetScrollChild(child)
        self.scrollChild = child
    end

    function region:Raise()
        self.raised = true
    end

    function region:Enable()
        self.enabled = true
    end

    function region:Disable()
        self.enabled = false
    end

    function region:IsEnabled()
        return self.enabled == true
    end

    function region:Click(button)
        if self.scripts.OnClick then
            self.scripts.OnClick(self, button)
        end
    end

    function region:StartMoving()
        self.startedMoving = true
    end

    function region:StartSizing(point)
        self.startedSizing = point
    end

    function region:StopMovingOrSizing()
        self.stoppedMoving = true
    end

    function region:SetFrameLevel(value)
        self.frameLevel = value
    end

    function region:GetFrameLevel()
        return self.frameLevel or 0
    end

    function region:GetFontString()
        if not self.fontString then
            self.fontString = createRegion("FontString", nil, self, nil)
        end
        return self.fontString
    end

    function region:CreateFontString(childName, _, childTemplate)
        local child = createRegion("FontString", childName, self, childTemplate)
        self.children[#self.children + 1] = child
        return child
    end

    function region:CreateTexture(childName, childLayer)
        local child = createRegion("Texture", childName, self, childLayer)
        self.children[#self.children + 1] = child
        return child
    end

    function region:GetStringHeight()
        local text = self.text or ""
        local lineCount = 1
        for _ in string.gmatch(text, "\n") do
            lineCount = lineCount + 1
        end
        return lineCount * 12
    end

    function region:GetStringWidth()
        local text = self.text or ""
        return string.len(text) * 6
    end

    return region
end

local function attachBasicFrameCloseButton(env, frame, name)
    local closeButtonName = name and (name .. "CloseButton") or nil
    local closeButton = createRegion("Button", closeButtonName, frame, "UIPanelCloseButton")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.children[#frame.children + 1] = closeButton
    frame.CloseButton = closeButton
    if closeButtonName then
        env[closeButtonName] = closeButton
    end
end

local function walkRegions(region, callback)
    callback(region)
    for _, child in ipairs(region.children or {}) do
        walkRegions(child, callback)
    end
    if region.fontString then
        walkRegions(region.fontString, callback)
    end
end

local function findRegionText(root, needle)
    local matchedText = nil
    walkRegions(root, function(region)
        if matchedText ~= nil then
            return
        end
        if type(region.text) == "string" and string.find(region.text, needle, 1, true) then
            matchedText = region.text
        end
    end)
    return matchedText
end

local function findDropdownButtonByText(dropdown, text)
    for _, button in ipairs(dropdown.buttons or {}) do
        if button:IsShown() and button.text and button.text:GetText() == text then
            return button
        end
    end

    return nil
end

local function dispatchEvent(env, frame, eventName, ...)
    if not frame or not eventName then
        return false
    end

    local eventArgs = { ... }
    local fired = false
    local dispatchedFrames = {}

    local function fireFrame(target)
        if not target or dispatchedFrames[target] then
            return
        end
        dispatchedFrames[target] = true

        if not (target.registeredEvents and target.registeredEvents[eventName]) then
            return
        end

        local onEvent = target:GetScript("OnEvent")
        if not onEvent then
            return
        end

        onEvent(target, eventName, unpack(eventArgs))
        fired = true
    end

    fireFrame(frame)

    for _, createdFrame in ipairs(env.__frames or {}) do
        fireFrame(createdFrame)
    end

    return fired
end

local function pressEscape(env)
    for _, frameName in ipairs(env.UISpecialFrames or {}) do
        local frame = env[frameName]
        if frame and frame:IsShown() then
            frame:Hide()
            return true
        end
    end

    return false
end

---@param env table
---@return table<string, LuassertSpy>
local function initializeBundledLibs(env)
    local libDataBroker = {}
    local libDBIcon = {
        Register = spy.new(),
        Refresh = spy.new(),
        Hide = spy.new(),
        Show = spy.new(),
    }

    function libDataBroker.NewDataObject(_, _, dataObject)
        return dataObject
    end

    ---@param libraryName string
    ---@param silent boolean|nil
    ---@return LibDataBrokerApi|LibDBIconApi|nil
    ---@overload fun(libraryName: "LibDataBroker-1.1", silent?: boolean): LibDataBrokerApi
    ---@overload fun(libraryName: "LibDBIcon-1.0", silent?: boolean): LibDBIconApi
    env.LibStub = function(libraryName, silent)
        if libraryName == "LibDataBroker-1.1" then
            return libDataBroker
        end

        if libraryName == "LibDBIcon-1.0" then
            return libDBIcon
        end

        if not silent then
            error("Unknown library: " .. tostring(libraryName))
        end

        return nil
    end

    return libDBIcon
end

---@param env table
---@param options table|nil
---@return table
local function initializeGlobals(env, options)
    options = options or {}
    env.UIParent = createRegion("Frame", "UIParent", nil, nil)
    env.UIParent:SetSize(1024, 768)
    env.GrimCharacterState = nil
    env.LibStub = nil
    env.UISpecialFrames = {}
    env.__frames = {}
    local function registerCanvasLayoutCategory(frame, name)
        local category = {
            ID = env.Settings.nextCategoryId,
            name = name,
            frame = frame,
        }

        function category:GetID()
            return self.ID
        end

        env.Settings.nextCategoryId = env.Settings.nextCategoryId + 1
        env.Settings.registeredCanvasCategories[#env.Settings.registeredCanvasCategories + 1] = category
        return category
    end

    local function registerAddOnCategory(category)
        env.Settings.registeredAddOnCategories[#env.Settings.registeredAddOnCategories + 1] = category
        return category
    end

    env.Settings = {
        registeredCanvasCategories = {},
        registeredAddOnCategories = {},
        nextCategoryId = 1,
        RegisterCanvasLayoutCategory = registerCanvasLayoutCategory,
        RegisterAddOnCategory = registerAddOnCategory,
    }
    env.wipe = function(values)
        for key in pairs(values) do
            values[key] = nil
        end

        return values
    end

    env.CreateFrame = function(kind, name, parent, template)
        local frame = createRegion(kind, name, parent, template)
        env.__frames[#env.__frames + 1] = frame
        if parent then
            parent.children[#parent.children + 1] = frame
        end
        if name then
            env[name] = frame
        end
        if template == "BasicFrameTemplateWithInset" then
            attachBasicFrameCloseButton(env, frame, name)
        end
        return frame
    end

    env.DEFAULT_CHAT_FRAME = {
        messages = {},
    }

    function env.DEFAULT_CHAT_FRAME:AddMessage(message)
        self.messages[#self.messages + 1] = message
    end

    local sendChatMessage = spy.new()
    env.SendChatMessage = sendChatMessage
    env.IsInGuild = function()
        return options.inGuild ~= false
    end

    local cvars = {
        hardcoreDeathChatType = options.hardcoreDeathChatType or "1",
    }
    env.GetCVar = function(name)
        return cvars[name]
    end
    ---@param name string
    ---@param value string
    ---@return nil
    local setCVar = spy.new(function(name, value)
        cvars[name] = value
    end)
    env.SetCVar = setCVar

    local joinedChannels = {
        HardcoreDeaths = options.hardcoreDeathsJoined ~= false,
    }
    env.GetChannelName = function(name)
        if joinedChannels[name] then
            return 1, name
        end

        return 0, nil
    end
    ---@param name string
    ---@return nil
    local joinPermanentChannel = spy.new(function(name)
        joinedChannels[name] = true
    end)
    env.JoinPermanentChannel = joinPermanentChannel

    env.SlashCmdList = {}

    env.GameTooltip = {
        lines = {},
        visible = false,
    }

    function env.GameTooltip:SetOwner(owner, anchor)
        self.owner = owner
        self.anchor = anchor
        self.lines = {}
    end

    function env.GameTooltip:AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB)
        self.lines[#self.lines + 1] = {
            left = leftText,
            right = rightText,
            leftColor = leftR and { leftR, leftG, leftB } or nil,
            rightColor = rightR and { rightR, rightG, rightB } or nil,
        }
    end

    function env.GameTooltip:Show()
        self.visible = true
    end

    function env.GameTooltip:Hide()
        self.visible = false
    end

    env.FauxScrollFrame_Update = function(frame, totalItems, visibleItems, itemHeight)
        frame.lastUpdate = {
            totalItems = totalItems,
            visibleItems = visibleItems,
            itemHeight = itemHeight,
        }
    end

    env.FauxScrollFrame_GetOffset = function(frame)
        return frame.offset or 0
    end

    env.FauxScrollFrame_OnVerticalScroll = function(frame, offset, itemHeight, updateFunc)
        frame.offset = math.floor(offset / itemHeight)
        updateFunc()
    end

    env.FormatLargeNumber = options.formatLargeNumber or tostring

    env.strtrim = function(text)
        return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
    end

    env.time = function()
        return 24680
    end

    env.date = function(formatString)
        if formatString == "%H:%M:%S" then
            return "12:34:56"
        end
        if formatString == "%B %d, %Y" then
            return "January 01, 1970"
        end
        if formatString == "%Y" then
            return "1970"
        end
        return "10:05"
    end

    env.UnitName = function(_)
        return "HarnessPlayer"
    end

    env.UnitLevel = function(_)
        return 17
    end

    env.GetZoneText = function()
        return "Elwynn Forest"
    end

    env.GetRealmName = function()
        return "Defias Pillager"
    end

    -- https://wago.tools/db2/GlobalStrings?build=1.15.5.57979&filter%5BBaseTag%5D=HARDCORE_CAUSEOFDEATH&page=1&sort%5BBaseTag%5D=asc
    -- not all of these are used, we include everything to ensure proper testing
    env.HARDCORE_CAUSEOFDEATH_CREATURE = "|Hplayer:%s|h[%s]|h has been slain by a %s in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_DROWNING = "|Hplayer:%s|h[%s]|h drowned to death in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_DUEL = "|Hplayer:%s|h[%s]|h has been slain in a duel by %s in $s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_FALLING = "|Hplayer:%s|h[%s]|h fell to their death in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_FATIGUE = "|Hplayer:%s|h[%s]|h died of fatigue in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_FIRE = "|Hplayer:%s|h[%s]|h was burnt to death by fire in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_LAVA = "|Hplayer:%s|h[%s]|h was burnt to a crisp by lava in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_NONE = "|Hplayer:%s|h[%s]|h has died at level %d"
    env.HARDCORE_CAUSEOFDEATH_PVP = "|Hplayer:%s|h[%s]|h has been slain by %s in %s! They were level %d"
    env.HARDCORE_CAUSEOFDEATH_SLIME = "|Hplayer:%s|h[%s]|h was slimed to death in %s! They w"

    env.UnitFactionGroup = function(_)
        return options.faction or "Alliance"
    end

    env.ITEM_QUALITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },
        [1] = { r = 1.0, g = 1.0, b = 1.0 },
        [2] = { r = 0.12, g = 1.0, b = 0.0 },
        [3] = { r = 0.0, g = 0.44, b = 0.87 },
        [4] = { r = 0.64, g = 0.21, b = 0.93 },
    }

    return {
        libDBIcon = initializeBundledLibs(env),
        sendChatMessage = sendChatMessage,
        cvars = cvars,
        setCVar = setCVar,
        joinedChannels = joinedChannels,
        joinPermanentChannel = joinPermanentChannel,
    }
end

local function loadUiModules(loader)
    loader:LoadThrough("GrimUIMain")

    return loader, loader.ns.GrimUI, loader.ns.GrimUIMain, loader.ns.GrimUIMinimap
end

local UIHarness = {}

function UIHarness.Create(options)
    options = options or {}
    local loader = AddonLoader.Create()
    local environment = initializeGlobals(loader.env, options)

    if options.version then
        loader:Load("GrimConstants").VERSION = options.version
    end

    local printedMessages = {}
    local _, GrimUI, GrimUIMain, GrimUIMinimap = loadUiModules(loader)
    local ns = loader.ns
    loader.env.GrimCharacterState = ns.GrimDatabase.Init(options.state)
    local GrimMainFrame, GrimDebug, GrimLog = GrimUIMain.Initialize(
        loader.env.GrimCharacterState,
        ns.GrimLogic,
        ns.GrimConstants.STORAGE.maxRecentDeaths
    )
    GrimMainFrame.__testNs = ns
    local introDemoController = ns.GrimDemo.Initialize(
        loader.env.GrimCharacterState,
        function()
            GrimMainFrame:RefreshDeaths()
            GrimMainFrame:RefreshLockedPrediction()
            GrimMainFrame:RefreshCollapsedSummary()
        end
    )
    introDemoController:AttachFrame(GrimMainFrame)

    return {
        env = loader.env,
        loader = loader,
        ns = ns,
        GrimUI = GrimUI,
        GrimUIAutocomplete = ns.GrimUIAutocomplete,
        GrimUIDeathLogList = ns.GrimUIDeathLogList,
        GrimUIDebug = ns.GrimUIDebug,
        GrimUIDemo = ns.GrimUIDemo,
        GrimUIHelp = ns.GrimUIHelp,
        GrimUILog = ns.GrimUILog,
        GrimUIMain = GrimUIMain,
        GrimUIMainCollapsed = ns.GrimUIMainCollapsed,
        GrimUIMainPrediction = ns.GrimUIMainPrediction,
        GrimUIMainRecentDeaths = ns.GrimUIMainRecentDeaths,
        GrimUIMinimap = GrimUIMinimap,
        GrimUIRefresh = ns.GrimUIRefresh,
        GrimUITooltip = ns.GrimUITooltip,
        GrimConstants = ns.GrimConstants,
        GrimDatabase = ns.GrimDatabase,
        GrimLogic = ns.GrimLogic,
        GrimStats = ns.GrimStats,
        GrimDemo = ns.GrimDemo,
        GrimMainFrame = GrimMainFrame,
        GrimDebug = GrimDebug,
        GrimLog = GrimLog,
        introDemoController = introDemoController,
        printedMessages = printedMessages,
        sendChatMessage = environment.sendChatMessage,
        libDBIcon = environment.libDBIcon,
        cvars = environment.cvars,
        setCVar = environment.setCVar,
        joinedChannels = environment.joinedChannels,
        joinPermanentChannel = environment.joinPermanentChannel,
        dispatchEvent = function(frame, eventName, ...)
            return dispatchEvent(loader.env, frame, eventName, ...)
        end,
        pressEscape = function()
            return pressEscape(loader.env)
        end,
        findRegionText = findRegionText,
        findDropdownButtonByText = findDropdownButtonByText,
    }
end

function UIHarness.CreateAddon(options)
    options = options or {}
    local loader = AddonLoader.Create()
    local environment = initializeGlobals(loader.env, options)

    local _, GrimUI, GrimUIMain, GrimUIMinimap = loadUiModules(loader)
    local ns = loader.ns
    loader.env.GrimCharacterState = options.state
    loader:LoadAll()

    local function getController()
        return rawget(loader.env, "GrimAddonFrame")
    end

    local function getMainFrame()
        return rawget(loader.env, "GrimFrame")
    end

    local function getDebugFrame()
        return rawget(loader.env, "GrimDebugFrame")
    end

    local function getLogFrame()
        return rawget(loader.env, "GrimLogFrame")
    end

    return {
        env = loader.env,
        loader = loader,
        ns = ns,
        GrimUI = GrimUI,
        GrimUIAutocomplete = ns.GrimUIAutocomplete,
        GrimUIDeathLogList = ns.GrimUIDeathLogList,
        GrimUIDebug = ns.GrimUIDebug,
        GrimUIDemo = ns.GrimUIDemo,
        GrimUIHelp = ns.GrimUIHelp,
        GrimUILog = ns.GrimUILog,
        GrimUIMain = GrimUIMain,
        GrimUIMainCollapsed = ns.GrimUIMainCollapsed,
        GrimUIMainPrediction = ns.GrimUIMainPrediction,
        GrimUIMainRecentDeaths = ns.GrimUIMainRecentDeaths,
        GrimUIMinimap = GrimUIMinimap,
        GrimUIRefresh = ns.GrimUIRefresh,
        GrimUITooltip = ns.GrimUITooltip,
        GrimConstants = ns.GrimConstants,
        GrimDatabase = ns.GrimDatabase,
        GrimDebug = ns.GrimDebug,
        GrimDebugState = ns.GrimDebugState,
        GrimLogic = ns.GrimLogic,
        GrimUISettings = ns.GrimUISettings,
        controller = getController(),
        getController = getController,
        getMainFrame = getMainFrame,
        getDebugFrame = getDebugFrame,
        getLogFrame = getLogFrame,
        chatMessages = loader.env.DEFAULT_CHAT_FRAME.messages,
        sendChatMessage = environment.sendChatMessage,
        libDBIcon = environment.libDBIcon,
        cvars = environment.cvars,
        setCVar = environment.setCVar,
        joinedChannels = environment.joinedChannels,
        joinPermanentChannel = environment.joinPermanentChannel,
        dispatchEvent = function(frame, eventName, ...)
            return dispatchEvent(loader.env, frame, eventName, ...)
        end,
        pressEscape = function()
            return pressEscape(loader.env)
        end,
    }
end

return UIHarness
