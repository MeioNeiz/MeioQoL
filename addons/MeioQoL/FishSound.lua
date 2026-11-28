-- Fishing sounds: from a Fishing cast until you move, fight, zone or stop casting for a while,
-- music and ambience go down and effects up so the splash is heard. The player's volumes are
-- kept account-wide (where the game keeps them) until put back, so a crash mid-session puts
-- them back at the next login.
local _, ns = ...

local FISHING = 7620
local IDLE = 30
local VOLUMES = {
    Sound_MusicVolume = function(v) return v * 0.3 end,
    Sound_AmbienceVolume = function(v) return v * 0.3 end,
    Sound_SFXVolume = function(v) return math.max(v, 0.8) end,
}

local fishing, idleTimer = false, nil
local moving = CreateFrame("Frame")

local function Stop()
    if idleTimer then idleTimer:Cancel() idleTimer = nil end
    fishing = false
    moving:UnregisterEvent("PLAYER_STARTED_MOVING")
    local own = ns.db and ns.db.fishOwn
    if not own then return end
    for cvar, value in pairs(own) do pcall(SetCVar, cvar, value) end
    ns.db.fishOwn = nil
end
moving:SetScript("OnEvent", Stop)

local function Start()
    if idleTimer then idleTimer:Cancel() idleTimer = nil end
    if fishing or not ns.Active("fishSound") or InCombatLockdown() then return end
    fishing = true
    moving:RegisterEvent("PLAYER_STARTED_MOVING")
    if ns.db.fishOwn then return end
    local own = {}
    for cvar, lower in pairs(VOLUMES) do
        local now = tonumber(GetCVar(cvar))
        if now then
            local want = lower(now)
            if math.abs(want - now) > 0.001 and pcall(SetCVar, cvar, ("%.2f"):format(want)) then
                own[cvar] = tostring(now)
            end
        end
    end
    ns.db.fishOwn = own
end

local function IsFishing(spellID)
    if canaccessvalue and not canaccessvalue(spellID) then return false end
    local name = spellID and C_Spell.GetSpellName(spellID)
    return name ~= nil and name == C_Spell.GetSpellName(FISHING)
end

ns.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
    if unit == "player" and IsFishing(spellID) then Start() end
end)
ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
    if unit == "player" and fishing then
        if idleTimer then idleTimer:Cancel() end
        idleTimer = C_Timer.NewTimer(IDLE, Stop)
    end
end)
ns.On("PLAYER_REGEN_DISABLED", Stop)
ns.On("PLAYER_LEAVING_WORLD", Stop)
ns.On("PLAYER_LOGIN", Stop)

function ns.Apply.fishSound()
    if not ns.Active("fishSound") then Stop() end
end
