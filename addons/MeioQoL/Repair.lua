-- Repairs from guild funds when the rank may and the guild can pay the whole bill; anything
-- else is left to FlareUI's own-gold auto repair (or the player).
-- Order: our MERCHANT_SHOW is registered at file load, FlareUI's at PLAYER_LOGIN, so ours runs
-- first. If something did repair before us this visit, we stay out of it.
local _, ns = ...

local tried, repairedThisVisit

hooksecurefunc("RepairAllItems", function() repairedThisVisit = true end)

-- what this character may take from the guild bank for repairs
local function GuildFunds()
    local allowed, bank = GetGuildBankWithdrawMoney(), GetGuildBankMoney()
    if allowed == -1 then return bank end -- guild leader
    return math.min(allowed or 0, bank or 0)
end

-- FlareUI's repair runs on the same MERCHANT_SHOW and still reads the old cost (durability
-- comes back from the server later), so it would pay nothing yet print a second repair. Its
-- autoRepair is held off for this one event and put back on the next frame.
local function HoldFlareRepair()
    local t = ns.FlareTweaks()
    if not (t and t.autoRepair) then return end
    t.autoRepair = false
    C_Timer.After(0, function() t.autoRepair = true end)
end

local function GuildRepair()
    if tried then return end
    tried = true
    if not ns.db.guildRepair or IsShiftKeyDown() or repairedThisVisit then return end
    if not (CanMerchantRepair() and CanGuildBankRepair and CanGuildBankRepair()) then
        return
    end
    local cost, canRepair = GetRepairAllCost()
    if not (canRepair and cost and cost > 0) or GuildFunds() < cost then return end
    RepairAllItems(true)
    ns.guildPaidRepair = true
    HoldFlareRepair()
    ns.Say("repaired from guild funds for " .. ns.Money(cost))
end

ns.On("MERCHANT_SHOW", GuildRepair)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.Merchant then
        GuildRepair()
    end
end)
ns.On("MERCHANT_CLOSED", function()
    tried, repairedThisVisit, ns.guildPaidRepair = nil, nil, nil
end)
