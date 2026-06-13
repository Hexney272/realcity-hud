-- ==========================================================================
--  RealCity HUD - client.lua
--  Státusz / Pénz / Szerver / Jármű + voice, auto-hide, /hud kapcsoló
-- ==========================================================================

local ESX = nil
local hudVisible = true        -- /hud kapcsoló állapota
local nuiReady = false
local lastStatus = { hunger = 0, thirst = 0 }
local lastMoney  = { cash = 0, bank = 0, black = 0, rc = 0 }
local playerLoaded = false

-- ESX betöltése (ha van)
CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        if exports['es_extended'] then
            ESX = exports['es_extended']:getSharedObject()
        end
        if ESX == nil then
            while ESX == nil do
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Wait(100)
            end
        end
        playerLoaded = ESX.IsPlayerLoaded and ESX.IsPlayerLoaded() or true
    else
        playerLoaded = true -- standalone fallback
    end
end)

-- ---------------------------------------------------------------------------
--  Segédfüggvények
-- ---------------------------------------------------------------------------

local function sendNUI(action, data)
    if not nuiReady then return end
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function round(n)
    return math.floor(n + 0.5)
end

-- NUI jelzi, hogy betöltött -> küldjük a témát és a config-ot
RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendNUI('init', {
        theme   = Config.Theme,
        modules = Config.Modules,
        server  = { name = Config.Server.name },
        speedUnit = Config.SpeedUnit,
        currency = Config.Currency,
    })
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
--  ESX status (éhség / szomjúság / stamina) -> esx_status onTick
-- ---------------------------------------------------------------------------

CreateThread(function()
    if GetResourceState('esx_status') ~= 'started' then return end
    while true do
        Wait(1000)
        TriggerEvent('esx_status:getStatus', Config.StatusKeys.hunger, function(s)
            if s then lastStatus.hunger = round(s.val / 10000) end
        end)
        TriggerEvent('esx_status:getStatus', Config.StatusKeys.thirst, function(s)
            if s then lastStatus.thirst = round(s.val / 10000) end
        end)
    end
end)

-- ---------------------------------------------------------------------------
--  Voice (pma-voice) - beszél-e a játékos
-- ---------------------------------------------------------------------------

local function isTalking()
    if GetResourceState(Config.Voice.resource) ~= 'started' then
        return NetworkIsPlayerTalking(PlayerId())
    end
    local ok, talking = pcall(function()
        return LocalPlayer.state['talking'] == true
    end)
    if ok and talking ~= nil then return talking end
    return NetworkIsPlayerTalking(PlayerId())
end

-- ---------------------------------------------------------------------------
--  Üzemanyag (lc_fuel kompatibilis) + fallback
-- ---------------------------------------------------------------------------

local function getFuel(veh)
    if GetResourceState(Config.Fuel.resource) == 'started' then
        local ok, fuel = pcall(function()
            return exports[Config.Fuel.resource]:GetFuel(veh)
        end)
        if ok and fuel then return round(fuel) end
    end
    return round(GetVehicleFuelLevel(veh))
end

-- Öv (esx_cruisecontrol állapot vagy statebag fallback)
local seatbeltOn = false
RegisterNetEvent('seatbelt:toggle', function(state)
    seatbeltOn = state and true or false
end)

-- ---------------------------------------------------------------------------
--  Auto-hide: pause menü / NUI focus (inventory)
-- ---------------------------------------------------------------------------

local function shouldAutoHide()
    if Config.AutoHide.pauseMenu and IsPauseMenuActive() then return true end
    if Config.AutoHide.inventory and IsNuiFocused() then return true end
    return false
end

-- ---------------------------------------------------------------------------
--  Fő STÁTUSZ loop (élet, páncél, éhség, szomjúság, stamina, oxigén, voice)
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.UpdateRate.status)
        local ped = PlayerPedId()

        local hidden = (not hudVisible) or shouldAutoHide()
        sendNUI('visibility', { visible = not hidden })
        if hidden then goto continue end

        if Config.Modules.status then
            local health = math.max(0, GetEntityHealth(ped) - 100) -- 100 = halál küszöb
            local maxHealth = GetEntityMaxHealth(ped) - 100
            local healthPct = maxHealth > 0 and round((health / maxHealth) * 100) or 0
            local armor = round(GetPedArmour(ped))

            -- stamina: a sprint kifáradás (0 = pihent, 100 = kimerült) -> megfordítjuk
            local stamina = 100 - round(GetPlayerSprintStaminaRemaining(PlayerId()))

            -- oxigén csak víz alatt
            local underwater = IsPedSwimmingUnderWater(ped)
            local oxygen = underwater and round(GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10) or 0
            if oxygen > 100 then oxygen = 100 end

            sendNUI('status', {
                health    = healthPct,
                armor     = armor,
                hunger    = lastStatus.hunger,
                thirst    = lastStatus.thirst,
                stamina   = stamina,
                oxygen    = oxygen,
                underwater = underwater,
            })
        end

        if Config.Modules.voice then
            sendNUI('voice', { talking = isTalking() })
        end

        ::continue::
    end
end)

-- ---------------------------------------------------------------------------
--  PÉNZ loop + esemény-alapú frissítés (+/- animáció)
--  A készpénz és fekete pénz az ox_inventory-ból jön (item-ként),
--  a bank továbbra is ESX account marad.
-- ---------------------------------------------------------------------------

