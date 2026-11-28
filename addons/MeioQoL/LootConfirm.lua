-- Answers Blizzard's bind-on-pickup prompts for loot and rolls (lootConfirm), a frame after
-- the event so the dialog is up to be closed.
local _, ns = ...

ns.On("LOOT_BIND_CONFIRM", function(slot)
    if not ns.Active("lootConfirm") then return end
    C_Timer.After(0, function()
        ConfirmLootSlot(slot)
        StaticPopup_Hide("LOOT_BIND")
    end)
end)

local function Roll(rollID, rollType)
    if not ns.Active("lootConfirm") then return end
    C_Timer.After(0, function()
        ConfirmLootRoll(rollID, rollType)
        StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    end)
end
ns.On("CONFIRM_LOOT_ROLL", Roll)
-- a Disenchant roll asks in the same dialog, where the client has it
pcall(ns.On, "CONFIRM_DISENCHANT_ROLL", Roll)
