-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local V = vector.new
local prefix = "mcl_expeditions:"
local brick = "mcl_core:stonebrick"
local cracked_brick = "mcl_core:stonebrickcracked"
local fired_brick = "mcl_core:brick_block"
local quartz = "mcl_nether:quartz_smooth"
local glass = "mcl_core:glass"
local water = "mcl_core:water_source"
local air = "air"

local function fixture(description, tiles)
	return {
		description = description,
		tiles = tiles,
		is_ground_content = false,
		groups = {pickaxey = 1, not_in_creative_inventory = 1},
		drop = brick,
		sounds = mcl_sounds.node_sound_stone_defaults(),
		_mcl_hardness = 2,
		_mcl_blast_resistance = 6,
	}
end

local function permitted(pos, playername)
	if not core.is_protected(pos, playername) then return true end
	core.record_protection_violation(pos, playername)
	return false
end

local beacon = prefix .. "storm_lighthouse_lamp"
local broken_beacon = fixture(S("Broken Lighthouse Lamp"), {
	"mcl_copper_exposed_cut.png", "mcl_copper_exposed_cut.png",
	"mcl_ocean_sea_lantern.png^[multiply:#586267",
})
broken_beacon.on_rightclick = function(pos, _, player, stack)
	if not player or not player:is_player() then return stack end
	local name = player:get_player_name()
	if not permitted(pos, name) or core.get_node(pos).name ~= beacon .. "_broken" then return stack end
	if stack:get_name() ~= "mcl_copper:copper_ingot" or stack:get_count() < 3 then
		core.chat_send_player(name, S("Bring three copper ingots to repair the lighthouse lamp."))
		return stack
	end
	core.set_node(pos, {name = beacon})
	if not core.is_creative_enabled(name) then stack:take_item(3) end
	core.chat_send_player(name, S("The lighthouse is lit. Its lantern now marks the coast."))
	return stack
end
core.register_node(beacon .. "_broken", broken_beacon)

local live_beacon = fixture(S("Lighthouse Lamp"), {
	"mcl_copper_block_cut.png", "mcl_copper_block_cut.png", "mcl_ocean_sea_lantern.png",
})
live_beacon.light_source = core.LIGHT_MAX
live_beacon.paramtype = "light"
core.register_node(beacon, live_beacon)

local function coastal_ground(pos)
	local supported = 0
	for _, x in ipairs({-3, 3}) do
		for _, z in ipairs({-3, 3}) do
			local floor = core.registered_nodes[core.get_node(vector.offset(pos, x, -6, z)).name]
			if floor and floor.walkable then supported = supported + 1 end
		end
	end
	if supported < 3 then return false end

	-- Require a body of water outside the tower, rather than a lone puddle.
	for _, direction in ipairs({V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1)}) do
		for depth = 2, 10 do
			local shore = vector.offset(pos, direction.x * 8, -depth, direction.z * 8)
			local beyond = vector.offset(shore, direction.x * 2, 0, direction.z * 2)
			if core.get_item_group(core.get_node(shore).name, "water") > 0
				and core.get_item_group(core.get_node(beyond).name, "water") > 0 then
				return true
			end
		end
	end
	return false
end

