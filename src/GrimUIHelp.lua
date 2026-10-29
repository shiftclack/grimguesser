local _, ns = ...
---@cast ns GrimNamespace

local GrimUI = ns.GrimUI
local GrimUIHelp = ns.GrimUIHelp or {}
local GrimConstants = ns.GrimConstants
ns.GrimUIHelp = GrimUIHelp
local HELP_RULES = GrimConstants.HELP
local VERSION = GrimConstants.VERSION
local DOWNLOAD_AREA_WIDTH = 204
local GITHUB_LINK_DIALOG_WIDTH = 430
local GITHUB_LINK_DIALOG_HEIGHT = 112

---@class GrimHelpOwnerFrame: GrimMainFrameShell
---@field [string] any

---@class GrimGitHubLinkFrame
---@field [string] any
---@field title table
---@field urlBox table
---@field okButton table
---@field backdropOverlay GrimModalBackdropOverlay
---@field titlebarDragHandle GrimModalTitlebarDragHandle

---@class GrimHelpFrame
---@field [string] any
---@field scrollFrame table
---@field scrollContent table
---@field helpText table
---@field downloadArea table
---@field downloadLink table
---@field githubLinkFrame GrimGitHubLinkFrame
---@field closeButton table
---@field demoButton table
---@field backdropOverlay GrimModalBackdropOverlay
---@field titlebarDragHandle GrimModalTitlebarDragHandle

---@return string
local function BuildHelpWindowText()
    local skull = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12:0:0|t"
    local diamond = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12|t"
    local version

    if VERSION == "0.0.0" then
        version = "unreleased version"
    else
        version = "version " .. VERSION
    end

    return table.concat({"",
        diamond .. " Game Overview " .. diamond,
        "",
        "Grim Guesser is a |cFFFFFF00death prediction minigame|r for your faction.",
        "",
        skull .. " Predict the |cFFFFFF00level|r, |cFFFFFF00location|r and |cFFFFFF00source|r of incoming deaths\n",
        skull .. " View deaths in |cFFFFFF00real time|r\n",
        skull .. " Earn points if |cFFFFFF00any part|r of your prediction matches\n",
        skull .. " Win even more with |cFFFFFF00streak bonuses|r\n",
        skull .. " Gain |cFFFFFF00extra points|r if someone dies in the same zone as you\n",
        skull .. " The game ends when you die and receive your |cFFFFFF00final score|r\n",
        "",
        "",
        diamond .. " Missing deaths? " .. diamond,
        "",
        "Press Escape, Press Options, type |cFFFFFF00Hardcore|r into the Search menu. "
            .. "Set |cFFFFFF00Hardcore death announcements|r to |cFFFFFF00All Deaths|r. "
            .. "Then type |cFFFFFF00/join hardcoredeaths|r to join the chat channel.",
        "",
        "",
        diamond .. " About " .. diamond,
        "",
        "Grim Guesser " .. version .. " © 2026 Shiftclack.",
    }, "\n")
end


---@return string
function GrimUIHelp.GetDownloadUrl()
    return HELP_RULES.downloadUrl
end

---@param ownerFrame GrimHelpOwnerFrame
---@param active boolean
local function RefreshOwnerFrameForHelpModal(ownerFrame, active)
    if ownerFrame:IsShown() then
        if active then
            ownerFrame.SetPredictionInputsLocked(true)
            ownerFrame.RefreshPredictionActionButtonState()
        else
            ownerFrame:RefreshLockedPrediction()
        end
    end
end

