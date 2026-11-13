local modname = core.get_current_modname ()
local path = core.get_modpath (modname)
local S = core.get_translator (modname)
local phantom = "mobs_mc:phantom"
local membrane = "mcl_mobitems:phantom_membrane"

core.register_craftitem (":" .. membrane, {
	description = S ("Phantom Membrane"),
	inventory_image = "mcl_phantoms_membrane.png",
	_tt_help = S ("Brews Slow Falling potions and repairs Elytra"),
})

dofile (path .. "/phantom.lua") (phantom, membrane, S)
dofile (path .. "/insomnia.lua") (phantom)
