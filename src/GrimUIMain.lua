local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIAutocomplete = ns.GrimUIAutocomplete
local GrimDatabase = ns.GrimDatabase
local GrimConstants = ns.GrimConstants
local GrimUIDebug = ns.GrimUIDebug
local GrimUIHelp = ns.GrimUIHelp
local GrimUILog = ns.GrimUILog
local GrimUIMain = ns.GrimUIMain or {}
local GrimUIMainCollapsed = ns.GrimUIMainCollapsed
local GrimUIMainPrediction = ns.GrimUIMainPrediction
local GrimUIMainRecentDeaths = ns.GrimUIMainRecentDeaths
local GrimUIMode = ns.GrimUIMode
local GrimUIRefresh = ns.GrimUIRefresh
local GrimUISetup = ns.GrimUISetup
local GrimUITooltip = ns.GrimUITooltip
ns.GrimUIMain = GrimUIMain
local DEMO_RULES = GrimConstants.DEMO
local WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS = DEMO_RULES.waitingForFirstDeathMinDurationSeconds

---@class GrimMainLayout
---@field outsideGutter integer
---@field scrollbarWidth integer
---@field titlebarDragLeftInset integer
---@field titlebarDragRightInset integer
---@field titlebarDragTopInset integer
---@field titlebarDragHeight integer
---@field standardButtonWidth integer
---@field standardButtonHeight integer
---@field compactButtonHeight integer
---@field actionButtonGap integer
---@field modalButtonGap integer
---@field mainWindowHeight integer
---@field expandedWindowWidth integer
---@field footerGutter integer
---@field logWindowHeight integer
---@field logWindowWidth integer
---@field logVisibleRows integer
---@field deathLogRowHeight integer
---@field collapsedWindowWidth integer
---@field collapsedWindowHeight integer
---@field collapsedWindowMinHeight integer
---@field collapsedWindowMaxHeight integer
---@field collapsedLogVisibleRows integer
---@field collapsedLogHeaderY integer
---@field collapsedLogFrameY integer
---@field collapsedLogRowHeight integer
---@field deathLogHeaderY integer
---@field deathLogFrameY integer
---@field deathLogDividerY integer
---@field logVerticalSpacing integer
---@field historyScrollbarGap integer
---@field scrollbarInset integer
---@field historySubtitleY integer
---@field historySubtitleHeaderSpacing integer
---@field historyLogHeaderY integer
---@field historyLogFrameY integer
---@field scoreSummaryY integer
---@field predictionLabelX integer
---@field predictionControlX integer
---@field predictionSectionTop integer
---@field predictionLevelRowY integer
---@field predictionSourceRowY integer
---@field predictionZoneRowY integer
---@field predictionSummaryY integer
---@field predictionSummaryWidth integer
---@field predictionIntroDemoPanelX integer
---@field predictionIntroDemoPanelY integer
---@field predictionIntroDemoPanelWidth integer
---@field predictionIntroDemoPanelHeight integer
---@field predictionButtonY integer

---@class GrimWidget
---@field [string] any

---@class GrimEditBox: GrimWidget

---@class GrimPredictionPayoutPreviewRow
---@field text string

---@alias GrimIntroDemoDisplayLogic GrimMainLogic|GrimRefreshLogic

---@class GrimIntroDemoController
---@field IsActive fun(self: GrimIntroDemoController): boolean
---@field GetDisplayedState fun(self: GrimIntroDemoController, logic: GrimIntroDemoDisplayLogic): GrimDisplayState|nil
---@field Dismiss fun(self: GrimIntroDemoController)
---@field Tick fun(self: GrimIntroDemoController, elapsed: number)

---@class GrimMainLogic
---@field NormalizePredictionValue fun(value: string|nil, anyValue: string|nil): string|nil
---@field GetPredictionElements fun(prediction: GrimPrediction|GrimPredictionElements|nil): GrimPredictionElements|nil
---@field FormatLockedPrediction fun(prediction: GrimPrediction|GrimPredictionElements|nil): string
---@field UpdateDraftPrediction fun(database: GrimCharacterState, prediction: GrimPrediction|GrimPredictionElements): GrimPrediction|nil
---@field ApplyLockedPrediction fun(database: GrimCharacterState, prediction: GrimPrediction|GrimPredictionElements): GrimPrediction|nil
---@field ClearLockedPrediction fun(database: GrimCharacterState)
---@field GetDisplayState fun(database: GrimCharacterState): GrimDisplayState
---@field GetPredictionPayoutPreviewRows fun(prediction: GrimPrediction|GrimPredictionElements|nil): GrimPredictionPayoutPreviewRow[]
---@field ToDisplayText fun(value: string|nil): string|nil