---@param ownerFrame GrimHelpOwnerFrame
---@return GrimGitHubLinkFrame
local function CreateGitHubLinkDialog(ownerFrame)
    local layout = GrimUI.LAYOUT
    local githubLinkFrame = CreateFrame("Frame", "GrimGitHubLinkFrame", UIParent, "BasicFrameTemplateWithInset")
    ---@cast githubLinkFrame GrimGitHubLinkFrame
    githubLinkFrame:SetSize(GITHUB_LINK_DIALOG_WIDTH, GITHUB_LINK_DIALOG_HEIGHT)
    githubLinkFrame:SetPoint("CENTER", ownerFrame, "CENTER", 0, 0)
    githubLinkFrame:SetFrameStrata("DIALOG")
    githubLinkFrame:SetToplevel(true)
    githubLinkFrame:SetMovable(false)
    githubLinkFrame:EnableMouse(true)
    githubLinkFrame:Hide()
    githubLinkFrame.backdropOverlay = GrimUI.CreateModalBackdropOverlay(ownerFrame)

    githubLinkFrame:SetScript("OnShow", function(self)
        GrimUI.ShowExpandedOwnerFrame(ownerFrame)
        self.backdropOverlay:Show()
        RefreshOwnerFrameForHelpModal(ownerFrame, true)
    end)
    githubLinkFrame:SetScript("OnHide", function(self)
        self.backdropOverlay:Hide()
        RefreshOwnerFrameForHelpModal(ownerFrame, false)
    end)

    local title = githubLinkFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", githubLinkFrame, "TOP", 0, -6)
    title:SetText("GitHub Link")
    githubLinkFrame.title = title

    githubLinkFrame.titlebarDragHandle = GrimUI.CreateModalTitlebarDragHandle(githubLinkFrame, ownerFrame)

    local urlBox = CreateFrame("EditBox", nil, githubLinkFrame, "InputBoxTemplate")
    urlBox:SetAutoFocus(false)
    urlBox:SetSize(GITHUB_LINK_DIALOG_WIDTH - (layout.outsideGutter * 2), 20)
    urlBox:SetPoint("TOPLEFT", githubLinkFrame, "TOPLEFT", layout.outsideGutter, -42)
    urlBox:SetFontObject("GameFontHighlightSmall")
    urlBox:SetText(GrimUIHelp.GetDownloadUrl())
    urlBox:SetCursorPosition(0)
    ---@param self table
    urlBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    ---@param self table
    urlBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:HighlightText(0, 0)
    end)

    local okButton = CreateFrame("Button", "GrimGitHubLinkOKButton", githubLinkFrame, "GameMenuButtonTemplate")
    okButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    okButton:SetPoint("BOTTOM", githubLinkFrame, "BOTTOM", 0, layout.outsideGutter)
    okButton:SetText("OK")
    okButton:SetScript("OnClick", function()
        githubLinkFrame:Hide()
    end)

    githubLinkFrame.urlBox = urlBox
    githubLinkFrame.okButton = okButton

    return githubLinkFrame
end

