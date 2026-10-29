local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIAutocomplete = ns.GrimUIAutocomplete
local GrimDatabase = ns.GrimDatabase
local GrimUIDeathLogList = ns.GrimUIDeathLogList
local GrimUIMode = ns.GrimUIMode
local GrimUIMinimap = ns.GrimUIMinimap
local GrimUIRefresh = ns.GrimUIRefresh or {}
local GrimUISetup = ns.GrimUISetup
ns.GrimUIRefresh = GrimUIRefresh

---@alias GrimRefreshFontStringMap table<string, table>

---@class GrimRefreshLogic
---@field GetDisplayState fun(database: GrimCharacterState): GrimDisplayState
---@field FormatLockedPrediction fun(prediction: GrimPrediction|GrimPredictionElements|nil): string
---@field FormatMultiplier fun(multiplierValue: number|string|nil): string
---@field GetComboDetails fun(prediction: GrimPrediction|GrimPredictionElements|nil, death: GrimDeath|nil, streak: integer|nil): GrimComboDetails
---@field GetStoredDeathComboDetails fun(death: GrimDeath): GrimComboDetails
---@field GetStoredDeathBasePoints fun(death: GrimDeath): integer
---@field GetStoredDeathSameZoneBonusPoints fun(death: GrimDeath): integer
---@field GetStoredDeathMultiplierValue fun(death: GrimDeath): integer
---@field GetStoredDeathAwardedPoints fun(death: GrimDeath): integer

---@class GrimRefreshViewState
---@field history GrimDeathLogDisplayEntry[]
---@field subtitle string
---@field filterButtonText string

---@class GrimRefreshScoreValues
---@field comboDetails GrimComboDetails
---@field basePoints integer|nil
---@field sameZoneBonusPoints integer|nil
---@field totalMultiplier integer|nil
---@field awardedPoints integer|nil

---@class GrimRefreshStateFields
---@field totalPoints integer
---@field currentPredictionStreak integer
---@field longestPredictionStreak integer
---@field lockedPrediction string

---@class GrimRefreshLatestDeathFields
---@field time string|nil
---@field name string|nil
---@field level integer|nil
---@field sourceName string|nil
---@field zone string|nil
---@field sourceMessage string|nil

---@class GrimRefreshDebugParsedDeathFields: GrimRefreshLatestDeathFields
---@field predictionStreak integer|nil

---@class GrimRefreshDebugScoreFields
---@field basePoints integer|nil
---@field comboMultiplier string|nil
---@field streakMultiplier string|nil
---@field multiplier string|nil
---@field awardedPoints integer|nil
---@field pointFormula string|nil
---@field comboDetails string|nil

---@class GrimRefreshDebugDetailFields: GrimRefreshStateFields
---@field time string|nil
---@field name string|nil
---@field level integer|nil
---@field sourceName string|nil
---@field zone string|nil
---@field predictionStreak integer|nil
---@field sourceMessage string|nil
---@field basePoints integer|nil
---@field comboMultiplier string|nil
---@field streakMultiplier string|nil
---@field multiplier string|nil
---@field awardedPoints integer|nil
---@field pointFormula string|nil
---@field comboDetails string|nil

---@class GrimRefreshControllerFrame
---@field displayCache table|nil
---@field introDemoController GrimIntroDemoController|nil
---@field totalPointsValue table|nil
---@field currentStreakValue table|nil
---@field longestStreakValue table|nil
---@field recentDeathsFrame table|nil
---@field emptyPredictionPrompt table|nil
---@field setupFrame GrimSetupFrame|nil
---@field waitingPromptText table|nil
---@field waitingPromptDots table|nil
---@field waitingPromptHelpText table|nil
---@field waitingPromptDotCount integer|nil
---@field waitingPromptElapsed number|nil
---@field waitingPromptDisplayDuration number|nil
---@field isWaitingForFirstDeathPromptShown boolean|nil
---@field setupActive boolean|nil
---@field detailValues GrimRefreshFontStringMap|nil
---@field lockedPredictionValue table|nil
---@field pauseButton table|nil
---@field collapsedLogFrame table|nil
---@field collapsedPointsValue table|nil
---@field GetHeight fun(self: GrimRefreshControllerFrame): number|nil
---@field RefreshIntroDemoVisibility fun(self: GrimRefreshControllerFrame)|nil
---@field ApplyPredictionInputState fun(prediction: GrimPrediction|GrimPredictionElements|nil)
---@field SetPredictionInputsLocked fun(locked: boolean)
---@field RefreshPredictionActionButtonState fun()
---@field RefreshRecentDeathLogState fun(self: GrimRefreshControllerFrame)|nil
---@field RefreshLatestDeathDetails fun(self: GrimRefreshControllerFrame, death: GrimDeath|nil)|nil
---@field RefreshLockedPrediction fun(self: GrimRefreshControllerFrame)|nil
---@field RefreshDeaths fun(self: GrimRefreshControllerFrame)|nil
---@field RefreshCollapsedSummary fun(self: GrimRefreshControllerFrame)|nil