mcl_expeditions.register("storm_lighthouse", {
	title = S("Storm Lighthouse"),
	environment = "land",
	biomes = {"Beach", "StonyShore", "SnowyBeach", "Plains", "Meadow"},
	max_y = 20,
	bounds = {min = V(-10, -10, -10), max = V(10, 17, 10)},
	site_ok = coastal_ground,
	build = function(ctx)
		ctx:fill(-4, -5, -4, 4, -1, 4, brick)
		ctx:fill(-1, -1, -6, 1, -1, -3, cracked_brick)
		ctx:fill(-1, 0, -6, 1, 2, -3, air)
		ctx:fill(-3, 0, -3, 3, 16, 3, air)

		for y = 0, 13 do
			for x = -3, 3 do
				for z = -3, 3 do
					local edge = math.max(math.abs(x), math.abs(z))
					if edge == 3 and math.abs(x) + math.abs(z) ~= 6 then
						local material = y < 2 and brick or (y % 6 < 3 and fired_brick or quartz)
						ctx:set(x, y, z, material)
					end
				end
			end
		end
		ctx:fill(-1, 0, -3, 1, 2, -3, air)

		for _, y in ipairs({4, 8, 12}) do
			ctx:fill(-2, y, -2, 2, y, 2, brick)
			ctx:set(0, y, 1, air)
			ctx:set(-3, y + 1, 0, glass)
			ctx:set(3, y + 1, 0, glass)
		end
		ctx:fill(0, 0, 2, 0, 13, 2, brick)
		for y = 0, 13 do
			ctx:set(0, y, 1, "mcl_core:ladder", 4)
		end

		ctx:fill(-4, 13, -4, 4, 13, 4, brick)
		ctx:set(0, 13, 1, "mcl_core:ladder", 4)
		for _, side in ipairs({-1, 1}) do
			ctx:fill(-4, 14, 4 * side, 4, 14, 4 * side, "mcl_fences:spruce_fence")
			ctx:fill(4 * side, 14, -3, 4 * side, 14, 3, "mcl_fences:spruce_fence")
			ctx:fill(-2, 14, 2 * side, 2, 16, 2 * side, glass)
			ctx:fill(2 * side, 14, -1, 2 * side, 16, 1, glass)
		end
		ctx:set(0, 14, 2, brick)
		ctx:set(0, 14, 1, "mcl_core:ladder", 4)
		ctx:fill(0, 14, -2, 0, 15, -2, air)
		ctx:fill(-3, 17, -3, 3, 17, 3, fired_brick)
		ctx:set(0, 15, 0, beacon .. "_broken")
		ctx:sign(-3, 14, -1, S("Storm Lighthouse\nLamp needs 3 copper ingots"))
		ctx:sign(-2, 0, -4, S("Storm Lighthouse\nClimb to the lantern"))
		ctx:chest(-2, 0, 1, {"mcl_farming:bread 4", "mcl_torches:torch 8", "mcl_fishing:fish_cooked 3"})
	end,
})

local warm_valve = prefix .. "bathhouse_hot_valve"
local cold_valve = prefix .. "bathhouse_cold_valve"
local seal = prefix .. "bathhouse_pressure_seal"
core.register_node(seal, fixture(S("Bathhouse Pressure Seal"), {"mcl_copper_exposed_cut.png"}))

