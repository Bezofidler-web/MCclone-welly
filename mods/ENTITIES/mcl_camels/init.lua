local S = core.get_translator (core.get_current_modname ())
local path = core.get_modpath (core.get_current_modname ())
local mob_class = mcl_mobs.mob_class
local CAMEL, HUSK = "mobs_mc:camel", "mobs_mc:camel_husk"
local SADDLE = "mcl_mobitems:saddle"
local CACTUS = "mcl_core:cactus"
local RABBIT_FOOT = "mcl_mobitems:rabbit_foot"

local camel = {
	description = S ("Camel"),
	type = "animal",
	_spawn_category = "creature",
	hp_min = 32,
	hp_max = 32,
	xp_min = 1,
	xp_max = 3,
	drops = {},
	mesh = "mcl_camels_camel.b3d",
	_child_mesh = "mcl_camels_camel_baby.b3d",
	visual = "mesh",
	visual_size = {x = 1, y = 1},
	textures = {{"mcl_camels_camel.png", "blank.png"}},
	use_texture_alpha = true,
	collisionbox = {-0.85, 0, -0.85, 0.85, 2.375, 0.85},
	head_eye_height = 2.1,
	stepheight = 1.5,
	_safe_fall_distance = 5,
	can_ride_boat = false,
	can_ride_cart = false,
	floats = 1,
	runaway = true,
	movement_speed = 2.5,
	drive_bonus = 1.15,
	steer_class = "controls",
	_csm_driving_enabled = false,
	follow = {CACTUS},
	follow_distance = 10,
	_pace_interval = 4,
	makes_footstep_sound = true,
	sounds = {eat = "mobs_mc_animal_eat_generic", distance = 12},
	animation = {
		stand_start = 0, stand_end = 20, stand_speed = 12,
		walk_start = 21, walk_end = 41, walk_speed = 20,
		run_start = 21, run_end = 41, run_speed = 28,
		sit_start = 42, sit_end = 62, sit_speed = 12,
		dash_start = 63, dash_end = 83, dash_speed = 24, dash_loop = false,
	},
}

local valid_rider, update_seats, clear_players = dofile (path .. "/seats.lua") (camel)
local texture_for = {
	[CAMEL] = "mcl_camels_camel.png",
	[HUSK] = "mcl_camels_camel_husk.png",
}
local saddle_texture_for = {
	[CAMEL] = "mcl_camels_camel_saddle.png",
	[HUSK] = "mcl_camels_camel_husk_saddle.png",
}

local function update_texture (self)
	if self.child then
		self.base_texture = {"mcl_camels_camel_baby.png"}
	else
		self.base_texture = {texture_for[self.name], self._camel_saddle and saddle_texture_for[self.name] or "blank.png"}
	end
	self:set_textures (self.base_texture)
end

local function body_dimensions (self)
	local cbox = table.copy (self.base_colbox)
	local scale = self.child and 0.5 or 1
	for i = 1, 6 do cbox[i] = cbox[i] * scale end
	if self._camel_sitting then cbox[5] = cbox[5] - 0.87 * scale end
	self.collisionbox = cbox
	self:set_properties ({collisionbox = cbox, selectionbox = cbox})
end

function camel:mob_activate (staticdata, dtime)
	if not mob_class.mob_activate (self, staticdata, dtime) then return false end
	update_texture (self)
	body_dimensions (self)
	if self._camel_sitting then self:set_animation ("sit") end
	return true
end

function camel:on_grown ()
	update_texture (self)
	body_dimensions (self)
end

function camel:set_sitting (sitting)
	if (self._camel_sitting == true) == sitting or self.dead then return end
	if not sitting then
		local pos = self.object:get_pos ()
		local size = self.base_colbox[5] * (self.child and 0.5 or 1)
		local ceiling = core.get_node (vector.round (vector.offset (pos, 0, size - 0.05, 0)))
		local def = core.registered_nodes[ceiling.name]
		if not def or def.walkable then return end
	end
	self._camel_sitting = sitting
	self._camel_sit_time = sitting and math.random (5, 12) or nil
	self._camel_stand_delay = not sitting and 0.65 or nil
	self:cancel_navigation ()
	self:halt_in_tracks (false, true)
	body_dimensions (self)
	update_seats (self)
	self:set_animation (sitting and "sit" or "stand")
end

function camel:should_drive ()
	if self.driver and not valid_rider (self, self.driver) then
		local driver = self.driver
		self.driver = nil
		self:driver_detached (driver, false)
	end
	return self._camel_saddle and mob_class.should_drive (self)
end

function camel:apply_driver_input (speed, pos, moveresult, dtime)
	local control = self.driver:get_player_control ()
	if self._camel_sitting and (control.up or control.jump or (control.movement_y or 0) > 0) then
		self:set_sitting (false)
	end
	if self._camel_sitting or self._camel_stand_delay then
		self:halt_in_tracks (false, true)
		self._jump = false
		return
	end
	if control.aux1 and not self._camel_dash_cooldown then speed = speed * 1.75 end
	mob_class.apply_driver_input (self, speed, pos, moveresult, dtime)
	self._jump = self._liquidtype == "water" and (self._immersion_depth or 0) > 0.4
	if control.jump and not self._camel_dash_cooldown and moveresult.touching_ground and not self._liquidtype then
		self._camel_charge = math.min ((self._camel_charge or 0) + dtime, 0.5)
	end
end