---@class GrimMainFrameShell: GrimRefreshReadyControllerFrame
---@field [string] any
---@field state GrimCharacterState
---@field introDemoController GrimIntroDemoController|nil
---@field isCollapsed boolean|nil
---@field activeEditBox GrimEditBox|nil
---@field suggestionList string[]|nil
---@field suggestionKind string|nil
---@field collapsedWindowStates table<string, boolean>|nil

---@class GrimMainFrame: GrimMainFrameShell
---@field logFrame GrimWidget
---@field helpFrame GrimWidget
---@field githubLinkFrame GrimGitHubLinkFrame
---@field dropdown GrimWidget
---@field gameInfoCallout GrimWidget
---@field sourceEditBox GrimEditBox
---@field zoneEditBox GrimEditBox
---@field lockButton GrimWidget
---@field pauseButton GrimWidget
---@field bottomLogButton GrimWidget
---@field helpButton GrimWidget
---@field minimizeButton GrimWidget
---@field levelRangeButtons GrimWidget[]
---@field collapsedLogHeaders GrimWidget[]
---@field collapsedLogFrame GrimWidget
---@field collapsedScoreDivider GrimWidget
---@field collapsedPointsValue GrimWidget
---@field collapsedPointsLabel GrimWidget
---@field collapsedResizeHandle GrimWidget
---@field recentDeathsFrame GrimWidget
---@field demoModeWatermark GrimWidget
---@field emptyPredictionPrompt GrimWidget
---@field waitingPromptText GrimWidget
---@field waitingPromptDots GrimWidget
---@field waitingPromptHelpText GrimWidget
---@field setupFrame GrimSetupFrame
---@field deathRows GrimWidget[]
---@field totalPointsValue GrimWidget
---@field currentStreakValue GrimWidget
---@field longestStreakValue GrimWidget
---@field introDemoAttractPanel GrimWidget
---@field levelRangeLabel GrimWidget
---@field sourceLabel GrimWidget
---@field zoneLabel GrimWidget
---@field currentPredictionLabel GrimWidget
---@field lockedPredictionValue GrimWidget
---@field selectedLevelRange string
---@field predictionInputsLocked boolean
---@field setupActive boolean
---@field waitingPromptDotCount integer
---@field waitingPromptElapsed number
---@field waitingPromptDisplayDuration number
---@field isWaitingForFirstDeathPromptShown boolean
---@field ApplyPredictionInputState fun(prediction: GrimPrediction|GrimPredictionElements|nil)
---@field RefreshPredictionActionButtonState fun()
---@field SetPredictionInputsLocked fun(locked: boolean)
---@field RefreshAuxiliaryWindowState fun(self: GrimMainFrame)
---@field RefreshIntroDemoVisibility fun(self: GrimMainFrame)
---@field RefreshRecentDeathLogState fun(self: GrimMainFrame)
---@field RefreshCollapsedSummary fun(self: GrimMainFrame)

---@class GrimMainBuildContext
---@field frame GrimMainFrameShell
---@field state GrimCharacterState
---@field logic GrimMainLogic
---@field layout GrimMainLayout
---@field maxRecentDeaths integer
---@field levelRanges string[]
---@field deathLogColumns GrimDeathLogColumn[]
---@field collapsedLogColumns GrimDeathLogColumn[]

---@class GrimMainContext: GrimMainBuildContext
---@field frame GrimMainFrame

---@param ctx GrimMainContext
---@return GrimDisplayState
local function GetMainWindowDisplayState(ctx)
    return GrimUI.GetIntroDemoDisplayedState(ctx.frame, ctx.logic) or ctx.logic.GetDisplayState(GrimUI.GetState(ctx.frame))
end

---@param ctx GrimMainContext
---@return GrimUIModeState
local function ResolveMainWindowMode(ctx)
    return GrimUIMode.Resolve(ctx.frame, GetMainWindowDisplayState(ctx), GrimUI.GetState(ctx.frame))
