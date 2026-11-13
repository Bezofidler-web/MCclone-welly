-- SPDX-License-Identifier: GPL-3.0-or-later

return function (S, id, chest, statue, states, take_one, scrape)
	local mob_class = mcl_mobs.mob_class
	local normal_chests = {
		"mcl_chests:chest_small", "mcl_chests:chest_left", "mcl_chests:chest_right",
		"mcl_chests:trapped_chest_small", "mcl_chests:trapped_chest_left", "mcl_chests:trapped_chest_right",
		"mcl_chests:trapped_chest_on_small", "mcl_chests:trapped_chest_on_left", "mcl_chests:trapped_chest_on_right",
	}
	local regular = {}
	for _, name in ipairs (normal_chests) do regular[name] = true end

	local golem = {
		description = S ("Copper Golem"),
		type = "npc",
		_spawn_category = "misc",
		hp_min = 12,
		hp_max = 12,
		collisionbox = {-0.24, 0, -0.24, 0.24, 0.97, 0.24},
		head_eye_height = 0.75,
		visual = "mesh",
		mesh = "mcl_copper_golems_golem.obj",
		textures = {"mcl_copper_golems_golem.png"},
		rotate = 180,
		use_texture_alpha = true,
		backface_culling = false,
		can_despawn = false,
		movement_speed = 3.6,
		_copper_level = 1,
		drops = {{name = "mcl_copper:copper_ingot", chance = 1, min = 1, max = 3}},
	}

	local function display (self)
		local suffix = states[self._copper_level]
		self:set_textures ({"mcl_copper_golems_golem" .. suffix .. ".png^mcl_copper_golems_eyes" .. suffix .. ".png"})
	end

	local function release (self, pos)
		local stack = ItemStack (self._copper_carried or "")
		if not stack:is_empty () and not core.add_item (pos, stack) then return false end
		self._copper_carried = nil
		return true
	end

	function golem:after_activate ()
		display (self)
		self._copper_aging = self._copper_aging or math.random (1200, 1800)
	end

	function golem:on_rightclick (player)
		local name = player:get_player_name ()
		if self._copper_owner and self._copper_owner ~= "" and name ~= self._copper_owner then return end
		local stack = player:get_wielded_item ()
		local item = stack:get_name ()
		if item == "mcl_honey:honeycomb" and not self._copper_waxed then
			self._copper_waxed = true
			player:set_wielded_item (take_one (stack, player))
		elseif core.get_item_group (item, "axe") > 0 and (self._copper_waxed or self._copper_level > 1) then
			if self._copper_waxed then self._copper_waxed = nil
			else self._copper_level = self._copper_level - 1 end
			self._copper_aging = math.random (1200, 1800)
			player:set_wielded_item (scrape (stack, player))
			display (self)
		elseif stack:is_empty () then
			release (self, vector.offset (self.object:get_pos (), 0, 0.5, 0))
		end
	end

	function golem:on_die (pos)
		release (self, pos)
	end

	local function inventory_for (self, pos, incoming)
		local node = core.get_node (pos)
		if not (incoming and regular[node.name] or not incoming and core.get_item_group (node.name, "copper_sort_input") > 0)
			or core.is_protected (pos, self._copper_owner or "") then return end
		local above = core.get_node (vector.offset (pos, 0, 1, 0))
		if core.get_item_group (above.name, "opaque") ~= 0 then return end
		return core.get_meta (pos):get_inventory ()
	end

	local function eligible (self, pos, carried)
		local incoming = not carried:is_empty ()
		local inv = inventory_for (self, pos, incoming)
		if not inv then return end
		if incoming then
			local items = inv:get_list ("main") or {}
			local empty, matches = true, false
			for _, stack in ipairs (items) do
				if not stack:is_empty () then
					empty = false
					if stack:get_name () == carried:get_name () then matches = true end
				end
			end
			if (empty or matches) and inv:room_for_item ("main", carried:peek_item (1)) then return inv end
		elseif not inv:is_empty ("main") then
			return inv
		end
	end

	local function exchange (self, pos, inv, carried)
		if carried:is_empty () then
			for i, stack in ipairs (inv:get_list ("main") or {}) do
				if not stack:is_empty () then
					local taken = stack:take_item (16)
					inv:set_stack ("main", i, stack)
					self._copper_carried = taken:to_string ()
					break
				end
			end
		else
			local leftover = inv:add_item ("main", carried)
			self._copper_carried = leftover:to_string ()
		end
		mcl_redstone.update_comparators (pos)
	end

	local sides = {vector.new (0,0,1), vector.new (1,0,0), vector.new (0,0,-1), vector.new (-1,0,0)}
	local function move_to_chest (self, target)
		for _, offset in ipairs (sides) do
			local next_pos = vector.add (target, offset)
			if core.get_node (next_pos).name == "air"
				and self:gopath (next_pos, 1.0, nil, nil, nil) then
				self._copper_target = target
				self._copper_path_time = 15
				return true
			end
		end
	end

	local function sort_items (self, pos, dtime)
		local carried = ItemStack (self._copper_carried or "")
		local target = self._copper_target
		if target then
			local inv = eligible (self, target, carried)
			self._copper_path_time = (self._copper_path_time or 0) - dtime
			if inv and vector.distance (pos, target) < 1.65 then
				exchange (self, target, inv, carried)
				self:cancel_navigation ()
				self:halt_in_tracks ()
				self._copper_target = nil
				self._copper_search = 1
			elseif not inv or self._copper_path_time <= 0 or self:navigation_finished () then
				self._copper_target = nil
				self:cancel_navigation ()
				self._copper_search = 3
			end
			return "sorting"
		end
		self._copper_search = (self._copper_search or 0) - dtime
		if self._copper_search > 0 then return false end
		self._copper_search = 7
		local types = carried:is_empty () and {"group:copper_sort_input"} or normal_chests
		local nodes = core.find_nodes_in_area (vector.offset (pos,-32,-8,-32), vector.offset (pos,32,8,32), types)
		table.sort (nodes, function (a,b) return vector.distance (a,pos) < vector.distance (b,pos) end)
		for i = 1, math.min (10, #nodes) do
			local target_pos = nodes[i]
			local inv = eligible (self, target_pos, carried)
			if inv then
				if vector.distance (pos, target_pos) < 1.65 then
					exchange (self, target_pos, inv, carried)
					self._copper_search = 1
					return "sorting"
				elseif move_to_chest (self, target_pos) then
					return "sorting"
				end
			end
		end
		return false
	end

	function golem:do_custom (dtime)
		if self._copper_waxed then return end
		self._copper_aging = self._copper_aging - dtime
		if self._copper_aging > 0 then return end
		if self._copper_level < 3 then
			self._copper_level = self._copper_level + 1
			self._copper_aging = math.random (1200, 1800)
			display (self)
			return
		end
		local pos = vector.round (self.object:get_pos ())
		if core.get_node (pos).name ~= "air" or core.is_protected (pos, self._copper_owner or "")
			or not release (self, pos) then
			self._copper_aging = 15
			return
		end
		core.set_node (pos, {name = statue .. states[4], param2 = core.dir_to_facedir (core.yaw_to_dir (self:get_yaw ()))})
		local meta = core.get_meta (pos)
		meta:set_string ("name", self.nametag or "")
		meta:set_string ("owner", self._copper_owner or "")
		self:safe_remove ()
	end

	golem.ai_functions = {sort_items, mob_class.check_pace}
	mcl_mobs.register_mob (id, golem)
	mcl_mobs.register_egg (id, S ("Copper Golem"), "#b26141", "#77d6b7", 0)
	core.override_item (id, {inventory_image = "mcl_copper_golems_spawn_egg.png"})

	core.register_on_placenode (function (pos, newnode, placer)
		if newnode.name ~= "mcl_farming:pumpkin_face" and newnode.name ~= "mcl_farming:pumpkin_face_light" then return end
		local owner = placer and placer:is_player () and placer:get_player_name () or ""
		local support = vector.offset (pos, 0, -1, 0)
		local name = core.get_node (support).name
		for i, suffix in ipairs (states) do
			local block = "mcl_copper:block" .. suffix
			local waxed = name == block .. "_preserved"
			if (name == block or waxed) and not core.is_protected (pos, owner) and not core.is_protected (support, owner) then
				local data = core.serialize ({_copper_owner = owner, _copper_level = math.min (3, i), _copper_waxed = waxed})
				local obj = core.add_entity (vector.offset (pos, 0, 0.51, 0), id, data)
				if obj then
					core.remove_node (pos)
					core.set_node (support, {name = chest .. suffix .. (waxed and "_waxed" or ""), param2 = newnode.param2})
					obj:set_pos (vector.offset (pos, 0, -0.49, 0))
				end
				return
			end
		end
	end)
end
