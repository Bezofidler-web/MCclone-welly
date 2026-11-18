-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local register = mcl_expeditions.register
local V = vector.new
local oak = "mcl_trees:wood_oak"
local spruce = "mcl_trees:wood_spruce"
local pile = "mcl_trees:tree_spruce"
local fence = "mcl_fences:oak_fence"
local lantern = "mcl_lanterns:lantern_floor"
local cobble = "mcl_core:cobble"
local brick = "mcl_core:stonebrick"
local cracked = "mcl_core:stonebrickcracked"
local glass = "mcl_core:glass"
local iron = "mcl_core:iron_ingot"

local function water_depth(pos)
	for y = 0, 4 do
		local node = core.get_node_or_nil(vector.offset(pos, 0, y, 0))
		if not node then return end
		if core.get_item_group(node.name, "water") == 0 then
			if node.name == "air" and y >= 2 then return y end
			return
		end
	end
end

local function support(ctx, x, top, z)
	local bottom = -5
	for y = -1, -5, -1 do
		local node = core.get_node_or_nil(vector.offset(ctx.pos, x, y, z))
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable and node.name ~= "ignore" then
			bottom = y
			break
		end
	end
	ctx:fill(x, bottom, z, x, top, z, pile)
end

local function add_hut(ctx, side, deck)
	local lo, hi = side == -1 and -10 or 4, side == -1 and -4 or 10
	local outer = side * 10
	local roof = deck + 4
	ctx:fill(lo, deck + 1, -5, hi, deck + 3, 5, oak)
	ctx:fill(lo + 1, deck + 1, -4, hi - 1, deck + 3, 4, "air")
	ctx:fill(lo, roof, -5, hi, roof, 5, spruce)
	for _, x in ipairs({lo, hi}) do
		for _, z in ipairs({-5, 5}) do support(ctx, x, deck + 3, z) end
	end
	local bridge_door = side * 4
	ctx:fill(bridge_door, deck + 1, -1, bridge_door, deck + 2, 0, "air")
	ctx:fill(side * 6, deck + 1, -5, side * 6, deck + 2, -5, "air")
	ctx:fill(outer, deck + 2, -3, outer, deck + 2, -2, glass)
	ctx:fill(outer, deck + 2, 2, outer, deck + 2, 3, glass)
	ctx:fill(lo + 2, deck + 2, 5, hi - 2, deck + 2, 5, glass)

	-- Facing 0 pairs the two bed parts along +Z.
	ctx:set(side * 8, deck + 1, -3, "mcl_beds:bed_blue_bottom", 0)
	ctx:set(side * 8, deck + 1, -2, "mcl_beds:bed_blue_top", 0)
	ctx:set(side * 8, deck + 1, 3, "mcl_barrels:barrel_closed", 0)
	ctx:set(side * 5, deck + 1, 4, lantern)

	-- Outer ladders open onto a fenced roof route above the street.
	local ladder_x = side * 11
	ctx:fill(ladder_x, deck + 1, 0, ladder_x, roof, 0, "mcl_core:ladder", side == -1 and 2 or 3)
	for _, z in ipairs({-5, 5}) do
		ctx:fill(lo, roof + 1, z, hi, roof + 1, z, fence)
	end
	ctx:fill(outer, roof + 1, -4, outer, roof + 1, -1, fence)
	ctx:fill(outer, roof + 1, 1, outer, roof + 1, 4, fence)
	ctx:fill(bridge_door, roof + 1, -4, bridge_door, roof + 1, 1, fence)
	ctx:set(side * 6, roof + 1, -4, lantern)

	if mcl_vars.mobs_spawn then
		local bed = vector.offset(ctx.pos, side * 8, deck + 1, -3)
		local spawn = vector.offset(ctx.pos, side * 7, deck + 0.55, 1)
		ctx:after(function()
			local villager = core.add_entity(spawn, "mobs_mc:villager")
			local def = villager and villager:get_luaentity()
			if def then def:claim_home(bed) end
		end)
	end
end