end

---@param frame GrimMainFrameShell
local function ToggleLogWindow(frame)
    local isLogShown = frame.logFrame:IsShown()
    GrimUI.SetLogWindowShown(frame, GrimUI.GetState(frame), not isLogShown)
end

---@param ctx GrimMainBuildContext
---@param region GrimWidget
---@param lines string[]|fun(): string[]
local function AttachGameInfoCallout(ctx, region, lines)
    local frame = ctx.frame

    GrimUITooltip.AttachGameInfoCallout(region, {
        callout = function()
            return frame.gameInfoCallout
        end,
        owner = function()
            return frame.lockButton
        end,
        relativeTo = function()
            return frame.lockButton
        end,
        point = "BOTTOMRIGHT",
        relativePoint = "TOPRIGHT",
        xOffset = 0,
        yOffset = 10,
        lines = lines,
        shouldShow = function()
            return frame.gameInfoCallout ~= nil
                and frame.isCollapsed ~= true
                and frame:IsShown()
        end,
    })
end

---@param frame GrimMainFrame
---@param elapsed number
local function TickWaitingForFirstDeathPrompt(frame, elapsed)
    local previousDisplayDuration
    local didAdvanceWaitingPromptDots
    local didCompleteMinimumDuration

    if frame.isWaitingForFirstDeathPromptShown ~= true then
        return
    end

    previousDisplayDuration = frame.waitingPromptDisplayDuration
    didAdvanceWaitingPromptDots = false
    frame.waitingPromptElapsed = frame.waitingPromptElapsed + elapsed
    frame.waitingPromptDisplayDuration = previousDisplayDuration + elapsed
    didCompleteMinimumDuration = previousDisplayDuration < WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS
        and frame.waitingPromptDisplayDuration >= WAITING_FOR_FIRST_DEATH_MIN_DURATION_SECONDS

    while frame.waitingPromptElapsed >= 1 do
        frame.waitingPromptElapsed = frame.waitingPromptElapsed - 1
        frame.waitingPromptDotCount = frame.waitingPromptDotCount + 1
        didAdvanceWaitingPromptDots = true
        if frame.waitingPromptDotCount > 3 then
            frame.waitingPromptDotCount = 0
        end
    end

    if didAdvanceWaitingPromptDots or didCompleteMinimumDuration then
        frame:RefreshRecentDeathLogState()
    end
end

---@param frame GrimMainFrameShell
---@param ctx GrimMainBuildContext
local function AttachMainFrameScripts(frame, ctx)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        GrimUI.SaveWindowPosition(self, GrimUI.GetState(self), self.isCollapsed)
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if self.isCollapsed == true and button == "LeftButton" then
            GrimUI.SetWindowCollapsed(self, GrimUI.GetState(self), false)
        end
    end)
    frame:SetScript("OnHide", function(self)
        if self.githubLinkFrame then
            self.githubLinkFrame:Hide()
        end
        GrimUITooltip.HideGameInfoCallout(self.gameInfoCallout)
        if self.RefreshIntroDemoVisibility then
            self:RefreshIntroDemoVisibility()
        end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if self.introDemoController then
            self.introDemoController:Tick(elapsed)
        end

        TickWaitingForFirstDeathPrompt(self, elapsed)
    end)
    frame:SetScript("OnSizeChanged", function(self, width, height)
        local normalizedHeight

        if self.isCollapsed ~= true then
            return
        end

        normalizedHeight = GrimUI.NormalizeCollapsedWindowHeight(height)

        if width ~= ctx.layout.collapsedWindowWidth or normalizedHeight ~= height then
            if self.isAdjustingCollapsedSize then
                return
            end

            self.isAdjustingCollapsedSize = true
            self:SetSize(ctx.layout.collapsedWindowWidth, normalizedHeight)
            self.isAdjustingCollapsedSize = false
            return
        end

        GrimUI.SaveCollapsedWindowHeight(self, GrimUI.GetState(self))
        if self.RefreshCollapsedSummary then
            self:RefreshCollapsedSummary()
        end
    end)
end

