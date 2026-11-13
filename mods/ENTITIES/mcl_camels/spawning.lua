return function (camel, camel_husk)
	local storage = core.get_mod_storage ()
	local village_id = "mcl_villages:village_desert"
	local clearance = table.merge (mcl_mobs.default_spawner, {name = camel})
	local pending = {}
	local desert
	core.register_on_mods_loaded (function ()
		desert = mcl_biome_dispatch.make_biome_test ({"Desert"})
	end)

	local function desert_village (bell)
		if mcl_levelgen.levelgen_enabled or mcl_levelgen.enable_ersatz then
			local other_village = false
			for _, area in pairs (mcl_levelgen.get_structures_at (bell, false)) do
				if area.data == village_id then return true end
				if area.data and area.data:find ("^mcl_villages:village_") then other_village = true end
			end
			if other_village then return false end
		end
		return desert (mcl_biome_dispatch.get_biome_name (bell))
	end

	local function spawn_near_bell (bell, key, retries)
		if not desert_village (bell) then
			pending[key] = nil
			return
		end
		local a = vector.offset (bell, -10, -4, -10)
		local b = vector.offset (bell, 10, 1, 10)
		core.load_area (vector.offset (a, -1, 0, -1), vector.offset (b, 1, 3, 1))
		for _, floor in ipairs (core.find_nodes_in_area_under_air (a, b, {"group:solid"})) do
			local pos = vector.offset (floor, 0, 0.5, 0)
			if mcl_weather.is_outdoor (pos) and not core.is_protected (pos, "")
				and mcl_mobs.is_position_completely_generated (pos)
				and clearance:test_spawn_clearance (pos) then
				local object = core.add_entity (pos, camel, core.serialize ({persistent = true}))
				if object and object:is_valid () then
					storage:set_int (key, 1)
					pending[key] = nil
					return
				end
			end
		end
		-- The custom generator can notify us before the neighbouring terrain is ready.
		if mcl_levelgen.levelgen_enabled and retries > 0 then
			core.after (1, spawn_near_bell, bell, key, retries - 1)
		else
			pending[key] = nil
		end
	end

	mcl_villages.register_on_villager_spawned (function (villager)
		local entity = type (villager) == "userdata" and villager:get_luaentity () or villager
		if not entity or not entity._bell then return end
		local bell = vector.round (entity._bell)
		local key = "village:" .. core.pos_to_string (bell)
		if pending[key] or storage:get_int (key) == 1 then return end
		pending[key] = true
		core.after (0, spawn_near_bell, bell, key, 15)
	end)

	local monster_spawner = mobs_mc.monster_spawner
	local spawner = table.merge (monster_spawner, {
		name = camel_husk,
		biomes = {"Desert"},
		weight = 8,
		pack_min = 1,
		pack_max = 1,
	})

	function spawner:test_spawn_position (pos, node_pos, data, cache, flag)
		return mcl_weather.is_outdoor (node_pos)
			and monster_spawner.test_spawn_position (self, pos, node_pos, data, cache, flag)
	end

	function spawner:spawn (pos, index, data, pack_size)
		if index > 0 then data = {_camel_generate_riders = true} end
		return monster_spawner.spawn (self, pos, index, data, pack_size)
	end

	mcl_mobs.register_spawner (spawner)
end
