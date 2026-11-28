-- Picks an NPC's only chat option when there are no quests. Blizzard's gossip frame already
-- does this for options flagged selectOptionWhenOnlyOption; this covers the rest. A flight
-- master with no quests opens its map even beside other options.
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

local function Icon(o)
    return o.overrideIconID or o.icon
end

local function Available(o)
    local available = Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available or 0
    return not (o.status and o.status ~= available) and not o.failureDescription
end

local function Select(o)
    local npc = UnitGUID("npc")
    if npc and canaccessvalue and not canaccessvalue(npc) then npc = nil end
    local key = (npc or "?") .. ":" .. (o.gossipOptionID or o.orderIndex or 0)
    local now = GetTime()
    if picked[key] and now - picked[key] < REPEAT_AFTER then return end
    picked[key] = now
    if o.gossipOptionID then
        C_GossipInfo.SelectOption(o.gossipOptionID)
    else
        C_GossipInfo.SelectOptionByIndex(o.orderIndex)
    end
end

local function Pick()
    if IsShiftKeyDown() then return end
    local G = C_GossipInfo
    if G.GetNumAvailableQuests() > 0 or G.GetNumActiveQuests() > 0 then return end
    if G.ForceGossip and G.ForceGossip() then return end
    local options = G.GetOptions() or {}
    if ns.Active("taxi") then
        for _, o in ipairs(options) do
            if Icon(o) == TAXI and Available(o) then return Select(o) end
        end
    end
    if not ns.db.gossip then return end
    local o = options[1]
    if #options ~= 1 or o.selectOptionWhenOnlyOption or not Available(o) then return end
    if o.rewards and #o.rewards > 0 then return end
    local icon = Icon(o)
    -- a flight master is left to the flight map switch (ours or FlareUI's)
    if NEVER[icon] or icon == TAXI then return end
    if SERVICE[icon] and not ns.db.gossipServices then return end
    Select(o)
end

ns.On("GOSSIP_SHOW", Pick)