local function pushMoney(cash, bank, black, rc)
    rc = rc or lastMoney.rc
    local deltaCash  = cash  - lastMoney.cash
    local deltaBank  = bank  - lastMoney.bank
    local deltaBlack = black - lastMoney.black
    local deltaRc    = rc    - lastMoney.rc

    sendNUI('money', {
        cash = cash, bank = bank, black = black, rc = rc,
        deltaCash = deltaCash, deltaBank = deltaBank, deltaBlack = deltaBlack, deltaRc = deltaRc,
    })

    lastMoney.cash, lastMoney.bank, lastMoney.black, lastMoney.rc = cash, bank, black, rc
end

-- ox_inventory küldi a pénz adatokat (item-alapú cash/black_money + ESX bank)
RegisterNetEvent('ox_inventory:updateMoney', function(data)
    if not data then return end
    local cash  = tonumber(data.cash) or lastMoney.cash
    local bank  = tonumber(data.bank) or lastMoney.bank
    local black = tonumber(data.black) or lastMoney.black
    pushMoney(cash, bank, black, lastMoney.rc)
end)

-- ESX account változás eseményből (bank és RC frissítés - ezek maradnak ESX-ben)
RegisterNetEvent('esx:setAccountMoney', function(account)
    if not account then return end
    if account.name == 'bank' then
        pushMoney(lastMoney.cash, account.money, lastMoney.black, lastMoney.rc)
    elseif account.name == 'realcoin' or account.name == 'rc' then
        pushMoney(lastMoney.cash, lastMoney.bank, lastMoney.black, account.money)
    end
    -- 'money' és 'black_money' account változásokat IGNORÁLJUK,
    -- mert azokat az ox_inventory:updateMoney kezeli (item-ként).
end)

-- RealCoin (RC) külön event-ből is frissíthető (pl. saját webshop/prémium rendszer)
RegisterNetEvent('realcity_hud:setRealCoin', function(amount)
    pushMoney(lastMoney.cash, lastMoney.bank, lastMoney.black, tonumber(amount) or 0)
end)

-- Pénz polling: kérjük az ox_inventory-tól a money item adatokat
-- Bank-ot ESX-ből kérjük, RC-t ESX-ből
CreateThread(function()
    while true do
        Wait(Config.UpdateRate.money)
        if Config.Modules.money then
            -- Kérjük az inventory-tól a pénz item adatokat
            TriggerServerEvent('ox_inventory:requestMoney')

            -- Bank és RC továbbra is ESX-ből (account)
            if ESX then
                local accounts = ESX.GetPlayerData and ESX.GetPlayerData().accounts or nil
                if accounts then
                    local bank = lastMoney.bank
                    local rc   = lastMoney.rc
                    for _, acc in pairs(accounts) do
                        if acc.name == 'bank' then bank = acc.money
                        elseif acc.name == 'realcoin' or acc.name == 'rc' then rc = acc.money end
                    end
                    if bank ~= lastMoney.bank or rc ~= lastMoney.rc then
                        pushMoney(lastMoney.cash, bank, lastMoney.black, rc)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  JÁRMŰ loop (sebesség, rpm, üzemanyag, fokozat, motor, öv)
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.UpdateRate.vehicle)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if Config.Modules.vehicle and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local speedMs = GetEntitySpeed(veh)
            local speed = Config.SpeedUnit == 'mph'
                and round(speedMs * 2.236936)
                or  round(speedMs * 3.6)

            local rpm = GetVehicleCurrentRpm(veh)              -- 0.0 - 1.0
            local gear = GetVehicleCurrentGear(veh)
            local engineHealth = round((GetVehicleEngineHealth(veh) / 1000) * 100)
            if engineHealth < 0 then engineHealth = 0 end
            if engineHealth > 100 then engineHealth = 100 end

            sendNUI('vehicle', {
                inVehicle    = true,
                speed        = speed,
                rpm          = round(rpm * 100),
                fuel         = getFuel(veh),
                gear         = gear,
                engineHealth = engineHealth,
                seatbelt     = seatbeltOn,
            })
        else
            sendNUI('vehicle', { inVehicle = false })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  SZERVER info (játékosszám, szerver ID) - szervertől kérjük le
-- ---------------------------------------------------------------------------

RegisterNetEvent('realcity_hud:serverInfo', function(data)
    sendNUI('server', {
        players  = data.players,
        maxPlayers = data.maxPlayers,
        serverId = data.serverId,
        name     = Config.Server.name,
    })
end)

-- Játékos szint a HUD-on (a realcity-leveling resource küldi)
--   TriggerClientEvent('realcity_hud:setLevel', src, { level = 12, xp = 340, xpNext = 800 })
RegisterNetEvent('realcity_hud:setLevel', function(data)
    if type(data) ~= 'table' then return end
    sendNUI('level', {
        level  = data.level,
        xp     = data.xp,
        xpNext = data.xpNext,
    })
end)

CreateThread(function()
    while true do
        Wait(Config.UpdateRate.server)
        if Config.Modules.server and nuiReady then
            TriggerServerEvent('realcity_hud:requestServerInfo')
        end
    end
end)

-- ---------------------------------------------------------------------------
--  /hud kapcsoló parancs
-- ---------------------------------------------------------------------------

RegisterCommand(Config.ToggleCommand, function()
    hudVisible = not hudVisible
    local msg = hudVisible and 'HUD bekapcsolva' or 'HUD kikapcsolva'
    TriggerEvent('chat:addMessage', {
        color = { 61, 220, 132 },
        multiline = false,
        args = { 'RealCity HUD', msg },
    })
end, false)

-- Resource leállításkor takarítás
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        nuiReady = false
    end
end)
