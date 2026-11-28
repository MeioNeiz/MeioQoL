-- Small automations: gossip skip and flight map, quests, resurrection, summons, repair, vendor
-- purchases and restock, faster auto loot, loot confirmations, group invite control, camera
-- and fishing sound. Each feature file registers its own events here.
local ADDON, ns = ...

local PREFIX = "|cffb090ffMeioQoL:|r "
ns.ON, ns.OFF = "|cff80ff80on|r", "|cffff8080off|r"

ns.DEFAULTS = {
    gossip = true, gossipServices = false, res = true, summon = true, guildRepair = true,
    restock = true, bankRestock = true, lowWarn = true, reserve = 1, fastLoot = true,
    inviteInfo = true, inviteDecline = false, inviteFriends = true, inviteReason = "",
    taxi = true, questAccept = false, questTurnIn = false, repair = false, bulkBuy = true,
    wideMerchant = true, lootConfirm = false, camera = false, cameraZoom = 2.6,
    cameraSpeed = 50, fishSound = false,
}

-- our toggle -> FlareUI's tweak doing the same job. Ours waits while FlareUI's is on, so the
-- two never both act. bag: FlareUI files it under Bags & Looting, which has its own switch.
ns.FLARE = {
    taxi = { key = "taxiMap", what = "flight map" },
    questAccept = { key = "autoAcceptQuests", what = "quest accept" },
    questTurnIn = { key = "autoTurnInQuests", what = "quest turn-in" },
    repair = { key = "autoRepair", what = "auto repair", bag = true },
    bulkBuy = { key = "bulkBuy", what = "vendor purchases", bag = true },
    wideMerchant = { key = "merchantWide", what = "wider vendor window", bag = true,
        reload = true },
    lootConfirm = { key = "skipLootConfirm", what = "loot confirmations", bag = true },
    -- FlareUI's camera values are numbers; false (like its nil) leaves Blizzard's own
    camera = { key = "cameraMaxZoom", also = "cameraZoomSpeed", what = "camera" },
    fishSound = { key = "fishSound", what = "fishing sounds" },
}
ns.FLARE_ORDER = { "taxi", "questAccept", "questTurnIn", "repair", "bulkBuy", "wideMerchant",
    "lootConfirm", "camera", "fishSound" }

-- features that apply something when their toggle (or FlareUI's) changes
ns.Apply = {}

function ns.Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

function ns.Cmd(text)
    return "|cffffd100" .. text .. "|r"
end

function ns.Money(copper)
    return GetMoneyString(math.floor(copper + 0.5), true)
end

-- one handler list per event, each run in its own pcall so one feature's error can't stop
-- the others. Registered at file load: MERCHANT_SHOW must reach us before FlareUI, which
-- registers it at PLAYER_LOGIN (see Repair.lua).
local frame = CreateFrame("Frame")
local handlers = {}
function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end
frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- FlareUI's tweaks table (profile settings), or nil without FlareUI
function ns.FlareTweaks()
    local f = _G.FlareUI
    return type(f) == "table" and f.db and f.db.profile and f.db.profile.tweaks or nil
end

-- FlareUI's own copy of a tweak is switched on and running
function ns.FlareOwns(key)
    local f, t = ns.FLARE[key], ns.FlareTweaks()
    if not (f and t and t.enabled) then return false end
    if f.bag and not t.bagModule then return false end
    return (t[f.key] or (f.also and t[f.also])) and true or false
end

-- a feature that is on here and not left to FlareUI's copy
function ns.Active(key)
    return ns.db and ns.db[key] and not ns.FlareOwns(key) or false
end

local function RunApply(key)
    if ns.Apply[key] then
        local ok, err = pcall(ns.Apply[key])
        if not ok then geterrorhandler()(err) end
    end
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    MeioQoLDB = MeioQoLDB or {}
    for k, v in pairs(ns.DEFAULTS) do
        if MeioQoLDB[k] == nil then MeioQoLDB[k] = v end
    end
    MeioQoLCharDB = MeioQoLCharDB or {}
    MeioQoLCharDB.restock = MeioQoLCharDB.restock or {}
    ns.db, ns.char = MeioQoLDB, MeioQoLCharDB
end)

