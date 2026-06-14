-- ==========================================================================
--  RealCity HUD - server.lua
--  Játékosszám, szerver ID, max slot lekérés, szint lekérés
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


-- ==========================================================================
--  RealCoin (RC) - prémium valuta ESX account alapon
--  Az account neve: Config.RealCoinAccount (alap: 'realcoin').
--  FONTOS: az account-ot regisztrálni kell az ESX-ben (ld. README / lent),
--  különben az add/get műveletek nem találják.
-- ==========================================================================

local ESX = nil
CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

local RC_ACCOUNT = Config.RealCoinAccount or 'realcoin'

-- A HUD azonnali frissítése (a poll amúgy is frissítené ~1 mp-en belül)
local function pushRcToHud(src, amount)
    TriggerClientEvent('realcity_hud:setRealCoin', src, amount)
end

--- RC egyenleg lekérése. -1 ha nincs ESX / account.
local function getRealCoin(src)
    if not ESX then return -1 end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return -1 end
    local acc = xPlayer.getAccount(RC_ACCOUNT)
    return acc and acc.money or -1
end

--- RC hozzáadása.
local function addRealCoin(src, amount)
    amount = tonumber(amount)
    if not ESX or not amount or amount == 0 then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if not xPlayer.getAccount(RC_ACCOUNT) then
        print(('[realcity-hud] HIBA: a(z) "%s" ESX account nem létezik. Regisztráld az ESX-ben!'):format(RC_ACCOUNT))
        return false
    end
    xPlayer.addAccountMoney(RC_ACCOUNT, amount)
    pushRcToHud(src, xPlayer.getAccount(RC_ACCOUNT).money)
    return true
end

--- RC levonása.
local function removeRealCoin(src, amount)
    amount = tonumber(amount)
    if not ESX or not amount or amount <= 0 then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local acc = xPlayer.getAccount(RC_ACCOUNT)
    if not acc then return false end
    if acc.money < amount then return false end   -- nincs elég RC
    xPlayer.removeAccountMoney(RC_ACCOUNT, amount)
    pushRcToHud(src, xPlayer.getAccount(RC_ACCOUNT).money)
    return true
end

--- RC fix értékre állítása.
local function setRealCoin(src, amount)
    amount = tonumber(amount)
    if not ESX or not amount or amount < 0 then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.getAccount(RC_ACCOUNT) then return false end
    xPlayer.setAccountMoney(RC_ACCOUNT, amount)
    pushRcToHud(src, amount)
    return true
end

-- Exportok más resource-oknak (boltok, webshop, jutalmak, stb.)
exports('GetRealCoin', getRealCoin)
exports('AddRealCoin', addRealCoin)
exports('RemoveRealCoin', removeRealCoin)
exports('SetRealCoin', setRealCoin)

-- Admin parancs: /giverc [id|üres=magamnak] [mennyiség]
-- Jogosultság: ace 'realcity.rc.admin' (vagy konzolból mindig megy).
RegisterCommand('giverc', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'realcity.rc.admin') then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 93, 93 }, args = { 'RealCity', 'Nincs jogosultságod ehhez.' } })
        return
    end

    local target, amount
    if #args >= 2 then
        target = tonumber(args[1]); amount = tonumber(args[2])
    elseif #args == 1 then
        target = src; amount = tonumber(args[1])   -- magadnak
    end

    if not target or not amount then
        local who = (src == 0) and 0 or src
        if who ~= 0 then
            TriggerClientEvent('chat:addMessage', who, {
                color = { 255, 209, 102 }, args = { 'RealCity', 'Használat: /giverc [id] [mennyiség]  (id elhagyható = magadnak)' } })
        else
            print('Hasznalat: giverc [id] [mennyiseg]')
        end
        return
    end

    if addRealCoin(target, amount) then
        TriggerClientEvent('chat:addMessage', target, {
            color = { 61, 220, 132 }, args = { 'RealCity', ('Kaptál %s RC-t!'):format(amount) } })
    elseif src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 93, 93 }, args = { 'RealCity', 'Sikertelen (nincs ESX, vagy a realcoin account nincs regisztrálva).' } })
    end
end, false)



-- ==========================================================================
--  Szint (Level) lekérés - a HUD kliens periodikusan kéri
--  A realcity-leveling resource-ból exporttal kapjuk meg az adatokat.
-- ==========================================================================

RegisterNetEvent('realcity_hud:requestLevel', function()
    local src = source
    if GetResourceState('realcity-leveling') ~= 'started' then return end

    -- Próbáljuk a GetSnapshot exportot (ez a teljes pillanatképet adja)
    local ok, snap = pcall(function()
        return exports['realcity-leveling']:GetSnapshot(src)
    end)

    if ok and snap then
        TriggerClientEvent('realcity_hud:setLevel', src, {
            level  = snap.level or 1,
            xp     = snap.xp or 0,
            xpNext = snap.xpNext or 100,
        })
    else
        -- Fallback: csak a szintet kérjük
        local ok2, level = pcall(function()
            return exports['realcity-leveling']:GetLevel(src)
        end)
        if ok2 and level then
            TriggerClientEvent('realcity_hud:setLevel', src, {
                level  = level or 1,
                xp     = 0,
                xpNext = 100,
            })
        end
    end
end)



-- ==========================================================================
--  RC egyenleg lekérés - a HUD kliens polling-olja
-- ==========================================================================

RegisterNetEvent('realcity_hud:requestRcBalance', function()
    local src = source
    local rc = getRealCoin(src)
    if rc >= 0 then
        TriggerClientEvent('realcity_hud:setRealCoin', src, rc)
    end
end)
