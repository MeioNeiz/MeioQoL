-- Repair at vendors: guild funds first when the rank may and the guild can pay the whole bill,
-- then (Auto repair on) your own gold. While FlareUI's auto repair is on it pays the own-gold
-- part. Order: our MERCHANT_SHOW is registered at file load, FlareUI's at PLAYER_LOGIN, so ours
-- runs first. If something did repair before us this visit, we stay out of it.
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

local function GuildPays(cost)
    if not ns.db.guildRepair or not (CanGuildBankRepair and CanGuildBankRepair()) then
        return false
    end
    if GuildFunds() < cost then return false end
    RepairAllItems(true)
    ns.guildPaidRepair = true
    HoldFlareRepair()
    ns.Say("repaired from guild funds for " .. ns.Money(cost))
    return true
end

local function Repair()
    if tried then return end
    tried = true
    if IsShiftKeyDown() or repairedThisVisit or not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not (canRepair and cost and cost > 0) then return end
    if GuildPays(cost) or not ns.Active("repair") then return end
    if GetMoney() < cost then
        ns.Say("not enough gold to repair (" .. ns.Money(cost) .. ")")
        return
    end
    RepairAllItems()
    ns.Say("repaired for " .. ns.Money(cost))
end

ns.On("MERCHANT_SHOW", Repair)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.Merchant then
        Repair()
    end
end)
ns.On("MERCHANT_CLOSED", function()
    tried, repairedThisVisit, ns.guildPaidRepair = nil, nil, nil
end)
