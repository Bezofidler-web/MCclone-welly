-- SPDX-License-Identifier: GPL-3.0-or-later
local definitions = mcl_expeditions.definitions
local storage = core.get_mod_storage()
local candidates = {}
local levelgen = mcl_levelgen.levelgen_enabled
local water_level = tonumber(core.get_mapgen_setting("water_level")) or 1
local protected = levelgen and mcl_levelgen.is_protected_chunk
local obstruction = {
	"group:chest", "group:bed", "group:sign", "group:connect_to_raillike", "group:wood",
	"mcl_core:stonebrick", "mcl_core:brick_block", "mcl_nether:nether_brick",
	"mcl_end:end_bricks", "mcl_end:purpur_block",
}

core.register_on_mods_loaded(function()
	local ids = {}
	for id in pairs(definitions) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		if not mcl_structures.is_disabled(id) then
			local def = definitions[id]
			def.matches_biome = mcl_biome_dispatch.make_biome_test(def.biomes)
			candidates[#candidates + 1] = def
		end
	end
end)

local function terrain(name)
	return name == "mcl_core:stone" or name == "mcl_core:gravel"
		or name == "mcl_core:snowblock" or name == "mcl_core:clay"
		or core.get_item_group(name, "soil") > 0
		or core.get_item_group(name, "sand") > 0
end

local function environment(name, floor_name, dimension)
	if dimension == "nether" then
		if name == "air" and core.get_item_group(floor_name, "lava") > 0 then return "lava" end
	elseif dimension == "end" then
		if name == "air" and floor_name == "mcl_end:end_stone" then return "end" end
	elseif terrain(floor_name) then
		if core.get_item_group(name, "water") > 0 then return "sea" end
		if name == "air" or core.get_item_group(name, "snow_cover") > 0 then return "land" end
	end
end

local function open_shallows(pos)
	for depth = 0, 4 do
		local liquid = core.get_node(vector.offset(pos, 0, depth, 0)).name
		if core.get_item_group(liquid, "water") == 0 then
			return depth >= 2 and liquid == "air" and mcl_weather.is_outdoor(vector.offset(pos, 0, depth, 0))
		end
	end
	return false
end

local function dice(pr, lo, hi)
	return lo == hi and lo or pr:next(lo, hi)
end

local function has_surface_support(lo, hi)
	local supported = 0
	for _, x in ipairs({lo.x + 1, hi.x - 1}) do
		for _, z in ipairs({lo.z + 1, hi.z - 1}) do
			local node = core.get_node(vector.new(x, lo.y - 1, z))
			local def = core.registered_nodes[node.name]
			if def and def.walkable then supported = supported + 1 end
		end
	end
	return supported >= 3
end

local function validate_area(def, pos, minp, maxp)
	local lo = vector.add(pos, def.bounds.min)
	local hi = vector.add(pos, def.bounds.max)
	if lo.x < minp.x or lo.y < minp.y or lo.z < minp.z or hi.x > maxp.x or hi.z > maxp.z then
		return false
	end
	local overflow = hi.y > maxp.y
	if overflow and def.environment ~= "end" then return false end
	if protected then
		local function start(n) return math.floor(n / 16) * 16 end
		for z = start(lo.z), hi.z, 16 do
			for y = start(lo.y), hi.y, 16 do
				for x = start(lo.x), hi.x, 16 do
					if protected(vector.new(x, y, z)) then return false, true end
				end
			end
		end
	end
	if overflow then
		local air_min = vector.new(lo.x, maxp.y + 1, lo.z)
		-- Towers can project above a chunk seam once the upper chunk has
		-- generated. Leave anything already built in that volume alone.
		if (not protected and not mcl_vars.is_generated(air_min))
			or not core.compare_block_status(air_min, "loaded")
			or not core.compare_block_status(hi, "loaded") then
			return false, true
		end
		local count = (hi.x - lo.x + 1) * (hi.y - maxp.y) * (hi.z - lo.z + 1)
		if #core.find_nodes_in_area(air_min, hi, {"air"}) ~= count then return false end
	end
	if #core.find_nodes_in_area(lo, hi, obstruction) > 0 then return false end

	if def.environment == "lava" then
		-- Keep both ends and the marked crossing over a body of lava.
		for x = -10, 10, 5 do
			local p = vector.offset(pos, x, -1, 0)
			if core.get_item_group(core.get_node(p).name, "lava") == 0
				or core.get_node(vector.offset(p, 0, 4, 0)).name ~= "air" then
				return false
			end
		end
	elseif def.environment == "sea" then
		local above = vector.offset(pos, 0, math.max(2, def.bounds.max.y - 1), 0)
		if core.get_item_group(core.get_node(above).name, "water") == 0 then return false end
	elseif def.environment == "shallows" then
		if not open_shallows(pos) then return false end
	elseif def.bounds.min.y >= -6 and (lo.y <= minp.y or not has_surface_support(lo, hi)) then
		return false
	end
	if def.site_ok and not def.site_ok(pos) then return false end
	return true
end

local function generate(minp, maxp, blockseed, retry)
	if #candidates == 0 or maxp.x - minp.x < 28 or maxp.z - minp.z < 28 then return end
	local nether_y = mcl_vars.mg_lava_nether_max
	local end_y = mcl_vars.mg_end_min
	local dimension, low, high = "overworld", water_level - 52, 240
	if minp.y <= nether_y + 3 and maxp.y >= nether_y - 3 then
		dimension, low, high = "nether", nether_y - 2, nether_y + 3
	elseif minp.y <= end_y + 180 and maxp.y >= end_y + 24 then
		dimension, low, high = "end", end_y + 24, end_y + 180
	end
	local ymin = math.max(minp.y + 1, low)
	local ymax = math.min(maxp.y, high)
	if ymin > ymax then return end

	local pr = PcgRandom(blockseed)
	if pr:next(1, 5) ~= 1 then return end
	local key = "chunk/" .. core.pos_to_string(minp)
	if storage:get_int(key) == 1 then return end
	local waiting = false
	local shallow_min, shallow_max = math.max(ymin, water_level - 8), math.min(ymax, water_level + 8)
	local coast_columns = dimension == "overworld" and shallow_min <= shallow_max and 25 or 0
	local margin_x, margin_z = minp.x + 14, minp.z + 14
	local usable_x, usable_z = maxp.x - 14 - margin_x, maxp.z - 14 - margin_z
	local shores = PcgRandom(blockseed)
	for attempt = 1, coast_columns + 3 do
		-- Spread the shallow-water search across the chunk before a site on
		-- land or in deeper water claims it.
		local shallow_only = attempt <= coast_columns
		local scan_min, scan_max = ymin, ymax
		local x, z
		if shallow_only then
			local column, row = (attempt - 1) % 5, math.floor((attempt - 1) / 5)
			x = margin_x + math.floor((column + shores:next(0, 100) / 100) * usable_x / 5)
			z = margin_z + math.floor((row + shores:next(0, 100) / 100) * usable_z / 5)
			scan_min, scan_max = shallow_min, shallow_max
		else
			x = dice(pr, margin_x, margin_x + usable_x)
			z = dice(pr, margin_z, margin_z + usable_z)
		end
		if dimension == "end" and x * x + z * z < 1000 * 1000 then return end
		local first = (shallow_only and shores or pr):next(1, #candidates)
		for y = scan_max, scan_min, -1 do
			local pos = vector.new(x, y, z)
			local node = core.get_node_or_nil(pos)
			if not node or node.name == "ignore" or (protected and protected(pos)) then
				waiting = waiting or levelgen
			else
				local mode = environment(node.name, core.get_node(vector.offset(pos, 0, -1, 0)).name, dimension)
				if mode and (not shallow_only or mode == "sea")
					and (mode ~= "land" or mcl_weather.is_outdoor(pos)) then
					local biome = mcl_biome_dispatch.get_biome_name(pos)
					for i = 0, #candidates - 1 do
						local def = candidates[(first + i - 1) % #candidates + 1]
						local compatible = def.environment == mode
							or (mode == "sea" and def.environment == "shallows")
						if compatible and (not shallow_only or def.environment == "shallows")
							and y >= (def.min_y or -math.huge)
							and y <= (def.max_y or math.huge) and def.matches_biome(biome) then
							local ok, pending = validate_area(def, pos, minp, maxp)
							if ok then
								local placed, result = pcall(mcl_expeditions.place, def.id, pos, pr)
								if placed and result then
									storage:set_int(key, 1)
								elseif not placed then
									core.log("error", "[mcl_expeditions] " .. def.id .. ": " .. tostring(result))
								end
								return
							end
							waiting = waiting or pending
						end
					end
					-- Do not place a second land building lower beneath this surface.
					break
				end
			end
		end
	end
	if waiting and retry < 5 then
		core.after(2 ^ (retry + 1), generate, minp, maxp, blockseed, retry + 1)
	end
end

mcl_mapgen_core.register_engine_generator(function(minp, maxp, blockseed)
	-- Native levelgen initially exposes proto chunks. Never build into a block
	-- that still belongs to its terrain completion queue.
	if levelgen then
		core.after(2, generate, vector.copy(minp), vector.copy(maxp), blockseed, 1)
	else
		generate(minp, maxp, blockseed, 0)
	end
end)
