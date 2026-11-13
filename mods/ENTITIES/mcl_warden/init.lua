-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_warden")
local mob_class = mcl_mobs.mob_class
local mob_name = "mobs_mc:warden"
local angry_at = 80
local anger_limit = 150
local senses_range = 24
local melee_damage = {16, 30, 45}
local sonic_damage = {6, 10, 15}

mcl_damage.register_type ("sonic_boom", {bypasses_armor = true, bypasses_armor_enchantments = true})

local base_texture = "mcl_warden_warden.png^mcl_warden_warden_bioluminescent_layer.png"
local idle_texture = base_texture .. "^mcl_warden_warden_pulsating_spots_1.png"
local heartbeat_texture = base_texture .. "^mcl_warden_warden_pulsating_spots_2.png^mcl_warden_warden_heart.png"

local warden = {
	description = S ("Warden"),
	type = "monster",
	_spawn_category = "monster",
	hp_min = 500,
	hp_max = 500,
	xp_min = 5,
	xp_max = 5,
	visual = "mesh",
	mesh = "mcl_warden.b3d",
	textures = {{base_texture}},
	visual_size = {x = 1, y = 1},
	use_texture_alpha = true,
	backface_culling = false,
	collisionbox = {-0.45, 0, -0.45, 0.45, 2.9, 0.45},
	head_eye_height = 2.55,
	view_range = senses_range,
	tracking_distance = 32,
	knockback_resistance = 1,
	fire_resistant = true,
	lava_damage = 0,
	breathes_in_water = true,
	movement_speed = 5,
	stepheight = 1.05,
	can_despawn = false,
	makes_footstep_sound = true,
	sounds = {
		damage = "mcl_warden_hurt",
		death = "mcl_warden_death",
		distance = 32,
	},
	drops = {{name = "mcl_sculk:catalyst", chance = 1, min = 1, max = 1}},
	animation = {
		stand_start = 0, stand_end = 40, stand_speed = 20,
		walk_start = 41, walk_end = 81, walk_speed = 30,
		emerge_start = 82, emerge_end = 216, emerge_speed = 20, emerge_loop = false,
		dig_start = 217, dig_end = 317, dig_speed = 20, dig_loop = false,
		roar_start = 318, roar_end = 402, roar_speed = 20, roar_loop = false,
		sniff_start = 403, sniff_end = 487, sniff_speed = 20, sniff_loop = false,
		punch_start = 488, punch_end = 508, punch_speed = 20, punch_loop = false,
		sonic_start = 509, sonic_end = 569, sonic_speed = 20, sonic_loop = false,
	},
}

local function target_ok (self, target)
	if not target or target == self.object or not target.is_valid or not target:is_valid () then
		return false
	end
	if target:is_player () then
		return mcl_sculk.is_survival_player (target)
	end
	local entity = target:get_luaentity ()
	return entity and entity.is_mob and not entity.dead and entity.name ~= mob_name
end

local function target_anger (self, target)
	if target:is_player () then
		return self._player_anger[target:get_player_name ()] or 0
	end
	return self._suspects[target] or 0
end

local function halt (self, pose)
	self:cancel_navigation ()
	self:halt_in_tracks (false, true)
	self:set_animation (pose)
end

local function enter_state (self, pose, duration, sound)
	self._pose = pose
	self._pose_left = duration
	halt (self, pose)
	if sound then
		core.sound_play (sound, {object = self.object, gain = 1, max_hear_distance = 40}, true)
	end
end

function warden:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if not data then return end
	data._suspects = nil
	data._vibration = nil
	data._projectile_source = nil
	data._hunt_target = nil
	data._heartbeat_time = nil
	data._heart_glow = nil
	data._target_name = self._target_name
	data._player_anger = table.copy (self._player_anger)
	return data
end

local function hear_vibration (object, pos, event, source)
	local self = object:get_luaentity ()
	if not self or self.dead or self._emerging or self._pose == "dig"
		or self._vibration or self._listen_cooldown > 0 then
		return
	end
	local receiver = vector.offset (object:get_pos (), 0, 1.8, 0)
	local delay = math.floor (vector.distance (pos, receiver)) / 20
	self._vibration = {pos = vector.copy (pos), event = event, source = source, delay = delay}
	mcl_sculk.show_vibration (pos, receiver, delay)