-- slash toggles, in help order; Settings.lua builds its checkboxes from the same table, with a
-- header where a toggle starts a section
ns.TOGGLES = {
    { key = "gossip", cmd = "gossip", label = "Skip NPC chat", section = "NPC chat and quests",
      sectionTip = "Skip the chat window when an NPC has nothing to say but one option, open "
          .. "the flight map, take and hand in quests. Hold Shift to talk normally.",
      help = "pick an NPC's only chat option when it has no quests",
      tip = "Talking to an NPC with no quests and one chat option picks it for you. "
          .. "Vendors, trainers, bankers and innkeepers still show their menu (below). "
          .. "Hold Shift to talk normally." },
    { key = "gossipServices", cmd = "services", label = "Also for services",
      help = "also for vendors, trainers, bankers and innkeepers",
      tip = "Skip the chat to the window of an NPC whose only option is a service: "
          .. "vendor, trainer, banker, innkeeper, auctioneer." },
    { key = "taxi", cmd = "taxi", label = "Instant flight map",
      help = "a flight master with no quests opens the flight map",
      tip = "Talking to a flight master with no quests for you opens the flight map "
          .. "straight away, even when it has other chat options. Hold Shift to talk "
          .. "normally." },
    { key = "questAccept", cmd = "accept", label = "Accept quests",
      help = "accept the quests an NPC offers as you talk to them",
      tip = "An NPC's quests are accepted as you talk to them, one after another. Never "
          .. "repeatable, daily or grey quests, PvP quests or ones an item starts. Hold "
          .. "Shift to read them first." },
    { key = "questTurnIn", cmd = "turnin", label = "Turn in quests",
      help = "hand in finished quests, taking the reward when there is no choice",
      tip = "Finished quests are handed in as you talk to the NPC, and the reward taken "
          .. "when there is one or none; with a choice of rewards the window waits for "
          .. "you. Never repeatable quests, ones that cost gold or take battleground marks. "
          .. "Hold Shift to do it yourself." },
    { key = "repair", cmd = "repair", label = "Auto repair", section = "Vendors",
      sectionTip = "Repair, buy and restock at vendors. Hold Shift as you open a vendor to "
          .. "skip the automatic ones.",
      help = "repair from your own gold at vendors that repair",
      tip = "At a vendor that repairs, your gear is repaired from your gold, with a chat "
          .. "line for the cost (guild funds first when Guild repair is on). Off "
          .. "until you turn it on. Hold Shift to skip." },
    { key = "guildRepair", cmd = "guildrepair", label = "Guild repair",
      help = "repair from guild funds before your own gold",
      tip = "At a vendor that repairs, pay from the guild bank when your rank may and the "
          .. "guild has enough. Otherwise Auto repair (or you) pays as before. Hold Shift "
          .. "to skip." },
    { key = "bulkBuy", cmd = "bulk", label = "Buy many at once",
      help = "Shift-click a vendor item to buy several stacks",
      tip = "Shift-click an item at a vendor: the amount box goes up to as many as your "
          .. "gold, the stock and your bag room allow, with Stack and MAX buttons. It buys a "
          .. "stack at a time with its progress above the window. Nothing is bought until "
          .. "you click Okay." },
    { key = "wideMerchant", cmd = "wide", label = "Wider vendor",
      help = "show 20 items a page at vendors (after a /reload)",
      tip = "Vendors show 20 items a page in four columns instead of 10. The buyback tab "
          .. "keeps Blizzard's window. Switching takes a /reload." },
    { key = "restock", cmd = "restock", label = "Vendor restock",
      help = "buy your restock items when you open a vendor",
      tip = "Opening a vendor buys what's missing of the items you keep topped up. "
          .. "Alt-click an item at a vendor to add or remove it, or /qol restock <item> "
          .. "<n>. Hold Shift to skip." },
    { key = "bankRestock", cmd = "bank", label = "Restock from bank",
      help = "take your restock items from the bank when you open it",
      tip = "Opening your bank moves what's missing of the items you keep topped up into "
          .. "your bags, before a vendor has to sell them to you. Your character bank only, "
          .. "never the warband bank. Hold Shift to skip." },
    { key = "lowWarn", cmd = "low", label = "Warn when low",
      help = "warn when a restock item is down to a quarter",
      tip = "When an item you keep topped up drops to a quarter of its amount (5 of 20 "
          .. "water, 50 of 200 arrows), a message on screen and a chat line say so, once "
          .. "until you have more again. At login, one line lists what is already low." },
    { key = "fastLoot", cmd = "loot", label = "Faster auto loot", section = "Looting",
      sectionTip = "Auto loot without waiting on the loot window or its prompts.",
      help = "take all loot at once, without the loot window",
      tip = "Auto loot takes every item the moment the loot is ready and skips Blizzard's "
          .. "loot window. The window still shows when something is left: bags full, a "
          .. "roll or a bind prompt. Hold your auto loot key to loot by hand." },
    { key = "lootConfirm", cmd = "confirm", label = "Skip bind prompts",
      help = "confirm the bind-on-pickup prompt when you loot or roll",
      tip = "Looting a bind-on-pickup item, or rolling Need or Greed on one, answers "
          .. "Blizzard's \"are you sure\" box for you, so the item binds to you without a "
          .. "click. Off until you turn it on." },
    { key = "res", cmd = "res", label = "Accept res",
      section = "Resurrection and summons",
      sectionTip = "Accept a resurrection or summon without clicking.",
      help = "accept a resurrection once the caster is out of combat",
      tip = "A resurrection from a group member is accepted as soon as they are out of "
          .. "combat, with one chat line saying who. Never a soulstone or spirit healer; "
          .. "from someone outside your group the popup waits for you." },
    { key = "summon", cmd = "summon", label = "Accept summons",
      help = "accept a summon 5 seconds after you are out of combat",
      tip = "A summon (warlock ritual or meeting stone) is accepted 5 seconds after you are "
          .. "out of combat, with a chat line saying who and where. Click Cancel on the "
          .. "pop-up meanwhile to stay." },
    { key = "inviteInfo", cmd = "inviter", label = "Show inviter info",
      section = "Group invites",
      sectionTip = "See who is inviting before you join, or turn down invites you didn't "
          .. "ask for.",
      help = "show the inviter's level, class and zone on a group invite",
      tip = "A group invite shows the inviter's level, class and zone under their name, as "
          .. "far as the game tells: level and zone are only known for friends, guild "
          .. "members, someone nearby or in your last /who; otherwise race and class." },
    { key = "inviteDecline", cmd = "invites", label = "Decline invites",
      help = "decline group invites you didn't ask for",
      tip = "Group invites are declined at once with a chat line saying whose, and the "
          .. "message below whispered to them if you set one. Never declined: group finder "
          .. "invites, while you are listed or queued, or from someone you whispered in the "
          .. "last 10 minutes." },
    { key = "inviteFriends", cmd = "friends", label = "Allow friends, guild",
      help = "let invites from friends and guild members through",
      tip = "Invites from your friends (Battle.net too) and guild members still show the "
          .. "pop-up when declining is on." },
    { key = "camera", cmd = "camera", label = "Farther camera",
      section = "Camera and sound",
      sectionTip = "Blizzard settings the options don't offer, put back as they were when "
          .. "you turn these off.",
      help = "zoom the camera out further and faster",
      tip = "Lets the camera zoom out further and faster as you scroll: Blizzard's camera "
          .. "distance and zoom speed, set to the values below. Your own come back when you "
          .. "turn it off." },
    { key = "fishSound", cmd = "fishsound", label = "Fishing sounds",
      help = "music and ambience down while fishing, so the splash is heard",
      tip = "From your first cast until you move, fight or stop casting for 30 seconds, "
          .. "music and ambience go down and sound effects up, so you hear the bobber "
          .. "splash. Your volumes come back after, at the next login if the game closed "
          .. "meanwhile." },
}
local byCmd = {}
for _, t in ipairs(ns.TOGGLES) do byCmd[t.cmd] = t end

