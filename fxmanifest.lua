fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'cobalt_crime'
author 'Project Cobalt'
description 'Street crime for Project Cobalt: parking meters, copper scrap, chop shop, plate cloning, drug package runs and store robberies'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'cobalt_core',
    'cobalt_inventory',
}

ox_libs { 'locale' }

shared_script '@ox_lib/init.lua'

client_script 'client/init.lua'

server_script 'server/init.lua'

files {
    'locales/*.json',
    'client/*.lua',
    'shared/*.lua',
    'parkingmeters/config.lua',
    'parkingmeters/client.lua',
    'copperscrap/config.lua',
    'copperscrap/client.lua',
    'chopshop/config.lua',
    'chopshop/client.lua',
    'cloning/config.lua',
    'cloning/client.lua',
    'drugruns/config.lua',
    'drugruns/client.lua',
    'storerobbery/config.lua',
    'storerobbery/client.lua',
}
