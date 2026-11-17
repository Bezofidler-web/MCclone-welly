local air = "air"
local cobble = "mcl_core:cobble"
local bricks = "mcl_core:stonebrick"
local carved = "mcl_core:stonebrickcarved"
local timber = "mcl_trees:tree_oak"
local planks = "mcl_trees:wood_oak"
local slab = "mcl_stairs:slab_oak"
local lantern = "mcl_lanterns:lantern_floor"
local chest = "mcl_chests:chest_small"
local endpoint = "mcl_villages:path_endpoint"

local function square (width, height, ground)
	local schematic = {
		size = { x = width, y = height, z = width },
		data = {},
		yslice_prob = {},
	}
	local last = width - 1
	local center = last / 2

	local function set (x, y, z, name, param2)
		schematic.data[(z * height + y) * width + x + 1] = {
			name = name,
			prob = name == "ignore" and 0 or 255,
			param2 = param2 or 0,
		}
	end

	local function layer (x1, z1, x2, z2, y, name, param2)
		for z = z1, z2 do
			for x = x1, x2 do
				set (x, y, z, name, param2)
			end
		end
	end

	for y = 0, height - 1 do
		local name = y == 0 and ground or (y <= 3 and air or "ignore")
		layer (0, 0, last, last, y, name)
	end
	set (center, 1, 0, endpoint)
	set (center, 1, last, endpoint)
	set (0, 1, center, endpoint)
	set (last, 1, center, endpoint)
	return schematic, set, layer
end

local function village_green ()
	local schematic, set, layer = square (9, 5, "mcl_core:dirt")
	local path = "mcl_core:grass_path"
	layer (0, 3, 8, 5, 0, path)
	layer (3, 0, 5, 8, 0, path)

	-- A well at the corner and a timber bell frame spanning the footpath.
	layer (0, 0, 2, 2, 1, cobble)
	set (1, 1, 1, "mcl_core:water_source")
	for _, x in ipairs ({ 2, 6 }) do
		set (x, 1, 4, cobble)
		set (x, 2, 4, timber)
		set (x, 1, 7, cobble)
		set (x, 2, 7, lantern, 1)
	end
	layer (2, 4, 6, 4, 3, planks)
	layer (2, 4, 6, 4, 4, slab)
	set (4, 2, 4, "mcl_bells:bell_ceiling")
	return schematic
end

local function town_square ()
	local schematic, set, layer = square (13, 5, cobble)
	layer (0, 5, 12, 7, 0, bricks)
	layer (5, 0, 7, 12, 0, bricks)
	layer (4, 4, 8, 8, 0, bricks)

	-- Two modest stalls leave all four routes open across the square.
	local function stall (x, z, counter_z, cloth)
		for _, post_x in ipairs ({ x, x + 3 }) do
			for _, post_z in ipairs ({ z, z + 2 }) do
				set (post_x, 1, post_z, timber)
				set (post_x, 2, post_z, timber)
				set (post_x, 3, post_z, planks)
			end
		end
		for dx = 0, 3 do
			local stripe = dx % 2 == 0 and cloth or "mcl_wool:white"
			layer (x + dx, z, x + dx, z + 2, 4, stripe)
		end
		layer (x + 1, counter_z, x + 2, counter_z, 1, "mcl_stairs:slab_oak_top")
		set (x + 1, 2, counter_z, lantern, 1)
	end
	stall (1, 1, 3, "mcl_wool:red")
	stall (8, 9, 9, "mcl_wool:yellow")
	set (3, 1, 1, chest, 2)

	for _, x in ipairs ({ 4, 8 }) do
		for _, z in ipairs ({ 4, 8 }) do
			set (x, 0, z, carved)
			set (x, 1, z, lantern, 1)
		end
	end
	set (6, 1, 6, carved)
	set (6, 2, 6, "mcl_bells:bell")
	return schematic
end

local function city_square ()
	local schematic, set, layer = square (19, 10, cobble)
	layer (0, 7, 18, 11, 0, bricks)
	layer (7, 0, 11, 18, 0, bricks)
	layer (3, 3, 15, 15, 1, bricks)
	local stair = "mcl_stairs:stair_stonebrick"
	for i = 7, 11 do
		set (i, 1, 3, stair, 0)
		set (3, 1, i, stair, 1)
		set (i, 1, 15, stair, 2)
		set (15, 1, i, stair, 3)
	end

	-- Open bell arcade on the raised plaza, with a low stepped roof.
	for _, x in ipairs ({ 6, 12 }) do
		for _, z in ipairs ({ 4, 8 }) do
			set (x, 2, z, carved)
			for y = 3, 6 do
				set (x, y, z, bricks)
			end
		end
	end
	layer (7, 6, 11, 6, 4, planks)
	set (9, 3, 6, "mcl_bells:bell_ceiling")
	layer (6, 4, 12, 8, 5, bricks)
	layer (6, 4, 12, 8, 6, air)
	for _, z in ipairs ({ 4, 8 }) do
		layer (6, z, 8, z, 6, bricks)
		layer (10, z, 12, z, 6, bricks)
	end
	layer (5, 3, 13, 9, 7, slab)
	layer (6, 4, 12, 8, 7, planks)
	layer (6, 4, 12, 8, 8, slab)
	layer (7, 5, 11, 7, 8, planks)
	layer (7, 5, 11, 7, 9, slab)
	-- The records counter opens onto the aisle through the arcade.
	set (11, 2, 7, "mcl_cartography_table:cartography_table", 1)
	set (11, 2, 8, chest, 1)

	-- A shallow stone water trough and planted bed flank the opposite end.
	layer (4, 11, 7, 13, 2, bricks)
	layer (5, 12, 6, 12, 2, "mcl_core:water_source")
	layer (11, 11, 14, 13, 2, bricks)
	layer (12, 12, 13, 12, 2, "mcl_core:dirt")
	set (12, 3, 12, "mcl_flowers:poppy")
	set (13, 3, 12, "mcl_flowers:dandelion")
	for _, x in ipairs ({ 4, 14 }) do
		set (x, 2, 6, lantern, 1)
		set (x, 2, 9, lantern, 1)
	end
	return schematic
end

return {
	village_green = village_green (),
	town_square = town_square (),
	city_square = city_square (),
}