end

function warden:mob_activate (staticdata, dtime)
	if not mob_class.mob_activate (self, staticdata, dtime) then
		return false
	end
	self._suspects = {}
	self._hunt_target = nil
	self._player_anger = self._player_anger or {}
	self._listen_cooldown = 0
	self._darkness_time = 0
	self._heartbeat_time = 0
	self._sniff_time = self._sniff_time or 5
	self._idle_time = self._idle_time or 0
	self._melee_time = self._melee_time or 0
	self._sonic_time = self._sonic_time or 10
	self._anger_time = self._anger_time or 0
	self._last_projectile = 0
	if self._emerging then
		self.object:set_properties ({pointable = false})
		if self._pose ~= "emerge" then
			enter_state (self, "emerge", self._emerging, "mcl_warden_emerge")
		end
	elseif self._pose == "dig" then
		self.object:set_properties ({pointable = false})
	end
	if self._pose then
		self:set_animation (self._pose)
	end
	mcl_sculk.listen_for_vibrations (self.object, hear_vibration)
	return true
end

function warden:on_deactivate (removal)
	mcl_sculk.stop_listening (self.object)
	mob_class.on_deactivate (self, removal)
end

function warden:anger (target, amount)
	if not target_ok (self, target) then
		return
	end
	local records = self._suspects
	local key = target
	if target:is_player () then
		records = self._player_anger
		key = target:get_player_name ()
	end
	local previous = records[key] or 0
	local value = math.min (anger_limit, previous + amount)
	records[key] = value
	self._idle_time = 0
	if previous < angry_at and value >= angry_at and not self._hunt_target then
		self._hunt_target = target
		self._target_name = target:is_player () and key or nil
		self._sonic_time = 10
		self:look_at (target:get_pos ())
		enter_state (self, "roar", 4.2, "mcl_warden_roar")
	end
end

function warden:receive_damage (reason, damage)
	if (self._emerging or self._pose == "dig") and reason.type ~= "out_of_world" then
		return false
	end
	if damage > 0 and not self.dead then
		self:anger (reason.source, angry_at + 20)
	end
	return mob_class.receive_damage (self, reason, damage)
end

function warden:shield_impact (object)
	mcl_shields.disable_player_shield (object)
end

local function receive_vibration (self, vibration)
	self._listen_cooldown = 2
	self._idle_time = 0
	self._investigate = vibration.pos
	self._investigate_time = 8
	if vibration.event == "projectile_land" then
		local source = vibration.source
		if source and self._projectile_source == source and self._last_projectile > 0 then
			self:anger (source, 35)
			if target_ok (self, source) then
				self._investigate = source:get_pos ()
			end
		end
		self._projectile_source = source
		self._last_projectile = 5
	else
		self:anger (vibration.source, 35)
	end
	core.sound_play ("mcl_warden_listen", {object = self.object, gain = 0.6, max_hear_distance = 24}, true)
end

local function sniff (self, pos)
	local nearest, best = nil, senses_range
	for obj in core.objects_inside_radius (pos, senses_range) do
		if target_ok (self, obj) then
			local target_pos = obj:get_pos ()
			local distance = vector.distance (target_pos, pos)
			if distance < best then
				nearest, best = obj, distance
			end
		end
	end
	if nearest then
		self._investigate = nearest:get_pos ()
		self._investigate_time = 8
		local dx = self._investigate.x - pos.x
		local dz = self._investigate.z - pos.z
		if dx * dx + dz * dz <= 36 and math.abs (self._investigate.y - pos.y) <= 20 then
			self:anger (nearest, 35)
		end
	end
end

