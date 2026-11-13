-- SPDX-License-Identifier: GPL-3.0-or-later

-- Sulfur and cinnabar outcrops exposed in existing caves on both map generators.
local floor_nodes = {"mcl_core:stone", "mcl_deepslate:deepslate", "mcl_deepslate:tuff"}
local sulfur = "mcl_sulfur:sulfur"
local cinnabar = "mcl_sulfur:cinnabar"
local air = core.CONTENT_AIR
local substrates = {}
for _, name in ipairs (floor_nodes) do substrates[core.get_content_id (name)] = true end
local sulfur_id, cinnabar_id = core.get_content_id (sulfur), core.get_content_id (cinnabar)
local native_min_y = core.ipc_get ("mcl_sulfur_cube:native_min_y")
local data = {}

local function paint_floor (get, set, x, y, z, lower, upper, next_int)
	for dx = -4, 4 do
		for dz = -4, 4 do
			if dx * dx + dz * dz <= 15 + next_int () then
				for dy = -2, 2 do
					local bx, by, bz = x + dx, y + dy, z + dz
					if by >= lower and by <= upper and substrates[get (bx, by, bz)]
						and get (bx, by + 1, bz) == air then
						set (bx, by, bz, dz % 4 == 0 and cinnabar_id or sulfur_id, 0)
						break
					end
				end
			end
		end
	end
end

-- Keep changes within the generated chunk. Coal, ores, structures and liquids are untouched.
if native_min_y then
	core.register_on_generated (function (vm, minp, maxp, seed)
		local lower = math.max (minp.y, native_min_y + 9)
		local upper = math.min (maxp.y - 2, -25)
		if lower > upper or maxp.x - minp.x < 8 or maxp.z - minp.z < 8 then return end
		local rng = PcgRandom (seed, 916733)
		if rng:next (1, 3) ~= 1 then return end
		vm:get_data (data)
		local emin, emax = vm:get_emerged_area ()
		local area = VoxelArea (emin, emax)
		local replaced = false
		local function get (x, y, z) return data[area:index (x, y, z)] end
		local function set (x, y, z, cid)
			data[area:index (x, y, z)] = cid
			replaced = true
		end
		local function random () return rng:next (0, 4) end
		for _ = 1, 48 do
			local x = rng:next (minp.x + 4, maxp.x - 4)
			local z = rng:next (minp.z + 4, maxp.z - 4)
			for py = upper, lower, -1 do
				if substrates[get (x, py, z)] and get (x, py + 1, z) == air and get (x, py + 2, z) == air then
					paint_floor (get, set, x, py, z, lower, upper, random)
					break
				end
			end
			if replaced then break end
		end
		if replaced then vm:set_data (data) end
	end)
	return
end

local id = "mcl_sulfur_cube:cave_outcrop"
local function place_outcrop (_, x, y, z, _, rng)
	local get = mcl_levelgen.get_block
	local set = mcl_levelgen.set_block
	for py = y, y - 8, -1 do
		if substrates[get (x, py, z)] and get (x, py + 1, z) == air and get (x, py + 2, z) == air then
			paint_floor (get, set, x, py, z, y - 10, y + 2, function () return rng:next_within (5) end)
			return true
		end
	end
	return false
end

mcl_levelgen.register_feature (id, {place = place_outcrop})
mcl_levelgen.register_configured_feature (id, {feature = id})
mcl_levelgen.register_placed_feature (id, {
	configured_feature = id,
	placement_modifiers = {
		mcl_levelgen.build_count (function (rng) return rng:next_within (4) == 0 and 14 or 0 end),
		mcl_levelgen.build_in_square (),
		mcl_levelgen.build_height_range (mcl_levelgen.uniform_height (-54, 37)),
		mcl_levelgen.build_in_biome (),
	},
})

local caves = {}
for biome, def in pairs (mcl_levelgen.registered_biomes) do
	local ores = def.features[7]
	if biome ~= "DeepDark" and def.groups.is_overworld and ores and table.indexof (ores, "mcl_levelgen:disk_sand") ~= -1 then
		caves[#caves + 1] = biome
	end
end
mcl_levelgen.generate_feature (id, "mcl_levelgen:disk_sand", caves, 7)
