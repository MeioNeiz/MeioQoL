-- Accepts a summon (warlock ritual, meeting stone) a few seconds after you are free to
-- take it: out of combat and able to teleport, as Blizzard's Accept button needs. The
-- pop-up stays up meanwhile so Cancel still works. Scenario and starting-area summons are
-- left to you.
local _, ns = ...

local GRACE = 5
local CHECK_EVERY = 0.5

local ticker, readyAt, summoner

local function Stop()
    readyAt, summoner = nil, nil
    if ticker then ticker:Cancel() ticker = nil end
end

local function Free()
    return not UnitAffectingCombat("player") and PlayerCanTeleport()
end

-- true when finished (accepted, cancelled, expired or switched off)
local function Try()
    if not ns.db.summon or not StaticPopup_Visible("CONFIRM_SUMMON") then return true end
    if (C_SummonInfo.GetSummonConfirmTimeLeft() or 0) <= 0 then return true end
    if not Free() then
        readyAt = GetTime() + GRACE
        return false
    end
    if GetTime() < readyAt then return false end
    C_SummonInfo.ConfirmSummon()
    StaticPopup_Hide("CONFIRM_SUMMON")
    ns.Say("accepted the summon from " .. summoner)
    return true
end

local function Check()
    if Try() then Stop() end
end

ns.On("CONFIRM_SUMMON", function(reason, skippingStart)
    if not ns.db.summon or skippingStart then return end
    if Enum.SummonReason and reason == Enum.SummonReason.Scenario then return end
    Stop()
    summoner = C_SummonInfo.GetSummonConfirmSummoner() or "?"
    local area = C_SummonInfo.GetSummonConfirmAreaName()
    readyAt = GetTime() + GRACE
    ns.Say(("summon from %s%s: accepting in %d s%s, Cancel to stay"):format(summoner,
        area and area ~= "" and (" to " .. area) or "", GRACE,
        Free() and "" or " once you are out of combat"))
    -- Blizzard shows the pop-up on this same event, maybe after us: look on the next frame
    C_Timer.After(0, Check)
    ticker = C_Timer.NewTicker(CHECK_EVERY, Check)
end)

ns.On("CANCEL_SUMMON", Stop)
