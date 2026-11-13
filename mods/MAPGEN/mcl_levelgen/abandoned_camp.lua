-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original Mineclonia layout, inspired by the Wilderness Bound release notes:
-- https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3
-- Camp spacing and loot categories reference the released Java 26.3 game data.
-- https://github.com/misode/mcmeta/tree/26.3-data/data/minecraft

local camp_id = "mcl_levelgen:abandoned_camp"
local supplies_id = camp_id .. "_supplies"
local stash_id = camp_id .. "_stash"
local cushion_notify = camp_id .. "_cushion"
local cushion_item = "mcl_cushions:white"

mcl_levelgen.register_loot_table (camp_id, {
	{
		stacks_min = 4,
		stacks_max = 6,
		items = {
			{ itemstring = "mcl_bows:arrow", amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_mobitems:bone", amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_compass:compass" },
			{ itemstring = "mcl_maps:map_empty", amount_min = 1, amount_max = 2 },
			{ itemstring = "mcl_mobitems:gunpowder", amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_fishing:fishing_rod" },
			{ itemstring = "mcl_fire:flint_and_steel" },
			{ itemstring = "mcl_potions:glass_bottle", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_mobitems:leather", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_mobitems:rabbit_hide", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_mobitems:saddle" },
		},
	},
	{
		stacks_min = 2,
		stacks_max = 2,
		items = {
			{ itemstring = "mcl_bows:bow" },
			{ itemstring = "mcl_buckets:bucket_empty" },
			{ itemstring = "mcl_tools:axe_copper" },
			{ itemstring = "mcl_tools:sword_copper" },
			{ itemstring = "mcl_armor:boots_copper" },
			{ itemstring = "mcl_armor:chestplate_copper" },
			{ itemstring = "mcl_armor:leggings_copper" },
			{ itemstring = "mcl_spyglass:spyglass" },
			{ itemstring = "mcl_tools:shears" },
		},
	},
	{
		stacks_min = 1,
		stacks_max = 1,
		items = { { itemstring = "mcl_maps:abandoned_camp_map" } },
	},
})

mcl_levelgen.register_loot_table (supplies_id, {
	{
		stacks_min = 4,
		stacks_max = 8,
		items = {
			{ itemstring = "mcl_bows:arrow", amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_mobitems:bone", amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_core:bowl", amount_min = 1, amount_max = 2 },
			{ itemstring = "mcl_farming:bread", amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_core:coal_lump", amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_core:cobweb" },
			{ itemstring = "mcl_potions:glass_bottle", amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_mobitems:leather", amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_mobitems:rabbit_hide", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_mobitems:string", amount_min = 1, amount_max = 2 },
			{ itemstring = "mcl_farming:wheat_item", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_beds:straw_bed", amount_min = 2, amount_max = 4 },
			{ itemstring = cushion_item, amount_min = 1, amount_max = 2 },
		},
	},
	{
		stacks_min = 1,
		stacks_max = 1,
		items = {
			{ itemstring = "mcl_tools:axe_wood" },
			{ itemstring = "mcl_fishing:fishing_rod" },
		},
	},
})

mcl_levelgen.register_loot_table (stash_id, {
	{
		stacks_min = 2,
		stacks_max = 2,
		items = {
			{ itemstring = "mcl_core:diamond" },
			{ itemstring = "mcl_potions:healing" },
			{ itemstring = "mcl_potions:leaping" },
			{ itemstring = "mcl_potions:night_vision" },
			{ itemstring = "mcl_potions:swiftness" },
		},
	},
	{
		stacks_min = 4,
		stacks_max = 6,
		items = {
			{ itemstring = "mcl_maps:map_empty" },
			{ itemstring = "mcl_copper:copper_ingot", amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_core:gold_ingot", amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_core:iron_ingot", amount_min = 1, amount_max = 3 },
		},
	},
	{
		stacks_min = 1,
		stacks_max = 1,
		items = {
			{ itemstring = "mcl_maps:ancient_city_map" },
			{ itemstring = "mcl_maps:jungle_explorer_map" },
			{ itemstring = "mcl_maps:trial_explorer_map" },
			{ itemstring = "mcl_maps:woodland_explorer_map" },
		},
	},
})

-- Use Mineclonia's wood names and the Java camp biome palette as a reference.
local palettes = {
	BambooJungle = {"bamboo", "yellow"},
	BirchForest = {"birch", "yellow"},
	CherryGrove = {"cherry_blossom", "pink"},
	DappledForest = {"poplar", "orange"},
	FlowerForest = {"oak", "pink"},
	Forest = {"oak", "white"},
	Meadow = {"oak", "light_blue"},
	OldGrowthBirchForest = {"birch", "green"},
	OldGrowthPineTaiga = {"spruce", "brown"},
	OldGrowthSpruceTaiga = {"spruce", "grey"},
	PaleGarden = {"pale_oak", "silver"},
	Savannah = {"acacia", "yellow"},
	SnowyTaiga = {"spruce", "light_blue"},
	SparseJungle = {"jungle", "lime"},
	Swamp = {"oak", "green"},
	Taiga = {"spruce", "green"},
	WindsweptForest = {"spruce", "grey"},
	WoodedMesa = {"oak", "red"},
}

local biomes = {}
local timber = {}
local function getcid (name)
	if mcl_levelgen.is_levelgen_environment then
		return core.get_content_id (name)
	end
end
for biome, palette in pairs (palettes) do
	biomes[#biomes + 1] = biome
	local wood = palette[1]
	if not timber[wood] then
		timber[wood] = {
			fence = getcid ("mcl_fences:" .. wood .. "_fence"),
			log = getcid ("mcl_trees:tree_" .. wood),
			planks = getcid ("mcl_trees:wood_" .. wood),
		}
	end
end
table.sort (biomes)

local cid_air = core.CONTENT_AIR
local cid_dirt = getcid ("mcl_core:dirt")
local cid_coarse_dirt = getcid ("mcl_core:coarse_dirt")
local cid_path = getcid ("mcl_core:grass_path")
local cid_gravel = getcid ("mcl_core:gravel")
local cid_wool = getcid ("mcl_wool:white")
local cid_wool_stair = getcid ("mcl_stairs:stair_wool_white")
local cid_bed = getcid ("mcl_beds:straw_bed")
local cid_bed_top = getcid ("mcl_beds:straw_bed_top")
local cid_web = getcid ("mcl_core:cobweb")
local cid_campfire = getcid ("mcl_campfires:campfire")
local cid_chest = getcid ("mcl_chests:chest_small")
local cid_barrel = getcid ("mcl_barrels:barrel_closed")
local cid_lantern = getcid ("mcl_lanterns:lantern_floor")
local cid_mossy_cobble = getcid ("mcl_core:mossycobble")
local canvas_trim = {}
for biome, palette in pairs (palettes) do
	canvas_trim[biome] = getcid ("mcl_wool:" .. palette[2])
end

local set_block = mcl_levelgen.set_block
local set_loot_table = mcl_levelgen.set_loot_table
local index_heightmap = mcl_levelgen.index_heightmap
local template_transform = mcl_levelgen.template_transform
local rotate_param2 = mcl_levelgen.rotate_param2
local notify_generated = mcl_levelgen.notify_generated
local CAMP_RADIUS = 6
local MAX_CUT = 4
local MAX_TERRAIN_ADJUSTMENT = 8
local ROOF_HEIGHT = 4

if not mcl_levelgen.is_levelgen_environment then
	mcl_levelgen.register_notification_handler (cushion_notify, function (_, coords)
		local x, y, z = mcl_levelgen.level_to_minetest_position (coords[1], coords[2], coords[3])
		local pos = vector.new (x, y, z)
		core.load_area (pos, vector.offset (pos, 0, 1, 0))
		mcl_cushions.place (pos, ItemStack (cushion_item), coords[4])
	end)
end

local function place_camp (self, _, _, rng, x1, z1, x2, z2)
	local wood = timber[self.wood]
	local rotation = self.rotation
	if self.y + MAX_TERRAIN_ADJUSTMENT < mcl_levelgen.placement_level_min
		or self.y - MAX_TERRAIN_ADJUSTMENT >= mcl_levelgen.placement_level_min + mcl_levelgen.placement_level_height then
		return
	end
	local function absolute (x, y, z)
		x, y, z = template_transform (nil, x, y, z, 0, 0, nil, rotation)
		return self.x + x, self.y + y, self.z + z
	end
	local function place (x, y, z, cid, param2, loot)
		x, y, z = absolute (x, y, z)
		set_block (x, y, z, cid, param2 and rotate_param2 (cid, param2, rotation) or 0)
		if loot then
			set_loot_table (x, y, z, rng, loot)
		end
	end

	-- Prepare a small, irregular clearing around the tent and campfire.
	for x = -CAMP_RADIUS, CAMP_RADIUS do
		for z = -CAMP_RADIUS, CAMP_RADIUS do
			local px, _, pz = absolute (x, 0, z)
			if x * x + z * z <= CAMP_RADIUS * CAMP_RADIUS + 8
				and px >= x1 and px <= x2 and pz >= z1 and pz <= z2 then
				local _, ground = index_heightmap (px, pz, true)
				for y = math.max (ground, self.y - MAX_TERRAIN_ADJUSTMENT), self.y - 2 do
					set_block (px, y, pz, cid_dirt, 0)
				end
				local ground_block = cid_coarse_dirt
				if z >= 0 and math.abs (x + 1) <= 1 then
					ground_block = cid_path
				elseif ground >= self.y and (x + z * 3) % 5 == 0 then
					ground_block = cid_gravel
				end
				set_block (px, self.y - 1, pz, ground_block, 0)
				local top = math.min (ground - 1, self.y + MAX_TERRAIN_ADJUSTMENT)
				for y = self.y, math.max (self.y + ROOF_HEIGHT, top) do
					set_block (px, y, pz, cid_air, 0)
				end
			end
		end
	end

	-- White canvas on a timber frame. The open end faces the fire.
	for z = -5, -1 do
		for x = -2, 2 do
			place (x, -1, z, wood.planks)
		end
		place (-2, 1, z, cid_wool_stair, 1)
		place (-1, 2, z, cid_wool_stair, 1)
		local ridge = (z == -5 or z == -1) and canvas_trim[self.biome] or cid_wool
		place (0, 3, z, ridge)
		place (1, 2, z, cid_wool_stair, 3)
		place (2, 1, z, cid_wool_stair, 3)
	end
	for z = -5, -1, 4 do
		place (-2, 0, z, wood.fence)
		place (2, 0, z, wood.fence)
	end
	for x = -1, 1 do
		place (x, 0, -5, cid_wool)
	end
	place (0, 1, -5, cid_wool)
	place (1, 0, -2, cid_bed, 0)
	place (1, 0, -3, cid_bed_top, 0)
	place (-1, 0, -4, cid_chest, 0, camp_id)
	place (1, 1, -4, cid_web)
	place (-1, 0, -1, cid_lantern, 1)

	place (0, 0, 3, cid_campfire, 0)
	place (1, -1, 2, cid_coarse_dirt)
	local cx, cy, cz = absolute (1, -1, 2)
	notify_generated (cushion_notify, cx, cy, cz, {cx, cy, cz, math.rad (tonumber (rotation))})
	place (-3, 0, 3, wood.log, 4)
	place (-3, 0, 4, wood.log, 4)
	place (2, 0, 5, wood.log, 12)
	place (3, 0, 0, cid_barrel, 0, supplies_id)
	place (4, 0, 0, wood.fence)
	place (4, 1, 0, cid_lantern, 1)

	if self.stash then
		place (4, -2, 3, cid_chest, 0, stash_id)
		place (4, -1, 3, cid_mossy_cobble)
		place (4, 0, 3, wood.log, 12)
	end
end

local function create_camp_start (self, level, terrain, rng, cx, cz)
	local x, z = cx * 16 + 8, cz * 16 + 8
	local is_not_air = mcl_levelgen.is_not_air
	local y = terrain:get_one_height (x, z, is_not_air)
	local sea = level.preset.sea_level
	if y <= sea + 1 then return nil end
	local biome = level.preset:index_biomes_block (x, y - 1, z)
	local palette = palettes[biome]
	if not palette then return nil end

	local half_radius = CAMP_RADIUS / 2
	for dx = -CAMP_RADIUS, CAMP_RADIUS, half_radius do
		for dz = -CAMP_RADIUS, CAMP_RADIUS, half_radius do
			if (dx ~= 0 or dz ~= 0) and dx * dx + dz * dz <= CAMP_RADIUS * CAMP_RADIUS + 8 then
				local height = terrain:get_one_height (x + dx, z + dz, is_not_air)
				if height <= sea + 1 or math.abs (height - y) > MAX_CUT then
					return nil
				end
			end
		end
	end

	return mcl_levelgen.create_structure_start (self, {
		{
			bbox = {
				x - CAMP_RADIUS, y - MAX_TERRAIN_ADJUSTMENT, z - CAMP_RADIUS,
				x + CAMP_RADIUS, y + MAX_TERRAIN_ADJUSTMENT, z + CAMP_RADIUS,
			},
			place = place_camp,
			rotation = mcl_levelgen.random_schematic_rotation (rng),
			biome = biome,
			wood = palette[1],
			stash = rng:next_within (3) == 0,
			x = x,
			y = y,
			z = z,
		},
	})
end

mcl_levelgen.register_structure (camp_id, {
	create_start = create_camp_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = biomes,
})

mcl_levelgen.register_structure_set ("mcl_levelgen:abandoned_camps", {
	structures = { camp_id },
	placement = mcl_levelgen.build_random_spread_placement (1.0, "default", 37, 8,
							      91231127, "linear", nil, nil),
})
