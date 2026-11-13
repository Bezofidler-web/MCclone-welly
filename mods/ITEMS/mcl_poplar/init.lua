local modpath = core.get_modpath (core.get_current_modname ())

dofile(modpath .. "/wood.lua")
dofile(modpath .. "/red_bush.lua")
dofile(modpath .. "/shelf_mushroom.lua")

for i, schematic in ipairs(mcl_trees.woods.poplar.tree_schems) do
	mcl_levelgen.register_portable_schematic("mcl_poplar:tree_" .. i, schematic.file, true)
end
mcl_levelgen.register_levelgen_script(modpath .. "/levelgen.lua")
