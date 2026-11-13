local modname = core.get_current_modname ()
local path = core.get_modpath (modname)
local shared = {
	translate = core.get_translator (modname),
	frog = "mobs_mc:frog",
	tadpole = "mobs_mc:tadpole",
	spawn = "mcl_frogs:frogspawn",
	slimeball = "mcl_mobitems:slimeball",
	lights = {
		cold = "mcl_frogs:verdant_froglight",
		temperate = "mcl_frogs:ochre_froglight",
		warm = "mcl_frogs:pearlescent_froglight",
	},
}

function shared.register_egg (mob, description, image)
	mcl_mobs.register_egg (mob, description, "#637e38", "#ddb38a", 0)
	core.override_item (mob, {inventory_image = image})
end

dofile (path .. "/blocks.lua") (shared)
dofile (path .. "/tadpole.lua") (shared)
dofile (path .. "/frog.lua") (shared)
