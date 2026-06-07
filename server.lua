-- ==========================================================================
--  RealCity HUD - server.lua
--  Játékosszám, szerver ID, max slot lekérés
-- ==========================================================================

local maxPlayers = GetConvarInt('sv_maxclients', 48)

RegisterNetEvent('realcity_hud:requestServerInfo', function()
    local src = source
    local players = #GetPlayers()

    TriggerClientEvent('realcity_hud:serverInfo', src, {
        players    = players,
        maxPlayers = maxPlayers,
        serverId   = src,
    })
end)

-- Csatlakozás/kilépés naplózás (nem kötelező, de hasznos debughoz)
AddEventHandler('playerConnecting', function()
    -- A számláló a requestServerInfo-ból frissül a klienseknél.
end)

AddEventHandler('playerDropped', function()
    -- ugyanaz: a következő poll frissíti a számot.
end)
