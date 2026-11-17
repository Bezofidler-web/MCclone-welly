local function test()
	local pos = vector.new(0, 200, 0)
	local front = pos:offset(0, 0, -1)
	local dispenser = "mcl_dispensers:dispenser"
	local hive = "mcl_beehives:beehive_5"
	local bottle = "mcl_potions:glass_bottle"
	local water = "mcl_core:water_source"
	local empty_buckets = "mcl_buckets:bucket_empty 2"
	local filled_bucket = "mcl_buckets:bucket_water"
	local def = core.registered_nodes[dispenser]
	core.load_area(pos:offset(-6, -4, -6), pos:offset(6, 4, 6))

	local function pulse(ingredient, target, full)
		for obj in core.objects_inside_radius(pos, 4) do obj:remove() end
		core.remove_node(pos)
		core.set_node(front, {name = target})
		core.set_node(pos, {name = dispenser})
		core.set_node(pos:offset(1, 0, 0), {name = "mcl_redstone_torch:redstoneblock"})
		local inv = core.get_meta(pos):get_inventory()
		for i = 1, full and inv:get_size("main") or 1 do inv:set_stack("main", i, ingredient) end
		assert(mcl_redstone.get_power(pos) > 0, "dispenser fixture lacks power")
		def._mcl_redstone.update(pos, core.get_node(pos))
		return inv
	end

	local function dropped_item()
		for obj in core.objects_inside_radius(pos, 4) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "__builtin:item" then return ItemStack(ent.itemstring):get_name() end
		end
	end

	for _, wood in ipairs({"poplar_chest", "bamboo_chest", "birch", "bamboo"}) do
		local item = "mcl_boats:boat_" .. wood
		local inv = pulse(item, water)
		local found = 0
		for obj in core.objects_inside_radius(pos, 4) do
			local ent = obj:get_luaentity()
			if ent and ent.name:find("^mcl_boats:") then
				found = found + 1
				local expected = wood:find("chest") and "mcl_boats:chest_boat" or "mcl_boats:boat"
				assert(ent.name == expected and ent._itemstring == item, "wrong boat for " .. item)
				if wood:find("bamboo") then assert(obj:get_properties().mesh == "mcl_boats_raft.b3d") end
			end
		end
		assert(found == 1 and inv:is_empty("main"), "one input should launch exactly one boat")
	end

	pulse(empty_buckets, water, true)
	assert(dropped_item() == filled_bucket, "full dispenser ejected the wrong bucket")
	local inv = pulse(bottle, hive, true)
	assert(inv:contains_item("main", "mcl_honey:honey_bottle"), "filled bottle should occupy emptied slot")

	local notifications = 0
	mcl_redstone.register_action(function(changed)
		if changed == front then notifications = notifications + 1 end
	end, {hive})
	for _, tool in ipairs({bottle, "mcl_tools:shears"}) do
		notifications = 0
		pulse(tool, hive)
		assert(notifications > 0 and core.get_node(front).name == "mcl_beehives:beehive",
			"harvesting with " .. tool .. " failed to notify redstone")
	end

	-- Inject a transient engine allocation failure only in this disposable server.
	local add_item = core.add_item
	core.add_item = function() return nil end
	inv = pulse(empty_buckets, water, true)
	core.add_item = add_item
	assert(inv:get_stack("remainder", 1):get_name() == filled_bucket, "lost pending output")
	assert(not def.on_timer(pos) and dropped_item() == filled_bucket and inv:is_empty("remainder"))

	local add_entity = core.add_entity
	core.add_entity = function() return nil end
	for _, item in ipairs({"mcl_boats:boat_poplar_chest", "mobs_mc:sheep"}) do
		inv = pulse(item, water)
		assert(inv:contains_item("main", item), "failed spawn consumed " .. item)
	end
	core.add_entity = add_entity

	local floor = pos:offset(4, 0, 0)
	local wet = floor:offset(1, 0, 0)
	local dry = floor:offset(-1, 0, 0)
	core.set_node(floor, {name = "mcl_ocean:sea_pickle_1_brain_coral_block"})
	for _, at in ipairs({wet, dry}) do core.set_node(at, {name = "mcl_ocean:brain_coral_block"}) end
	core.set_node(wet:offset(0, 1, 0), {name = water})
	core.set_node(dry:offset(0, 1, 0), {name = "air"})
	local placer = {
		get_player_name = function() return "GameTest" end,
		get_player_control = function() return {sneak = true} end,
		is_player = function() return true end,
	}
	local node = core.get_node(floor)
	core.registered_nodes[node.name]._on_bone_meal(nil, placer,
		{type = "node", under = floor, above = floor:offset(0, 1, 0)}, floor, node)
	assert(core.get_item_group(core.get_node(wet).name, "sea_pickle") == 1, "underwater growth must be lit")
	assert(core.get_node(dry).name == "mcl_ocean:brain_coral_block", "growth spread onto dry ground")
	local hidden = core.registered_nodes["mcl_ocean:sea_pickle_2_sand"]
	assert(hidden.inventory_image:find(core.registered_nodes["mcl_core:sand"].tiles[1], 1, true))

	dofile(core.get_modpath("mcwelly_gameplay_test") .. "/spawning.lua")
end

core.register_on_mods_loaded(function() core.after(0, test) end)
