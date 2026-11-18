-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local register = mcl_expeditions.register
local brick = "mcl_core:stonebrick"
local moss = "mcl_core:stonebrickmossy"
local carved = "mcl_core:stonebrickcarved"
local stone = "mcl_core:stone"
local glass = "mcl_core:glass"
local water = "mcl_core:water_source"
local prismarine = "mcl_ocean:prismarine_brick"
local dark_prismarine = "mcl_ocean:prismarine_dark"
local lamp = "mcl_ocean:sea_lantern"
local iron = "mcl_core:iron_ingot"
local gate = "mcl_expeditions:copper_bulkhead"
local repair = "mcl_expeditions:broken_lock_winch"
local vent = "mcl_expeditions:observatory_vent"

local function stone_fixture(description, tiles)
	return {
		description = description,
		tiles = tiles,
		is_ground_content = false,
		groups = {pickaxey = 1, building_block = 1, not_in_creative_inventory = 1},
		sounds = mcl_sounds.node_sound_stone_defaults(),
		_mcl_hardness = 2,
		_mcl_blast_resistance = 6,
	}
end

core.register_node(gate, stone_fixture(S("Copper Bulkhead"), {
	"mcl_copper_block_cut.png", "mcl_copper_block_cut.png", "mcl_copper_exposed_cut.png",
}))
local vent_def = stone_fixture(S("Observatory Upwelling Vent"), {"mcl_ocean_sea_lantern.png"})
vent_def.light_source = 8
core.register_node(vent, vent_def)

local vent_elapsed = 0
core.register_globalstep(function(dtime)
	vent_elapsed = vent_elapsed + dtime
	if vent_elapsed < 0.2 then return end
	vent_elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = vector.round(player:get_pos())
		if player:get_hp() > 0 and not player:get_attach() and player:get_velocity().y < 1.6
			and not player:get_player_control().sneak
			and core.get_item_group(core.get_node(pos).name, "water") > 0 then
			local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
			if below == vent or below == water and core.get_node(vector.offset(pos, 0, -2, 0)).name == vent then
				player:add_velocity(vector.new(0, 0.55, 0))
			end
		end
	end
end)

