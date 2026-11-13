local modname = core.get_current_modname ()
local path = core.get_modpath (modname)
local shared = {
	translate = core.get_translator (modname),
	sniffer = "mobs_mc:sniffer",
	egg = "mcl_sniffers:sniffer_egg",
	seeds = "mcl_sniffers:torchflower_seeds",
	pod = "mcl_sniffers:pitcher_pod",
}

dofile (path .. "/plants.lua") (shared)
dofile (path .. "/egg.lua") (shared)
dofile (path .. "/sniffer.lua") (shared)
