-- Opening the bank tops up restock items from it into your bags, so the vendor is only for
-- what the bank lacks. One move at a time: each locks its slots until the server answers,
-- and counts are read again before the next. Character bank only, never the warband bank.
local _, ns = ...

local STEP = 0.3
local MAX_STEPS = 40
local MAX_TRIES = 3 -- per item, in case the server refuses a move

local ticker, steps, start, tries
local bankOpen = false

local function BankBags()
    local bags = { BANK_CONTAINER or -1 }
    local first = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
    if first then
        for i = 0, 5 do bags[#bags + 1] = first + i end
    end
    return bags
end

local function Info(bag, slot)
    return C_Container.GetContainerItemInfo(bag, slot)
end

-- an unlocked bank stack of the item, smallest first so whole stacks move when they can
local function FindInBank(id)
    local best, bestBag, bestSlot
    for _, bag in ipairs(BankBags()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = Info(bag, slot)
            if info and info.itemID == id and not info.isLocked
                and (not best or info.stackCount < best.stackCount) then
                best, bestBag, bestSlot = info, bag, slot
            end
        end
    end
    return best, bestBag, bestSlot
end

-- a bag slot to drop n of the item on: a stack of it with room, else an empty plain slot
local function Target(id, n)
    local maxStack = select(8, C_Item.GetItemInfo(id)) or 1
    local empty
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = Info(bag, slot)
            if info then
                if info.itemID == id and not info.isLocked and info.stackCount + n <= maxStack then
                    return bag, slot
                end
            elseif not empty and family == 0 then
                empty = { bag, slot }
            end
        end
    end
    if empty then return empty[1], empty[2] end
end

local function Busy()
    local bags = BankBags()
    for bag = 0, NUM_BAG_SLOTS or 4 do bags[#bags + 1] = bag end
    for _, bag in ipairs(bags) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = Info(bag, slot)
            if info and info.isLocked then return true end
        end
    end
    return false
end

local function Finish(why)
    if ticker then ticker:Cancel() ticker = nil end
    local parts = {}
    for id, had in pairs(start or {}) do
        local n = ns.Have(id) - had
        if n > 0 then parts[#parts + 1] = n .. " " .. ns.ItemLink(id) end
    end
    start, tries = nil, nil
    if #parts > 0 then
        table.sort(parts)
        ns.Say("took " .. table.concat(parts, ", ") .. " from the bank"
            .. (why and ("; " .. why) or ""))
    elseif why then
        ns.Say("bank restock: " .. why)
    end
end

-- one move; true when there is nothing left to do
local function Step()
    for id, want in pairs(ns.char.restock) do
        local need = want - ns.Have(id)
        local info, bag, slot
        if need > 0 and (tries[id] or 0) < MAX_TRIES then info, bag, slot = FindInBank(id) end
        if info then
            local n = math.min(need, info.stackCount)
            local toBag, toSlot = Target(id, n)
            if not toBag then
                Finish("bags full")
                return true
            end
            start[id] = start[id] or ns.Have(id)
            tries[id] = (tries[id] or 0) + 1
            if n == info.stackCount then
                C_Container.PickupContainerItem(bag, slot)
            else
                C_Container.SplitContainerItem(bag, slot, n)
            end
            C_Container.PickupContainerItem(toBag, toSlot)
            if CursorHasItem() then ClearCursor() end
            return false
        end
    end
    return true
end

local function Tick()
    steps = steps + 1
    if not bankOpen or steps > MAX_STEPS then return Finish() end
    -- a move still on its way to the server: wait rather than move it twice
    if Busy() then return end
    if Step() and ticker then Finish() end
end

ns.On("BANKFRAME_OPENED", function()
    bankOpen = true
    if not ns.db.bankRestock or IsShiftKeyDown() or not next(ns.char.restock) then return end
    if CursorHasItem() then return end
    if ticker then ticker:Cancel() end
    steps, start, tries = 0, {}, {}
    if Step() then return Finish() end
    ticker = C_Timer.NewTicker(STEP, Tick)
end)

ns.On("BANKFRAME_CLOSED", function()
    bankOpen = false
    if ticker then Finish() end
end)
