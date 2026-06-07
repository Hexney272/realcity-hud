fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealCity'
description 'RealCity HUD - glassmorphism HUD (status, money, server, vehicle)'
version '1.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client.lua'

server_script 'server.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- Opcionális függőségek (ha nincsenek fent, a HUD a fallback értékekre vált):
--   es_extended      (ESX core)
--   esx_status       (éhség / szomjúság / stamina / oxigén)
--   pma-voice        (voice indikátor)
--   lc_fuel          (üzemanyag)
--   esx_cruisecontrol (öv / tempomat)
dependencies {
    '/server:7290',
    '/onesync',
}
