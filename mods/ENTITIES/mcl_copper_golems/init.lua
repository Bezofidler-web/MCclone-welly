-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_copper_golems")
local modpath = core.get_modpath ("mcl_copper_golems")
local states = {"", "_exposed", "_weathered", "_oxidized"}
local prefixes = {"", "Exposed ", "Weathered ", "Oxidised "}
local mob = "mobs_mc:copper_golem"
local chest = "mcl_copper_golems:copper_chest"
local statue = "mcl_copper_golems:copper_golem_statue"
local honeycomb = "mcl_honey:honeycomb"

local function take_one (stack, player)
	if not core.is_creative_enabled (player:get_player_name ()) then
		stack:take_item ()
	end
	return stack
end

local function scrape (stack, player)
	if not core.is_creative_enabled (player:get_player_name ()) then
		local groups = stack:get_definition ()._mcl_diggroups
		local axe = groups and groups.axey
		if axe and axe.uses then stack:add_wear_by_uses (axe.uses) end
	end
	return stack
end

local function swap_state (pos, node, name)
	core.swap_node (pos, {name = name, param2 = node.param2})
	mcl_redstone.update_comparators (pos)
end

local function age_node (pos)
	local node = core.get_node (pos)
	local def = core.registered_nodes[node.name]
	if not def or not def._copper_next then return false end
	swap_state (pos, node, def._copper_next)
	return core.registered_nodes[def._copper_next]._copper_next ~= nil
end

local function begin_oxidation (pos, def)
	if def._copper_next then core.get_node_timer (pos):start (math.random (1200, 1800))
	else core.get_node_timer (pos):stop () end
end

local function handle_copper_tool (pos, node, player, stack)
	local def = core.registered_nodes[node.name]
	local name = player:get_player_name ()
	if core.is_protected (pos, name) then
		core.record_protection_violation (pos, name)
		return stack
	end
	if stack:get_name () == honeycomb and def._copper_waxed then
		swap_state (pos, node, def._copper_waxed)
		core.get_node_timer (pos):stop ()
		return take_one (stack, player)
	end
	if core.get_item_group (stack:get_name (), "axe") > 0 then
		if def._copper_previous then
			swap_state (pos, node, def._copper_previous)
			begin_oxidation (pos, core.registered_nodes[def._copper_previous])
			return scrape (stack, player)
		elseif def._copper_revive then
			local meta = core.get_meta (pos)
			local data = core.serialize ({nametag = meta:get_string ("name"), _copper_owner = meta:get_string ("owner")})
			if core.add_entity (vector.offset (pos, 0, -0.49, 0), mob, data) then
				core.remove_node (pos)
				core.check_for_falling (pos)
				return scrape (stack, player)
			end
		end
	end
end

local function chest_formspec (pos, player, label)
	local name = core.get_meta (pos):get_string ("name")
	if name == "" then name = label end
	local slots = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";main"
	core.show_formspec (player:get_player_name (), "mcl_copper_golems:chest",
		"formspec_version[4]size[11.75,10.425]label[0.375,0.375;" .. core.formspec_escape (name) .. "]"
		.. mcl_formspec.get_itemslot_bg_v4 (0.375, 0.75, 9, 3)
		.. "list[" .. slots .. ";0.375,0.75;9,3;]"
		.. mcl_formspec.get_itemslot_bg_v4 (0.375, 5.1, 9, 3) .. "list[current_player;main;0.375,5.1;9,3;9]"
		.. mcl_formspec.get_itemslot_bg_v4 (0.375, 9.05, 9, 1) .. "list[current_player;main;0.375,9.05;9,1;]"
		.. "listring[" .. slots .. "]listring[current_player;main]")
end

local function allow_inventory (pos, player, count)
	return player and not core.is_protected (pos, player:get_player_name ()) and count or 0
end

local function drop_inventory (pos, _, meta)
	for _, item in ipairs (meta.inventory.main or {}) do
		local stack = ItemStack (item)
		if not stack:is_empty () then core.add_item (pos, stack) end
	end
	mcl_redstone.update_comparators (pos)
end

