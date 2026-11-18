-- SPDX-License-Identifier: GPL-3.0-or-later
-- luacheck: globals mcl_expeditions
local S = core.get_translator(core.get_current_modname())
local V = vector.new
local register = mcl_expeditions.register

local stone = "mcl_core:stonebrick"
local mossy_stone = "mcl_core:stonebrickmossy"
local spruce = "mcl_trees:wood_spruce"
local spruce_log = "mcl_trees:tree_spruce"
local fence = "mcl_fences:spruce_fence"
local lantern = "mcl_lanterns:lantern_floor"
local glass = "mcl_core:glass"
local air = "air"

local function chart(pos, id)
	return mcl_maps.initialize_explorer_map(pos, ItemStack(id))
end

local wreck_chart = "mcl_expeditions:wreck_chart"
mcl_maps.register_explorer_map(wreck_chart, "#638096", {
	description = S("Wreck Explorer Map"),
	_explorer_map_structures = {"mcl_levelgen:shipwreck"},
	_treasure_symbol = "mcl_maps_map_icons.png^[sheet:16x16:10,0",
	_skip_existing_chunks = false,
})

local settlement_chart = "mcl_maps:city_explorer_map"
local district_charts = {
	"mcl_maps:plains_village_map",
	"mcl_maps:desert_village_map",
	"mcl_maps:savannah_village_map",
	"mcl_maps:taiga_village_map",
}

local function tell_route(player, id, from, heading)
	local origin = mcl_expeditions.nearest(id, from)
	local destination = origin and mcl_expeditions.nearest(id, from, origin)
	if destination then
		local distance = math.floor(vector.distance(from, destination) + 0.5)
		local message = S("@1 @2, @3 blocks away.", heading, core.pos_to_string(destination), distance)
		core.chat_send_player(player, message)
	else
		core.chat_send_player(player, S("There's no other surveyed stop on this route yet."))
	end
end

local caravan_post = "mcl_expeditions:caravan_route_post"
core.register_node(caravan_post, {
	description = S("Caravan Route Post"),
	tiles = {"default_wood.png^mcl_books_book_written.png", "default_wood.png", "default_wood.png^mcl_books_book_written.png"},
	groups = {handy = 1, axey = 1, not_in_creative_inventory = 1},
	_mcl_hardness = 2,
	drop = spruce,
	on_rightclick = function(pos, _, clicker, itemstack)
		tell_route(clicker:get_player_name(), "caravan_waystation", pos, S("Nearest other caravan waystation at"))
		return itemstack
	end,
})

