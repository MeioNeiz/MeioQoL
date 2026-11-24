-- Keeps chosen items topped up: opening a vendor that sells one buys the difference, never
-- spending below the gold reserve. The list is per character (MeioQoLCharDB.restock).
-- Alt-click, not Shift: Shift-click on a merchant item is Blizzard's (and FlareUI's) buy box.
local _, ns = ...

local function Link(itemID)
    local _, link = C_Item.GetItemInfo(itemID)
    return link or ("item " .. itemID)
end

local function StackSize(itemID)
    local stack = select(8, C_Item.GetItemInfo(itemID))
    return stack and stack > 0 and stack or 20
end

local function Have(itemID)
    return C_Item.GetItemCount(itemID, false) or 0
end

local function Buy()
    if not ns.db.restock or IsShiftKeyDown() then return end
    local list = ns.char.restock
    if not next(list) then return end
    local budget = GetMoney() - ns.db.reserve * 10000
    if CanMerchantRepair() and not ns.guildPaidRepair then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost then budget = budget - cost end
    end

    local bought, short, spent = {}, {}, 0
    local got = {} -- per item: a vendor may list one item twice, bags update later
    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID(i)
        local info = id and list[id] and C_MerchantFrame.GetItemInfo(i)
        local need = info and list[id] - Have(id) - (got[id] or 0) or 0
        if need > 0 and not info.hasExtendedCost and info.isPurchasable ~= false then
            local lot = math.max(1, info.stackCount or 1)
            local price = info.price or 0
            local n = math.ceil(need / lot) * lot
            if info.numAvailable and info.numAvailable >= 0 then
                n = math.min(n, info.numAvailable * lot)
            end
            if price > 0 then
                local afford = math.max(0, math.floor(budget / price)) * lot
                if afford < n then
                    short[#short + 1] = Link(id)
                    n = afford
                end
            end
            -- one purchase takes at most a stack, in whole lots
            local maxStack = GetMerchantItemMaxStack(i) or lot
            local perBuy = math.max(lot, math.floor(maxStack / lot) * lot)
            local left = n
            while left > 0 do
                local q = math.min(left, perBuy)
                BuyMerchantItem(i, q)
                left = left - q
            end
            if n > 0 then
                local cost = n / lot * price
                budget, spent = budget - cost, spent + cost
                bought[#bought + 1] = n .. " " .. Link(id)
                got[id] = (got[id] or 0) + n
            end
        end
    end

    if #bought == 0 and #short == 0 then return end
    local line = #bought > 0 and ("restocked " .. table.concat(bought, ", ") .. " for "
        .. ns.Money(spent)) or "restock"
    if #short > 0 then
        line = line .. (#bought > 0 and "; " or ": ") .. "not enough gold above your "
            .. ns.Money(ns.db.reserve * 10000) .. " reserve for " .. table.concat(short, ", ")
    end
    ns.Say(line)
end

ns.On("MERCHANT_SHOW", Buy)

local function SetCount(itemID, n)
    if n > 0 then
        ns.char.restock[itemID] = n
        ns.Say(("keeping %d %s topped up at vendors"):format(n, Link(itemID)))
    elseif ns.char.restock[itemID] then
        ns.char.restock[itemID] = nil
        ns.Say("no longer restocking " .. Link(itemID))
    else
        ns.Say(Link(itemID) .. " isn't on your restock list")
    end
end

function ns.RestockList()
    local ids = {}
    for id in pairs(ns.char.restock) do ids[#ids + 1] = id end
    if #ids == 0 then
        ns.Say("no restock items yet: Alt-click an item at a vendor, or "
            .. ns.Cmd("/qol restock <item> <n>"))
        return
    end
    table.sort(ids)
    ns.Say("items kept topped up at vendors (" .. (ns.db.restock and ns.ON or ns.OFF) .. ")")
    for _, id in ipairs(ids) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %d %s |cff999999(have %d)|r"):format(
            ns.char.restock[id], Link(id), Have(id)))
    end
end

-- item link, item ID, or the name of an item on the list, at this vendor or in the cache
local function Resolve(text)
    local id = tonumber(text:match("item:(%d+)") or text:match("^%d+$") or "")
    if id then return id end
    local lower = text:lower()
    for listed in pairs(ns.char.restock) do
        local name = C_Item.GetItemInfo(listed)
        if name and name:lower() == lower then return listed end
    end
    for i = 1, GetMerchantNumItems() do
        local info = C_MerchantFrame.GetItemInfo(i)
        if info and info.name and info.name:lower() == lower then
            return GetMerchantItemID(i)
        end
    end
    return (C_Item.GetItemInfoInstant(text))
end

function ns.RestockCommand(rest)
    if rest == "" then return ns.RestockList() end
    local itemText, n = rest:match("^(.-)%s+(%d+)%s*$")
    local id = itemText and Resolve(strtrim(itemText))
    if not n then
        ns.Say("usage: " .. ns.Cmd("/qol restock <item> <n>")
            .. " (item link, name or ID; 0 stops)")
    elseif not id then
        ns.Say(("no item called \"%s\": shift-click it into chat for a link"):format(itemText))
    else
        SetCount(id, tonumber(n))
    end
end

local function MerchantAltClick(button)
    if not (IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then return end
    if not MerchantFrame or MerchantFrame.selectedTab ~= 1 then return end
    local id = GetMerchantItemID(button:GetID())
    if not id then return end
    SetCount(id, ns.char.restock[id] and 0 or StackSize(id))
end

if MerchantItemButton_OnModifiedClick then
    hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantAltClick)
end

-- a line on vendor item tooltips for items on the list
if GameTooltip.SetMerchantItem then
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
        local id = GetMerchantItemID(index)
        local n = id and ns.char and ns.char.restock[id]
        if not n then return end
        tooltip:AddLine(("Restock: keeps %d |cff999999(Alt-click to stop)|r"):format(n),
            NORMAL_FONT_COLOR:GetRGB())
        tooltip:Show()
    end)
end