---@param ctx GrimMainBuildContext
local function CreateHeaderSection(ctx)
    local frame = ctx.frame

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText("GRIM GUESSER")

    local minimizeButton = CreateFrame("Button", "GrimMinimizeButton", frame)
    minimizeButton:SetSize(25, 25)
    minimizeButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", 7, 0)
    minimizeButton:SetScript("OnClick", function()
        GrimUI.SetWindowCollapsed(frame, GrimUI.GetState(frame), not frame.isCollapsed)
    end)
    frame.minimizeButton = minimizeButton

    AttachGameInfoCallout(ctx, minimizeButton, {
        "Show the mini log",
    })
end

---@param ctx GrimMainBuildContext
local function CreateScoreSummarySection(ctx)
    local frame = ctx.frame
    local scoreWidth = 60
    local scoreX = ctx.layout.expandedWindowWidth - ctx.layout.outsideGutter - scoreWidth

    local totalPointsValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalPointsValue:SetPoint("TOPLEFT", frame, "TOPLEFT", scoreX, ctx.layout.scoreSummaryY)
    totalPointsValue:SetWidth(scoreWidth)
    totalPointsValue:SetJustifyH("RIGHT")
    frame.totalPointsValue = totalPointsValue
    GrimUI.RegisterCollapsibleRegion(frame, totalPointsValue)

    local totalPointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalPointsLabel:SetPoint("LEFT", totalPointsValue, "LEFT", -27, 0)
    totalPointsLabel:SetText("Score:")
    GrimUI.RegisterCollapsibleRegion(frame, totalPointsLabel)

    local currentStreakValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    currentStreakValue:SetPoint("RIGHT", totalPointsLabel, "LEFT", -44, 0)
    currentStreakValue:SetWidth(28)
    currentStreakValue:SetJustifyH("LEFT")
    frame.currentStreakValue = currentStreakValue
    GrimUI.RegisterCollapsibleRegion(frame, currentStreakValue)

    local currentStreakLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentStreakLabel:SetPoint("RIGHT", currentStreakValue, "LEFT", -8, 0)
    currentStreakLabel:SetText("Current streak:")
    GrimUI.RegisterCollapsibleRegion(frame, currentStreakLabel)

    local longestStreakValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    longestStreakValue:SetPoint("RIGHT", currentStreakLabel, "LEFT", -44, 0)
    longestStreakValue:SetWidth(28)
    longestStreakValue:SetJustifyH("LEFT")
    frame.longestStreakValue = longestStreakValue
    GrimUI.RegisterCollapsibleRegion(frame, longestStreakValue)

    local longestStreakLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    longestStreakLabel:SetPoint("RIGHT", longestStreakValue, "LEFT", -8, 0)
    longestStreakLabel:SetText("Longest streak:")
    GrimUI.RegisterCollapsibleRegion(frame, longestStreakLabel)
end

