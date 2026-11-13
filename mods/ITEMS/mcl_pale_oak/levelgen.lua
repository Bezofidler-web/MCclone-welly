local air = core.CONTENT_AIR
local log = core.get_content_id ("mcl_trees:tree_pale_oak")
local leaves = core.get_content_id ("mcl_trees:leaves_pale_oak")
local heart = core.get_content_id ("mcl_pale_oak:creaking_heart_natural")
local moss = core.get_content_id ("mcl_pale_oak:pale_moss")
local carpet = core.get_content_id ("mcl_pale_oak:pale_moss_carpet")
local hanging_moss = core.get_content_id ("mcl_pale_oak:hanging_moss")
local moss_tip = core.get_content_id ("mcl_pale_oak:hanging_moss_tip")
local flower = core.get_content_id ("mcl_flowers:eyeblossom")
local get_block = mcl_levelgen.get_block
local set_block = mcl_levelgen.set_block
local is_dirt = mcl_levelgen.is_cid_dirt
local in_range = mcl_levelgen.in_range
local centre = {place_center_x = true, place_center_z = true}

local function place_groundcover (x, tree_y, z, rng)
	for y = tree_y + 3, tree_y - 5, -1 do
		if in_range (x, y - 1, z) and get_block (x, y, z) == air and is_dirt[get_block (x, y - 1, z)] then
			if rng:next_within (3) == 0 then
				set_block (x, y, z, flower, 0)
			else
				set_block (x, y - 1, z, moss, 0)
				if rng:next_within (2) == 0 then set_block (x, y, z, carpet, 0) end
			end
			return
		end
	end
end

local function place_tree (_, x, y, z, _, rng)
	local soil = get_block (x, y - 1, z)
	if soil ~= moss and not is_dirt[soil] then return false end
	for dy = 0, 5 do
		if get_block (x, y + dy, z) ~= air then return false end
	end
	local index = 1 + rng:next_within (3)
	mcl_levelgen.place_schematic (x, y, z, "mcl_pale_oak:tree_" .. index, "random", false, centre, rng)
	if rng:next_within (10) == 0 then
		for dx = -1, 1 do
			local placed = false
			for dz = -1, 1 do
				if get_block (x + dx, y + 1, z + dz) == log
						and get_block (x + dx, y + 2, z + dz) == log
						and get_block (x + dx, y + 3, z + dz) == log then
					set_block (x + dx, y + 2, z + dz, heart, 0)
					placed = true
					break
				end
			end
			if placed then break end
		end
	end
	for _ = 1, 5 do
		local xx, zz = x + rng:next_within (9) - 4, z + rng:next_within (9) - 4
		for yy = y + 10, y + 3, -1 do
			local node = get_block (xx, yy, zz)
			if (node == leaves or node == log) and get_block (xx, yy - 1, zz) == air then
				local length = 1 + rng:next_within (3)
				for dy = 1, length do
					local tip = dy == length or get_block (xx, yy - dy - 1, zz) ~= air
					set_block (xx, yy - dy, zz, tip and moss_tip or hanging_moss, 0)
					if tip then break end
				end
				break
			end
		end
	end
	for _ = 1, 6 do
		local xx, zz = x + rng:next_within (11) - 5, z + rng:next_within (11) - 5
		place_groundcover (xx, y, zz, rng)
	end
	return true
end

local function register (id)
	mcl_levelgen.register_feature (id, {place = place_tree})
	mcl_levelgen.register_configured_feature (id, {feature = id})
	mcl_levelgen.register_placed_feature (id, {
		configured_feature = id,
		placement_modifiers = {
			mcl_levelgen.build_count (function () return 16 end),
			mcl_levelgen.build_in_square (),
			mcl_levelgen.build_surface_water_depth_filter (0),
			mcl_levelgen.build_heightmap ("motion_blocking_wg"),
			mcl_levelgen.build_in_biome (),
		},
	})
end

register ("mcl_pale_oak:pale_garden_vegetation")
