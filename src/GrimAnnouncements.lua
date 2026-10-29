local _, ns = ...
---@cast ns GrimNamespace

local GrimAnnouncements = ns.GrimAnnouncements or {}
local GrimConstants = ns.GrimConstants
local GrimDatabase = ns.GrimDatabase
ns.GrimAnnouncements = GrimAnnouncements

local ANNOUNCEMENT_RULES = GrimConstants.ANNOUNCEMENTS
local MIN_ANNOUNCE_LEVEL = 10

---@param state GrimCharacterState
---@param level integer
function GrimAnnouncements.AnnouncePlayerLevelUp(state, level)
    if level % ANNOUNCEMENT_RULES.levelUpFrequency ~= 0 then
        return
    end

    if not IsInGuild() then
        return
    end

    if not GrimDatabase.GetGuildAnnouncementsEnabled(state) then
        return
    end

    if not GrimDatabase.GetAnnounceScoreOnLevelUp(state) then
        return
    end

    SendChatMessage(
        string.format(
            "[Grim Guesser] %s has reached level %d! Their score is %s",
            UnitName("player"),
            level,
            FormatLargeNumber(GrimDatabase.GetTotalPoints(state))
        ),
        "GUILD"
    )
end

---@param state GrimCharacterState
---@param printMessage GrimPrint
function GrimAnnouncements.AnnouncePlayerDeath(state, printMessage)
    local formattedScore = FormatLargeNumber(GrimDatabase.GetTotalPoints(state))
    local playerLevel = UnitLevel("player")

    printMessage("Your final score is " .. formattedScore .. ".")

    if playerLevel >= MIN_ANNOUNCE_LEVEL and
        IsInGuild() and
        GrimDatabase.GetGuildAnnouncementsEnabled(state) and
        GrimDatabase.GetAnnounceDeathToGuild(state)
    then
        SendChatMessage(
            string.format(
                "[Grim Guesser] Final score: %s",
                formattedScore
            ),
            "GUILD"
        )
    end
end

return GrimAnnouncements
