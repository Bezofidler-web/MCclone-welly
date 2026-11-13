local modname = core.get_current_modname ()
local path = core.get_modpath (modname)
local shared = {
	translate = core.get_translator (modname),
	turtle = "mobs_mc:turtle",
	egg = "mcl_turtles:turtle_egg",
	scute = "mcl_turtles:turtle_scute",
}

function shared.is_sand (node)
	return node and core.get_item_group (node.name, "sand") > 0
end

dofile (path .. "/eggs.lua") (shared)
dofile (path .. "/turtle.lua") (shared)
dofile (path .. "/items.lua") (shared)
