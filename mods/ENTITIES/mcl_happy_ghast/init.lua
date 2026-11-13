-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_happy_ghast")
local D = mcl_util.get_dynamic_translator ()
local mob_class = mcl_mobs.mob_class
local prefix = "mcl_happy_ghast:"
local mob_id = "mobs_mc:happy_ghast"
local art = "mcl_happy_ghast_"
local adult_skin = art .. "adult.png"
local baby_skin = art .. "baby.png"
local blank = art .. "blank.png"
local snowball = "mcl_throwing:snowball"
local harnesses = {}
local java_colours = {grey = "gray", silver = "light_gray"}

for color, dye in pairs (mcl_dyes.colors) do
	local java_color = java_colours[color] or color
	local id = prefix .. java_color .. "_harness"
	local icon = art .. java_color .. "_harness.png"
	harnesses[id] = art .. java_color .. "_body.png"
	core.register_craftitem (id, {
		description = D (dye.readable_name .. " Harness"),
		inventory_image = icon,
		stack_max = 1,
		groups = {happy_ghast_harness = 1},
	})
	local leather = "mcl_mobitems:leather"
	core.register_craft ({
		output = id,
		recipe = {
			{leather, leather, leather},
			{"mcl_core:glass", "mcl_wool:" .. color, "mcl_core:glass"},
		},
	})
	core.register_craft ({
		output = id,
		type = "shapeless",
		recipe = {"group:happy_ghast_harness", "mcl_dyes:" .. color},
	})
end

local ghast = {
	description = S ("Happy Ghast"),
	type = "animal",
	_spawn_category = "misc",
	hp_min = 20,
	hp_max = 20,
	visual = "mesh",
	mesh = art .. "adult.b3d",
	_child_mesh = art .. "baby.b3d",
	textures = {{adult_skin, blank}},
	child_texture = {{baby_skin}},
	collisionbox = {-2, 0, -2, 2, 4, 2},
	head_eye_height = 2.55,
	doll_size_override = {x = 0.95, y = 0.95},
	animation = {stand_start = 0, stand_end = 40, stand_speed = 20},
	_child_animations = {stand_start = 0, stand_end = 40, stand_speed = 20},
	use_texture_alpha = true,
	backface_culling = false,
	sounds = {
		random = "mcl_happy_ghast_coo",
		damage = "mcl_happy_ghast_hurt",
		death = "mcl_happy_ghast_death",
		distance = 32,
	},
	_no_fall_damage = true,
	can_ride_boat = false,
	can_ride_cart = false,
	makes_footstep_sound = false,
	can_despawn = false,
	motion_step = mob_class.flying_step,
	driver_attach_at = vector.new (0, 40, 12),
	steer_class = "controls",
}

local seats = {
	{position = vector.new (-12, 40, 0), rotation = vector.new (0, 270, 0)},
	{position = vector.new (0, 40, -12), rotation = vector.new (0, 180, 0)},
	{position = vector.new (12, 40, 0), rotation = vector.new (0, 90, 0)},
}

local function show_harness (self)
	if self.child then
		self:set_textures ({baby_skin})
		return
	end
	self:set_textures ({adult_skin, harnesses[self._harness] or blank})
	local raised = not self.driver
	self.object:set_bone_override ("goggles", {
		position = {vec = vector.new (0, raised and 12.5 or 0, 0), absolute = false},
		rotation = {vec = vector.new (raised and math.pi / 4 or 0, 0, 0), absolute = false},
	})
end

function ghast:scale_size_of_child ()
	mob_class.scale_size_of_child (self, 0.2375)
end

function ghast:after_activate ()
	self.base_texture = {adult_skin, blank}
	self._ghast_passengers = {}
	self._ghast_home = self._ghast_home or self.object:get_pos ()
	show_harness (self)
end

function ghast:on_grown ()
	show_harness (self)
	self.object:set_animation ({x = 0, y = 40}, 20, 0, true)
end

function ghast:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if data then
		data.driver = nil
		data._ghast_passengers = nil
		data._flight_goal = nil
		data._landing = nil
	end
	return data
end

local function begin_ride (self, player)
	if not self:attach (player, true) then return end
	self._landing = nil
	self._flight_goal = nil
	show_harness (self)
end

local function dismount (self, player)
	local mount_pos = self.object:get_pos ()
	local pos = mcl_attachments.get_attachment_pos (player)
	if self.driver == player then
		self:detach (player, vector.zero ())
	else
		mcl_util.detach_object (player)
	end
	if mount_pos and pos then
		pos.y = math.max (pos.y, mount_pos.y + 4.08)
		player:set_pos (pos)
	end