---@param ownerFrame GrimHelpOwnerFrame
---@return GrimHelpFrame
function GrimUIHelp.CreateHelpWindow(ownerFrame)
    local layout = GrimUI.LAYOUT
    local helpFrame = CreateFrame("Frame", "GrimHelpFrame", UIParent, "BasicFrameTemplateWithInset")
    ---@cast helpFrame GrimHelpFrame
    helpFrame:SetSize(500, 369)
    helpFrame:SetPoint("CENTER", ownerFrame, "CENTER", 0, 0)
    helpFrame:SetFrameStrata("DIALOG")
    helpFrame:SetToplevel(true)
    helpFrame:SetMovable(false)
    helpFrame:EnableMouse(true)
    helpFrame:Hide()
    helpFrame.backdropOverlay = GrimUI.CreateModalBackdropOverlay(ownerFrame)

    helpFrame:SetScript("OnShow", function(self)
        GrimUI.ShowExpandedOwnerFrame(ownerFrame)
        self.backdropOverlay:Show()
        RefreshOwnerFrameForHelpModal(ownerFrame, true)
    end)
    helpFrame:SetScript("OnHide", function(self)
        self.backdropOverlay:Hide()
        RefreshOwnerFrameForHelpModal(ownerFrame, false)
    end)

    local title = helpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", helpFrame, "TOP", 0, -6)
    title:SetText("HELP")
    helpFrame.titlebarDragHandle = GrimUI.CreateModalTitlebarDragHandle(helpFrame, ownerFrame)

    local scrollFrame = CreateFrame("ScrollFrame", "GrimHelpScrollFrame", helpFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", helpFrame, "TOPLEFT", layout.outsideGutter, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", helpFrame, "BOTTOMRIGHT", -(layout.outsideGutter + layout.scrollbarInset), 84)
    helpFrame.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(
        helpFrame:GetWidth() - (layout.outsideGutter * 2) - layout.scrollbarWidth - layout.scrollbarInset
    )
    scrollFrame:SetScrollChild(content)

    local helpText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetJustifyV("TOP")
    helpText:SetWordWrap(true)
    helpText:SetNonSpaceWrap(false)
    helpText:SetWidth(content:GetWidth())
    helpText:SetText(BuildHelpWindowText())

    content:SetHeight(helpText:GetStringHeight() + 12)
    helpFrame.scrollContent = content
    helpFrame.helpText = helpText

    local footer = CreateFrame("Frame", nil, helpFrame)
    footer:SetPoint("BOTTOMLEFT", helpFrame, "BOTTOMLEFT", layout.outsideGutter, layout.outsideGutter)
    footer:SetPoint("BOTTOMRIGHT", helpFrame, "BOTTOMRIGHT", -layout.outsideGutter, layout.outsideGutter)
    footer:SetHeight(60)

    local downloadArea = CreateFrame("Frame", nil, footer)
    downloadArea:SetSize(DOWNLOAD_AREA_WIDTH, 40)
    downloadArea:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 0, 4)

    local downloadLink = CreateFrame("Button", nil, downloadArea)
    downloadLink:SetSize(DOWNLOAD_AREA_WIDTH, 18)
    downloadLink:SetPoint("BOTTOMLEFT", downloadArea, "BOTTOMLEFT", 0, 0)
    downloadLink:SetNormalFontObject("GameFontHighlightSmall")
    downloadLink:SetHighlightFontObject("GameFontHighlightSmall")
    downloadLink:SetText("Download on GitHub")
    downloadLink:GetFontString():SetJustifyH("LEFT")
    downloadLink:GetFontString():SetWidth(DOWNLOAD_AREA_WIDTH)
    downloadLink:GetFontString():SetTextColor(0.25, 0.6, 1.0)

    ---@param self table
    downloadLink:SetScript("OnEnter", function(self)
        self:GetFontString():SetTextColor(0.45, 0.75, 1.0)
    end)
    ---@param self table
    downloadLink:SetScript("OnLeave", function(self)
        self:GetFontString():SetTextColor(0.25, 0.6, 1.0)
    end)

    local githubLinkFrame = CreateGitHubLinkDialog(ownerFrame)
    downloadLink:SetScript("OnClick", function()
        helpFrame:Hide()
        githubLinkFrame.urlBox:SetText(GrimUIHelp.GetDownloadUrl())
        githubLinkFrame.urlBox:SetCursorPosition(0)
        githubLinkFrame:Show()
        githubLinkFrame:Raise()
        githubLinkFrame.urlBox:SetFocus()
        githubLinkFrame.urlBox:HighlightText()
    end)

    local closeButton = CreateFrame("Button", "GrimHelpCloseButton", helpFrame, "GameMenuButtonTemplate")
    closeButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    closeButton:SetPoint("BOTTOMRIGHT", helpFrame, "BOTTOMRIGHT", -layout.outsideGutter, layout.outsideGutter)
    closeButton:SetText("CLOSE")
    closeButton:SetScript("OnClick", function()
        helpFrame:Hide()
    end)

    local demoButton = CreateFrame("Button", "GrimHelpDemoButton", helpFrame, "GameMenuButtonTemplate")
    demoButton:SetSize(layout.standardButtonWidth, layout.standardButtonHeight)
    demoButton:SetPoint("RIGHT", closeButton, "LEFT", -layout.modalButtonGap, 0)
    demoButton:SetText("DEMO")
    demoButton:SetScript("OnClick", function()
        helpFrame:Hide()
        if ownerFrame and ownerFrame.introDemoController and ownerFrame.introDemoController.Show then
            ownerFrame.introDemoController:Show()
        end
    end)

    helpFrame.downloadArea = downloadArea
    helpFrame.downloadLink = downloadLink
    helpFrame.githubLinkFrame = githubLinkFrame
    helpFrame.closeButton = closeButton
    helpFrame.demoButton = demoButton

    return helpFrame
end
