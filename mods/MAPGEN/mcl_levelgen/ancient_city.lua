-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original Mineclonia layout based on Mojang's Ancient City overview:
-- https://www.minecraft.net/en-us/article/ancient-city
-- Depth, spacing and loot weights reference the released Java 26.3 data:
-- https://github.com/misode/mcmeta/tree/26.3-data/data/minecraft

local city = "mcl_levelgen:ancient_city"
local ice_box = city .. "_ice_box"

local function swift_sneak (stack, pr)
	mcl_enchanting.enchant (stack, "swift_sneak", pr:next (1, 3))
end

local function enchant_equipment (stack, pr)
	mcl_enchanting.enchant_randomly (stack, pr:next (30, 50), true, false, false, pr)
end

local function enchant_iron (stack, pr)
	mcl_enchanting.enchant_randomly (stack, pr:next (20, 39), true, false, false, pr)
end

local function freeze_stew (stack, pr)
	local effect = pr:next (1, 2) == 1 and "night_vision" or "blindness"
	stack:get_meta ():set_string ("effect", effect)
end

mcl_levelgen.register_loot_table (city, {
	{
		stacks_min = 5,
		stacks_max = 10,
		items = {
			{ itemstring = "mcl_core:apple_gold_enchanted", amount_min = 1, amount_max = 2 },
			{ itemstring = "mcl_compass:compass", weight = 2 },
			{ itemstring = "mcl_sculk:catalyst", weight = 2, amount_min = 1, amount_max = 2 },
			{ itemstring = "mcl_farming:hoe_diamond", weight = 2, wear_min = 0, wear_max = 13100,
			  func = enchant_equipment },
			{ itemstring = "mcl_mobitems:diamond_horse_armor", weight = 2 },
			{ itemstring = "mcl_mobitems:leather", weight = 2, amount_min = 1, amount_max = 5 },
			{ itemstring = "mcl_jukebox:record_13", weight = 2 },
			{ itemstring = "mcl_armor:leggings_diamond", weight = 2, func = enchant_equipment },
			{ itemstring = "mcl_books:book", weight = 3, func = swift_sneak },
			{ itemstring = "mcl_sculk:sculk", weight = 3, amount_min = 4, amount_max = 10 },
			{ itemstring = "mcl_sculk:sensor", weight = 3, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_candles:candle_1", weight = 3, amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_amethyst:amethyst_shard", weight = 3, amount_min = 1, amount_max = 15 },
			{ itemstring = "mcl_experience:bottle", weight = 3, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_lush_caves:glow_berry", weight = 3, amount_min = 1, amount_max = 15 },
			{ itemstring = "mcl_armor:leggings_iron", weight = 3, func = enchant_iron },
			{ itemstring = "mcl_sculk:echo_shard", weight = 4, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_potions:regeneration", weight = 5, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_books:book", weight = 5, func = function (stack, pr)
				mcl_enchanting.enchant_uniform_randomly (stack, { "swift_sneak", "soul_speed" }, pr)
			end },
			{ itemstring = "mcl_books:book", weight = 5, amount_min = 3, amount_max = 10 },
			{ itemstring = "mcl_mobitems:bone", weight = 5, amount_min = 1, amount_max = 15 },
			{ itemstring = "mcl_blackstone:soul_torch", weight = 5, amount_min = 1, amount_max = 15 },
			{ itemstring = "mcl_core:coal_lump", weight = 7, amount_min = 6, amount_max = 15 },
		},
	},
	{
		stacks_min = 1,
		stacks_max = 1,
		items = {
			{ nothing = true, weight = 75 },
			{ itemstring = "mcl_armor:ward", weight = 4 },
			{ itemstring = "mcl_armor:silence" },
		},
	},
})

mcl_levelgen.register_loot_table (ice_box, {
	{
		stacks_min = 4,
		stacks_max = 10,
		items = {
			{ itemstring = "mcl_sus_stew:stew", func = freeze_stew },
			{ itemstring = "mcl_farming:carrot_item_gold", amount_min = 1, amount_max = 10 },
			{ itemstring = "mcl_farming:potato_item_baked", amount_min = 1, amount_max = 10 },
			{ itemstring = "mcl_core:packed_ice", weight = 2, amount_min = 2, amount_max = 6 },
			{ itemstring = "mcl_throwing:snowball", weight = 4, amount_min = 2, amount_max = 6 },
		},
	},
})

-- The street follows Java's usual floor depth of Y=-51.
local FLOOR_Y = -51
local CITY_WIDTH = 85
local CITY_LENGTH = 105
local CITY_HEIGHT = 27
local BEDROCK_CLEARANCE = 5
local BASE_DEPTH = 7
local is_ersatz = mcl_levelgen.enable_ersatz

local function getcid (name)
	if mcl_levelgen.is_levelgen_environment then
		return core.get_content_id (name)
	end
end

local air = core.CONTENT_AIR
local bricks = getcid ("mcl_deepslate:deepslate_bricks")
local cracked = getcid ("mcl_deepslate:deepslate_bricks_cracked")
local tiles = getcid ("mcl_deepslate:deepslate_tiles")
local polished = getcid ("mcl_deepslate:deepslate_polished")
local cobble = getcid ("mcl_deepslate:deepslate_cobbled")
local reinforced = getcid ("mcl_deepslate:deepslate_reinforced")
local wool = getcid ("mcl_wool:blue")
local carpet = getcid ("mcl_wool:cyan_carpet")
local soul_lantern = getcid ("mcl_lanterns:soul_lantern_floor")
local candle = getcid ("mcl_candles:candle_lit_1")
local sculk = getcid ("mcl_sculk:sculk")
local sensor = getcid ("mcl_sculk:sensor")
local shrieker = getcid ("mcl_sculk:shrieker_natural")
local catalyst = getcid ("mcl_sculk:catalyst")
local chest = getcid ("mcl_chests:chest_small")
local packed_ice = getcid ("mcl_core:packed_ice")
local dark_oak = getcid ("mcl_trees:wood_dark_oak")
local trapdoor = getcid ("mcl_doors:trapdoor_dark_oak")
local ladder = getcid ("mcl_core:ladder")
local redstone_lamp = getcid ("mcl_redstone_lamp:lamp_off")
local lever = getcid ("mcl_lever:lever_off")

local min, max, abs = math.min, math.max, math.abs
local set_block = mcl_levelgen.set_block
local rotate_param2 = mcl_levelgen.rotate_param2
local template_transform = mcl_levelgen.template_transform
local set_loot_table = mcl_levelgen.set_loot_table

local function place_city (self, _, _, rng, chunk_x1, chunk_z1, chunk_x2, chunk_z2)
	local city_y = self.y
	local region_y1 = mcl_levelgen.placement_level_min
	local region_y2 = region_y1 + mcl_levelgen.placement_level_height - 1
	if city_y + CITY_HEIGHT < region_y1 or city_y - BASE_DEPTH > region_y2 then
		return
	end

	-- Trial chambers and strongholds may share this depth. They were
	-- placed in an earlier step, and need their rooms and access intact.
	local obstructions = {}
	for _, start in ipairs (mcl_levelgen.current_chunk_structure_starts ()) do
		if start.structure ~= city then
			for _, piece in ipairs (start.pieces) do
				if mcl_levelgen.AABB_intersect_p (self.bbox, piece.bbox)
					and mcl_levelgen.intersect_2d_p (piece.bbox, chunk_x1, chunk_z1, chunk_x2, chunk_z2) then
					obstructions[#obstructions + 1] = piece.bbox
				end
			end
		end
	end
	local function is_open (x, y, z)
		for _, box in ipairs (obstructions) do
			if x >= box[1] and y >= box[2] and z >= box[3]
				and x <= box[4] and y <= box[5] and z <= box[6] then
				return false
			end
		end
		return true
	end

	local rotation = self.rotation
	local function rotate (x, y, z)
		return template_transform (nil, x, y, z, 0, 0, nil, rotation)
	end
	local function fill (x1, y1, z1, x2, y2, z2, cid)
		local ax, ay, az = rotate (x1, y1, z1)
		local bx, by, bz = rotate (x2, y2, z2)
		local x_min, x_max = self.x + min (ax, bx), self.x + max (ax, bx)
		local z_min, z_max = self.z + min (az, bz), self.z + max (az, bz)
		for x = max (x_min, chunk_x1), min (x_max, chunk_x2) do
			for y = max (city_y + ay, region_y1), min (city_y + by, region_y2) do
				for z = max (z_min, chunk_z1), min (z_max, chunk_z2) do
					if is_open (x, y, z) then set_block (x, y, z, cid, 0) end
				end
			end
		end
	end
	local function place (x, y, z, cid, param2, loot)
		x, y, z = rotate (x, y, z)
		x, y, z = self.x + x, city_y + y, self.z + z
		if x < chunk_x1 or x > chunk_x2 or z < chunk_z1 or z > chunk_z2
			or y < region_y1 or y > region_y2 or not is_open (x, y, z) then
			return
		end
		set_block (x, y, z, cid, param2 and rotate_param2 (cid, param2, rotation) or 0)
		if loot then set_loot_table (x, y, z, rng, loot) end
	end
	local function ruin_stone (x, y, z, dense)
		local pattern = (x * 43 + y * 23 + z * 19 + self.weathering) % 13
		if pattern == 0 and not dense then return end
		local cid = pattern < 4 and cracked or bricks
		place (x, y, z, cid)
	end

	-- The cave's rough profile keeps the rim low and gives the centre
	-- room for the frame. Leave the surrounding rock in place.
	for dz = -52, 52 do
		local inset = max (0, abs (dz) - 36)
		local half = 42 - inset
		local rim = 35 - inset
		local top = 16 + (52 - abs (dz)) % 5
		fill (-half, -2, dz, half, -1, dz, cobble)
		fill (-half, 0, dz, half, top - 6, dz, air)
		fill (-rim, top - 5, dz, rim, top, dz, air)
		fill (-21, top + 1, dz, 21, top + 3, dz, air)
	end
	fill (-18, 16, -25, 18, CITY_HEIGHT, 21, air)

	-- Wool is continuous along the avenue and branching routes.
	fill (-4, -1, -50, 4, -1, 50, tiles)
	fill (-2, -1, -50, 2, -1, 50, wool)
	fill (-41, -1, -2, 41, -1, 2, tiles)
	fill (-41, -1, -1, 41, -1, 1, wool)
	for _, side in ipairs ({ -1, 1 }) do
		for _, row in ipairs ({ -30, 26 }) do
			local x = 22 * side
			fill (min (0, x), -1, row - 2, max (0, x), -1, row + 2, tiles)
			fill (min (0, x), -1, row, max (0, x), -1, row, wool)
		end
		for z = -43, 43, 10 do
			fill (5 * side, -1, z, 5 * side, 0, z, polished)
			place (5 * side, 1, z, soul_lantern, 1)
		end
		for z = -42, 43 do
			for y = 0, 3 + (z + self.weathering) % 3 do
				if abs (z) > 3 then ruin_stone (32 * side, y, z, false) end
			end
		end
	end

	-- Raised centre, head-shaped frame and sealed redstone room below it.
	fill (-13, -1, -13, 13, 1, 11, tiles)
	fill (-11, 2, -11, 11, 2, 9, polished)
	fill (-2, 2, -10, 2, 2, 11, wool)
	fill (-4, 0, 11, 4, 0, 15, bricks)
	fill (-3, 1, 11, 3, 1, 13, tiles)
	fill (-2, 2, 11, 2, 2, 11, wool)
	fill (-12, 3, -8, 12, 5, -7, bricks)
	for _, side in ipairs ({ -1, 1 }) do
		local x = 10 * side
		fill (x - 2, 4, -9, x + 2, 17, -6, bricks)
		fill (x - 1, 18, -9, x + 1, 21, -7, tiles)
		fill (8 * side, 6, -8, 8 * side, 16, -7, reinforced)
		fill (10 * side, 19, -6, 10 * side, 21, -6, reinforced)
		place (12 * side, 6, -6, soul_lantern, 1)
	end
	fill (-8, 5, -8, 8, 5, -7, reinforced)
	fill (-8, 17, -8, 8, 17, -7, reinforced)
	fill (-8, 18, -8, 8, 18, -7, bricks)
	fill (-6, -6, -9, 6, -2, 2, air)
	fill (-6, -7, -9, 6, -7, 2, tiles)
	fill (-6, -6, -10, 6, -2, -10, bricks)
	fill (-7, -6, -9, -7, -2, 2, bricks)
	fill (7, -6, -9, 7, -2, 2, bricks)
	fill (-6, -6, 3, 6, -2, 3, bricks)
	fill (5, -6, 1, 5, 2, 1, air)
	fill (6, -6, 1, 6, 2, 1, bricks)
	for y = -6, 1 do place (5, y, 1, ladder, 2) end
	place (5, 2, 1, trapdoor, 20)
	place (-3, -5, -9, redstone_lamp)
	place (-3, -5, -8, lever, 0)
	place (0, -6, -7, chest, 0, city)

	-- Broken towers, covered alleys and small loot rooms on both sides.
	for _, x in ipairs ({ -22, 22 }) do
		for _, z in ipairs ({ -30, 0, 26, 39 }) do
			local height = 3 + (x * 7 + z + self.weathering) % 5
			fill (x - 6, -1, z - 5, x + 6, -1, z + 5, tiles)
			fill (x - 4, 0, z - 4, x + 4, height, z - 4, bricks)
			for dx = -4, 4 do
				for y = 0, height do
					if abs (dx) > 1 or y > 2 then ruin_stone (x + dx, y, z + 4, y < height) end
				end
			end
			for dz = -3, 3 do
				for y = 0, height do
					if abs (dz) > 1 or y > 2 then
						ruin_stone (x - 4, y, z + dz, y < height)
						ruin_stone (x + 4, y, z + dz, y < height)
					end
				end
			end
			fill (x - 4, height, z - 4, x + 4, height, z - 2, tiles)
			fill (x - 2, 0, z + 1, x + 2, 0, z + 1, carpet)
			place (x + 2, 0, z - 2, chest, 0, city)
			place (x - 2, 0, z - 2, candle)
			place (x - 3, 0, z + 2, sensor)
			place (x + 3, 0, z + 2, shrieker)
			place (x - 1, 0, z - 3, catalyst)
		end
	end

	-- Ice-box room with its own food and ice loot.
	fill (-29, -1, -47, -15, -1, -36, packed_ice)
	fill (-29, 0, -47, -29, 4, -36, bricks)
	fill (-15, 0, -47, -15, 4, -36, bricks)
	fill (-28, 0, -47, -16, 4, -47, bricks)
	fill (-29, 4, -47, -15, 4, -36, dark_oak)
	fill (-24, -2, -44, -20, -2, -39, air)
	fill (-24, -3, -44, -20, -3, -39, packed_ice)
	place (-23, -1, -40, trapdoor, 0)
	place (-21, 0, -44, chest, 0, ice_box)
	place (-27, 0, -39, soul_lantern, 1)
	place (-17, 0, -39, sensor)
	place (-18, 0, -45, shrieker)

	-- Overgrowth breaks up the flooring beside the quiet wool paths.
	for _, x in ipairs ({ -34, -13, 13, 34 }) do
		for _, z in ipairs ({ -43, -18, 7, 18, 45 }) do
			for dx = -2, 2 do
				for dz = -2, 2 do
					if (dx * dx + dz * dz + self.weathering) % 7 < 4 then
						place (x + dx, -1, z + dz, sculk)
					end
				end
			end
			place (x, -1, z, sculk)
			place (x, 0, z, sensor)
			if (x + z) % 2 == 0 then
				place (x + 1, -1, z, sculk)
				place (x + 1, 0, z, shrieker)
			end
		end
	end
end

local function create_city_start (self, level, terrain, rng, cx, cz)
	local x, z = cx * 16 + 8, cz * 16 + 8
	local y = FLOOR_Y
	-- Built-in worlds raise the city's floor slightly so the redstone
	-- basement remains above their bedrock and basal lava.
	if is_ersatz then y = level.preset.min_y + 19 end
	if y - BASE_DEPTH < level.preset.min_y + BEDROCK_CLEARANCE
		or not mcl_levelgen.structure_biome_test (level, self, x, y, z) then
		return nil
	end
	if terrain:get_one_height (x, z) < y + CITY_HEIGHT + 8 then return nil end
	local rotation = mcl_levelgen.random_schematic_rotation (rng)
	local half_x = (CITY_WIDTH - 1) / 2
	local half_z = (CITY_LENGTH - 1) / 2
	if rotation == "90" or rotation == "270" then
		half_x, half_z = half_z, half_x
	end
	local bbox = { x - half_x, y - BASE_DEPTH, z - half_z, x + half_x, y + CITY_HEIGHT, z + half_z }
	return mcl_levelgen.create_structure_start (self, {
		{
			bbox = bbox,
			place = place_city,
			rotation = rotation,
			weathering = rng:next_within (169),
			x = x,
			y = y,
			z = z,
		},
	})
end

mcl_levelgen.register_structure (city, {
	create_start = create_city_start,
	step = mcl_levelgen.UNDERGROUND_DECORATION,
	terrain_adaptation = "none",
	biomes = { "DeepDark" },
})

mcl_levelgen.register_structure_set ("mcl_levelgen:ancient_cities", {
	structures = { city },
	placement = mcl_levelgen.build_random_spread_placement (1.0, "default", 24, 8,
							      20083232, "linear", nil, nil),
})
