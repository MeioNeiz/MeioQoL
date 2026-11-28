-- Vendor window: Shift-click buys many (bulkBuy) and 20 items a page (wideMerchant).
-- Buy many follows FlareUI's bulk buy, under its licence:
--
-- MIT License, Copyright (c) 2026 Malkkav
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this
-- software and associated documentation files (the "Software"), to deal in the Software
-- without restriction, including without limitation the rights to use, copy, modify, merge,
-- publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
-- to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
local _, ns = ...

local function GamepadUI()
    return C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
        or false
end

-- Buy many: Shift-click opens Blizzard's amount box with room for many stacks (or many of an
-- item that doesn't stack), up to what gold, stock and bag room allow. Okay buys one stack at
-- a time, each after the last reached the bags; an error, the vendor closing, the list moving
-- or 5 s without a delivery stops it. Items paid in items or currency keep Blizzard's box.
local Bulk = {}
ns.Bulk = Bulk
local DELIVERY_WAIT = 5

-- room for itemID: free slots of bags that take it, plus what its part stacks still hold
function Bulk.Room(itemID, stackSize)
    local family = C_Item.GetItemFamily(itemID) or 0
    local room = 0
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 and (not bagFamily or bagFamily == 0
            or bit.band(bagFamily, family) ~= 0) then
            room = room + free * stackSize
        end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and info.stackCount then
                room = room + math.max(0, stackSize - info.stackCount)
            end
        end
    end
    return room
end

function Bulk.Say(text, r, g, b, hideAfter)
    if not Bulk.line then
        Bulk.line = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        Bulk.line:SetPoint("BOTTOM", MerchantFrame, "TOP", 0, 4)
    end
    if Bulk.hideTimer then Bulk.hideTimer:Cancel() Bulk.hideTimer = nil end
    Bulk.line:SetText(text)
    Bulk.line:SetTextColor(r or 1, g or 0.82, b or 0)
    Bulk.line:Show()
    if hideAfter then
        Bulk.hideTimer = C_Timer.NewTimer(hideAfter, function() Bulk.line:Hide() end)
    end
end

function Bulk.Stop(early)
    if Bulk.timer then Bulk.timer:Cancel() Bulk.timer = nil end
    local q = Bulk.queue
    Bulk.queue = nil
    Bulk.events:UnregisterAllEvents()
    if q and early then
        Bulk.Say(("Stopped: %d of %d bought"):format(q.total - q.left - q.pending, q.total),
            1, 0.5, 0.5, 5)
    end
end

function Bulk.Next()
    local q = Bulk.queue
    if Bulk.timer then Bulk.timer:Cancel() Bulk.timer = nil end
    if not q then return end
    q.pending = 0
    if q.left <= 0 then
        Bulk.Say(("Bought %d"):format(q.total), 0.5, 1, 0.5, 3)
        Bulk.Stop()
        return
    end
    if not MerchantFrame:IsShown() or GetMerchantItemID(q.index) ~= q.itemID then
        return Bulk.Stop(true)
    end
    local amount = math.min(q.left, q.perBuy)
    Bulk.Say(("Buying %d of %d..."):format(q.total - q.left, q.total))
    q.left, q.pending = q.left - amount, amount
    BuyMerchantItem(q.index, amount)
    Bulk.timer = C_Timer.NewTimer(DELIVERY_WAIT, function() Bulk.Stop(true) end)
end

function Bulk.Start(index, total, perBuy)
    Bulk.Stop()
    Bulk.queue = { index = index, itemID = GetMerchantItemID(index), total = total,
        left = total, perBuy = perBuy, pending = 0 }
    Bulk.events:RegisterEvent("BAG_UPDATE_DELAYED")
    Bulk.events:RegisterEvent("UI_ERROR_MESSAGE")
    Bulk.events:RegisterEvent("MERCHANT_CLOSED")
    Bulk.Next()
end

-- an amount into Blizzard's box, as its arrows would
function Bulk.SetAmount(amount)
    local split = StackSplitFrame
    if not (split and split:IsShown() and split.owner == Bulk.owner) then return end
    amount = math.max(split.minSplit or 1, math.min(split.maxStack or amount, amount))
    split.split, split.typing = amount, 0
    if split.UpdateStackText then split:UpdateStackText()
    else split.StackSplitText:SetText(amount) end
    if split.LeftButton then split.LeftButton:SetEnabled(amount > (split.minSplit or 1)) end
    if split.RightButton then split.RightButton:SetEnabled(amount < (split.maxStack or amount)) end
end

function Bulk.Buttons(split)
    if not Bulk.stackButton then
        local function Make(text, onClick)
            local b = CreateFrame("Button", nil, split, "UIPanelButtonTemplate")
            b:SetSize(60, 22)
            b:SetText(text)
            b:SetScript("OnClick", onClick)
            return b
        end
        Bulk.stackButton = Make("Stack", function() Bulk.SetAmount(Bulk.owner.stack) end)
        Bulk.maxButton = Make("MAX", function() Bulk.SetAmount(Bulk.owner.cap) end)
        Bulk.stackButton:SetPoint("TOPRIGHT", split, "BOTTOM", -2, 2)
        Bulk.maxButton:SetPoint("TOPLEFT", split, "BOTTOM", 2, 2)
        split:HookScript("OnHide", function()
            Bulk.stackButton:Hide()
            Bulk.maxButton:Hide()
        end)
    end
    local many = Bulk.owner.cap > 1
    Bulk.stackButton:SetShown(many)
    Bulk.maxButton:SetShown(many)