for level, suffix in ipairs (states) do
	for _, waxed in ipairs ({false, true}) do
		local name = suffix .. (waxed and "_waxed" or "")
		local label = S ((waxed and "Waxed " or "") .. prefixes[level] .. "Copper Chest")
		local function changes (base)
			return {
				_copper_level = level,
				_copper_next = not waxed and states[level + 1] and base .. states[level + 1] or nil,
				_copper_waxed = not waxed and base .. suffix .. "_waxed" or nil,
				_copper_previous = waxed and base .. suffix or states[level - 1] and base .. states[level - 1] or nil,
				on_timer = age_node,
			}
		end
		core.register_node (chest .. name, table.merge (changes (chest), {
			description = label,
			drawtype = "mesh",
			mesh = "mcl_copper_golems_chest.obj",
			tiles = {"mcl_copper_golems_chest" .. suffix .. ".png"},
			paramtype = "light",
			paramtype2 = "facedir",
			on_place = core.rotate_node,
			selection_box = {type = "fixed", fixed = {-0.4375,-0.5,-0.4375,0.4375,0.375,0.4375}},
			collision_box = {type = "fixed", fixed = {-0.4375,-0.5,-0.4375,0.4375,0.375,0.4375}},
			groups = {axey = 1, container = 2, deco_block = 1, copper_sort_input = 1, pathfinder_partial = 2},
			is_ground_content = false,
			sounds = mcl_sounds.node_sound_metal_defaults (),
			_mcl_hardness = 2.5,
			_mcl_blast_resistance = 2.5,
			on_construct = function (pos)
				core.get_meta (pos):get_inventory ():set_size ("main", 27)
				begin_oxidation (pos, core.registered_nodes[chest .. name])
			end,
			on_rightclick = function (pos, node, player, stack)
				local result = handle_copper_tool (pos, node, player, stack)
				if result then return result end
				local above = core.get_node (vector.offset (pos, 0, 1, 0))
				if core.get_item_group (above.name, "opaque") == 0 then chest_formspec (pos, player, label) end
				return stack
			end,
			after_dig_node = drop_inventory,
			allow_metadata_inventory_put = function (pos, _, _, stack, player)
				return allow_inventory (pos, player, stack:get_count ())
			end,
			allow_metadata_inventory_take = function (pos, _, _, stack, player)
				return allow_inventory (pos, player, stack:get_count ())
			end,
			allow_metadata_inventory_move = function (pos, _, _, _, _, count, player)
				return allow_inventory (pos, player, count)
			end,
			on_metadata_inventory_put = mcl_redstone.update_comparators,
			on_metadata_inventory_take = mcl_redstone.update_comparators,
			on_metadata_inventory_move = mcl_redstone.update_comparators,
		}))
		mcl_redstone.register_comparator_measure_func (chest .. name, function (pos)
			local sum = 0
			for _, stack in ipairs (core.get_meta (pos):get_inventory ():get_list ("main") or {}) do
				if not stack:is_empty () then sum = sum + stack:get_count () / stack:get_stack_max () end
			end
			return sum == 0 and 0 or math.floor (14 * sum / 27) + 1
		end)

		core.register_node (statue .. name, table.merge (changes (statue), {
			description = S ((waxed and "Waxed " or "") .. prefixes[level] .. "Copper Golem Statue"),
			drawtype = "mesh",
			mesh = "mcl_copper_golems_statue.obj",
			tiles = {"mcl_copper_golems_golem" .. suffix .. ".png"},
			paramtype = "light",
			paramtype2 = "facedir",
			on_place = core.rotate_node,
			selection_box = {type = "fixed", fixed = {-0.28,-0.5,-0.25,0.28,0.55,0.25}},
			collision_box = {type = "fixed", fixed = {-0.28,-0.5,-0.25,0.28,0.55,0.25}},
			groups = {pickaxey = 1, deco_block = 1},
			_mcl_hardness = 3,
			_mcl_blast_resistance = 6,
			is_ground_content = false,
			sounds = mcl_sounds.node_sound_metal_defaults (),
			_copper_revive = not waxed and level == 1,
			on_construct = function (pos) begin_oxidation (pos, core.registered_nodes[statue .. name]) end,
			on_rightclick = function (pos, node, player, stack)
				return handle_copper_tool (pos, node, player, stack) or stack
			end,
			preserve_metadata = function (_, _, oldmeta, drops)
				if drops[1] and oldmeta.name and oldmeta.name ~= "" then
					drops[1]:get_meta ():set_string ("name", oldmeta.name)
				end
			end,
			after_place_node = function (pos, _, stack)
				core.get_meta (pos):set_string ("name", stack:get_meta ():get_string ("name"))
			end,
		}))
	end
end

core.register_craft ({output = chest, recipe = {
	{"mcl_copper:copper_ingot", "mcl_copper:copper_ingot", "mcl_copper:copper_ingot"},
	{"mcl_copper:copper_ingot", "mcl_chests:chest", "mcl_copper:copper_ingot"},
	{"mcl_copper:copper_ingot", "mcl_copper:copper_ingot", "mcl_copper:copper_ingot"},
}})

local register = dofile (modpath .. "/golem.lua")
register (S, mob, chest, statue, states, take_one, scrape)
