-- Small automations Leatrix Plus used to do and FlareUI doesn't: gossip skip, resurrection,
-- guild-funded repair, vendor restock, faster auto loot. Each feature file registers its own
-- events here.
local ADDON, ns = ...

local PREFIX = "|cffb090ffMeioQoL:|r "
ns.ON, ns.OFF = "|cff80ff80on|r", "|cffff8080off|r"

ns.DEFAULTS = {
    gossip = true, gossipServices = false, res = true, guildRepair = true,
    restock = true, reserve = 1, fastLoot = true,
}

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

-- slash toggles, in help order; Settings.lua builds its checkboxes from the same table
ns.TOGGLES = {
    { key = "gossip", cmd = "gossip", label = "Skip NPC chat",
      help = "pick an NPC's only chat option when it has no quests",
      tip = "Talking to an NPC with no quests and one chat option picks it for you. "
          .. "Vendors, trainers, bankers and innkeepers still show their menu (below). "
          .. "Hold Shift to talk normally." },
    { key = "gossipServices", cmd = "services", label = "Also for services",
      help = "also for vendors, trainers, bankers and innkeepers",
      tip = "Skip the chat to the window of an NPC whose only option is a service: "
          .. "vendor, trainer, banker, innkeeper, auctioneer. Flight masters are left to "
          .. "FlareUI's flight map tweak when it is on." },
    { key = "res", cmd = "res", label = "Accept resurrection",
      help = "accept a resurrection once the caster is out of combat",
      tip = "A resurrection from a group member is accepted as soon as they are out of "
          .. "combat, with one chat line saying who. Never a soulstone or spirit healer; "
          .. "from someone outside your group the popup waits for you." },
    { key = "guildRepair", cmd = "guildrepair", label = "Guild-funded repair",
      help = "repair from guild funds before your own gold",
      tip = "At a vendor that repairs, pay from the guild bank when your rank may and the "
          .. "guild has enough. Otherwise FlareUI's auto repair (or you) pays as before. "
          .. "Hold Shift to skip." },
    { key = "restock", cmd = "restock", label = "Restock at vendors",
      help = "buy your restock items when you open a vendor",
      tip = "Opening a vendor buys what's missing of the items you keep topped up. "
          .. "Alt-click an item at a vendor to add or remove it, or /qol restock <item> "
          .. "<n>. Hold Shift to skip." },
    { key = "fastLoot", cmd = "loot", label = "Faster auto loot",
      help = "take all loot at once, without the loot window",
      tip = "Auto loot takes every item the moment the loot is ready and skips Blizzard's "
          .. "loot window. The window still shows when something is left: bags full, a "
          .. "roll or a bind prompt. Hold your auto loot key to loot by hand. Turn off "
          .. "FlareUI's Faster Auto Loot so the two don't both loot." },
}
local byCmd = {}
for _, t in ipairs(ns.TOGGLES) do byCmd[t.cmd] = t end

local function State(on)
    return on and ns.ON or ns.OFF
end

function ns.Help()
    ns.Say("small automations at NPCs and when you die")
    local lines = {}
    local function Add(cmd, text) lines[#lines + 1] = ns.Cmd(cmd) .. " - " .. text end
    for _, t in ipairs(ns.TOGGLES) do
        if t.key == "restock" then
            Add("/qol restock <item> <n>", "keep n of an item, 0 to stop (or Alt-click it "
                .. "at a vendor)")
            Add("/qol restock", "list the items kept topped up")
        end
        Add("/qol " .. t.cmd .. " on||off", t.help .. " (now " .. State(ns.db[t.key]) .. ")")
    end
    Add("/qol reserve <gold>", "restocking never takes your gold below this (now "
        .. ns.Money(ns.db.reserve * 10000) .. ")")
    lines[#lines + 1] = "|cff999999Hold Shift at an NPC to skip the chat skip, repair and "
        .. "restock|r"
    lines[#lines + 1] = "Settings: Esc > Options > AddOns > MeioQoL ("
        .. ns.Cmd("/qol settings") .. ")"
    for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
end

function ns.SetToggle(t, on)
    ns.db[t.key] = on
    ns.Say(t.label:sub(1, 1):lower() .. t.label:sub(2) .. " " .. State(on))
end

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
    elseif cmd == "restock" then
        ns.RestockCommand(rest)
    elseif cmd == "reserve" and tonumber(word) and tonumber(word) >= 0 then
        ns.db.reserve = math.floor(tonumber(word))
        ns.Say("restock gold reserve " .. ns.Money(ns.db.reserve * 10000))
    elseif t or cmd == "reserve" then
        ns.Say(("\"%s\" needs %s"):format(cmd, cmd == "reserve" and "an amount of gold"
            or "on or off"))
        ns.Help()
    else
        ns.Say(("unknown command \"%s\""):format(cmd))
        ns.Help()
    end
end

function MeioQoL_OnAddonCompartmentClick()
    OpenSettings()
end
