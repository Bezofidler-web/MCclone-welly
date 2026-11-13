local modname = core.get_current_modname ()
local path = core.get_modpath (modname)
local shared = {
	translate = core.get_translator (modname),
	mob = "mobs_mc:armadillo",
	scute = "mcl_armadillos:armadillo_scute",
}

dofile (path .. "/armadillo.lua") (shared)
dofile (path .. "/wolf_armor.lua") (shared)
