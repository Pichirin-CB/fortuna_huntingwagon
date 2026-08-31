fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'pichirin_cb'
description 'Secure, localized hunting-wagon storage for RedM'
version '2.2.0'
license 'GPL-3.0-or-later'
documentation 'https://docs.pichirincb.com/#/'
discord 'https://discord.gg/hsx6AvBg5s'

shared_scripts {
    'shared/config.lua',
    'locales/*.lua',
    'shared/shared.lua'
}

server_scripts {
    'server/discord.lua',
    'server/persistence.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

files {
    'README.md',
    'LICENSE',
    'INSTALL_FILES/fortuna_huntingwagon.sql'
}