local function sonic_boom (self, target, pos)
	if not target_ok (self, target) then
		return
	end
	local target_pos = target:get_pos ()
	local horizontal = vector.distance (vector.new (pos.x, 0, pos.z), vector.new (target_pos.x, 0, target_pos.z))
	if horizontal > 15 or math.abs (target_pos.y - pos.y) > 20 then
		return
	end
	local from = vector.offset (pos, 0, 1.7, 0)
	local to = vector.offset (target_pos, 0, 0.85, 0)
	local direction = vector.direction (from, to)
	for index = 1, math.floor (vector.distance (from, to)) + 4 do
		local point = vector.add (from, vector.multiply (direction, index))
		core.add_particle ({pos = point, expirationtime = 0.5, size = 4, glow = 12,
			texture = "mcl_warden_sonic_boom_" .. math.min (15, index - 1) .. ".png"})
	end
	core.sound_play ("mcl_warden_sonic_boom", {object = self.object, gain = 1, max_hear_distance = 48}, true)
	mcl_util.deal_damage (target, sonic_damage[mcl_vars.difficulty] or 10,
		{type = "sonic_boom", source = self.object, direct = self.object})
	if target:is_valid () then
		local ent = target:get_luaentity ()
		local resistance = ent and ent.knockback_resistance or 0
		target:add_velocity (vector.multiply (vector.new (direction.x * 5, 2, direction.z * 5), 1 - resistance))
	end
end

local function move_towards (self, pos, target_pos, dtime, speed)
	if self:navigation_finished () or not self._navigation_session then
		self._repath_time = (self._repath_time or 0) - dtime
		if self._repath_time <= 0 then
			self._repath_time = 0.75
			self:session_navigate (target_pos, speed, 1, 1, 0.5)
		end
	else
		self:poll_navigation_state (pos, dtime, 5, target_pos)
	end
end

local function hunt (self, target, pos, dtime)
	local target_pos = target:get_pos ()
	local dx, dz = pos.x - target_pos.x, pos.z - target_pos.z
	local range = math.sqrt (dx * dx + dz * dz)
	local height = math.abs (pos.y - target_pos.y)
	if range <= 2 and height <= 2 and self:target_visible (pos, target) then
		self:look_at (target_pos)
		halt (self, "stand")
		if self._melee_time <= 0 then
			self._melee_time = 1.8
			self._sonic_time = math.max (self._sonic_time, 2)
			enter_state (self, "punch", 0.65)
			local damage = mcl_util.deal_damage (target, melee_damage[mcl_vars.difficulty] or 30,
				{type = "mob", source = self.object, direct = self.object})
			if damage and damage > 0 and target:is_valid () then
				local direction = vector.direction (pos, target_pos)
				local entity = target:get_luaentity ()
				if target:is_player () then
					mcl_player.player_knockback (target, self.object, direction, nil, damage)
				elseif entity and entity.is_mob then
					entity:projectile_knockback (1, direction)
				end
			end
		end
	elseif range <= 15 and height <= 20 and self._sonic_time <= 0 then
		self:look_at (target_pos)
		self._sonic_fired = false
		self._sonic_time = 5
		enter_state (self, "sonic", 3, "mcl_warden_sonic_charge")
	else
		move_towards (self, pos, target_pos, dtime, 1.2)
	end
end

local function select_target (self, pos)
	local target, best = nil, angry_at - 1
	local function consider (candidate, anger)
		if anger > best and target_ok (self, candidate)
			and vector.distance (pos, candidate:get_pos ()) <= self.tracking_distance then
			target, best = candidate, anger
		end
	end
	for name, anger in pairs (self._player_anger) do
		consider (core.get_player_by_name (name), anger)
	end
	for suspect, anger in pairs (self._suspects) do
		consider (suspect, anger)
	end
	return target
end