register("caravan_waystation", {
	title = S("Caravan Waystation"),
	biomes = {"Plains", "SunflowerPlains", "Meadow", "Savannah", "SavannahPlateau", "Desert", "Taiga"},
	environment = "land",
	bounds = {min = V(-8, -3, -6), max = V(8, 5, 7)},
	build = function(ctx)
		ctx:fill(-7, -3, -5, 7, -1, 5, stone)
		ctx:fill(-7, 0, -5, 7, 3, 5, air)
		ctx:fill(-2, -1, -6, 2, -1, 7, "mcl_core:cobble")
		ctx:fill(-1, 0, -6, 1, 2, 7, air)

		-- Twin shelters frame a through-road wide enough for a horse.
		for _, side in ipairs({-1, 1}) do
			local lo = side == -1 and -7 or 3
			local hi = side == -1 and -3 or 7
			ctx:fill(lo, 0, -4, hi, 1, -4, fence)
			ctx:fill(lo, 0, 4, hi, 0, 4, fence)
			for _, x in ipairs({lo, hi}) do
				for _, z in ipairs({-4, 4}) do
					ctx:fill(x, 0, z, x, 3, z, spruce_log)
				end
			end
			ctx:fill(lo, 4, -5, hi, 4, 5, spruce)
			ctx:fill(lo + 1, 4, -4, hi - 1, 4, 4,
				side == -1 and "mcl_wool:yellow" or "mcl_wool:red")
			ctx:fill(lo + 2, 5, -4, lo + 2, 5, 4, spruce)
			ctx:set(lo + 2, 0, 4, air)
		end

		-- A fenced watering stall with a contained one-block-deep trough.
		ctx:fill(-7, 0, -3, -7, 0, 3, fence)
		ctx:fill(-3, 0, -3, -3, 0, 0, fence)
		ctx:fill(-6, 0, -3, -4, 0, -3, stone)
		ctx:fill(-6, 0, -1, -4, 0, -1, stone)
		ctx:set(-6, 0, -2, stone)
		ctx:set(-5, 0, -2, "mcl_core:water_source")
		ctx:set(-4, 0, -2, stone)
		ctx:set(-6, 0, 2, "mcl_farming:hay_block")
		ctx:set(6, 0, -2, lantern)
		ctx:set(6, 0, 3, "mcl_campfires:campfire")
		ctx:set(3, 0, 1, caravan_post)
		ctx:sign(3, 0, 3, S("Caravan Waystation\nStables across the road\nMaps in the chest\nUse post for next stop"))

		local local_chart = district_charts[ctx.pr:next(1, #district_charts)]
		ctx:chest(5, 0, -3, {
			chart(ctx.pos, settlement_chart),
			chart(ctx.pos, local_chart),
			"mcl_compass:compass",
			"mcl_farming:bread 6",
		})
	end,
})

local harness = "mcl_happy_ghast:red_harness"
local route_counter = "mcl_expeditions:harness_counter"
core.register_node(route_counter, {
	description = S("Harness Counter"),
	tiles = {"default_wood.png^mcl_happy_ghast_red_harness.png", "default_wood.png", "default_wood.png"},
	groups = {handy = 1, axey = 1, not_in_creative_inventory = 1},
	_mcl_hardness = 2,
	drop = spruce,
	on_rightclick = function(pos, _, clicker, itemstack)
		local player = clicker:get_player_name()
		local count = itemstack:get_count()
		if itemstack:get_name() ~= "mcl_core:emerald" or count < 3 then
			core.chat_send_player(player, S("Hold at least 3 emeralds and use this counter to buy a red Happy Ghast harness."))
			tell_route(player, "cliffside_air_dock", pos, S("Nearest other air dock at"))
			return itemstack
		end
		local inventory = clicker:get_inventory()
		if count == 3 then return ItemStack(harness) end
		if not inventory:room_for_item("main", harness) then
			core.chat_send_player(player, S("Make room in your inventory for the harness."))
			return itemstack
		end
		inventory:add_item("main", harness)
		itemstack:take_item(3)
		return itemstack
	end,
})

local function is_walkable(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	return def and def.walkable
end

register("cliffside_air_dock", {
	title = S("Cliffside Air Dock"),
	biomes = {"StonyPeaks", "JaggedPeaks", "FrozenPeaks", "WindsweptHills", "WindsweptGravellyHills", "WindsweptSavannah", "Meadow"},
	environment = "land",
	min_y = 60,
	bounds = {min = V(-7, -10, -5), max = V(7, 6, 12)},
	site_ok = function(pos)
		-- The rear approach should reach the ridge, while the runway
		-- extends over a drop instead of cutting through another hill.
		return is_walkable(vector.offset(pos, 0, -2, -5))
			and not is_walkable(vector.offset(pos, 0, -4, 10))
	end,
	build = function(ctx)
		ctx:fill(-7, 0, -5, 7, 6, 12, air)
		ctx:fill(-2, -1, -5, 2, -1, 0, stone)
		ctx:fill(-7, -1, -1, 7, -1, 12, spruce)
		ctx:fill(-7, -1, -1, 7, -1, -1, stone)
		-- Braced timbers hold the deck away from the rock face.
		for _, x in ipairs({-6, 6}) do
			ctx:fill(x, -10, 0, x, -2, 0, stone)
			for z = 1, 8 do
				ctx:set(x, z - 10, z, spruce_log)
			end
			ctx:fill(x, -2, 0, x, -2, 10, spruce_log)
			ctx:fill(x, 0, 0, x, 0, 10, fence)
			ctx:fill(x, 0, -3, x, 4, -3, spruce_log)
			ctx:set(x, 5, -3, lantern)
		end
		-- Two unobstructed six-block-wide landing lanes.
		for _, x in ipairs({-4, 3}) do
			ctx:fill(x, -1, 3, x, -1, 11, "mcl_wool:white")
			ctx:fill(x - 1, -1, 7, x + 1, -1, 7, "mcl_wool:white")
		end
		ctx:fill(-7, 0, -4, -3, 0, -1, stone)
		ctx:set(-5, 1, -2, route_counter)
		ctx:sign(-3, 1, -2, S("Cliffside Air Dock\nHarness for 3 emeralds\nLand on a white mark"))
		ctx:chest(5, 0, -2, {
			chart(ctx.pos, settlement_chart),
			"mcl_throwing:snowball 8",
			"mcl_farming:bread 4",
		})
		ctx:set(6, 0, 11, lantern)
		ctx:set(-6, 0, 11, lantern)
	end,
})

register("mountain_rescue_shelter", {
	title = S("Mountain Rescue Shelter"),
	biomes = {"SnowySlopes", "FrozenPeaks", "JaggedPeaks", "Grove", "SnowyTaiga", "IceSpikes", "WindsweptHills"},
	environment = "land",
	min_y = 54,
	bounds = {min = V(-6, -3, -5), max = V(6, 8, 6)},
	build = function(ctx)
		ctx:fill(-6, -3, -5, 6, -1, 5, stone)
		ctx:fill(-6, 0, -5, 6, 7, 5, air)
		ctx:fill(-4, 0, -4, 4, 3, 3, spruce)
		ctx:fill(-3, 0, -3, 3, 3, 2, air)
		ctx:fill(-4, 0, -4, 4, 0, -4, stone)
		ctx:fill(-4, 0, 3, 4, 0, 3, stone)
		for _, x in ipairs({-4, 4}) do
			ctx:fill(x, 0, -4, x, 0, 3, stone)
			ctx:fill(x, 1, -1, x, 2, 1, glass)
		end

		for offset = 0, 4 do
			local y = 4 + offset
			ctx:fill(-5 + offset, y, -5, -5 + offset, y, 4, spruce)
			ctx:fill(5 - offset, y, -5, 5 - offset, y, 4, spruce)
			if offset < 4 then
				ctx:fill(-4 + offset, y, -4, 4 - offset, y, -4, spruce)
				ctx:fill(-4 + offset, y, 3, 4 - offset, y, 3, spruce)
			end
		end
		ctx:fill(0, 8, -5, 0, 8, 4, spruce_log)
		ctx:fill(0, 0, 3, 0, 2, 5, air)
		ctx:fill(-2, -1, 4, 2, -1, 6, "mcl_core:cobble")
		for _, x in ipairs({-2, 2}) do
			ctx:set(x, 0, -3, "mcl_beds:bed_red_bottom", 0)
			ctx:set(x, 0, -2, "mcl_beds:bed_red_top", 0)
		end
		ctx:set(0, 0, -3, lantern)
		ctx:set(-2, 0, 2, lantern)

		-- Hay makes the stock campfire emit the taller rescue smoke column.
		ctx:fill(5, 0, 1, 5, 2, 1, stone)
		ctx:set(5, 3, 1, "mcl_farming:hay_block")
		ctx:set(5, 4, 1, "mcl_campfires:campfire")
		ctx:set(5, 0, 3, lantern)
		ctx:sign(2, 0, 4, S("Rescue Shelter\nBeds and supplies\nLight the brazier\nto signal friends"))
		ctx:chest(2, 0, 2, {
			"mcl_fire:flint_and_steel",
			"mcl_farming:bread 8",
			"mcl_torches:torch 8",
			chart(ctx.pos, wreck_chart),
		})
	end,
})

register("overgrown_glasshouse", {
	title = S("Overgrown Glasshouse"),
	biomes = {"FlowerForest", "BirchForest", "OldGrowthBirchForest", "Forest", "Meadow", "SparseJungle", "BambooJungle"},
	environment = "land",
	bounds = {min = V(-6, -3, -6), max = V(6, 6, 6)},
	build = function(ctx)
		ctx:fill(-6, -3, -6, 6, -1, 6, mossy_stone)
		ctx:fill(-6, 0, -6, 6, 4, 6, air)
		ctx:fill(-5, 0, -5, 5, 0, 5, stone)
		for _, z in ipairs({-6, 6}) do
			ctx:fill(-6, 0, z, 6, 0, z, stone)
			ctx:fill(-6, 1, z, 6, 3, z, glass)
		end
		for _, x in ipairs({-6, 6}) do
			ctx:fill(x, 0, -6, x, 0, 6, stone)
			ctx:fill(x, 1, -6, x, 3, 6, glass)
		end
		for offset = 0, 2 do
			local x = 6 - 2 * offset
			ctx:fill(-x, 4 + offset, -6, x, 4 + offset, 6, glass)
			for _, z in ipairs({-6, 0, 6}) do
				ctx:fill(-x, 4 + offset, z, x, 4 + offset, z, spruce_log)
			end
		end
		for _, x in ipairs({-6, 6}) do
			for _, z in ipairs({-6, 0, 6}) do
				ctx:fill(x, 1, z, x, 4, z, spruce_log)
			end
		end
		ctx:fill(-1, 0, 6, 1, 2, 6, air)
		ctx:fill(-1, 0, 6, 1, 0, 6, stone)
		ctx:fill(2, 4, -4, 4, 5, -2, air)
		ctx:fill(-6, 1, 1, -6, 2, 2, air)

		-- Stone lips contain water at floor height. Only some beds have
		-- survived, leaving usable soil and seeds for players to restore.
		ctx:fill(0, 0, -4, 0, 0, 3, "mcl_core:water_source")
		for _, x in ipairs({-4, -2, 2, 4}) do
			ctx:fill(x, 0, -4, x, 0, 3, "mcl_farming:soil_wet")
			for z = -4, 3 do
				if ctx.pr:next(1, 3) == 1 then
					ctx:set(x, 1, z, x < 0 and "mcl_farming:wheat_1" or "mcl_farming:carrot_1")
				end
			end
		end
		ctx:set(-5, 1, -5, lantern)
		ctx:set(5, 1, 4, lantern)
		ctx:set(-5, 0, 3, "mcl_lush_caves:moss")
		ctx:set(-4, 0, 4, "mcl_lush_caves:moss")
		ctx:set(-5, 1, 4, "mcl_lush_caves:azalea")
		ctx:sign(4, 1, 5, S("Overgrown Glasshouse\nSeeds in the chest\nKeep the channel full"))
		ctx:chest(5, 1, -5, {
			"mcl_core:glass 12",
			"mcl_farming:beetroot_seeds 4",
			"mcl_farming:pumpkin_seeds 3",
			"mcl_farming:melon_seeds 3",
			"mcl_lush_caves:glow_berry 3",
		})
	end,
})