---@class GrimRefreshReadyControllerFrame: GrimRefreshControllerFrame
---@field totalPointsValue table
---@field currentStreakValue table
---@field longestStreakValue table
---@field recentDeathsFrame table
---@field deathRows table[]
---@field emptyPredictionPrompt table
---@field setupFrame GrimSetupFrame
---@field waitingPromptText table
---@field waitingPromptDots table
---@field waitingPromptHelpText table
---@field waitingPromptDotCount integer
---@field waitingPromptElapsed number
---@field waitingPromptDisplayDuration number
---@field isWaitingForFirstDeathPromptShown boolean
---@field setupActive boolean
---@field detailValues GrimRefreshFontStringMap|nil
---@field lockedPredictionValue table
---@field collapsedLogFrame table
---@field collapsedPointsValue table
---@field GetHeight fun(self: GrimRefreshReadyControllerFrame): number
---@field ApplyPredictionInputState fun(prediction: GrimPrediction|GrimPredictionElements|nil)
---@field SetPredictionInputsLocked fun(locked: boolean)
---@field RefreshPredictionActionButtonState fun()
---@field RefreshRecentDeathLogState fun(self: GrimRefreshReadyControllerFrame)
---@field RefreshLatestDeathDetails fun(self: GrimRefreshReadyControllerFrame, death: GrimDeath|nil)
---@field RefreshLockedPrediction fun(self: GrimRefreshReadyControllerFrame)
---@field RefreshDeaths fun(self: GrimRefreshReadyControllerFrame)
---@field RefreshCollapsedSummary fun(self: GrimRefreshReadyControllerFrame)

---@class GrimRefreshDebugFrame
---@field detailValues GrimRefreshFontStringMap|nil
---@field RefreshLatestDeathDetails fun(self: GrimRefreshDebugFrame, death: GrimDeath|nil, state: GrimDisplayState)|nil

---@class GrimRefreshReadyDebugFrame: GrimRefreshDebugFrame
---@field detailValues GrimRefreshFontStringMap
---@field RefreshLatestDeathDetails fun(self: GrimRefreshReadyDebugFrame, death: GrimDeath|nil, state: GrimDisplayState)

---@class GrimRefreshHistoryFrame
---@field rows table[]|nil
---@field logSubtitle table|nil
---@field filterButton table|nil
---@field columnHeaders table<string, table>|nil
---@field showSuccessfulOnly boolean|nil
---@field scrollFrame table
---@field displayCache table|nil
---@field RefreshHistory fun(self: GrimRefreshHistoryFrame)|nil

---@class GrimRefreshReadyHistoryFrame: GrimRefreshHistoryFrame
---@field rows table[]
---@field logSubtitle table
---@field filterButton table
---@field columnHeaders table<string, table>
---@field scrollFrame table
---@field RefreshHistory fun(self: GrimRefreshReadyHistoryFrame)