register("floodplain_village", {
	title = S("Floodplain Village"),
	environment = "shallows",
	biomes = {"River", "Swamp", "MangroveSwamp", "LukewarmOcean", "WarmOcean", "Ocean", "Beach", "Plains", "Meadow"},
	bounds = {min = V(-11, -5, -14), max = V(11, 11, 6)},
	site_ok = function(pos)
		local depth = water_depth(pos)
		if not depth then return false end
		for _, z in ipairs({-13, -8, 0}) do
			for _, x in ipairs({-1, 1}) do
				local p = vector.offset(pos, x, depth - 1, z)
				local surface = core.get_node(p)
				if core.get_item_group(surface.name, "water") == 0
					or core.get_node(vector.offset(p, 0, 1, 0)).name ~= "air" then return false end
			end
		end
		return true
	end,
	build = function(ctx)
		local depth = water_depth(ctx.pos) or 3
		local deck = depth + 2
		for _, side in ipairs({-1, 1}) do
			local lo, hi = side == -1 and -11 or 3, side == -1 and -3 or 11
			ctx:fill(lo, deck, -6, hi, deck, 6, spruce)
			add_hut(ctx, side, deck)
			local x0, x1 = side == -1 and -6 or 3, side == -1 and -3 or 6
			ctx:fill(x0, depth - 1, -13, x1, depth - 1, -10, oak)
			for y = depth, deck do
				local z = -9 + y - depth
				ctx:fill(x0, y, z, x1, y, z, oak)
			end
			support(ctx, side * 6, depth - 1, -13)
			support(ctx, side * 6, deck - 2, -9)
			ctx:set(side * 6, depth, -13, lantern)
		end
		-- No pier interrupts the water lane through the village.
		ctx:fill(-3, deck, -1, 3, deck, 1, "mcl_stairs:slab_oak_top")
		ctx:fill(-2, deck + 1, -1, 2, deck + 1, -1, fence)
		ctx:fill(-2, deck + 1, 1, 2, deck + 1, 1, fence)
		ctx:fill(-4, deck + 4, 2, 4, deck + 4, 4, spruce)
		ctx:fill(-4, deck + 5, 2, 4, deck + 5, 2, fence)
		ctx:fill(-4, deck + 5, 4, 4, deck + 5, 4, fence)
		ctx:sign(-5, depth, -12, S("Floodplain Dock\nKeep channel clear\nLadders to roofs"), 0)
		ctx:chest(-9, deck + 1, -4, {
			"mcl_boats:boat_oak", "mcl_farming:bread 6", "mcl_fishing:fishing_rod",
		})
		ctx:chest(9, deck + 1, 3, {
			"mcl_fishing:fish_cooked 5", "mcl_torches:torch 8",
		})
	end,
})

local broken = "mcl_expeditions:damaged_quarry_cutter"
local working = "mcl_expeditions:quarry_cutter"
local products = {
	["mcl_core:andesite"] = "mcl_core:andesite_smooth",
	["mcl_core:diorite"] = "mcl_core:diorite_smooth",
	["mcl_core:granite"] = "mcl_core:granite_smooth",
	["mcl_core:stonebrick"] = "mcl_core:stonebrickcarved",
}

local function cutter_available(pos, player)
	if not player or not player:is_player() then return false end
	local name = player:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	return name
end

local machine = {
	description = S("Damaged Quarry Cutter"),
	tiles = {"mcl_stonecutter_top.png^mcl_core_andesite.png", "mcl_stonecutter_bottom.png",
		"mcl_stonecutter_side.png"},
	drop = cobble,
	is_ground_content = false,
	groups = {pickaxey = 1, deco_block = 1, not_in_creative_inventory = 1},
	sounds = mcl_sounds.node_sound_stone_defaults(),
	_mcl_hardness = 3,
	_mcl_blast_resistance = 6,
	on_rightclick = function(pos, node, player, stack)
		local name = cutter_available(pos, player)
		if not name then return stack end
		if stack:get_name() ~= iron or stack:get_count() < 3 then
			core.chat_send_player(name, S("Use 3 iron ingots to repair the quarry cutter."))
			return stack
		end
		core.swap_node(pos, {name = working, param2 = node.param2})
		if not core.is_creative_enabled(name) then stack:take_item(3) end
		core.chat_send_player(name, S("Cutter repaired. Use andesite, diorite, granite or stone bricks on it."))
		return stack
	end,
}
core.register_node(broken, machine)