---@param ctx GrimMainBuildContext
local function CreateActionButtons(ctx)
    local frame = ctx.frame
    local layout = ctx.layout

    frame.gameInfoCallout = GrimUITooltip.CreateGameInfoCallout("GrimGameInfoCallout", frame)

    local helpButton = CreateFrame("Button", "GrimHelpButton", frame, "GameMenuButtonTemplate")
    helpButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    helpButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", layout.predictionControlX, layout.predictionButtonY)
    helpButton:SetText("HELP")
    helpButton:SetScript("OnClick", function()
        if not helpButton:IsEnabled() then
            return
        end
        frame.helpFrame:Show()
        frame.helpFrame:Raise()
    end)
    frame.helpButton = helpButton
    GrimUI.RegisterCollapsibleRegion(frame, helpButton)
    AttachGameInfoCallout(ctx, helpButton, {
        "More information",
    })

    local bottomLogButton = CreateFrame("Button", "GrimBottomLogButton", frame, "GameMenuButtonTemplate")
    bottomLogButton:SetSize(100, layout.standardButtonHeight)
    bottomLogButton:SetPoint("LEFT", helpButton, "RIGHT", layout.actionButtonGap, 0)
    bottomLogButton:SetText(GrimUI.LOG_TOGGLE_BUTTON_TEXT)
    bottomLogButton:SetScript("OnClick", function()
        if not bottomLogButton:IsEnabled() then
            return
        end
        ToggleLogWindow(frame)
    end)
    frame.bottomLogButton = bottomLogButton
    GrimUI.RegisterCollapsibleRegion(frame, bottomLogButton)
    AttachGameInfoCallout(ctx, bottomLogButton, {
        "Open the log window",
    })

    local pauseButton = CreateFrame("Button", "GrimPauseButton", frame, "GameMenuButtonTemplate")
    pauseButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    pauseButton:SetPoint("LEFT", bottomLogButton, "RIGHT", layout.actionButtonGap, 0)
    pauseButton:SetText("PAUSE")
    pauseButton:SetScript("OnClick", function()
        ---@cast frame GrimMainFrame
        GrimUIMainPrediction.OnMainPredictionPauseButtonClicked(frame, ctx.logic)
    end)
    frame.pauseButton = pauseButton
    GrimUI.RegisterCollapsibleRegion(frame, pauseButton)
    AttachGameInfoCallout(ctx, pauseButton, {
        "Pause to change your prediction",
    })

    local lockButton = CreateFrame("Button", "GrimLockButton", frame, "GameMenuButtonTemplate")
    lockButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    lockButton:SetPoint("LEFT", pauseButton, "RIGHT", layout.actionButtonGap, 0)
    lockButton:SetText("LOCK IN")
    lockButton:SetScript("OnClick", function()
        ---@cast frame GrimMainFrame
        GrimUIMainPrediction.OnMainPredictionLockButtonClicked(frame, ctx.logic, ctx.levelRanges)
    end)
    frame.lockButton = lockButton
    GrimUI.RegisterCollapsibleRegion(frame, lockButton)
    AttachGameInfoCallout(ctx, lockButton, {
        "Begin the game",
    })
end

---@param ctx GrimMainContext
---@param uiMode GrimUIModeState
local function RefreshAuxiliaryWindowState(ctx, uiMode)
    local frame = ctx.frame
    local isDemoShown = GrimUIMode.IsDemoMode(uiMode)
    local hasSeenFirstRun = GrimDatabase.GetHasSeenFirstRun(GrimUI.GetState(frame))

    if isDemoShown or not hasSeenFirstRun then
        frame.bottomLogButton:Disable()
    else
        frame.bottomLogButton:Enable()
    end

    if isDemoShown then
        frame.helpButton:Disable()
    else
        frame.helpButton:Enable()
    end

    if isDemoShown then
        frame.logFrame:Hide()
        frame.helpFrame:Hide()
        if frame.githubLinkFrame then
            frame.githubLinkFrame:Hide()
        end

        frame.collapsedWindowStates.logFrame = false
        -- Starting the demo intentionally closes Help instead of restoring it afterward.
        frame.collapsedWindowStates.helpFrame = false
    elseif GrimUI.ApplyDesiredLogWindowState then
        GrimUI.ApplyDesiredLogWindowState(frame, GrimUI.GetState(frame))
    end
end

---@param frame GrimMainFrame
---@param ctx GrimMainContext
local function RefreshIntroDemoVisibility(frame, ctx)
    local uiMode = ResolveMainWindowMode(ctx)
    local isIntroDemoShown = GrimUIMode.IsDemoMode(uiMode)
    local shouldShowIntroDemo = isIntroDemoShown and not frame.isCollapsed and frame:IsShown()

    RefreshAuxiliaryWindowState(ctx, uiMode)

    if isIntroDemoShown then
        frame.SetPredictionInputsLocked(uiMode.inputsLocked)
    end

    if frame.demoModeWatermark then
        if shouldShowIntroDemo then
            frame.demoModeWatermark:Show()
        else
            frame.demoModeWatermark:Hide()
        end
    end

    if frame.introDemoAttractPanel then
        if shouldShowIntroDemo then
            frame.introDemoAttractPanel:Show()
        else
            frame.introDemoAttractPanel:Hide()
        end
    end
end

---@param ctx GrimMainBuildContext
local function AttachMainFrameMethods(ctx)
    local frame = ctx.frame

    frame.RefreshAuxiliaryWindowState = function(_self)
        ---@cast ctx GrimMainContext
        RefreshAuxiliaryWindowState(ctx, ResolveMainWindowMode(ctx))
    end
    frame.RefreshIntroDemoVisibility = function(self)
        ---@cast ctx GrimMainContext
        ---@cast self GrimMainFrame
        RefreshIntroDemoVisibility(self, ctx)
    end
