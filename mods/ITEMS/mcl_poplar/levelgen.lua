local tree = core.get_content_id ("mcl_trees:tree_poplar")
local shrub = core.get_content_id ("mcl_poplar:red_shrub")
local mushroom = core.get_content_id ("mcl_poplar:shelf_mushroom")
local large_mushroom = core.get_content_id ("mcl_poplar:shelf_mushroom_big")
local litter = core.get_content_id ("mcl_flowers:leaf_litter_1")
local air = core.CONTENT_AIR
local get_block = mcl_levelgen.get_block
local set_block = mcl_levelgen.set_block
local is_dirt = mcl_levelgen.is_cid_dirt

-- X and Z offsets are in the level generator's coordinates. Facedir uses Luanti's Z axis.
local sides = {
	{ 1, 0, 3 }, { -1, 0, 1 }, { 0, 1, 0 }, { 0, -1, 2 },
}

local function add_mushroom (x, y, z, rng)
	if get_block (x, y, z) ~= tree then return end
	local side = sides[1 + rng:next_within (4)]
	local x, z = x + side[1], z + side[2]
	if get_block (x, y, z) == air then
		local cid = rng:next_within (3) == 0 and large_mushroom or mushroom
		set_block (x, y, z, cid, side[3])
	end
end

local function place_fallen_poplar (x, y, z, rng)
	local dir = sides[1 + rng:next_within (4)]
	local dx, dz = dir[1], dir[2]
	local length = 3 + rng:next_within (3)
	for i = 0, length + 1 do
		local x, z = x + dx * i, z + dz * i
		if get_block (x, y, z) ~= air or not is_dirt[get_block (x, y - 1, z)] then
			return false
		end
	end
	set_block (x, y, z, tree, 0)
	for i = 2, length + 1 do
		set_block (x + dx * i, y, z + dz * i, tree, dx == 0 and 4 or 12)
	end
	add_mushroom (x + dx * 3, y, z + dz * 3, rng)
	return true
end

local centre = { place_center_x = true, place_center_z = true }
local tree_heights = { 9, 7, 10 }
local function place_poplar (_, x, y, z, _, rng)
	if not is_dirt[get_block (x, y - 1, z)] then return false end
	if rng:next_within (8) == 0 and place_fallen_poplar (x, y, z, rng) then
		return true
	end
	local tree_id = 1 + rng:next_within (9)
	local height = tree_heights[(tree_id - 1) % #tree_heights + 1]
	for dy = 0, height - 1 do
		if get_block (x, y + dy, z) ~= air then return false end
	end
	mcl_levelgen.place_schematic (x, y, z, "mcl_poplar:tree_" .. tree_id, "random", false, centre, rng)
	if rng:next_within (2) == 0 then
		add_mushroom (x, y + 2 + rng:next_within (2), z, rng)
	end
	for _, side in ipairs (sides) do
		local x, z = x + side[1] * 2, z + side[2] * 2
		if rng:next_within (2) == 0 and get_block (x, y, z) == air and is_dirt[get_block (x, y - 1, z)] then
			set_block (x, y, z, litter, rng:next_within (4))
		end
	end
	return true
end

local function place_shrub (_, x, y, z)
	if get_block (x, y, z) ~= air or not is_dirt[get_block (x, y - 1, z)] then return false end
	set_block (x, y, z, shrub, 0)
	return true
end

local function in_dappled_forest (x, y, z)
	if mcl_levelgen.index_biome (x, y, z) == "DappledForest" then
		return { x, y, z }
	end
end

local function register_feature (id, place, modifiers)
	mcl_levelgen.register_feature (id, { place = place })
	mcl_levelgen.register_configured_feature (id, { feature = id })
	mcl_levelgen.register_placed_feature (id, { configured_feature = id, placement_modifiers = modifiers })
end

local function shrub_horizontal_offset (rng) return rng:next_within (8) - rng:next_within (8) end
register_feature ("mcl_poplar:trees_dappled_forest", place_poplar, {
	mcl_levelgen.build_count (function () return 6 end),
	mcl_levelgen.build_in_square (),
	mcl_levelgen.build_surface_water_depth_filter (0),
	mcl_levelgen.build_heightmap ("motion_blocking_wg"),
	mcl_levelgen.build_in_biome (),
})

register_feature ("mcl_poplar:patch_red_shrub", place_shrub, {
	mcl_levelgen.build_in_square (),
	mcl_levelgen.build_heightmap ("motion_blocking_wg"),
	in_dappled_forest,
	mcl_levelgen.build_count (function () return 8 end),
	mcl_levelgen.build_random_offset (shrub_horizontal_offset, function () return 0 end),
	mcl_levelgen.build_heightmap ("motion_blocking_wg"),
	mcl_levelgen.build_in_biome (),
})