-- These fixtures control only their own generated bulkhead. Missing gate
-- blocks are harmless, and they never overwrite a replacement block.
local function open_bulkhead(player, control, first, last, waterline)
	local name = player:get_player_name()
	if core.is_protected(control, name) then
		core.record_protection_violation(control, name)
		return false
	end
	local swaps = {}
	for x = first.x, last.x do
		for y = first.y, last.y do
			for z = first.z, last.z do
				local pos = vector.new(x, y, z)
				local node = core.get_node_or_nil(pos)
				if not node then return false end
				if node.name == gate then
					if core.is_protected(pos, name) then
						core.record_protection_violation(pos, name)
						return false
					end
					swaps[#swaps + 1] = pos
				end
			end
		end
	end
	for _, pos in ipairs(swaps) do
		core.set_node(pos, {name = pos.y <= waterline and water or "air"})
	end
	return #swaps
end

local valves = {
	"mcl_expeditions:ebb_valve",
	"mcl_expeditions:anchor_valve",
	"mcl_expeditions:flood_valve",
}
local order = {1, 3, 2}
local valve_desc = {S("Ebb Valve"), S("Anchor Valve"), S("Flood Valve")}
local valve_tiles = {
	"mcl_core_lapis_block.png",
	"default_steel_block.png",
	"default_gold_block.png",
}

local function turn_valve(pos, player, index, itemstack)
	if not player or not player:is_player() then return itemstack end
	local name = player:get_player_name()
	local root = vector.offset(pos, 1 - index, 0, 0)
	local first = vector.offset(root, 3, -4, 5)
	local last = vector.offset(first, 2, 3, 0)
	if core.is_protected(pos, name) or core.is_protected(root, name) then return itemstack end
	for i, valve in ipairs(valves) do
		if core.get_node(vector.offset(root, i - 1, 0, 0)).name ~= valve then return itemstack end
	end
	local meta = core.get_meta(root)
	local stage = meta:get_int("valve_stage")
	if stage >= #order then
		core.chat_send_player(name, S("The smuggler's watergate is already open."))
	elseif index ~= order[stage + 1] then
		meta:set_int("valve_stage", index == order[1] and 1 or 0)
		core.chat_send_player(name, S("The valves rattle and the pressure resets."))
	elseif stage == #order - 1 then
		if open_bulkhead(player, root, first, last, first.y + 1) then
			meta:set_int("valve_stage", #order)
			core.chat_send_player(name, S("The smuggler's watergate opens."))
		end
	else
		meta:set_int("valve_stage", stage + 1)
		core.chat_send_player(name, S("The valve holds its pressure."))
	end
	return itemstack
end

for i, valve in ipairs(valves) do
	local index = i
	local def = stone_fixture(valve_desc[i], {valve_tiles[i]})
	def.on_rightclick = function(pos, _, player, itemstack)
		return turn_valve(pos, player, index, itemstack)
	end
	core.register_node(valve, def)
end

local winch = stone_fixture(S("Broken Canal Winch"), {"default_steel_block.png", "default_steel_block.png",
	"mcl_copper_exposed_cut.png"})
winch.on_rightclick = function(pos, _, player, stack)
	if not player or not player:is_player() then return stack end
	local name = player:get_player_name()
	local meta = core.get_meta(pos)
	if meta:get_int("repaired") == 1 then
		core.chat_send_player(name, S("The winch is repaired and the canal is open."))
	elseif stack:get_name() ~= iron or stack:get_count() < 3 then
		core.chat_send_player(name, S("Use three iron ingots on the winch to repair it."))
	else
		local first = vector.offset(pos, 1, -3, 2)
		local last = vector.offset(first, 4, 4, 0)
		local opened = open_bulkhead(player, pos, first, last, first.y + 1)
		if opened then
			meta:set_int("repaired", 1)
			meta:set_string("infotext", S("Repaired Canal Winch"))
			if opened > 0 and not core.is_creative_enabled(name) then stack:take_item(3) end
			core.chat_send_player(name, S("The gate rises. A boat can now pass through the lock."))
		end
	end
	return stack
end
core.register_node(repair, winch)

register("flooded_observatory", {
	title = S("Flooded Observatory"),
	environment = "sea",
	biomes = {"Ocean", "DeepOcean", "ColdOcean", "DeepColdOcean", "LukewarmOcean",
		"DeepLukewarmOcean", "WarmOcean"},
	bounds = {min = vector.new(-8,-3,-9), max = vector.new(8,8,7)},
	build = function(ctx)
		-- Stepped octagonal dome. Its only opening is below the dry platforms.
		for x = -7, 7 do
			for z = -6, 6 do
				local edge = math.max(math.abs(x), math.abs(z))
				local diagonal = math.abs(x) + math.abs(z)
				if diagonal <= 10 then
					for y = -3, 5 do
						local wall = edge == 7 or math.abs(z) == 6 or diagonal == 10
						local node = y < 0 and dark_prismarine
							or (wall or y == 5) and (y >= 2 and glass or prismarine)
							or y <= 1 and water or "air"
						if y == 2 and wall then node = prismarine end
						ctx:set(x,y,z,node)
					end
				end
			end
		end
		ctx:fill(-5,6,-4,5,6,4,glass)
		ctx:fill(-3,7,-2,3,7,2,glass)
		ctx:set(0,8,0,lamp)
		ctx:fill(-2,-3,-9,2,-1,-6,prismarine)
		ctx:fill(-2,2,-9,2,2,-6,prismarine)
		ctx:fill(-2,0,-9,-2,1,-6,prismarine)
		ctx:fill(2,0,-9,2,1,-6,prismarine)
		ctx:fill(-1,0,-9,1,1,-6,water)
		ctx:set(-2,1,-9,lamp)
		ctx:set(2,1,-9,lamp)
		-- Two dry ledges face a deep pool. Divers can surface at either ledge
		-- without closing a door behind them.
		for _, x in ipairs({-4, 4}) do
			ctx:fill(x-1,0,-2,x+1,1,3,dark_prismarine)
			ctx:set(x,1,-2,lamp)
			ctx:set(x,1,3,lamp)
		end
		ctx:fill(-3,1,3,3,1,3,prismarine)
		ctx:set(0,-1,-3,vent)
		ctx:set(0,-1,1,vent)
		ctx:sign(-4,2,-1,S("Air above\nExit below"),0)
		ctx:chest(4,2,2,{
			"mcl_mobitems:nautilus_shell",
			"mcl_potions:water_breathing",
			"mcl_ocean:prismarine_crystals " .. ctx.pr:next(3,7),
			"mcl_core:iron_ingot 3",
		})
		ctx:chest(-4,2,2,{"mcl_fishing:fish_cooked 3", "mcl_ocean:sea_lantern 2"})
	end,
})

register("tide_locked_smuggler_cave", {
	title = S("Tide-Locked Smuggler Cave"),
	environment = "land",
	biomes = {"Beach", "StonyShore", "SnowyBeach", "Swamp", "MangroveSwamp"},
	max_y = 35,
	bounds = {min = vector.new(-8,-10,-9), max = vector.new(8,2,10)},
	build = function(ctx)
		local sandstone = "mcl_core:sandstone"
		-- The stair winds down to a dry valve room facing a flooded cut.
		ctx:fill(-8,-10,-3,8,-4,10,stone)
		ctx:fill(-6,-9,-2,6,-5,9,"air")
		for x = -5, 5 do
			for z = -1, 8 do
				if ctx.pr:next(1,5) == 1 then ctx:set(x,-10,z,moss) end
				if ctx.pr:next(1,8) == 1 then ctx:set(x,-4,z,sandstone) end
			end
		end
		for step = 0, 8 do
			local z = -9 + step
			local y = -step
			ctx:fill(-5,y-2,z,-1,y-2,z,sandstone)
			ctx:fill(-4,y-1,z,-2,2,z,"air")
		end
		ctx:fill(-4,-9,-2,-2,-5,0,"air")
		ctx:set(-5,-1,-9,moss)
		ctx:set(-5,-1,-8,moss)
		ctx:set(-1,-1,-8,moss)
		ctx:set(-5,-2,-7,lamp)
		ctx:set(-1,-2,-7,lamp)
		ctx:fill(-5,-9,2,5,-8,8,water)
		ctx:fill(-6,-9,1,6,-8,1,moss)
		-- The exposed opening is flooded. A quieter route through the rock
		-- reaches the valve room on foot.
		ctx:fill(2,-7,2,6,-1,5,sandstone)
		ctx:fill(3,-9,3,5,-1,4,water)
		ctx:fill(3,0,3,5,2,4,"air")
		ctx:set(2,0,2,lamp)
		ctx:sign(6,0,2,S("High tide\nDry steps west"),0)
		ctx:fill(-6,-9,5,6,-5,5,brick)
		ctx:fill(1,-9,5,3,-6,5,gate)
		ctx:fill(-2,-9,0,0,-6,0,carved)
		for i, valve in ipairs(valves) do
			ctx:set(i-3,-5,0,valve)
		end
		ctx:sign(-3,-7,1,S("First the ebb\nThen the flood\nAnchor last"),0)
		ctx:set(-5,-6,2,lamp)
		ctx:set(5,-7,7,lamp)
		ctx:fill(-1,-9,7,4,-8,9,brick)
		ctx:chest(2,-7,8,{"mcl_core:gold_ingot " .. ctx.pr:next(4,7),
			"mcl_mobitems:nautilus_shell", "mcl_core:emerald 2", "mcl_torches:torch 8"})
	end,
})

register("buried_canal_lock", {
	title = S("Buried Canal Lock"),
	environment = "land",
	biomes = {"River", "Plains", "Savannah", "Meadow", "Swamp", "Forest"},
	max_y = 60,
	bounds = {min = vector.new(-9,-14,-14), max = vector.new(9,2,14)},
	build = function(ctx)
		-- A wide, level canal has enough clearance for both ordinary boats
		-- and rafts. Walkways let players reach the chamber without swimming.
		ctx:fill(-8,-14,-10,8,-7,12,brick)
		ctx:fill(-7,-12,-9,7,-8,11,"air")
		ctx:fill(-3,-13,-9,3,-13,11,water)
		ctx:fill(-3,-12,-9,3,-12,11,water)
		ctx:fill(-7,-13,-9,-4,-11,11,moss)
		ctx:fill(4,-13,-9,7,-11,11,moss)
		for z = -8, 10, 6 do
			ctx:set(-6,-8,z,lamp)
			ctx:set(6,-8,z,lamp)
			ctx:fill(-8,-10,z,-8,-8,z,carved)
			ctx:fill(8,-10,z,8,-8,z,carved)
		end
		-- Switchback from the surface to the upstream landing.
		for step = 0, 10 do
			local z = -14 + step
			local y = -step
			ctx:fill(-7,y-1,z,-5,y-1,z,brick)
			ctx:fill(-7,y,z,-5,2,z,"air")
		end
		ctx:fill(-7,-10,-8,-5,-8,-4,"air")
		ctx:set(-8,0,-13,lamp)
		ctx:set(-4,0,-13,lamp)
		ctx:set(-8,-1,-14,moss)
		ctx:sign(-8,0,-14,S("Old canal lock\nAccess stairs"),0)
		ctx:fill(-7,-12,1,7,-8,1,brick)
		ctx:fill(-3,-13,1,3,-10,1,brick)
		ctx:fill(-2,-13,1,2,-9,1,gate)
		ctx:set(-3,-10,-1,repair)
		ctx:set(-3,-11,-1,carved)
		ctx:sign(-5,-10,-1,S("Winch broken\nNeeds 3 iron"),0)
		ctx:chest(-6,-10,-6,{"mcl_boats:boat_oak", "mcl_core:iron_ingot 3", "mcl_torches:torch 8"})
		ctx:chest(6,-10,7,{"mcl_core:gold_ingot " .. ctx.pr:next(3,6),
			"mcl_core:emerald 2", "mcl_boats:boat_oak_chest", "mcl_core:iron_ingot 2"})
	end,
})
