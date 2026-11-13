-- SPDX-License-Identifier: GPL-3.0-or-later

local cid_sculk, cid_deepslate, cid_stone, cid_tuff, cid_vein
local cid_sensor, cid_shrieker, cid_catalyst
local cid_air = core.CONTENT_AIR

if mcl_levelgen.is_levelgen_environment then
	cid_sculk = core.get_content_id ("mcl_sculk:sculk")
	cid_deepslate = core.get_content_id ("mcl_deepslate:deepslate")
	cid_stone = core.get_content_id ("mcl_core:stone")
	cid_tuff = core.get_content_id ("mcl_deepslate:tuff")
	cid_vein = core.get_content_id ("mcl_sculk:vein")
	cid_sensor = core.get_content_id ("mcl_sculk:sensor")
	cid_shrieker = core.get_content_id ("mcl_sculk:shrieker_natural")
	cid_catalyst = core.get_content_id ("mcl_sculk:catalyst")
end

local function sculk_substrate (cid)
	return cid == cid_deepslate or cid == cid_tuff or cid == cid_stone
end

local function place_patch (_, x, y, z, cfg, rng)
	-- The feature environment installs its own block accessors after mod registration.
	local get_block = mcl_levelgen.get_block
	local set_block = mcl_levelgen.set_block
	local py
	-- The deepest climate cells can lie under the nearest exposed cave floor.
	for offset = 0, 28 do
		local dy = offset % 2 == 0 and offset / 2 or -(offset + 1) / 2
		if get_block (x, y + dy, z) == cid_air and sculk_substrate (get_block (x, y + dy - 1, z)) then
			py = y + dy
			break
		end
	end
	if not py then return false end
	y = py
	local converted = 0
	local rim
	for dx = -2, 2 do
		for dz = -2, 2 do
			if dx * dx + dz * dz <= 4 + rng:next_within (3) then
				for dy = -1, 1 do
					local px, py, pz = x + dx, y + dy, z + dz
					if get_block (px, py, pz) == cid_air and sculk_substrate (get_block (px, py - 1, pz)) then
						if rng:next_within (6) == 0 and (dx ~= 0 or dz ~= 0) then
							set_block (px, py, pz, cid_vein, 1)
						else
							set_block (px, py - 1, pz, cid_sculk, 0)
							converted = converted + 1
							if dx * dx + dz * dz >= 4 then rim = {x = px, y = py, z = pz} end
						end
						break
					end
				end
			end
		end
	end
	local growth = rng:next_within (cfg.rare_growth_denominator)
	if rim and converted >= 12 and growth < 5 then
		set_block (rim.x, rim.y, rim.z, cid_sensor, 0)
		set_block (x, y, z, cid_shrieker, 0)
	elseif growth < 2 then
		set_block (x, y, z, cid_shrieker, 0)
	elseif growth < 5 then
		set_block (x, y, z, cid_sensor, 0)
	elseif growth < 8 then
		set_block (x, y, z, cid_catalyst, 0)
	end
	return true
end

mcl_levelgen.register_feature ("mcl_sculk:sculk_patch", {place = place_patch})

for _, entry in ipairs ({
	{"mcl_sculk:sculk_patch_ancient_city", 6},
	{"mcl_sculk:sculk_patch_deep_dark", 13},
}) do
	mcl_levelgen.register_configured_feature (entry[1], {
		feature = "mcl_sculk:sculk_patch",
		rare_growth_denominator = entry[2],
	})
end

local function attempt_count () return 128 end

mcl_levelgen.register_placed_feature ("mcl_sculk:sculk_patch_deep_dark", {
	configured_feature = "mcl_sculk:sculk_patch_deep_dark",
	placement_modifiers = {
		mcl_levelgen.build_count (attempt_count),
		mcl_levelgen.build_in_square (),
		mcl_levelgen.build_height_range (mcl_levelgen.uniform_height (mcl_levelgen.overworld_preset.min_y, 0)),
		mcl_levelgen.build_in_biome (),
	},
})

-- Sculk patches also place veins. This keeps the original biome entry valid.
mcl_levelgen.register_feature ("mcl_sculk:sculk_vein_only", {place = function () return false end})
mcl_levelgen.register_configured_feature ("mcl_sculk:sculk_vein_only", {feature = "mcl_sculk:sculk_vein_only"})
mcl_levelgen.register_placed_feature ("mcl_sculk:sculk_vein", {
	configured_feature = "mcl_sculk:sculk_vein_only",
	placement_modifiers = {},
})
