-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_allays")
local mob_class = mcl_mobs.mob_class
local mob_name = "mobs_mc:allay"
local note_block = "mcl_noteblock:noteblock"
local jukebox = "mcl_jukebox:jukebox"
local amethyst = "mcl_amethyst:amethyst_shard"

local allay = {
	description = S ("Allay"),
	type = "animal",
	_spawn_category = "misc",
	hp_min = 20,
	hp_max = 20,
	collisionbox = {-0.175, 0, -0.175, 0.175, 0.6, 0.175},
	head_eye_height = 0.44,
	visual = "mesh",
	mesh = "mcl_allays_allay.obj",
	rotate = 180,
	textures = {"mcl_allays_allay.png"},
	use_texture_alpha = true,
	backface_culling = false,
	fly = true,
	_no_fall_damage = true,
	can_despawn = false,
	can_ride_boat = false,
	can_ride_cart = false,
	xp_min = 0,
	xp_max = 0,
	drops = {},
}

local function hand (self)
	return ItemStack (self._allay_sample or "")
end

local function carried (self)
	return ItemStack (self._allay_items or "")
end

local function stackable_with (a, b)
	if a:get_name () ~= b:get_name () or a:get_wear () ~= b:get_wear () then return false end
	local sample, other = ItemStack (a), ItemStack (b)
	sample:set_count (1)
	other:set_count (1)
	return sample:to_string () == other:to_string ()
end

local function show_sample (self)
	if self._allay_display and self._allay_display:is_valid () then self._allay_display:remove () end
	local stack = hand (self)
	if stack:is_empty () then return end
	local object = core.add_entity (self.object:get_pos (), "mcl_allays:held_item")
	if object then
		object:set_properties ({wield_item = stack:to_string ()})
		object:set_attach (self.object, "", vector.new (0, 2, 2), vector.new (20, 0, 0))
		self._allay_display = object
	end
end

core.register_entity ("mcl_allays:held_item", {
	initial_properties = {
		visual = "wielditem",
		visual_size = {x = 0.12, y = 0.12, z = 0.12},
		wield_item = "air",
		physical = false,
		pointable = false,
		static_save = false,
	},
	on_step = function (self)
		if not self.object:get_attach () then self.object:remove () end
	end,
})

function allay:after_activate ()
	show_sample (self)
end

function allay:on_deactivate (removed)
	if self._allay_display and self._allay_display:is_valid () then self._allay_display:remove () end
	return mob_class.on_deactivate (self, removed)
end

function allay:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if data then
		data._allay_display = nil
		data._allay_destination = nil
		data._allay_note = nil
	end
	return data
end

function allay:receive_damage (reason, damage)
	local source = reason.source
	if source and source:is_valid () and source:is_player ()
		and source:get_player_name () == self._allay_owner then return false end
	return mob_class.receive_damage (self, reason, damage)
end

local function give (player, stack)
	local left = player:get_inventory ():add_item ("main", stack)
	if not left:is_empty () then core.add_item (player:get_pos (), left) end
end

local function nearby_music (pos)
	for dx = -3, 3 do
		for dz = -3, 3 do
			for dy = -3, 3 do
				local point = vector.round (vector.offset (pos, dx, dy, dz))
				if vector.distance (point, pos) <= 3.46
					and mcl_jukebox.active_tracks[core.hash_node_position (point)]
					and core.get_node (point).name == jukebox then return point end
			end
		end
	end
end

function allay:on_rightclick (player)
	local pos = self.object:get_pos ()
	local player_name = player:get_player_name ()
	local stack = player:get_wielded_item ()
	local sample = hand (self)
	if stack:get_name () == amethyst and nearby_music (pos)
		and (self._allay_duplicate_after or 0) <= core.get_gametime () then
		local cooldown = core.get_gametime () + 300
		local child = core.add_entity (pos, mob_name, core.serialize ({_allay_duplicate_after = cooldown}))
		if child then
			self._allay_duplicate_after = cooldown
			if not core.is_creative_enabled (player_name) then
				stack:take_item ()
				player:set_wielded_item (stack)
			end
			mcl_mobs.effect (pos, 7, "heart.png", 2, 4, 1.5, 0.1)
		end
		return
	end
	if sample:is_empty () and not stack:is_empty () then
		local one = stack:peek_item (1)
		self._allay_sample = one:to_string ()
		self._allay_owner = player_name
		if not core.is_creative_enabled (player_name) then
			stack:take_item ()
			player:set_wielded_item (stack)
		end
		show_sample (self)
	elseif stack:is_empty () and not sample:is_empty () then
		give (player, sample)
		give (player, carried (self))
		self._allay_sample, self._allay_owner, self._allay_items = nil, nil, nil
		show_sample (self)
	end
end

