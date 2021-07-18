--[[----------------------------------
Creation Date:	24/01/21
]]------------------------------------
fx_version 'adamant'
game 'gta5'
author 'Leah#0001'
version '2.0.1'
versioncheck 'https://raw.githubusercontent.com/Leah-UK/bixbi_tracker/main/fxmanifest.lua'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
    'locales/en.lua',
	'config.lua'
}

client_scripts {
    'client/client.lua'
} 
 
server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}