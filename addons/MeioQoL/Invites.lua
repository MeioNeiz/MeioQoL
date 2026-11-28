-- Group invites: optional auto-decline (with a whisper the player writes), friends and guild
-- let through, and a line on the invite pop-up with what we know of the inviter.
-- What the client tells us: PARTY_INVITE_REQUEST gives name, role flags and the inviter's
-- GUID. The GUID gives race and class (once cached); level and zone only come from the
-- friends list, Battle.net, the guild roster, a unit we can see or the last /who.
local _, ns = ...

local RETRY = { 0.5, 1.5 }
local WHISPER_EVERY = 300
-- an invite from someone you whispered this recently is one you asked for
local ASKED_WITHIN = 600
local REASON_MAX = 200

local whispered, toldStop = {}, false
local asked = {}

local function Known(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function Short(name)
    return (name or ""):match("^[^-]+") or name
end

local function Key(name)
    return Short(name):lower()
end

local function Friend(name, guid)
    local fl = C_FriendList
    if fl then
        if guid and fl.IsFriend and fl.IsFriend(guid) then return true end
        if fl.GetFriendInfo and fl.GetFriendInfo(Short(name)) then return true end
    end
    local bn = C_BattleNet
    return guid and bn and bn.GetGameAccountInfoByGUID
        and bn.GetGameAccountInfoByGUID(guid) ~= nil or false
end

local function GuildRow(name, guid)
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then
        return
    end
    local key = Key(name)
    for i = 1, GetNumGuildMembers() do
        local full, _, _, level, class, zone, _, _, _, _, _, _, _, _, _, _, rowGUID =
            GetGuildRosterInfo(i)
        if (guid and rowGUID == guid) or (full and Key(full) == key) then
            return { level = level, class = class, zone = zone }
        end
    end
end

local function GuildMember(name, guid)
    if guid and IsGuildMember and IsGuildMember(guid) then return true end
    if C_GuildInfo and C_GuildInfo.MemberExistsByName
        and C_GuildInfo.MemberExistsByName(Short(name)) then
        return true
    end
    return GuildRow(name, guid) ~= nil
end

-- best known level, class and zone, from the richest source first
local function Inviter(name, guid)
    local info = {}
    local function Fill(level, class, zone)
        if Known(level) and level > 0 and not info.level then info.level = level end
        if Known(class) and class ~= "" and not info.class then info.class = class end
        if Known(zone) and zone ~= "" and not info.zone then info.zone = zone end
    end
    local fl = C_FriendList
    local f = fl and fl.GetFriendInfo and fl.GetFriendInfo(Short(name))
    if f and f.connected then Fill(f.level, f.className, f.area) end
    local bn = guid and C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID
        and C_BattleNet.GetGameAccountInfoByGUID(guid)
    if bn then Fill(bn.characterLevel, bn.className, bn.areaName) end
    local g = GuildRow(name, guid)
    if g then Fill(g.level, g.class, g.zone) end
    local unit = guid and UnitTokenFromGUID and UnitTokenFromGUID(guid)
    if unit and (not canaccessvalue or canaccessvalue(unit)) then
        Fill(UnitLevel(unit), (UnitClass(unit)), GetRealZoneText and GetRealZoneText())
    end
    if fl and fl.GetNumWhoResults and fl.GetWhoInfo then
        local key = Key(name)
        for i = 1, fl.GetNumWhoResults() or 0 do
            local w = fl.GetWhoInfo(i)
            if w and w.fullName and Key(w.fullName) == key then
                Fill(w.level, w.classStr, w.area)
            end
        end
    end
    if guid and GetPlayerInfoByGUID then
        local class, classFile, race = GetPlayerInfoByGUID(guid)
        if Known(class) then
            Fill(nil, class)
            info.classFile = classFile
            info.race = Known(race) and race ~= "" and race or nil
        end
    end
    return info
end

-- the pop-up line and whether it is complete (level and zone known), or nil
function ns.InviterLine(name, guid)
    local i = Inviter(name, guid)
    if not (i.level or i.class or i.zone) then return end
    local color = i.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[i.classFile]
    local class = i.class and color and color.colorStr
        and ("|c" .. color.colorStr .. i.class .. "|r") or i.class
    local who = class or "player"
    if i.race and class and not i.level then who = i.race .. " " .. class end
    local line = i.level and ("Level %d %s"):format(i.level, who) or who
    if i.zone then line = line .. " in " .. i.zone
    elseif not i.level then line = line .. ", level and zone not known" end
    return line, (i.level and i.zone) ~= nil
end

local function Popup()
    local _, dialog = StaticPopup_Visible("PARTY_INVITE")
    return dialog
end

-- per invite: what we wrote, and the dialog text before it (when there is no SubText)
local current, shownLine, baseText

-- the dialog's small second line when it has one, else a line under its text
local function Decorate(dialog, line)
    if dialog.SubText then
        dialog.SubText:SetText(line)
        dialog.SubText:Show()
        -- anchors were laid out with SubText hidden: lay out again so it sits above the buttons
        if dialog.SetupElementAnchoring then dialog:SetupElementAnchoring() end
    else
        local text = dialog.GetTextFontString and dialog:GetTextFontString() or dialog.text
        if not text then return end
        baseText = baseText or text:GetText()
        text:SetText(baseText .. "\n" .. line)
    end
    if dialog.Resize then
        dialog:Resize()
    elseif _G.StaticPopup_Resize then
        _G.StaticPopup_Resize(dialog, dialog.which)
    end
end

local function ShowInviter(name, guid, attempt)
    if current ~= name or not ns.db.inviteInfo then return end
    local dialog = Popup()
    if not dialog then
        if attempt == 0 then C_Timer.After(0, function() ShowInviter(name, guid, 1) end) end
        return
    end
    local line, complete = ns.InviterLine(name, guid)
    if line and line ~= shownLine then
        shownLine = line
        Decorate(dialog, line)
    end
    -- class comes once the server answers for the GUID, level and zone if they come in range
    local wait = not complete and RETRY[attempt + 1]
    if wait then
        C_Timer.After(wait - (RETRY[attempt] or 0), function()
            ShowInviter(name, guid, attempt + 1)
        end)
    end
end

-- why this invite goes to the player instead of being declined, or nil
local function LetThrough(name, guid, tank, healer, damage)
    if tank or healer or damage then return "group finder" end
    if C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then
        return "listed"
    end
    if WillAcceptInviteRemoveQueues and WillAcceptInviteRemoveQueues() then return "queued" end
    local t = asked[Key(name)]
    if t and GetTime() - t < ASKED_WITHIN then return "whispered" end
    if ns.db.inviteFriends and (Friend(name, guid) or GuildMember(name, guid)) then
        return "friend"
    end
end

local function Whisper(name)
    local reason = strtrim(ns.db.inviteReason or "")
    if reason == "" then return end
    local key = Key(name)
    if whispered[key] and GetTime() - whispered[key] < WHISPER_EVERY then return end
    whispered[key] = GetTime()
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    -- chat can be locked down (instances, encounters): skip the whisper, still decline
    pcall(send, reason, "WHISPER", nil, name)
end

local function Decline(name)
    DeclineGroup()
    StaticPopup_Hide("PARTY_INVITE")
    -- Blizzard may show the pop-up after us on this same event
    C_Timer.After(0, function() StaticPopup_Hide("PARTY_INVITE") end)
    Whisper(name)
    local msg = ("declined %s's group invite"):format(Short(name))
    if not toldStop then
        toldStop = true
        msg = msg .. " |cff999999(" .. ns.Cmd("/qol invites off") .. "|cff999999 to stop)|r"
    end
    ns.Say(msg)
end

ns.On("PARTY_INVITE_REQUEST", function(name, tank, healer, damage, _, _, _, guid)
    if not Known(name) or name == "" then return end
    if not Known(guid) then guid = nil end
    if ns.db.inviteDecline and not LetThrough(name, guid, tank, healer, damage) then
        current = nil
        Decline(name)
        return
    end
    current, shownLine, baseText = name, nil, nil
    ShowInviter(name, guid, 0)
end)

ns.On("CHAT_MSG_WHISPER_INFORM", function(_, target)
    if Known(target) then asked[Key(target)] = GetTime() end
end)

ns.On("PLAYER_LOGIN", function()
    if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end)

function ns.SetInviteReason(text)
    text = strtrim(tostring(text or "")):sub(1, REASON_MAX)
    ns.db.inviteReason = text
    if text == "" then
        ns.Say("declined invites get no whisper")
    else
        ns.Say("declined invites get the whisper: " .. text)
    end
end

function ns.InviteReasonState()
    local r = ns.db.inviteReason or ""
    return r == "" and "none" or ('"' .. r .. '"')
end

StaticPopupDialogs.MEIOQOL_INVITE_REASON = {
    text = "Whisper this to whoever's group invite MeioQoL declines. Leave it empty to "
        .. "decline without a word.",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = REASON_MAX,
    editBoxWidth = 300,
    OnShow = function(dialog)
        local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
        box:SetText(ns.db.inviteReason or "")
        box:HighlightText()
        box:SetFocus()
    end,
    OnAccept = function(dialog)
        local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
        ns.SetInviteReason(box:GetText())
    end,
    EditBoxOnEnterPressed = function(box)
        ns.SetInviteReason(box:GetText())
        box:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns.EditInviteReason()
    StaticPopup_Show("MEIOQOL_INVITE_REASON")
end