function allay:on_die (pos)
	for _, stack in ipairs ({hand (self), carried (self)}) do
		if not stack:is_empty () then core.add_item (pos, stack) end
	end
end

local function can_see (pos, target)
	return core.line_of_sight (vector.offset (pos, 0, 0.25, 0), target)
end

local function pickup_target (self, pos, sample)
	if core.get_gametime () < (self._allay_pickup_after or 0) then return end
	local picked = carried (self)
	local room = sample:get_stack_max () - picked:get_count ()
	if room <= 0 then return end
	local nearest, distance
	for obj in core.objects_inside_radius (pos, 32) do
		local entity = obj:get_luaentity ()
		local point = entity and entity.is_item and not entity._removed and obj:get_pos ()
		local stack = point and ItemStack (entity.itemstring)
		if stack and not stack:is_empty () and stackable_with (stack, sample)
			and can_see (pos, vector.offset (point, 0, 0.4, 0)) then
			local d = vector.distance (pos, point)
			if d <= 0.95 then
				local taken = stack:take_item (room)
				picked:add_item (taken)
				if stack:is_empty () then
					entity.itemstring = ""
					entity:safe_remove ()
				else
					entity:set_item (stack:to_string ())
				end
				self._allay_items = picked:to_string ()
				return nil
			elseif not distance or d < distance then
				nearest, distance = vector.offset (point, 0, 0.4, 0), d
			end
		end
	end
	return nearest
end

local function choose_destination (self, pos)
	local owner = self._allay_owner and core.get_player_by_name (self._allay_owner)
	local note = self._allay_note
	if note and (self._allay_note_until <= core.get_gametime () or core.get_node (note).name ~= note_block) then
		self._allay_note, note = nil, nil
	end
	local destination = note and vector.offset (note, 0, 1.2, 0)
		or owner and vector.offset (owner:get_pos (), 0, 1.1, 0)
	local sample = hand (self)
	if not sample:is_empty () then
		local picked = carried (self)
		if destination and not picked:is_empty () and vector.distance (destination, pos) <= 2.6
			and can_see (pos, destination) then
			local drop = core.add_item (pos, picked)
			if drop then
				drop:set_velocity (vector.multiply (vector.direction (pos, destination), 5))
				self._allay_items = nil
				self._allay_pickup_after = core.get_gametime () + 3
			end
		end
		return pickup_target (self, pos, sample) or destination
	end
	return destination
end

local function fly (self, pos)
	if self:check_timer ("allay_pickup", 0.45) then
		self._allay_destination = choose_destination (self, pos)
	end
	if self:check_timer ("allay_regenerate", 1) then self:heal_mob (2, 20) end
	if self:check_timer ("allay_music", 1) then self._allay_dance = nearby_music (pos) ~= nil end
	local target = self._allay_destination
	if not target and self:check_timer ("allay_drift", 2.5) then
		local direction = core.yaw_to_dir (math.random () * math.pi * 2)
		local point = vector.offset (vector.add (pos, vector.multiply (direction, 1.4)), 0, math.random () - 0.5, 0)
		self._allay_wander = can_see (pos, point) and point or nil
	end
	target = target or self._allay_wander
	if target and vector.distance (target, pos) > 0.5 then
		self:look_at (target)
	elseif self._allay_dance then
		self:set_yaw (self:get_yaw () + 0.13)
	end
	return "flight"
end

function allay:motion_step (dtime, _, pos)
	local target = self._allay_destination or self._allay_wander
	local desired = vector.zero ()
	if target and vector.distance (pos, target) > 0.38 then
		desired = vector.multiply (vector.direction (pos, target), self._allay_destination and 4.5 or 1.35)
		if not can_see (pos, target) then
			local above = vector.offset (pos, 0, 1, 0)
			desired = can_see (pos, above) and vector.new (0, 1.5, 0) or vector.zero ()
		end
	end
	local current = self.object:get_velocity ()
	local velocity = vector.add (current, vector.multiply (vector.subtract (desired, current), math.min (1, dtime * 8)))
	self.object:set_velocity (velocity)
	self.object:set_acceleration (vector.zero ())
end

function allay:hear_note (pos)
	local here = self.object:get_pos ()
	local ray = core.raycast (vector.offset (pos, 0, 0.55, 0), vector.offset (here, 0, 0.35, 0), false, false)
	for hit in ray do
		if core.get_item_group (core.get_node (hit.under).name, "wool") > 0 then return end
	end
	self._allay_note = vector.copy (pos)
	self._allay_note_until = core.get_gametime () + 30
end

allay.ai_functions = {fly}
mcl_mobs.register_mob (mob_name, allay)
mcl_mobs.register_egg (mob_name, S ("Allay"), "#30bad7", "#9effff", 0)
core.override_item (mob_name, {inventory_image = "mcl_allays_allay_spawn_egg.png"})
