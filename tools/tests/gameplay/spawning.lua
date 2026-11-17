-- The natural spawning pass accepts a snapshot of chunk and player positions.
-- Supply that snapshot without starting clients; all entities and nodes are real.
local centre = vector.new(7, 80, 7)
local function run()
	assert(core.compare_block_status(centre, "active"), "fixture mapblock must be active")
	local stone, air = {name = "mcl_core:stone"}, {name = "air"}
	local function room(roof)
		for x = 0, 15 do
			for z = 0, 15 do
				for y = 79, 84 do
					local wall = roof and (y == 84 or x == 0 or z == 0 or x == 15 or z == 15)
					core.set_node(vector.new(x, y, z), (wall or y == 79) and stone or air)
				end
			end
		end
		core.fix_light(vector.new(0, 77, 0), vector.new(15, 86, 15))
	end
	local biome = mcl_biome_dispatch.get_biome_name_nosample(centre)
	local monsters = assert(mcl_mobs.registered_spawners[biome].monster, biome)
	local total, zombie_roll = 0, nil
	for _, spawner in ipairs(monsters) do
		total = total + spawner.weight
		if spawner.name == "mobs_mc:zombie" then zombie_roll = total end
	end
	assert(zombie_roll, "fixture needs a biome with zombie spawning")
	local chunk = 2048 * 4096 + 2048
	local function cycle(distances, offset, sky_roll, brightness_roll)
		local players = {}
		for i, dx in ipairs(distances) do players[i] = centre:offset(dx, -0.5, 0) end
		local chunks = {overworld = {{chunk}, players, {[chunk] = {y_ranges = {80, 80}}}}}
		local coord_roll, random = 0, math.random
		local function choose(lo, hi)
			if lo == 0 and hi == 15 then return 7 end
			if lo == total and not hi then return zombie_roll end
			if lo == 0 and hi == 5 then
				coord_roll = coord_roll + 1
				return coord_roll % 4 == 1 and offset or 0
			end
			if lo == 0 and hi == 31 then return sky_roll end
			if lo == 0 and hi == 7 then return brightness_roll end
			if hi then return random(lo, hi) end
			if lo then return random(lo) end
			return random()
		end
		rawset(math, "random", choose)
		local ok, err = pcall(mcl_mobs.spawn_cycle, "overworld", chunks, 289, false)
		rawset(math, "random", random)
		assert(ok, err)
		local found = 0
		for obj in core.objects_inside_radius(centre, 9) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "mobs_mc:zombie" then
				found = found + 1
				obj:remove()
			end
		end
		return found
	end

	room(true)
	assert(core.get_natural_light(centre, 0.5) == 0, "sealed cave leaks sunlight")
	assert(cycle({-30}, 0, 0, 0) > 0, "zombies should spawn in a dark cave")
	assert(cycle({-25, 26}, 5, 0, 0) == 0, "pack member spawned too close to second player")
	core.set_node(centre:offset(2, 0, 0), {name = "mcl_torches:torch"})
	assert(core.get_artificial_light(core.get_node(centre).param1) > 0)
	assert(cycle({-30}, 0, 31, 7) == 0, "torch-lit cave permitted a natural zombie")
	room(false)
	core.set_timeofday(0.5)
	assert(core.get_natural_light(centre, 0.5) == 15)
	assert(cycle({-30}, 0, 31, 7) == 0, "daylight permitted a natural zombie")
	core.set_timeofday(0)
	assert(cycle({-30}, 0, 0, 7) == 0, "night ignored exposed sky")
	assert(cycle({-30}, 0, 31, 0) == 0, "night ignored brightness roll")
	assert(cycle({-30}, 0, 31, 7) > 0, "night should permit a surface zombie")
	assert(mcl_mobs.spawn_categories.water_ambient.chunk_mob_cap == 20)
	local cod, cow
	for _, categories in pairs(mcl_mobs.registered_spawners) do
		for _, spawner in ipairs(categories.water_ambient or {}) do
			assert(spawner.despawn_distance_sqr == 64 * 64)
			if spawner.name == "mobs_mc:cod" then cod = spawner end
		end
		for _, spawner in ipairs(categories.creature or {}) do
			if spawner.name == "mobs_mc:cow" then cow = spawner end
		end
	end
	assert(cod and cow, "natural animal and fish spawners must register")
	local function eligible(spawner, at)
		return spawner:test_spawn_position(at:offset(0, -0.5, 0), at, {}, {}, nil)
	end
	assert(not eligible(cow, centre), "natural cow on a stone floor")
	core.set_node(centre:offset(0,-1,0), {name = "mcl_core:dirt_with_grass"})
	assert(not eligible(cow, centre), "natural cow on dark grass")
	core.set_timeofday(0.5)
	assert(eligible(cow, centre), "daylit grass should admit a natural cow")
	local sea = vector.new(7, -5, 7)
	core.load_area(sea:offset(0,-1,0), sea:offset(0,1,0))
	for dy = -1, 1 do core.set_node(sea:offset(0,dy,0), {name = "mcl_core:water_source"}) end
	assert(eligible(cod, sea), "surface-water cod habitat")
	core.set_node(sea:offset(0,1,0), air)
	assert(not eligible(cod, sea), "cod with air overhead")
	core.log("action", "GAMEPLAY TEST natural pack spawning passed for cave darkness, torchlight, daylight, night and two-player exclusion")
	core.log("action", "GAMEPLAY TEST aquatic cap, fish range, cod water and cow pasture conditions passed")
	core.log("action", "GAMEPLAY TEST PASSED")
	core.request_shutdown("Gameplay test complete", false, 0)
end

core.forceload_block(centre, true)
core.emerge_area(centre:offset(-16,-16,-16), centre:offset(16,16,16), function(_, _, remaining)
	if remaining == 0 then core.after(2, run) end
end)