function camel:post_apply_driver_input (_, _, moveresult)
	if self.driver:get_player_control ().jump or not self._camel_charge then return end
	local charge = self._camel_charge
	self._camel_charge = nil
	if not moveresult.touching_ground or moveresult.standing_on_object or self._liquidtype then return end
	local strength = 0.4 + 1.2 * charge
	local direction = core.yaw_to_dir (self:get_yaw ())
	self.object:add_velocity (vector.new (direction.x * 19 * strength, 10 * strength, direction.z * 19 * strength))
	self._camel_dash_cooldown = 2.75
	self._camel_dash_animation = 0.7
end

function camel:drive (moving, idle, can_fly, dtime, moveresult)
	if self._camel_sitting then moving, idle = "sit", "sit" end
	if self._camel_dash_animation then moving, idle = "dash", "dash" end
	mob_class.drive (self, moving, idle, can_fly, dtime, moveresult)
end

function camel:expel_underwater_drivers ()
	-- Camels swim with riders. Dismount only if the mount is completely submerged.
	if core.get_item_group (self.head_in, "water") > 0 then clear_players (self) end
end

local function tick_timer (time, dtime)
	if time and time > dtime then return time - dtime end
end

function camel:ai_step (dtime)
	mob_class.ai_step (self, dtime)
	self._camel_dash_cooldown = tick_timer (self._camel_dash_cooldown, dtime)
	self._camel_dash_animation = tick_timer (self._camel_dash_animation, dtime)
	self._camel_stand_delay = tick_timer (self._camel_stand_delay, dtime)
	self._camel_sit_time = tick_timer (self._camel_sit_time, dtime)
end

local function sit (self, _, _, moveresult)
	if self._camel_sitting then
		if not self._camel_sit_time or self._liquidtype or self:is_frightened () then self:set_sitting (false) end
	elseif self._camel_stand_delay then
		return true
	elseif not self.driver and not self._camel_passenger and not self._jockey_rider and not self._camel_back_rider
		and not self.child and not self._liquidtype and moveresult.touching_ground and self:navigation_finished ()
		and self:check_timer ("camel_sit", 5) and math.random (3) == 1 then
		self:set_sitting (true)
	end
	return self._camel_sitting == true
end

local function check_breeding (self, pos, dtime)
	if not self.driver and not self._camel_passenger then
		return mob_class.check_breeding (self, pos, dtime)
	end
	return false
end

function camel:on_breed ()
	local cub = mcl_mobs.spawn_child (self.object:get_pos (), CAMEL)
	local entity = cub and cub:get_luaentity ()
	if entity then entity.persistent = true end
end

function camel:receive_damage (reason, damage)
	if reason.type == "cactus" then return false end
	if damage > 0 then self:set_sitting (false) end
	return mob_class.receive_damage (self, reason, damage)
end

function camel:actionable_on_rightclick ()
	return true
end

function camel:on_rightclick (player)
	if not player:is_player () or self.dead or self._jockey_rider or self._camel_back_rider then return end
	local item = player:get_wielded_item ()
	local name = item:get_name ()
	local undead = self.name == HUSK
	if name == (undead and RABBIT_FOOT or CACTUS) then
		local breeding = not undead and not self.child and self:breed_interact ()
		if self:feed_tame (player, 2, false, false) then
			self.persistent = true
		elseif breeding then
			if not core.is_creative_enabled (player:get_player_name ()) then
				item:take_item ()
				player:set_wielded_item (item)
			end
		end
		return
	end
	if self.child then return end
	if name == SADDLE and not self._camel_saddle then
		self._camel_saddle = true
		self.persistent = true
		update_texture (self)
		if not core.is_creative_enabled (player:get_player_name ()) then
			item:take_item ()
			player:set_wielded_item (item)
		end
		core.sound_play ("mcl_armor_equip_leather", {object = self.object}, true)
		return
	end
	if player:get_player_control ().sneak and not self.driver and not self._camel_passenger then
		self:set_sitting (not self._camel_sitting)
		self.persistent = true
	elseif not player:get_attach () and self:mount_player (player) then
		self.persistent = true
	end
end

function camel:on_die (pos)
	clear_players (self)
	if self._camel_saddle and mcl_vars.mobs_drop_items then core.add_item (pos, SADDLE) end
	self._camel_saddle = nil
end

function camel:do_custom ()
	self:check_passenger ()
	if self.driver and not self._camel_saddle then self:halt_in_tracks () end
	if self._camel_sitting then self:set_animation ("sit") end
end

function camel:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if data then
		data._camel_charge = nil
		data._camel_stand_delay = nil
		data._camel_dash_animation = nil
	end
	return data
end

function camel:on_deactivate (removal)
	clear_players (self)
	mob_class.on_deactivate (self, removal)
end

camel.ai_functions = {
	mob_class.check_frightened, check_breeding, mob_class.check_following, mob_class.follow_herd, sit, mob_class.check_pace,
}

local husk = dofile (path .. "/husk.lua") (camel)
mcl_mobs.register_mob (CAMEL, camel)
mcl_mobs.register_mob (HUSK, husk)
mcl_mobs.register_egg (CAMEL, S ("Camel"), "#d7a86d", "#7b482d", 0)
mcl_mobs.register_egg (HUSK, S ("Camel Husk"), "#777957", "#b8ac81", 0)
core.override_item (CAMEL, {inventory_image = "mcl_camels_camel_spawn_egg.png"})
core.override_item (HUSK, {inventory_image = "mcl_camels_camel_husk_spawn_egg.png"})

dofile (path .. "/spawning.lua") (CAMEL, HUSK)
