---@class GrimMinimapControllerFrame: GrimMainFrameShell
---@field IsShown fun(self: GrimMinimapControllerFrame): boolean
---@field Show fun(self: GrimMinimapControllerFrame)
---@field Hide fun(self: GrimMinimapControllerFrame)
---@field Raise fun(self: GrimMinimapControllerFrame)|nil

local _, ns = ...
---@cast ns GrimNamespace

local GrimUIMinimap = ns.GrimUIMinimap or {}
local GrimDatabase = ns.GrimDatabase
local GrimLogic = ns.GrimLogic
local LibStub = _G.LibStub
ns.GrimUIMinimap = GrimUIMinimap

local MINIMAP_ENABLED = true
local MINIMAP_ICON_PATH = "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01"
local MINIMAP_LAUNCHER_NAME = "GrimGuesser"
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")
---@type MinimapLauncher|nil
local minimapLauncher = nil
local minimapButtonRegistered = false
---@type GrimMinimapControllerFrame|nil
local activeFrame = nil
---@type GrimCharacterState|nil
local activeDatabase = nil

---@param database GrimCharacterState
---@return string
local function GetTooltipPredictionText(database)
    return GrimLogic.FormatLockedPrediction(GrimDatabase.GetLockedPrediction(database))
end

---@param database GrimCharacterState
---@return string
local function GetTooltipScoreText(database)
    return FormatLargeNumber(GrimDatabase.GetTotalPoints(database))
end

---@return boolean
function GrimUIMinimap.IsEnabled()
    return MINIMAP_ENABLED == true and LibDataBroker ~= nil and LibDBIcon ~= nil
end

---@param _ table|nil
---@param database GrimCharacterState
---@return string|nil
function GrimUIMinimap.RefreshLauncherText(_, database)
    if not GrimUIMinimap.IsEnabled() or not minimapLauncher then
        return nil
    end

    minimapLauncher.text = GetTooltipScoreText(database)
    minimapLauncher.value = minimapLauncher.text
    minimapLauncher.suffix = ""
    return minimapLauncher.text
end

---@param _ table|nil
---@param database GrimCharacterState
---@param hidden boolean
---@return boolean
function GrimUIMinimap.SetHidden(_, database, hidden)
    GrimDatabase.SetMinimapHidden(database, hidden)

    local libDBIcon = LibDBIcon
    if not GrimUIMinimap.IsEnabled() or not libDBIcon then
        return GrimDatabase.GetMinimapHidden(database)
    end

    if GrimDatabase.GetMinimapHidden(database) then
        libDBIcon:Hide(MINIMAP_LAUNCHER_NAME)
    else
        libDBIcon:Show(MINIMAP_LAUNCHER_NAME)
    end

    return GrimDatabase.GetMinimapHidden(database)
end

---@param frame GrimMinimapControllerFrame|nil
---@param database GrimCharacterState
---@return boolean
function GrimUIMinimap.ToggleHidden(frame, database)
    return GrimUIMinimap.SetHidden(frame, database, not GrimDatabase.GetMinimapHidden(database))
end

---@param frame GrimMinimapControllerFrame
local function RestoreOpenWindowState(frame)
    if frame.Raise then
        frame:Raise()
    end
end

---@param frame GrimMinimapControllerFrame|nil
---@param database GrimCharacterState
function GrimUIMinimap.Toggle(frame, database)
    if not GrimUIMinimap.IsEnabled() or not frame then
        return
    end

    if frame:IsShown() then
        GrimDatabase.SetHidden(database, true)
        frame:Hide()
        return
    end

    GrimDatabase.SetHidden(database, false)
    frame:Show()
    RestoreOpenWindowState(frame)
end

---@param frame GrimMinimapControllerFrame|nil
---@param database GrimCharacterState
function GrimUIMinimap.Initialize(frame, database)
    local libDataBroker = LibDataBroker
    local libDBIcon = LibDBIcon
    if not GrimUIMinimap.IsEnabled() or not frame or not libDataBroker or not libDBIcon then
        return
    end

    activeFrame = frame
    activeDatabase = database

    local minimapSettings = GrimDatabase.GetMinimapSettings(database)

    if not minimapLauncher then
        minimapLauncher = libDataBroker:NewDataObject(MINIMAP_LAUNCHER_NAME, {
            type = "data source",
            label = "Grim Guesser",
            text = GetTooltipScoreText(database),
            value = GetTooltipScoreText(database),
            suffix = "",
            icon = MINIMAP_ICON_PATH,
            OnClick = function()
                GrimUIMinimap.Toggle(activeFrame, activeDatabase)
            end,
            ---@param tooltip MinimapTooltip|nil
            OnTooltipShow = function(tooltip)
                if not tooltip then
                    return
                end

                tooltip:AddLine("Grim Guesser")
                tooltip:AddLine(GetTooltipPredictionText(activeDatabase), 1, 1, 1, true)
                tooltip:AddLine("Score: " .. GetTooltipScoreText(activeDatabase), 1, 0.82, 0)
            end,
        })
    end

    if minimapButtonRegistered then
        libDBIcon:Refresh(MINIMAP_LAUNCHER_NAME, minimapSettings)
    else
        libDBIcon:Register(MINIMAP_LAUNCHER_NAME, minimapLauncher, minimapSettings)
        minimapButtonRegistered = true
    end

    GrimUIMinimap.RefreshLauncherText(frame, database)
    GrimUIMinimap.SetHidden(frame, database, GrimDatabase.GetMinimapHidden(database))
end

return GrimUIMinimap
