-- Farther, faster camera: Blizzard's max camera distance and zoom speed set to ours. The
-- player's own values are kept per character (where the game may keep these) and go back
-- when it goes off or FlareUI's copy takes over.
local _, ns = ...

local CVARS = { zoom = "cameraDistanceMaxZoomFactor", speed = "cameraZoomSpeed" }

function ns.Apply.camera()
    if not ns.char then return end
    if ns.Active("camera") then
        if not ns.char.cameraOwn then
            ns.char.cameraOwn = { zoom = GetCVar(CVARS.zoom), speed = GetCVar(CVARS.speed) }
        end
        pcall(SetCVar, CVARS.zoom, ns.db.cameraZoom)
        pcall(SetCVar, CVARS.speed, ns.db.cameraSpeed)
    elseif ns.char.cameraOwn then
        for k, cvar in pairs(CVARS) do
            local own = ns.char.cameraOwn[k] or GetCVarDefault(cvar)
            if own then pcall(SetCVar, cvar, own) end
        end
        ns.char.cameraOwn = nil
    end
end

ns.On("PLAYER_LOGIN", ns.Apply.camera)