function warden:do_custom (dtime)
	local pos = self.object:get_pos ()
	self._listen_cooldown = self._listen_cooldown - dtime
	self._last_projectile = self._last_projectile - dtime
	self._melee_time = self._melee_time - dtime
	self._sonic_time = self._sonic_time - dtime
	self._darkness_time = self._darkness_time - dtime
	self._investigate_time = (self._investigate_time or 0) - dtime
	if self._darkness_time <= 0 then
		mcl_sculk.apply_darkness (pos, 20, 13)
		self._darkness_time = 6
	end
	self._anger_time = self._anger_time + dtime
	if self._anger_time >= 1 then
		self._anger_time = self._anger_time - 1
		for suspect, anger in pairs (self._suspects) do
			self._suspects[suspect] = anger > 1 and target_ok (self, suspect) and anger - 1 or nil
		end
		for name, anger in pairs (self._player_anger) do
			self._player_anger[name] = anger > 1 and anger - 1 or nil
		end
	end
	if self._vibration then
		self._vibration.delay = self._vibration.delay - dtime
		if self._vibration.delay <= 0 then
			receive_vibration (self, self._vibration)
			self._vibration = nil
		end
	end
	local target = self._hunt_target or self._target_name and core.get_player_by_name (self._target_name)
	if not target_ok (self, target) or target_anger (self, target) < angry_at
		or vector.distance (pos, target:get_pos ()) > self.tracking_distance then
		target = select_target (self, pos)
	end
	self._hunt_target = target
	self._target_name = target and target:is_player () and target:get_player_name () or nil
	if target then
		self._idle_time = 0
	else
		self._idle_time = self._idle_time + dtime
	end
	self._heartbeat_time = self._heartbeat_time - dtime
	if self._heartbeat_time <= 0 then
		self._heart_glow = not self._heart_glow
		self._heartbeat_time = target and 0.24 or self._heart_glow and 0.25 or 1.3
		self:set_textures ({self._heart_glow and heartbeat_texture or idle_texture})
		if self._heart_glow then
			core.sound_play ("mcl_warden_heartbeat", {object = self.object, gain = 0.45, max_hear_distance = 24}, true)
		end
	end
	if self._pose then
		self._pose_left = self._pose_left - dtime
		if self._pose == "sonic" and not self._sonic_fired and self._pose_left <= 1.3 then
			self._sonic_fired = true
			sonic_boom (self, target, pos)
		end
		if self._pose_left > 0 then
			return false
		end
		if self._pose == "dig" then
			self:safe_remove ()
			return false
		elseif self._pose == "emerge" then
			self._emerging = nil
			self.object:set_properties ({pointable = true})
		elseif self._pose == "sniff" then
			sniff (self, pos)
			if self._pose == "roar" then
				return false
			end
		end
		if self._pose_left <= 0 then
			self._pose = nil
			self:set_animation ("stand")
		end
	end
	if target then
		hunt (self, target, pos, dtime)
	elseif self._idle_time >= 60 and (not self.nametag or self.nametag == "") then
		if self._liquidtype and self._liquidtype ~= "none" then
			self:safe_remove ()
		else
			self.object:set_properties ({pointable = false})
			enter_state (self, "dig", 5, "mcl_warden_dig")
		end
	else
		self._sniff_time = self._sniff_time - dtime
		if self._investigate and self._investigate_time > 0 and vector.distance (self._investigate, pos) > 1.5 then
			move_towards (self, pos, self._investigate, dtime, 0.7)
		elseif self._sniff_time <= 0 then
			self._sniff_time = math.random (5, 10)
			enter_state (self, "sniff", 4.2, "mcl_warden_sniff")
		else
			self._investigate = nil
			self:check_pace (pos, dtime)
		end
	end
	return false
end

mcl_mobs.register_mob (mob_name, warden)
mcl_mobs.register_egg (mob_name, S ("Warden"), "#0e252f", "#39d6c1", 0)
core.override_item (mob_name, {inventory_image = "mcl_warden_spawn_egg.png"})

local spawner = table.merge (mcl_mobs.default_spawner, {
	name = mob_name,
	spawn_category = "monster",
	is_canonical = true,
})

function spawner:test_spawn_position (spawn_pos, node_pos, sdata, node_cache, spawn_flag)
	if mcl_vars.difficulty == 0 or mcl_vars.only_peaceful_mobs then
		return false
	end
	if spawn_flag == "sculk_shrieker" then
		for dy = 0, 2 do
			local node = self:get_node (node_cache, dy, node_pos)
			local def = core.registered_nodes[node.name]
			if not def or def.liquidtype ~= "none" then
				return false
			end
		end
	end
	return mcl_mobs.default_spawner.test_spawn_position (self, spawn_pos, node_pos, sdata, node_cache, spawn_flag)
end

mcl_mobs.register_spawner (spawner)