end

function Bulk.OnModifiedClick(button)
    if not ns.Active("bulkBuy") or GamepadUI() then return end
    if MerchantFrame.selectedTab ~= 1 or not IsModifiedClick("SPLITSTACK") then return end
    local split = StackSplitFrame
    if not split then return end
    local index = button:GetID()
    local perBuy = GetMerchantItemMaxStack(index)
    -- Blizzard opened its box (an item that stacks) or nothing (one that doesn't); a chat link
    -- or dress-up leaves the box closed
    local opened = split:IsShown() and split.owner == button
    if not opened and not (perBuy == 1 and not split:IsShown()) then return end
    if button.extendedCost then return end
    if not opened and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
    local info = C_MerchantFrame.GetItemInfo(index)
    local itemID = GetMerchantItemID(index)
    if not (info and itemID and perBuy and perBuy > 0) or info.hasExtendedCost then return end
    local unit = math.max(1, info.stackCount or 1)
    local cap = math.huge
    if info.price and info.price > 0 then cap = math.floor(GetMoney() / (info.price / unit)) end
    if info.numAvailable and info.numAvailable >= 0 then
        cap = math.min(cap, info.numAvailable * unit)
    end
    local stackSize = C_Item.GetItemMaxStackSizeByID(itemID) or perBuy
    cap = math.min(cap, Bulk.Room(itemID, stackSize))
    cap = math.floor(cap / unit) * unit
    if cap < unit then return end
    local owner = Bulk.owner
    owner.index, owner.cap = index, cap
    owner.perBuy = math.max(unit, math.floor(perBuy / unit) * unit)
    owner.stack = math.min(cap, math.max(unit, math.floor(stackSize / unit) * unit))
    owner:ClearAllPoints()
    owner:SetAllPoints(button)
    split:OpenStackSplitFrame(cap, owner, "BOTTOMLEFT", "TOPLEFT", unit)
    Bulk.Buttons(split)
end

Bulk.events = CreateFrame("Frame")
Bulk.events:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then Bulk.Next() else Bulk.Stop(true) end
end)
-- the amount box answers this frame's SplitStack, so no Blizzard button changes
Bulk.owner = CreateFrame("Frame", nil, UIParent)
Bulk.owner.SplitStack = function(owner, amount)
    if amount and amount > 0 and owner.index then Bulk.Start(owner.index, amount, owner.perBuy) end
end
if MerchantItemButton_OnModifiedClick then
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(button)
        local ok, err = pcall(Bulk.OnModifiedClick, button)
        if not ok then geterrorhandler()(err) end
    end)
end

-- Wider vendor window: 20 items a page in four columns. The page size is set before the
-- merchant code first runs (login), items 13 to 20 come from Blizzard's own template, and the
-- buyback tab gets Blizzard's narrow window back. Switching takes a reload.
local NARROW, COLUMN, PER_PAGE = 336, 165, 20
local rightBorder

local function Layout(wide)
    local frame = MerchantFrame
    if wide then
        frame:SetWidth(NARROW + 2 * COLUMN)
        MerchantItem11:ClearAllPoints()
        MerchantItem11:SetPoint("TOPLEFT", MerchantItem2, "TOPRIGHT", 12, 0)
        for i = 11, PER_PAGE do
            local item = _G["MerchantItem" .. i]
            if i > 12 then
                item:ClearAllPoints()
                if i % 2 == 1 then
                    item:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 2)], "BOTTOMLEFT", 0, -8)
                else
                    item:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", 12, 0)
                end
            end
            item:Show()
        end
        MerchantNextPageButton:ClearAllPoints()
        MerchantNextPageButton:SetPoint("CENTER", frame, "BOTTOMRIGHT", -26, 96)
        if not rightBorder then
            rightBorder = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
            rightBorder:SetAtlas("UI-Merchant-BotFrame")
            rightBorder:SetSize(334, 61)
            rightBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 26)
        end
        rightBorder:Show()
    else
        frame:SetWidth(NARROW)
        MerchantItem11:ClearAllPoints()
        MerchantItem11:SetPoint("TOPLEFT", MerchantItem9, "BOTTOMLEFT", 0, -15)
        for i = 13, PER_PAGE do _G["MerchantItem" .. i]:Hide() end
        MerchantNextPageButton:ClearAllPoints()
        MerchantNextPageButton:SetPoint("CENTER", frame, "BOTTOMLEFT", 310, 96)
        if rightBorder then rightBorder:Hide() end
    end
end

ns.On("PLAYER_LOGIN", function()
    if not ns.Active("wideMerchant") or GamepadUI() then return end
    if not (MerchantFrame and MerchantFrame_UpdateMerchantInfo and _G.MerchantItem12) then return end
    ns.wideMerchantOn = true
    MERCHANT_ITEMS_PER_PAGE = PER_PAGE
    for i = 13, PER_PAGE do
        if not _G["MerchantItem" .. i] then
            CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate")
        end
    end
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() Layout(true) end)
    if MerchantFrame_UpdateBuybackInfo then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function() Layout(false) end)
    end
end)
