-- Picks an NPC's only chat option when there are no quests. Blizzard's gossip frame already
-- does this for options flagged selectOptionWhenOnlyOption; this covers the rest.
local _, ns = ...

-- option icons, Interface\GossipFrame\*GossipIcon
local TAXI = 132057
-- the NPC's job: picked only with gossipServices on
local SERVICE = {
    [132060] = true, -- vendor
    [132058] = true, -- trainer
    [132059] = true, -- unlearn (talent reset)
    [132050] = true, -- banker
    [132052] = true, -- binder (innkeeper)
    [4955460] = true, -- innkeeper
    [528409] = true, -- auctioneer
    [TAXI] = true,
}
-- never picked: they cost money, queue you or resurrect you with sickness
local NEVER = {
    [132054] = true, -- spirit healer
    [132051] = true, -- battlemaster
    [132055] = true, -- guild charter
    [132056] = true, -- guild tabard
}

-- option picked per NPC, with the time: a chain that loops back to the same option stops
-- there instead of clicking forever
local picked = {}
local REPEAT_AFTER = 10

local function FlareTaxi()
    local t = ns.FlareTweaks()
    return t and t.taxiMap
end

local function Pick()
    if not ns.db.gossip or IsShiftKeyDown() then return end
    local G = C_GossipInfo
    if G.GetNumAvailableQuests() > 0 or G.GetNumActiveQuests() > 0 then return end
    if G.ForceGossip and G.ForceGossip() then return end
    local options = G.GetOptions() or {}
    local o = options[1]
    if #options ~= 1 or o.selectOptionWhenOnlyOption then return end
    local available = Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available or 0
    if (o.status and o.status ~= available) or o.failureDescription then return end
    if o.rewards and #o.rewards > 0 then return end
    local icon = o.overrideIconID or o.icon
    if NEVER[icon] or (icon == TAXI and FlareTaxi()) then return end
    if SERVICE[icon] and not ns.db.gossipServices then return end

    local key = (UnitGUID("npc") or "?") .. ":" .. (o.gossipOptionID or o.orderIndex or 0)
    local now = GetTime()
    if picked[key] and now - picked[key] < REPEAT_AFTER then return end
    picked[key] = now
    if o.gossipOptionID then
        G.SelectOption(o.gossipOptionID)
    else
        G.SelectOptionByIndex(o.orderIndex)
    end
end

ns.On("GOSSIP_SHOW", Pick)
