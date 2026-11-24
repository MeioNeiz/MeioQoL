-- FlareUI's Faster Auto Loot goes off once per FlareUI profile: FastLoot.lua replaces it and
-- the two would both loot. Once only, so turning it back on afterwards sticks.
-- flareBagFix: kept from an earlier version so profiles already done aren't touched again.
-- PLAYER_LOGIN: FlareUI settles each character's profile in its own PLAYER_LOGIN, which runs
-- first (registered at its file load, before ours).
local _, ns = ...

ns.On("PLAYER_LOGIN", function()
    local flare = _G.FlareUI
    local db = type(flare) == "table" and flare.db
    local tweaks = ns.FlareTweaks()
    if not (db and db.GetCurrentProfile and tweaks) then return end
    local profile = db:GetCurrentProfile()
    ns.db.flareBagFix = ns.db.flareBagFix or {}
    if ns.db.flareBagFix[profile] then return end
    ns.db.flareBagFix[profile] = true

    if not (ns.db.fastLoot and tweaks.fasterLoot) then return end
    tweaks.fasterLoot = false
    if flare.Tweaks and flare.Tweaks.Refresh then pcall(flare.Tweaks.Refresh, flare.Tweaks) end
    ns.Say("turned FlareUI's Faster Auto Loot off (MeioQoL's replaces it), once for FlareUI "
        .. "profile \"" .. profile .. "\"")
end)
