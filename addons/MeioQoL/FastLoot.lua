-- Faster auto loot: every slot is taken the moment the loot is ready, and Blizzard's loot window
-- never opens for it (its fade in, slide-out rows and fade out are most of the wait). The window
-- comes up as usual when something stays behind: bags full, a roll, a bind prompt.
-- How: LOOT_READY fires before LOOT_OPENED, so for an auto loot LootFrame stops listening to
-- LOOT_OPENED and never opens. It listens again on LOOT_CLOSED, on the reveal timer and on every
-- loot that isn't auto, so a missed close can't cost the window for long.
local _, ns = ...

-- loot still open this long after taking everything: something can't be taken, show it
local REVEAL_AFTER = 1
-- a LOOT_READY this long after the window's first is a new window whose close we missed
local NEW_WINDOW_AFTER = 3
local FULL_ERRORS = { "ERR_INV_FULL", "ERR_BAG_FULL", "ERR_LOOT_NO_SPACE", "ERR_ITEM_MAX_COUNT" }

local full = {}
for _, key in ipairs(FULL_ERRORS) do
    if _G[key] then full[_G[key]] = true end
end

-- the loot window as we see it: open, hidden by us, its slots already asked for
local open, hidden, fromItem, readyAt, asked = false, false, nil, nil, {}
local window = 0

local function Listen()
    if LootFrame and not LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:RegisterEvent("LOOT_OPENED")
    end
end

local function Reveal()
    if not hidden then return end
    hidden = false
    Listen()
    if open and GetNumLootItems() > 0 and LootFrame.OnEvent then
        LootFrame:OnEvent("LOOT_OPENED", false, fromItem)
    end
end

local function IsAuto(autoLoot)
    if autoLoot ~= nil then return autoLoot end
    return GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
end

local function TakeAll()
    for slot = GetNumLootItems(), 1, -1 do
        local locked = select(6, GetLootSlotInfo(slot))
        if not asked[slot] and not locked then
            asked[slot] = true
            LootSlot(slot)
        end
    end
end

ns.On("LOOT_READY", function(autoLoot)
    if not (open and readyAt and GetTime() - readyAt < NEW_WINDOW_AFTER) then
        Reveal()
        window, readyAt, asked, fromItem = window + 1, GetTime(), {}, nil
    end
    open = true
    if not (ns.db.fastLoot and IsAuto(autoLoot)) then
        Listen()
        return
    end
    if not hidden and LootFrame and not LootFrame:IsShown() then
        hidden = true
        LootFrame:UnregisterEvent("LOOT_OPENED")
        local this = window
        C_Timer.After(REVEAL_AFTER, function()
            if window == this then Reveal() end
        end)
    end
    TakeAll()
end)

-- also a second chance for slots that weren't filled in yet at LOOT_READY
ns.On("LOOT_OPENED", function(_, isFromItem)
    fromItem = isFromItem
    if hidden then TakeAll() end
end)

ns.On("UI_ERROR_MESSAGE", function(_, message)
    if hidden and full[message] then Reveal() end
end)

ns.On("LOOT_CLOSED", function()
    open, hidden, readyAt, asked = false, false, nil, {}
    Listen()
end)
