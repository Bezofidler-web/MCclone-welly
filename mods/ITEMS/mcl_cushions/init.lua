local S = core.get_translator (core.get_current_modname ())
local D = mcl_util.get_dynamic_translator ()
local entity_id = "mcl_cushions:cushion"
local items = {}
local corners = {-0.48, 0.48}

mcl_cushions = {}

local function support_height (pos, node)
	local def = core.registered_nodes[node.name]
	if not def or not def.walkable or (def.damage_per_second or 0) > 0 then return end
	local boxes = core.get_node_boxes ("collision_box", pos, node)
	local highest = -0.5
	for _, box in ipairs (boxes) do
		highest = math.max (highest, box[5])
	end
	-- The whole cushion needs a level surface. A lower slab is half a node down.
	for _, x in ipairs (corners) do
		for _, z in ipairs (corners) do
			local covered = false
			for _, box in ipairs (boxes) do
				if box[5] == highest and x >= box[1] and x <= box[4] and z >= box[3] and z <= box[6] then
					covered = true
					break
				end
			end
			if not covered then return end
		end
	end
	return highest
end

local function has_clearance (support)
	local node = core.get_node_or_nil (vector.offset (support, 0, 1, 0))
	if not node or node.name == "ignore" then return nil end
	local def = core.registered_nodes[node.name]
	return def and not def.walkable and (def.damage_per_second or 0) == 0
end

local function release_seat (self, player)
	if self._rider ~= player then return end
	self._rider = nil
	if mcl_player.players[player] then
		mcl_player.players[player].attached = false
		mcl_serverplayer.override_pose (player, nil)
		mcl_player.player_set_animation (player, "stand", 30)
	end
end

local function unseat (self)
	local player = self._rider
	if not player then return end
	if player:is_valid () and player:get_attach () == self.object then
		player:set_detach ()
	end
	release_seat (self, player)
end

local function remove_cushion (self, drop)
	local pos = self.object:get_pos ()
	if not pos then return end
	local support = core.get_node (self._support)
	local height = support_height (self._support, support)
	local drop_pos = vector.offset (pos, 0, math.max (0, self._support.y + (height or 0) - pos.y) + 0.2, 0)
	if has_clearance (self._support) == false then
		drop_pos.y = self._support.y + 1.6
	end
	unseat (self)
	self.object:remove ()
	if drop then core.add_item (drop_pos, self._item) end
end

core.register_entity (entity_id, {
	initial_properties = {
		visual = "mesh",
		mesh = "mcl_cushions_cushion.obj",
		textures = {"mcl_cushions_white.png"},
		physical = false,
		collide_with_objects = false,
		pointable = true,
		selectionbox = {-0.49, 0, -0.49, 0.49, 0.25, 0.49},
	},
	_mcl_pistons_unmovable = true,
	_elapsed = 0,
	on_activate = function (self, data)
		local saved = core.deserialize (data, true)
		if type (saved) ~= "table" or type (saved.item) ~= "string" or type (saved.support) ~= "table" then
			self.object:remove ()
			return
		end
		local stack = ItemStack (saved.item)
		local texture = items[stack:get_name ()]
		if not texture then self.object:remove () return end
		self._support = saved.support
		self._item = stack:peek_item (1):to_string ()
		self.object:set_properties ({ textures = {texture} })
		self.object:set_armor_groups ({ immortal = 1 })
		self.object:set_yaw (saved.yaw or 0)
	end,
	get_staticdata = function (self)
		return core.serialize ({ item = self._item, support = self._support, yaw = self.object:get_yaw () })
	end,
	on_rightclick = function (self, player)
		if not player:is_player () or player:get_hp () == 0 then return end
		if self._rider == player then unseat (self) return end
		local state = mcl_player.players[player]
		if self._rider or not state or state.attached or player:get_attach () then return end
		self._rider = player
		self._crouching = player:get_player_control ().sneak
		player:set_attach (self.object, "", vector.new (0, 2.5, 0), vector.zero (), true)
		state.attached = true
		mcl_serverplayer.override_pose (player, mcl_serverplayer.POSE_MOUNTED)
		mcl_player.player_set_animation (player, "sit", 30)
	end,
	on_detach_child = release_seat,
	on_deactivate = unseat,
	on_punch = function (self, player)
		if not player or not player:is_player () then return end
		local name = player:get_player_name ()
		if core.is_protected (self._support, name) then
			core.record_protection_violation (self._support, name)
			return
		end
		remove_cushion (self, not core.is_creative_enabled (name))
	end,
	on_step = function (self, dtime)
		local player = self._rider
		if player then
			local crouching = player:is_valid () and player:get_player_control ().sneak
			if not player:is_valid () or player:get_hp () == 0 or (crouching and not self._crouching) then
				unseat (self)
			end
			self._crouching = crouching
		end
		self._elapsed = self._elapsed + dtime
		if self._elapsed < 0.5 then return end
		self._elapsed = 0
		local node = core.get_node_or_nil (self._support)
		if not node or node.name == "ignore" then return end
		local height = support_height (self._support, node)
		if not height or math.abs (self.object:get_pos ().y - self._support.y - height) > 0.02
				or has_clearance (self._support) == false then
			remove_cushion (self, true)
		end
	end,
})

function mcl_cushions.place (support, stack, yaw)
	local node = core.get_node_or_nil (support)
	local height = node and support_height (support, node)
	if not height or not items[stack:get_name ()] then return end
	local pos = vector.offset (support, 0, height, 0)
	if not has_clearance (support) then return end
	for object in core.objects_inside_radius (pos, 0.4) do
		local other = object:get_luaentity ()
		if other and other.name == entity_id then return end
	end
	return core.add_entity (pos, entity_id, core.serialize ({
		item = stack:peek_item (1):to_string (), support = support, yaw = yaw,
	}))
end

local function on_place (stack, player, pointed)
	if not player or pointed.type ~= "node" or pointed.above.y <= pointed.under.y then return stack end
	local result = mcl_util.call_on_rightclick (stack, player, pointed)
	if result then return result end
	local name = player:get_player_name ()
	for _, pos in ipairs ({pointed.under, pointed.above}) do
		if core.is_protected (pos, name) then
			core.record_protection_violation (pos, name)
			return stack
		end
	end
	local yaw = math.floor (player:get_look_horizontal () / (math.pi / 2) + 0.5) * math.pi / 2
	if mcl_cushions.place (pointed.under, stack, yaw) and not core.is_creative_enabled (name) then
		stack:take_item ()
	end
	return stack
end

for colour, dye in pairs (mcl_dyes.colors) do
	local id = "mcl_cushions:" .. colour
	local base = "mcl_cushions_" .. colour
	items[id] = base .. ".png"
	core.register_craftitem (id, {
		description = D (dye.readable_name .. " Cushion"),
		_doc_items_usagehelp = S ("Place on a flat surface, right-click to sit and sneak to stand up."),
		inventory_image = base .. "_item.png",
		on_place = on_place,
	})
	local slab = "mcl_stairs:slab_wool_" .. colour
	core.register_craft ({output = id, recipe = {{slab, slab, slab}}})
end