local function bath_water_cells(origin, min_x, max_x, playername)
	local function holds_water(pos)
		local node = core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		return def and def.walkable and def.liquidtype == "none"
	end

	-- Leave the basins dry if their base or retaining walls have been broken.
	for x = min_x - 1, max_x + 1 do
		for z = -4, 2 do
			local border = x == min_x - 1 or x == max_x + 1 or z == -4 or z == 2
			if not holds_water(vector.offset(origin, x, border and -1 or -2, z)) then return end
		end
	end

	local cells = {}
	for x = min_x, max_x do
		for z = -3, 1 do
			local pos = vector.offset(origin, x, -1, z)
			local node = core.get_node_or_nil(pos)
			if not node or (node.name ~= air and node.name ~= water) then return end
			if not permitted(pos, playername) then return end
			cells[#cells + 1] = pos
		end
	end
	return cells
end

local function bath_seal_cells(origin, playername)
	local cells = {}
	for x = -1, 1 do
		for y = 0, 2 do
			local pos = vector.offset(origin, x, y, 4)
			local node = core.get_node_or_nil(pos)
			if not node or (node.name ~= seal and node.name ~= air) then return end
			if not permitted(pos, playername) then return end
			cells[#cells + 1] = pos
		end
	end
	return cells
end

local function activate_hot(pos, _, player, stack)
	if not player or not player:is_player() then return stack end
	local name = player:get_player_name()
	local cold = vector.offset(pos, 4, 0, 0)
	if not permitted(pos, name) or core.get_node(pos).name ~= warm_valve
		or core.get_node(cold).name ~= cold_valve then return stack end
	local meta = core.get_meta(pos)
	if meta:get_int("open") == 1 then
		core.chat_send_player(name, S("The hot water is running."))
		return stack
	end

	local origin = vector.offset(pos, 2, 0, -3)
	local cells = bath_water_cells(origin, -7, -3, name)
	if not cells then
		core.chat_send_player(name, S("The warm bath cannot hold water. Check its basin and walls."))
		return stack
	end
	core.bulk_set_node(cells, {name = water})
	meta:set_int("open", 1)
	meta:set_string("infotext", S("Hot Valve Open"))
	core.chat_send_player(name, S("The warm bath fills. Open the cold valve to balance the pressure."))
	return stack
end

local function activate_cold(pos, _, player, stack)
	if not player or not player:is_player() then return stack end
	local name = player:get_player_name()
	local hot = vector.offset(pos, -4, 0, 0)
	if not permitted(pos, name) or core.get_node(pos).name ~= cold_valve
		or core.get_node(hot).name ~= warm_valve then return stack end
	local meta = core.get_meta(pos)
	if meta:get_int("open") == 1 then return stack end
	if core.get_meta(hot):get_int("open") ~= 1 then
		core.chat_send_player(name, S("The pipes are cold. Open the hot valve first."))
		return stack
	end

	local origin = vector.offset(pos, -2, 0, -3)
	local warm_bath = bath_water_cells(origin, -7, -3, name)
	local cool_bath = bath_water_cells(origin, 3, 7, name)
	local threshold = bath_seal_cells(origin, name)
	if not warm_bath or not cool_bath or not threshold then
		core.chat_send_player(name, S("The pressure is uneven. Check the baths and the sealed doorway."))
		return stack
	end
	core.bulk_set_node(warm_bath, {name = water})
	core.bulk_set_node(cool_bath, {name = water})
	core.bulk_set_node(threshold, {name = air})
	meta:set_int("open", 1)
	meta:set_string("infotext", S("Cold Valve Open"))
	core.chat_send_player(name, S("Both baths are running. The pressure seal releases."))
	return stack
end

local hot_fixture = fixture(S("Hot Valve"), {"default_gold_block.png", "default_steel_block.png", "default_gold_block.png"})
hot_fixture.on_rightclick = activate_hot
core.register_node(warm_valve, hot_fixture)
local cold_fixture = fixture(S("Cold Valve"), {"mcl_core_lapis_block.png", "default_steel_block.png", "mcl_core_lapis_block.png"})
cold_fixture.on_rightclick = activate_cold
core.register_node(cold_valve, cold_fixture)

mcl_expeditions.register("ruined_bathhouse", {
	title = S("Ruined Bathhouse"),
	environment = "land",
	biomes = {"Plains", "SunflowerPlains", "Meadow", "BirchForest", "Forest", "Savannah"},
	bounds = {min = V(-9, -4, -8), max = V(9, 7, 8)},
	build = function(ctx)
		ctx:fill(-9, -4, -7, 9, -1, 8, brick)
		ctx:fill(-9, 0, -8, 9, 7, 8, air)
		ctx:fill(-9, 0, -7, -9, 4, 8, cracked_brick)
		ctx:fill(9, 0, -7, 9, 4, 8, brick)
		ctx:fill(-9, 0, -7, 9, 4, -7, brick)
		ctx:fill(-9, 0, 8, 9, 4, 8, brick)
		ctx:fill(-2, 0, -8, 2, 2, -7, air)
		ctx:fill(-2, -1, -8, 2, -1, -8, cracked_brick)
		ctx:fill(-9, 5, -7, 9, 5, 8, brick)
		ctx:fill(-3, 5, -3, 3, 5, 1, glass)
		ctx:fill(5, 5, -5, 7, 5, -2, air)
		ctx:fill(-7, 5, 5, -5, 5, 7, air)
		ctx:fill(-6, 6, -6, 6, 6, -6, cracked_brick)
		ctx:fill(-4, 7, -5, 4, 7, -5, brick)
		ctx:fill(-1, 6, -6, 1, 6, -6, quartz)

		for _, side in ipairs({-1, 1}) do
			local x = side * 8
			for _, z in ipairs({-5, 0, 5}) do
				ctx:fill(x, 0, z, x, 3, z, quartz)
				ctx:set(x, 4, z, "mcl_ocean:sea_lantern")
			end
			local min_x = side < 0 and -7 or 3
			local max_x = side < 0 and -3 or 7
			ctx:fill(min_x - 1, -2, -4, max_x + 1, -1, 2, quartz)
			ctx:fill(min_x, -1, -3, max_x, -1, 1, air)
			ctx:fill(min_x + 1, 0, -5, max_x - 1, 0, -5, "mcl_stairs:slab_quartz_smooth")
			ctx:fill(side * 2, 1, 3, side * 2, 3, 4, side < 0 and fired_brick or "mcl_core:lapisblock")
		end
		ctx:fill(-8, 0, 4, 8, 4, 4, brick)
		ctx:fill(-1, 0, 4, 1, 2, 4, seal)
		ctx:set(-2, 0, 3, warm_valve)
		ctx:set(2, 0, 3, cold_valve)
		ctx:sign(0, 0, 3, S("Warm the pipes first\nThen open the cold valve"))
		ctx:sign(-3, 0, -6, S("Old Public Baths\nRestore the water"))
		ctx:chest(0, 0, 7, {"mcl_core:gold_ingot 3", "mcl_nether:quartz 6", "mcl_potions:water_breathing"})
	end,
})