core.register_node(working, table.merge(machine, {
	description = S("Quarry Cutter"),
	tiles = {"mcl_stonecutter_top.png", "mcl_stonecutter_bottom.png", "mcl_stonecutter_side.png"},
	on_rightclick = function(pos, _, player, stack)
		local name = cutter_available(pos, player)
		if not name then return stack end
		local product = products[stack:get_name()]
		if not product then
			core.chat_send_player(name, S("Use andesite, diorite, granite or stone bricks to cut decorative blocks."))
			return stack
		end
		local count = math.min(8, stack:get_count())
		local output = ItemStack(product .. " " .. count)
		if stack:get_count() == count then return output end
		local inv = player:get_inventory()
		if not inv:room_for_item("main", output) then
			core.chat_send_player(name, S("Make room in your inventory for the cut blocks."))
			return stack
		end
		local remaining = inv:add_item("main", output)
		stack:take_item(count - remaining:get_count())
		return stack
	end,
}))

register("quarry_workshop", {
	title = S("Quarry Workshop"),
	environment = "land",
	biomes = {"Plains", "Meadow", "StonyPeaks", "WindsweptHills", "WindsweptGravellyHills", "SavannahPlateau"},
	bounds = {min = V(-11, -8, -9), max = V(11, 6, 12)},
	build = function(ctx)
		ctx:fill(-9, -3, -8, 9, -1, 1, cobble)
		ctx:fill(-9, 0, -8, 9, 5, 1, "air")
		ctx:fill(-8, 0, -7, 8, 3, -7, brick)
		for _, side in ipairs({-1, 1}) do
			local x = side * 8
			ctx:fill(x, 0, -6, x, 2, 1, brick)
			ctx:fill(x, 3, -6, x, 4, 1, pile)
			for _, z in ipairs({-6, -2, 1}) do
				ctx:fill(x, 0, z, x, 4, z, pile)
			end
		end
		for z = -7, -3 do
			ctx:fill(-8, 5, z, 8, 5, z, spruce)
		end
		for _, x in ipairs({-6, 0, 6}) do
			ctx:fill(x, 4, -6, x, 4, 1, pile)
		end
		ctx:fill(-8, 5, -2, -2, 5, -1, spruce)
		ctx:fill(4, 5, -2, 8, 5, 0, spruce)
		ctx:fill(-8, -1, 2, 8, -1, 4, cobble)
		ctx:set(3, 0, -5, broken)
		ctx:set(2, 0, -6, lantern)
		ctx:set(-5, 0, -4, "mcl_core:andesite_smooth")
		ctx:set(7, 0, -6, cracked)
		ctx:set(7, 0, -5, cobble)
		ctx:sign(2, 0, -5, S("Quarry Cutter\nNeeds 3 iron\nFeed it raw rock\nOr stone bricks"), 0)
		ctx:chest(5, 0, -4, {"mcl_core:iron_ingot", "mcl_farming:bread 4", "mcl_torches:torch 8"})
		ctx:sign(-3, 0, 1, S("Old Quarry\nSteps ahead\nMind the edge"), 0)

		-- The open cut contains finite raw material. A stepped access
		-- path stays open from the workshop to the lower benches.
		local seams = {"mcl_core:andesite", "mcl_core:diorite", "mcl_core:granite"}
		ctx:fill(-10, -8, 3, 10, -7, 12, cobble)
		ctx:fill(-9, -6, 4, 9, 2, 11, "air")
		for i, stone in ipairs(seams) do
			local x = -8 + (i - 1) * 6
			ctx:fill(x, -6, 11, x + 4, -4, 11, stone)
			ctx:set(x + ctx.pr:next(0, 4), -6, 10, stone)
		end
		ctx:fill(-10, -6, 4, -10, -2, 12, cracked)
		ctx:fill(10, -6, 4, 10, -2, 12, cracked)
		ctx:fill(-10, -6, 12, 10, -2, 12, brick)
		for step = 0, 5 do
			local y, z = -1 - step, 4 + step
			ctx:fill(-1, y, z, 1, y, z, cobble)
			ctx:fill(-1, y + 1, z, 1, y + 2, z, "air")
		end
		ctx:set(-2, -6, 10, lantern)
		ctx:set(2, -6, 10, lantern)
	end,
})