function ns.State(key)
    local s = ns.db[key] and ns.ON or ns.OFF
    if ns.db[key] and ns.FlareOwns(key) then s = s .. ", waiting while FlareUI's is on" end
    return s
end

function ns.CameraState()
    return ("%.1f, %d"):format(ns.db.cameraZoom, ns.db.cameraSpeed)
end

local function Section(title)
    DEFAULT_CHAT_FRAME:AddMessage("|cff999999" .. title .. "|r")
end

function ns.Help()
    ns.Say("small automations at NPCs and vendors, when you loot or die, for summons and "
        .. "group invites (hold Shift at an NPC to skip them)")
    local function Add(cmd, text) DEFAULT_CHAT_FRAME:AddMessage("  " .. ns.Cmd(cmd) .. " - " .. text) end
    for _, t in ipairs(ns.TOGGLES) do
        if t.section then Section(t.section) end
        if t.key == "restock" then
            Add("/qol restock <item> <n>", "keep n of an item, 0 to stop (or Alt-click it "
                .. "at a vendor)")
            Add("/qol restock", "list the items kept topped up")
        end
        Add("/qol " .. t.cmd .. " on||off", t.help .. " (now " .. ns.State(t.key) .. ")")
        if t.key == "lowWarn" then
            Add("/qol reserve <gold>", "restocking never takes your gold below this (now "
                .. ns.Money(ns.db.reserve * 10000) .. ")")
        elseif t.key == "inviteDecline" then
            Add("/qol invitereason <text>", "whisper this to whoever you decline, nothing "
                .. "for no whisper (now " .. ns.InviteReasonState() .. ")")
        elseif t.key == "camera" then
            Add("/qol camera <distance> <speed>", "how far (1 to 2.6) and how fast (5 to 50) "
                .. "(now " .. ns.CameraState() .. ")")
        end
    end
    Section("FlareUI")
    Add("/qol takeover", "turn off FlareUI's copies of the ones above that are on here, so "
        .. "ours do the job")
    Add("/qol flare", "give those back to FlareUI")
    DEFAULT_CHAT_FRAME:AddMessage("  Settings: Esc > Options > AddOns > MeioQoL ("
        .. ns.Cmd("/qol settings") .. ")")