---@param GrimMainFrame GrimRefreshReadyControllerFrame
---@param GrimDebug GrimRefreshReadyDebugFrame
---@param GrimLog GrimRefreshReadyHistoryFrame
---@param logic GrimRefreshLogic
function GrimUIRefresh.AttachRefreshMethods(GrimMainFrame, GrimDebug, GrimLog, logic)
    local deathLogColumns = GrimUI.DEATH_LOG_COLUMNS
    local historyLogColumns = GrimUI.HISTORY_LOG_COLUMNS
    local displayCache = GrimUIDeathLogList.CreateDeathLogDisplayCache()
    local FIRST_RUN_PROMPT_TEXT = "Make your prediction"
    local WAITING_FOR_FIRST_DEATH_TEXT = "Waiting for first death"
    local WAITING_FOR_FIRST_DEATH_HELP_TEXT = "Click HELP if you are missing deaths"
    ---@return GrimCharacterState
    local function GetState()
        return GrimUI.GetState(GrimMainFrame)
    end

    ---@param viewKey string
    ---@param sourceDeaths GrimDeath[]
    ---@param viewOptions table
    ---@return GrimDeathLogDisplayEntry[]
    local function GetCachedViewEntries(viewKey, sourceDeaths, viewOptions)
        return GrimUIDeathLogList.GetOrderedDeathLogViewEntries(displayCache, viewKey, sourceDeaths, viewOptions)
    end

    ---@param state GrimDisplayState
    ---@return GrimDisplayState
    local function BuildDisplayedState(state)
        return {
            deaths = state.deaths,
            totalPoints = state.totalPoints,
            currentPredictionStreak = state.currentPredictionStreak,
            longestPredictionStreak = state.longestPredictionStreak,
            lockedPrediction = state.lockedPrediction,
            draftPrediction = state.draftPrediction,
            lastPrediction = state.lastPrediction,
        }
    end

    ---@return GrimDisplayState
    local function GetBaseDisplayedState()
        return BuildDisplayedState(logic.GetDisplayState(GetState()))
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@return GrimDisplayState|nil
    local function GetDemoDisplayedState(frame)
        local introDemoController = frame.introDemoController
        local displayState = introDemoController and introDemoController:GetDisplayedState(logic) or nil
        if not displayState then
            return nil
        end

        return BuildDisplayedState(displayState)
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@return GrimDisplayState
    local function GetDisplayedState(frame)
        return GetDemoDisplayedState(frame) or GetBaseDisplayedState()
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@return string
    local function GetWaitingForFirstDeathPromptText(frame)
        return WAITING_FOR_FIRST_DEATH_TEXT .. string.rep(".", frame.waitingPromptDotCount)
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param notificationKind string|nil
    ---@return string|nil
    local function GetRecentDeathPaneNotificationText(frame, notificationKind)
        if notificationKind == "firstRun" then
            return FIRST_RUN_PROMPT_TEXT
        end

        if notificationKind == "waiting" then
            return GetWaitingForFirstDeathPromptText(frame)
        end

        return nil
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param notificationKind string|nil
    ---@param notificationText string|nil
    local function RefreshEmptyPredictionPrompt(frame, notificationKind, notificationText)
        if notificationKind == "waiting" then
            frame.emptyPredictionPrompt:Hide()
        elseif notificationText then
            frame.emptyPredictionPrompt:SetText(notificationText)
            frame.emptyPredictionPrompt:Show()
        else
            frame.emptyPredictionPrompt:Hide()
        end
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param notificationKind string|nil
    local function RefreshWaitingPromptText(frame, notificationKind)
        if notificationKind ~= "waiting" then
            frame.waitingPromptText:Hide()
            frame.waitingPromptDots:Hide()
            return
        end

        frame.waitingPromptText:SetText(WAITING_FOR_FIRST_DEATH_TEXT)
        frame.waitingPromptDots:SetText(string.rep(".", frame.waitingPromptDotCount))
        frame.waitingPromptText:Show()
        frame.waitingPromptDots:Show()
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param showWaitingHelpText boolean
    ---@param notificationKind string|nil
    local function RefreshWaitingPromptHelpText(frame, showWaitingHelpText, notificationKind)
        if notificationKind == "waiting" and showWaitingHelpText then
            frame.waitingPromptHelpText:SetText(WAITING_FOR_FIRST_DEATH_HELP_TEXT)
            frame.waitingPromptHelpText:Show()
            return
        end

        frame.waitingPromptHelpText:Hide()
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param showRows boolean
    local function RefreshRecentDeathRowVisibility(frame, showRows)
        for _, row in ipairs(frame.deathRows) do
            if showRows and row.death ~= nil then
                row:Show()
            else
                row:Hide()
            end
        end
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param uiMode GrimUIModeState
    ---@param notificationText string|nil
    local function RefreshRecentDeathPanePrompt(frame, uiMode, notificationText)
        if GrimUIMode.IsDemoMode(uiMode) or GrimUIMode.HasModal(uiMode) then
            RefreshEmptyPredictionPrompt(frame, nil, nil)
            GrimUISetup.Refresh(frame.setupFrame, frame, not GrimUIMode.IsSetupModal(uiMode))
            RefreshWaitingPromptText(frame, nil)
            RefreshWaitingPromptHelpText(frame, false, nil)
            return
        end

        RefreshEmptyPredictionPrompt(frame, uiMode.prompt, notificationText)
        GrimUISetup.Refresh(frame.setupFrame, frame, false)
        RefreshWaitingPromptText(frame, uiMode.prompt)
        RefreshWaitingPromptHelpText(frame, uiMode.showWaitingHelp, uiMode.prompt)
    end

    ---@param frame GrimRefreshHistoryFrame
    ---@return GrimRefreshViewState
    local function GetHistoryViewState(frame)
        local state = GetState()

        if frame.showSuccessfulOnly == true then
            return {
                history = GetCachedViewEntries(
                    "successfulView",
                    GrimDatabase.GetSuccessfullyPredictedDeaths(state),
                    { sortMode = "successful" }
                ),
                subtitle = GrimUI.HISTORY_SUBTITLE_SUCCESS_ONLY,
                filterButtonText = GrimUI.HISTORY_FILTER_BUTTON_SHOW_ALL,
            }
        end

        return {
            history = GetCachedViewEntries(
                "historyView",
                GrimDatabase.GetDeathHistory(state),
                {}
            ),
            subtitle = GrimUI.HISTORY_SUBTITLE_ALL,
            filterButtonText = GrimUI.HISTORY_FILTER_BUTTON_SHOW_SUCCESS_ONLY,
        }
    end

    ---@param frame GrimRefreshReadyControllerFrame
    ---@param state GrimDisplayState
    local function RefreshScoreSummary(frame, state)
        frame.totalPointsValue:SetText(FormatLargeNumber(state.totalPoints))
        frame.currentStreakValue:SetText(tostring(state.currentPredictionStreak))
        frame.longestStreakValue:SetText(tostring(state.longestPredictionStreak))
        if GrimUIMinimap and GrimUIMinimap.RefreshLauncherText then
            GrimUIMinimap.RefreshLauncherText(frame, GetState())
        end
    end

    ---@param detailValues GrimRefreshFontStringMap
    ---@param detailFields table<string, any>
    local function ApplyDetailValues(detailValues, detailFields)
        for fieldName, fontString in pairs(detailValues) do
            fontString:SetText(GrimUI.GetDeathFieldValue(detailFields[fieldName]))
        end
    end

    ---@param frame GrimRefreshReadyControllerFrame
    local function DisablePredictionActionsForDemo(frame)
        local uiMode = GrimUIMode.Resolve(frame, GetDisplayedState(frame), GetState())
        if not GrimUIMode.IsDemoMode(uiMode) then
            return
        end

        frame.SetPredictionInputsLocked(uiMode.inputsLocked)
        frame.pauseButton:Disable()
    end

    ---@param comboDetails GrimComboDetails
    ---@return string
    local function FormatDebugComboDetails(comboDetails)
        local comboParts = {}

        for _, combo in ipairs(comboDetails.combos) do
            comboParts[#comboParts + 1] = string.format(
                "%s %s",
                tostring(combo.label or "-"),
                tostring(combo.displayMultiplier or logic.FormatMultiplier(combo.multiplier))
            )
        end

        if #comboParts <= 0 then
            return comboDetails.displayComboSum
        end

        return table.concat(comboParts, " / ")
    end

    ---@return GrimDisplayState
    ---@return GrimDeath|nil
    local function GetLiveDebugSnapshot()
        local displayState = GetBaseDisplayedState()
        local deaths = displayState.deaths
        return displayState, deaths[#deaths]
    end

    ---@param state GrimDisplayState
    ---@return GrimRefreshStateFields
    local function GetDebugStateFields(state)
        return {
            totalPoints = state.totalPoints,
            currentPredictionStreak = state.currentPredictionStreak,
            longestPredictionStreak = state.longestPredictionStreak,
            lockedPrediction = logic.FormatLockedPrediction(state.lockedPrediction),
        }
    end

    ---@param death GrimDeath|nil
    ---@return GrimRefreshDebugParsedDeathFields
    local function GetDebugParsedDeathFields(death)
        local deathFields = death or {}

        return {
            time = death and GrimUI.GetStoredDeathTime(death),
            name = deathFields.name,
            level = deathFields.level,
            sourceName = deathFields.sourceName,
            zone = deathFields.zone,
            predictionStreak = deathFields.predictionStreak,
            sourceMessage = deathFields.sourceMessage,
        }
    end

    ---@param death GrimDeath|nil
    ---@return GrimRefreshScoreValues
    local function GetDebugScoreValues(death)
        return {
            comboDetails = death and logic.GetStoredDeathComboDetails(death) or logic.GetComboDetails(nil, nil, 0),
            basePoints = death and logic.GetStoredDeathBasePoints(death) or nil,
            sameZoneBonusPoints = death and logic.GetStoredDeathSameZoneBonusPoints(death) or nil,
            totalMultiplier = death and logic.GetStoredDeathMultiplierValue(death) or nil,
            awardedPoints = death and logic.GetStoredDeathAwardedPoints(death) or nil,
        }
    end

    ---@param death GrimDeath|nil
    ---@param scoreValues GrimRefreshScoreValues
    ---@return string|nil
    local function GetDebugPointFormula(death, scoreValues)
        if not death then
            return nil
        end

        local leftHandPoints = (scoreValues.basePoints or 0) + (scoreValues.sameZoneBonusPoints or 0)
        return string.format(
            "%d x%d = %d",
            leftHandPoints,
            scoreValues.totalMultiplier or 0,
            scoreValues.awardedPoints or 0
        )
    end

    ---@param death GrimDeath|nil
    ---@return GrimRefreshDebugScoreFields
    local function GetDebugScoreFields(death)
        local scoreValues = GetDebugScoreValues(death)
        local comboDetails = scoreValues.comboDetails

        return {
            basePoints = scoreValues.basePoints,
            comboMultiplier = comboDetails and logic.FormatMultiplier(comboDetails.comboMultiplier) or nil,
            streakMultiplier = comboDetails and logic.FormatMultiplier(comboDetails.streakMultiplier) or nil,
            multiplier = comboDetails and comboDetails.displayComboSum or nil,
            awardedPoints = scoreValues.awardedPoints,
            pointFormula = GetDebugPointFormula(death, scoreValues),
            comboDetails = FormatDebugComboDetails(comboDetails),
        }
    end

    ---@param death GrimDeath|nil
    ---@param state GrimDisplayState
    ---@return GrimRefreshDebugDetailFields
    local function GetDebugDetailFields(death, state)
        local stateFields = GetDebugStateFields(state)
        local parsedDeathFields = GetDebugParsedDeathFields(death)
        local scoreFields = GetDebugScoreFields(death)

        return {
            totalPoints = stateFields.totalPoints,
            currentPredictionStreak = stateFields.currentPredictionStreak,
            longestPredictionStreak = stateFields.longestPredictionStreak,
            lockedPrediction = stateFields.lockedPrediction,
            time = parsedDeathFields.time,
            name = parsedDeathFields.name,
            level = parsedDeathFields.level,
            sourceName = parsedDeathFields.sourceName,
            zone = parsedDeathFields.zone,
            predictionStreak = parsedDeathFields.predictionStreak,
            sourceMessage = parsedDeathFields.sourceMessage,
            basePoints = scoreFields.basePoints,
            comboMultiplier = scoreFields.comboMultiplier,
            streakMultiplier = scoreFields.streakMultiplier,
            multiplier = scoreFields.multiplier,
            awardedPoints = scoreFields.awardedPoints,
            pointFormula = scoreFields.pointFormula,
            comboDetails = scoreFields.comboDetails,
        }
    end

    ---@param self GrimRefreshReadyControllerFrame
    function GrimMainFrame:RefreshRecentDeathLogState()
        local state = GetDisplayedState(self)
        local deaths = state.deaths
        local uiMode = GrimUIMode.Resolve(self, state, GetState())
        local recentEntries = GetCachedViewEntries("recentView", deaths, {})
        local wasWaitingForFirstDeathPromptShown = self.isWaitingForFirstDeathPromptShown == true
        local recentDeathPaneNotificationKind = uiMode.prompt
        local recentDeathPaneNotificationText = GetRecentDeathPaneNotificationText(self, recentDeathPaneNotificationKind)

        self.isWaitingForFirstDeathPromptShown = recentDeathPaneNotificationKind == "waiting"
        if self.isWaitingForFirstDeathPromptShown then
            if not wasWaitingForFirstDeathPromptShown then
                self.waitingPromptDotCount = 0
                self.waitingPromptElapsed = 0
                self.waitingPromptDisplayDuration = 0
            end
        else
            self.waitingPromptDotCount = 0
            self.waitingPromptElapsed = 0
            self.waitingPromptDisplayDuration = 0
        end

        GrimUIDeathLogList.RefreshDeathLogRows(self.recentDeathsFrame, recentEntries, {
            columns = deathLogColumns,
            reverseOrder = false,
        })
        RefreshRecentDeathRowVisibility(self, uiMode.showRecentDeathRows)

        RefreshRecentDeathPanePrompt(self, uiMode, recentDeathPaneNotificationText)
        self.RefreshPredictionActionButtonState()
    end

    ---@param self GrimRefreshReadyControllerFrame
    function GrimMainFrame:RefreshDeaths()
        local state = GetDisplayedState(self)
        local deaths = state.deaths

        self:RefreshRecentDeathLogState()

        RefreshScoreSummary(self, state)
        self:RefreshLatestDeathDetails(deaths[#deaths])
        local debugState, latestDeath = GetLiveDebugSnapshot()
        GrimDebug:RefreshLatestDeathDetails(latestDeath, debugState)
        if self.RefreshIntroDemoVisibility then
            self:RefreshIntroDemoVisibility()
        end
        GrimLog:RefreshHistory()
    end

    ---@param self GrimRefreshReadyControllerFrame
    ---@param death GrimDeath|nil
    function GrimMainFrame:RefreshLatestDeathDetails(death)
        if not self.detailValues then
            return
        end

        ---@type GrimRefreshLatestDeathFields
        local detailFields = {
            time = death and GrimUI.GetStoredDeathTime(death),
            name = death and death.name,
            level = death and death.level,
            sourceName = death and death.sourceName,
            zone = death and death.zone,
            sourceMessage = death and death.sourceMessage,
        }

        ApplyDetailValues(self.detailValues, detailFields)
    end

    ---@param self GrimRefreshReadyControllerFrame
    function GrimMainFrame:RefreshLockedPrediction()
        local state = GetDisplayedState(self)
        local lockedPrediction = state.lockedPrediction
        local inputPrediction = lockedPrediction or state.draftPrediction or state.lastPrediction
        local uiMode = GrimUIMode.Resolve(self, state, GetState())
        self.lockedPredictionValue:SetText(logic.FormatLockedPrediction(lockedPrediction))

        self.ApplyPredictionInputState(inputPrediction)

        GrimUIAutocomplete.HideDropdown(self)

        self.SetPredictionInputsLocked(uiMode.inputsLocked)

        self.RefreshPredictionActionButtonState()
        self:RefreshRecentDeathLogState()
        DisablePredictionActionsForDemo(self)

        local debugState, latestDeath = GetLiveDebugSnapshot()
        GrimDebug:RefreshLatestDeathDetails(latestDeath, debugState)
    end

    ---@param self GrimRefreshReadyControllerFrame
    function GrimMainFrame:RefreshCollapsedSummary()
        local state = GetDisplayedState(self)
        local deaths = state.deaths
        local recentEntries = GetCachedViewEntries("recentView", deaths, {})
        local visibleRowCount = GrimUI.GetCollapsedVisibleRowCount(self:GetHeight())
        local offset = math.max(#deaths - visibleRowCount, 0)

        GrimUIDeathLogList.RefreshDeathLogRows(self.collapsedLogFrame, recentEntries, {
            columns = GrimUI.COLLAPSED_LOG_COLUMNS,
            offset = offset,
            reverseOrder = false,
            maxRows = visibleRowCount,
        })

        self.collapsedPointsValue:SetText(FormatLargeNumber(state.totalPoints))
    end

    ---@param self GrimRefreshReadyDebugFrame
    ---@param death GrimDeath|nil
    ---@param state GrimDisplayState
    function GrimDebug:RefreshLatestDeathDetails(death, state)
        ApplyDetailValues(self.detailValues, GetDebugDetailFields(death, state))
    end

    ---@param self GrimRefreshReadyHistoryFrame
    function GrimLog:RefreshHistory()
        local viewState = GetHistoryViewState(self)
        local history = viewState.history
        self.logSubtitle:SetText(viewState.subtitle)
        self.filterButton:SetText(viewState.filterButtonText)
        if self.columnHeaders.time then
            self.columnHeaders.time:SetText(
                self.showSuccessfulOnly == true and GrimUI.HISTORY_SUCCESS_RANK_LABEL or "Time"
            )
        end
        local totalHistory = #history

        FauxScrollFrame_Update(
            self.scrollFrame,
            totalHistory,
            #self.rows,
            GrimUI.LAYOUT.deathLogRowHeight
        )

        local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
        GrimUIDeathLogList.RefreshDeathLogRows(self, history, {
            columns = historyLogColumns,
            offset = offset,
            reverseOrder = true,
            columnContext = {
                showRank = self.showSuccessfulOnly == true,
            },
        })
    end

    GrimLog.displayCache = displayCache
    GrimMainFrame.displayCache = displayCache
end
