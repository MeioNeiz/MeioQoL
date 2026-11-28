-- Warns when an item on the restock list runs low: at a quarter of its amount, once per
-- drop, so a hunter sees the ammo going before the vendor is out of reach. Items only warn
-- on the way down; one just added or bought low is noted silently.
local _, ns = ...

local LOGIN_DELAY = 5

local low = {} -- itemID -> true/false once seen; nil = not seen yet
local ready = false

local function Threshold(want)
    return math.max(1, math.floor(want / 4))
end

local function Warn(id, have)
    local text = ("Running low: %d %s left"):format(have, ns.ItemLink(id))
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) end
    ns.Say(("running low on %s: %d left of %d"):format(ns.ItemLink(id), have,
        ns.char.restock[id]))
end

local function Scan()
    if not ready or not ns.char then return end
    local quiet = not ns.db.lowWarn or (MerchantFrame and MerchantFrame:IsShown())
    for id in pairs(low) do
        if not ns.char.restock[id] then low[id] = nil end
    end
    for id, want in pairs(ns.char.restock) do
        local have = ns.Have(id)
        local isLow = have <= Threshold(want)
        if isLow and low[id] == false and not quiet then Warn(id, have) end
        low[id] = isLow
    end
end

ns.On("BAG_UPDATE_DELAYED", Scan)

-- one line for what is already low at login, then warnings from there
ns.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    if not (isLogin or isReload) then return end
    C_Timer.After(LOGIN_DELAY, function()
        ready = true
        local lines = {}
        for id, want in pairs(ns.char.restock) do
            local have = ns.Have(id)
            low[id] = have <= Threshold(want)
            if low[id] then lines[#lines + 1] = have .. " " .. ns.ItemLink(id) end
        end
        if ns.db.lowWarn and #lines > 0 then
            table.sort(lines)
            ns.Say("running low on " .. table.concat(lines, ", "))
        end
    end)
end)