end

-- after a toggle changed, from chat or the Settings panel
function ns.Changed(key)
    RunApply(key)
end

function ns.SetToggle(t, on)
    ns.db[t.key] = on
    local line = t.label:sub(1, 1):lower() .. t.label:sub(2) .. " " .. ns.State(t.key)
    if on and ns.FlareOwns(t.key) then
        line = line .. " (" .. ns.Cmd("/qol takeover") .. ")"
    elseif ns.FLARE[t.key] and ns.FLARE[t.key].reload then
        line = line .. " after a " .. ns.Cmd("/reload")
    end
    ns.Say(line)
    ns.Changed(t.key)
end

local function CameraCommand(rest)
    local zoom, speed = rest:match("^([%d.]+)%s+(%d+)$")
    zoom, speed = tonumber(zoom), tonumber(speed)
    if not (zoom and speed and zoom >= 1 and zoom <= 2.6 and speed >= 5 and speed <= 50) then
        return false
    end
    ns.db.cameraZoom, ns.db.cameraSpeed = zoom, math.floor(speed)
    ns.Say("camera distance and speed " .. ns.CameraState())
    ns.Changed("camera")
    return true
end

-- what is on here and also on in FlareUI, in help order
local function Waiting()
    local list = {}
    for _, key in ipairs(ns.FLARE_ORDER) do
        if ns.db[key] and ns.FlareOwns(key) then list[#list + 1] = key end
    end
    return list
end

local function Names(keys)
    local names = {}
    for _, key in ipairs(keys) do names[#names + 1] = ns.FLARE[key].what end
    if #names < 2 then return names[1] or "" end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function RefreshFlare()
    local f = _G.FlareUI
    if f and f.Tweaks and f.Tweaks.Refresh then pcall(f.Tweaks.Refresh, f.Tweaks) end
end

local function NeedsReload(keys)
    for _, key in ipairs(keys) do
        if ns.FLARE[key].reload then return true end
    end
    return false
end

function ns.TakeOver()
    local t = ns.FlareTweaks()
    if not t then ns.Say("FlareUI isn't loaded: nothing to take over") return end
    local keys = Waiting()
    if #keys == 0 then
        ns.Say("nothing to take over: none of FlareUI's matching tweaks is on where ours is")
        return
    end
    ns.db.tookOver = ns.db.tookOver or {}
    for _, key in ipairs(keys) do
        local f = ns.FLARE[key]
        ns.db.tookOver[key] = { t[f.key], f.also and t[f.also] or nil }
        t[f.key] = false
        if f.also then t[f.also] = false end
    end
    -- FlareUI puts back what it changed (camera, volumes) before ours sets them
    RefreshFlare()
    for _, key in ipairs(keys) do RunApply(key) end
    ns.Say("took over FlareUI's " .. Names(keys) .. (NeedsReload(keys) and (": "
        .. ns.Cmd("/reload") .. " to finish") or "") .. " (" .. ns.Cmd("/qol flare")
        .. " gives them back)")
end

function ns.GiveBack()
    local t, saved = ns.FlareTweaks(), ns.db.tookOver
    if not t then ns.Say("FlareUI isn't loaded: nothing to give back") return end
    local keys = {}
    for _, key in ipairs(ns.FLARE_ORDER) do
        if saved and saved[key] then keys[#keys + 1] = key end
    end
    if #keys == 0 then ns.Say("nothing to give back: /qol takeover wasn't used") return end
    for _, key in ipairs(keys) do
        local f = ns.FLARE[key]
        t[f.key] = saved[key][1]
        if f.also then t[f.also] = saved[key][2] end
        saved[key] = nil
    end
    -- ours put back what they changed first, then FlareUI sets its own
    for _, key in ipairs(keys) do RunApply(key) end
    RefreshFlare()
    ns.Say("gave FlareUI's " .. Names(keys) .. " back" .. (NeedsReload(keys) and (": "
        .. ns.Cmd("/reload") .. " to finish") or ""))
end

-- Before the feature files' own PLAYER_LOGIN (registered first): a FlareUI tweak that is on
-- turns ours on, once per feature, so dropping FlareUI later keeps what the player chose.
ns.On("PLAYER_LOGIN", function()
    local t = ns.FlareTweaks()
    if not t then return end
    ns.db.fromFlare = ns.db.fromFlare or {}
    for _, key in ipairs(ns.FLARE_ORDER) do
        if not ns.db.fromFlare[key] then
            ns.db.fromFlare[key] = true
            if ns.FlareOwns(key) then
                ns.db[key] = true
                if key == "camera" then
                    ns.db.cameraZoom = tonumber(t.cameraMaxZoom) or ns.db.cameraZoom
                    ns.db.cameraSpeed = tonumber(t.cameraZoomSpeed) or ns.db.cameraSpeed
                end
            end
        end
    end
    -- the one login line: both copies on, and only the player can pick
    local keys = Waiting()
    if #keys > 0 then
        ns.Say("FlareUI's " .. Names(keys) .. (#keys == 1 and " is" or " are") .. " on, so "
            .. "ours wait: " .. ns.Cmd("/qol takeover") .. " swaps them")
    end
end)

local function OpenSettings()
    if not (ns.OpenSettings and ns.OpenSettings()) then ns.Help() end
end

SLASH_MEIOQOL1 = "/qol"
SLASH_MEIOQOL2 = "/meioqol"
SlashCmdList.MEIOQOL = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    local word = rest:lower()
    local t = byCmd[cmd]
    if cmd == "" or cmd == "settings" or cmd == "options" then
        OpenSettings()
    elseif cmd == "help" or cmd == "?" then
        ns.Help()
    elseif t and (word == "on" or word == "off") then
        ns.SetToggle(t, word == "on")
    elseif cmd == "camera" and CameraCommand(word) then
        return
    elseif cmd == "takeover" then
        ns.TakeOver()
    elseif cmd == "flare" then
        ns.GiveBack()
    elseif cmd == "invitereason" then
        ns.SetInviteReason(rest)
    elseif cmd == "restock" then
        ns.RestockCommand(rest)
    elseif cmd == "reserve" and tonumber(word) and tonumber(word) >= 0 then
        ns.db.reserve = math.floor(tonumber(word))
        ns.Say("restock gold reserve " .. ns.Money(ns.db.reserve * 10000))
    elseif t or cmd == "reserve" then
        local need = cmd == "reserve" and "an amount of gold"
            or cmd == "camera" and "on, off or a distance (1 to 2.6) and speed (5 to 50)"
            or "on or off"
        ns.Say(("\"%s\" needs %s"):format(cmd, need))
        ns.Help()
    else
        ns.Say(("unknown command \"%s\""):format(cmd))
        ns.Help()
    end
end

function MeioQoL_OnAddonCompartmentClick()
    OpenSettings()
end