end

---@param frame GrimMainFrameShell
local function InitializeMainFrameDefaults(frame)
    frame.collapsedWindowStates = {}
    frame.predictionInputsLocked = false
    frame.setupActive = false
    frame.waitingPromptDotCount = 0
    frame.waitingPromptElapsed = 0
    frame.waitingPromptDisplayDuration = 0
    frame.isWaitingForFirstDeathPromptShown = false
end

---@param ctx GrimMainContext
local function InitializeMainFrameState(ctx)
    local frame = ctx.frame

    frame.SetPredictionInputsLocked(GrimDatabase.GetLockedPrediction(GrimUI.GetState(frame)) ~= nil)
    frame.RefreshPredictionActionButtonState()
    frame:RefreshIntroDemoVisibility()
end

---@param state GrimCharacterState
---@param logic GrimMainLogic
---@param maxRecentDeaths integer
---@return GrimMainFrame
---@return GrimRefreshReadyDebugFrame
---@return GrimRefreshReadyHistoryFrame
function GrimUIMain.Initialize(state, logic, maxRecentDeaths)
    ---@type GrimMainLayout
    local layout = GrimUI.LAYOUT
    maxRecentDeaths = maxRecentDeaths or 5

    local frame = CreateFrame("Frame", "GrimFrame", UIParent, "BasicFrameTemplateWithInset")
    ---@cast frame GrimMainFrameShell
    frame.state = state
    frame:SetSize(layout.expandedWindowWidth, layout.mainWindowHeight)
    frame:SetPoint("CENTER")
    frame.frameStrata = "MEDIUM"
    frame:SetFrameStrata(frame.frameStrata)
    frame:SetFrameLevel(10)
    frame:SetMovable(true)
    frame:SetResizable(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    GrimUI.SetEscapeClosable(frame, true)

    ---@type GrimMainBuildContext
    local ctx = {
        frame = frame,
        state = state,
        logic = logic,
        layout = layout,
        maxRecentDeaths = maxRecentDeaths,
        levelRanges = GrimUI.LEVEL_RANGES,
        deathLogColumns = GrimUI.DEATH_LOG_COLUMNS,
        collapsedLogColumns = GrimUI.COLLAPSED_LOG_COLUMNS,
    }

    AttachMainFrameScripts(frame, ctx)

    local debugWindow = GrimUIDebug.CreateDebugWindow()
    local logWindow = GrimUILog.CreateHistoryWindow(frame)
    local helpWindow = GrimUIHelp.CreateHelpWindow(frame)
    local setupWindow = GrimUISetup.CreateWindow(frame)
    frame.helpFrame = helpWindow
    frame.githubLinkFrame = helpWindow.githubLinkFrame
    frame.logFrame = logWindow
    frame.setupFrame = setupWindow
    frame.dropdown = GrimUIAutocomplete.CreateSuggestionDropdown(frame)

    GrimUIRefresh.AttachRefreshMethods(frame, debugWindow, logWindow, logic)

    CreateHeaderSection(ctx)
    GrimUIMainCollapsed.CreateMainCollapsedSection(
        frame,
        layout,
        maxRecentDeaths,
        GrimUI.COLLAPSED_LOG_COLUMNS
    )

    GrimUIMainRecentDeaths.CreateMainRecentDeathsSection(
        frame,
        layout,
        maxRecentDeaths,
        GrimUI.DEATH_LOG_COLUMNS
    )
    CreateScoreSummarySection(ctx)
    GrimUIMainPrediction.CreateMainPredictionSection(
        frame,
        layout,
        logic,
        GrimUI.LEVEL_RANGES
    )
    CreateActionButtons(ctx)
    GrimUIMainPrediction.CreateMainCurrentPredictionSummarySection(frame, layout, logic)
    GrimUIMainPrediction.AttachMainPredictionMethods(frame, logic)
    AttachMainFrameMethods(ctx)
    InitializeMainFrameDefaults(frame)

    ---@cast frame GrimMainFrame
    ---@cast ctx GrimMainContext
    GrimUIMainPrediction.AttachMainPredictionEditBoxHandlers(frame, logic)
    InitializeMainFrameState(ctx)
    GrimUI.ApplyDesiredLogWindowState(frame, state)

    return frame, debugWindow, logWindow
end
