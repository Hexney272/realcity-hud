Config = {}

-- ==========================================================================
--  RealCity HUD - konfiguráció
-- ==========================================================================

-- Frissítési ütemezés (ms). Kisebb = simább, nagyobb CPU. 50 = 20 fps.
Config.UpdateRate = {
    status  = 250,   -- élet / páncél / éhség / szomjúság / stamina / oxigén
    money   = 1000,  -- pénz polling (a változás külön eventből is jön)
    vehicle = 50,    -- jármű (sebesség, rpm) -- gyors, hogy sima legyen
    server  = 5000,  -- játékosszám / szerver info
}

-- Témaszínek (a NUI ezeket CSS változókként kapja meg)
Config.Theme = {
    green = '#3ddc84',   -- élet, voice aktív, pozitív pénz
    blue  = '#4aa8ff',   -- víz / oxigén / bank
    gold  = '#ffd166',   -- készpénz / kiemelés
    red   = '#ff5d5d',   -- alacsony érték / negatív pénz
    armor = '#8ab4ff',   -- páncél
}

-- Modulok ki/be kapcsolása
Config.Modules = {
    status  = true,
    money   = true,
    server  = true,
    vehicle = true,
    voice   = true,
}

-- esx_status kulcsok -> HUD mező megfeleltetés
Config.StatusKeys = {
    hunger = 'hunger',
    thirst = 'thirst',
}

-- Voice (pma-voice) range színek nem kellenek, csak az aktív beszéd jelzés.
Config.Voice = {
    resource = 'pma-voice',
}

-- Üzemanyag resource (lc_fuel kompatibilis export)
Config.Fuel = {
    resource = 'lc_fuel',
}

-- Szerver branding
Config.Server = {
    name = 'RealCity',
    -- A logó a html/index.html-ben szöveges badge; cseréld képre ha van.
}

-- Sebesség mértékegység: 'kmh' vagy 'mph'
Config.SpeedUnit = 'kmh'

-- Pénznem felirat (a szerver forintot használ) + prémium valuta
Config.Currency = {
    cash    = 'Ft',   -- készpénz / bank / fekete pénz utótag
    premium = 'RC',   -- RealCoin (prémium fizetőeszköz) utótag
}

-- RealCoin (RC) forrása: 'account' = ESX account ('realcoin'/'rc'),
-- vagy saját rendszerből a 'realcity_hud:setRealCoin' event-tel frissíthető.
Config.RealCoinAccount = 'realcoin'

-- Auto-hide: ezek alatt elrejtjük a HUD-ot
Config.AutoHide = {
    pauseMenu  = true,  -- ESC / pause menü
    inventory  = true,  -- nui focus aktív (pl. inventory nyitva)
}

-- /hud parancs a teljes HUD kapcsolásához
Config.ToggleCommand = 'hud'
