-- Accepts a player's resurrection once the caster is out of combat (Leatrix AutoResNoCombat).
-- Only RESURRECT_REQUEST: soulstones and spirit healers are other dialogs and never touched.
local _, ns = ...

local POPUPS = { "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }
local CHECK_EVERY = 0.5

local pending, ticker

local function Popup()
    for _, which in ipairs(POPUPS) do
        if StaticPopup_Visible(which) then return which end
    end
end

local function Short(name)
    return (name or ""):match("^[^-]+") or name
end

-- the caster's unit token, if we can see them: group, target or mouseover
local function FindUnit(name)
    local short = Short(name)
    local function Is(unit)
        return UnitExists(unit) and UnitName(unit) == short
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if Is("raid" .. i) then return "raid" .. i end
        end
    else
        for i = 1, 4 do
            if Is("party" .. i) then return "party" .. i end
        end
    end
    for _, unit in ipairs({ "target", "focus", "mouseover" }) do
        if Is(unit) then return unit end
    end
end

-- false only when we know they're out of combat
local function CasterInCombat(name)
    local unit = FindUnit(name)
    if not unit then return nil end
    local combat = UnitAffectingCombat(unit)
    if issecretvalue and issecretvalue(combat) then return nil end
    return combat and true or false
end

local function Stop()
    pending = nil
    if ticker then ticker:Cancel() ticker = nil end
end

-- true when finished (accepted, declined, expired or alive again)
local function Try()
    if not pending or not ns.db.res then return true end
    if not UnitIsDeadOrGhost("player") then return true end
    local which = Popup()
    if not which then return true end
    if GetCorpseRecoveryDelay() > 0 then return false end
    if CasterInCombat(pending) ~= false then return false end
    AcceptResurrect()
    StaticPopup_Hide(which)
    ns.Say("accepted the resurrection from " .. Short(pending))
    return true
end

local function Check()
    if Try() then Stop() end
end

ns.On("RESURRECT_REQUEST", function(name)
    if not ns.db.res then return end
    -- sickness means a spirit-healer style res: leave the choice to you
    if ResurrectHasSickness and ResurrectHasSickness() then return end
    Stop()
    pending = name
    -- Blizzard shows the popup on this same event, maybe after us: look on the next frame
    C_Timer.After(0, Check)
    ticker = C_Timer.NewTicker(CHECK_EVERY, Check)
end)

ns.On("PLAYER_ALIVE", Stop)
ns.On("PLAYER_UNGHOST", Stop)