end

local function restore_unmounted_player (player)
	if not player:is_valid () or player:get_attach () then return end
	mcl_attachments.remove_attachment_entity (player)
	local state = mcl_player.players[player]
	if not state then return end
	state.attached = false
	player:set_eye_offset (vector.zero (), vector.zero ())
	player:set_properties ({visual_size = {x = 1, y = 1}})
	mcl_player.player_set_animation (player, "stand", 30)
end

local function finish_dismount (player, was_driver)
	if not player:is_valid () then return end
	if was_driver then mcl_mobs.remove_driving_hud (player) end
	restore_unmounted_player (player)
end

function ghast:driver_detached (driver, deactivated)
	-- Luanti calls on_detach_child before completing a direct transfer to another mount.
	core.after (0, finish_dismount, driver, true)
	if not deactivated and self.object:is_valid () then
		self._landing = true
		show_harness (self)
	end
end

function ghast:on_detach_child (child)
	mob_class.on_detach_child (self, child)
	for i, passenger in pairs (self._ghast_passengers or {}) do
		if passenger == child then
			self._ghast_passengers[i] = nil
			core.after (0, finish_dismount, passenger, false)
			break
		end
	end
end

local function detach_all (self)
	for _, passenger in pairs (self._ghast_passengers or {}) do
		if passenger:is_valid () and passenger:get_attach () == self.object then
			dismount (self, passenger)
		end
	end
	if self.driver and self.driver:is_valid () then
		dismount (self, self.driver)
	end
end

function ghast:on_deactivate (removal)
	detach_all (self)
	mob_class.on_deactivate (self, removal)
end

function ghast:on_die (pos)
	detach_all (self)
	if self._harness then core.add_item (pos, self._harness) end
end

local function update_home (self)
	self._ghast_home = self.object:get_pos ()
	self._flight_goal = nil
end

function ghast:on_rightclick (player)
	if player:get_attach () then return end
	local stack = player:get_wielded_item ()
	local name = stack:get_name ()
	if self.child then
		if name == snowball then
			self:feed_tame (player, nil, false, false)
			update_home (self)
		end
		return
	end
	if not self._harness and harnesses[name] then
		self._harness = name
		show_harness (self)
		update_home (self)
		if not mcl_util.is_creative (player) then
			stack:take_item ()
			player:set_wielded_item (stack)
		end
		return
	end
	if not self._harness then return end
	if core.get_item_group (name, "shears") > 0 and not self.driver and not next (self._ghast_passengers) then
		if not core.add_item (self.object:get_pos (), self._harness) then return end
		self._harness = nil
		show_harness (self)
		if not mcl_util.is_creative (player) then
			stack:add_wear_by_uses (stack:get_definition ()._mcl_diggroups.shearsy.uses)
			player:set_wielded_item (stack)
		end
		return
	end
	if player:get_player_control ().sneak then return end
	if not self.driver and not next (self._ghast_passengers) then
		begin_ride (self, player)
		return
	end
	for i, seat in ipairs (seats) do
		if not self._ghast_passengers[i] then
			self._ghast_passengers[i] = player
			player:set_attach (self.object, "", seat.position, seat.rotation)
			mcl_attachments.spawn_attachment_entity (player)
			mcl_player.players[player].attached = true
			mcl_player.player_set_animation (player, "sit_mount", 30)
			return
		end
	end
end

local function move (self, desired, dtime)
	local current = self.object:get_velocity ()
	local blend = 1 - math.exp (-4.5 * dtime)
	self.object:set_velocity (current + (desired - current) * blend)
end

function ghast:drive (_, _, _, dtime)
	local pilot = self.driver
	local input = pilot:get_player_control ()
	if input.sneak then
		dismount (self, pilot)
		self.object:set_velocity (vector.zero ())
		return
	end
	local yaw = pilot:get_look_horizontal ()
	self:set_yaw (yaw)
	local forward = input.movement_y or ((input.up and 1 or 0) - (input.down and 1 or 0))
	local sideways = input.movement_x or ((input.right and 1 or 0) - (input.left and 1 or 0))
	local heading = core.yaw_to_dir (yaw)
	local speed = 4.0
	local rise = input.jump and 1 or -math.sin (pilot:get_look_vertical ()) * forward
	local desired = heading * (forward * speed) + vector.new (heading.z, 0, -heading.x) * (sideways * speed * 0.5)
	desired.y = rise * speed * 0.75
	move (self, desired, dtime)
end

local function footing (pos, depth)
	return core.raycast (vector.offset (pos, 0, -0.2, 0), vector.offset (pos, 0, -depth, 0), false, false):next ()
end

local function standing_on_top (self, pos)
	if self.child then return false end
	for player in mcl_util.connected_players () do
		if not player:get_attach () then
			local delta = player:get_pos () - pos
			if math.abs (delta.x) < 2.2 and math.abs (delta.z) < 2.2 and delta.y >= 3.95 and delta.y <= 4.3 then
				return true
			end
		end
	end
	return false
end

local function attraction (self, pos)
	local best, best_distance = nil, 16
	for obj in core.objects_inside_radius (pos, 16) do
		if obj ~= self.object then
			local candidate = obj:get_luaentity ()
			local target = obj:get_pos ()
			local desired
			if obj:is_player () and not obj:get_attach () then
				local item = obj:get_wielded_item ():get_name ()
				desired = self.child or item == snowball or (not self._harness and harnesses[item])
			elseif self.child and candidate and candidate.is_mob and not candidate.dead
				and not candidate.child and candidate.type == "animal" and not candidate._aquatic then
				desired = true
			end
			if desired then
				local distance = vector.distance (pos, target)
				if distance < best_distance and self:line_of_sight (pos, target) then
					best = target
					best_distance = distance
				end
			end
		end
	end
	return best
end

function ghast:run_ai (dtime, moveresult)
	local pos = self.object:get_pos ()
	if standing_on_top (self, pos) then
		self.object:set_velocity (vector.zero ())
		local quadrant = math.pi / 2
		self:set_yaw (math.floor (self:get_yaw () / quadrant + 0.5) * quadrant)
		return
	end
	if self._landing then
		local ground = footing (pos, 64)
		if not ground or pos.y - ground.intersection_point.y > 1.4 then
			move (self, vector.new (0, -1.8, 0), dtime)
			return
		end
		self._landing = nil
		update_home (self)
	end
	self._flight_wait = (self._flight_wait or 0) - dtime
	if self._flight_wait <= 0 then
		self._flight_wait = 1.5
		local roam = (self.child or self._harness) and 32 or 64
		if vector.distance (pos, self._ghast_home) > roam + 16 then update_home (self) end
		local target = attraction (self, pos)
		if not target and (moveresult.collides or not self._flight_goal or vector.distance (pos, self._flight_goal) < 1) then
			local home = self._ghast_home
			target = vector.offset (pos, math.random (-12, 12), math.random (-3, 6), math.random (-12, 12))
			if vector.distance (target, home) > roam then target = home end
			local ground = footing (target, 18)
			if ground then target.y = math.max (target.y, ground.intersection_point.y + 1.7) end
		end
		if target then
			self._flight_goal = self:line_of_sight (pos, target) and target or nil
		end
	end
	local target = self._flight_goal
	local direction = vector.zero ()
	if target and vector.distance (target, pos) > 1.1 then
		direction = vector.direction (pos, target)
		if math.abs (direction.x) + math.abs (direction.z) > 0.1 then
			self:set_yaw (core.dir_to_yaw (direction))
		end
	end
	move (self, direction * (self.child and 2.5 or 2), dtime)
end

function ghast:do_custom ()
	for i = 1, #seats do
		local passenger = self._ghast_passengers[i]
		if passenger then
			if not passenger:is_valid () or passenger:get_attach () ~= self.object then
				self._ghast_passengers[i] = nil
				restore_unmounted_player (passenger)
			elseif passenger:get_player_control ().sneak then
				dismount (self, passenger)
			elseif not self.driver then
				mcl_util.detach_object (passenger)
				begin_ride (self, passenger)
			end
		end
	end
	local max_health = self.object:get_properties ().hp_max
	if not self.child and self.health < max_health and self:check_timer ("happy_ghast_regen", 2.5) then
		local pos = self.object:get_pos ()
		local wet = mcl_weather.rain.raining and mcl_weather.is_outdoor (pos)
		local clouds = self.driver and self.driver:get_clouds ()
		local in_clouds = clouds and math.abs (pos.y - clouds.height) < 8
		self:heal_mob ((wet or in_clouds) and 2 or 1, max_health)
	end
end

mcl_mobs.register_mob (mob_id, ghast)
mcl_mobs.register_egg (mob_id, S ("Happy Ghast"), "#f2e8e4", "#a65554", 0)
core.override_item (mob_id, {inventory_image = art .. "spawn_egg.png"})

dofile (core.get_modpath ("mcl_happy_ghast") .. "/dried.lua")
