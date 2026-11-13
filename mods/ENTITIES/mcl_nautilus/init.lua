-- SPDX-License-Identifier: GPL-3.0-or-later

local modpath = core.get_modpath (core.get_current_modname ())
local S = core.get_translator ("mcl_nautilus")
local mob_class = mcl_mobs.mob_class
local armor = dofile (modpath .. "/items.lua")
local breath_effect = dofile (modpath .. "/breath.lua")
local normal, zombie = "mobs_mc:nautilus", "mobs_mc:zombie_nautilus"
local pufferfish, pufferfish_bucket = "mcl_fishing:pufferfish_raw", "mcl_buckets:bucket_pufferfish"
local saddle = "mcl_mobitems:saddle"
local is_warm_ocean, is_river

mcl_nautilus = {}

core.register_on_mods_loaded (function ()
	is_warm_ocean = mcl_biome_dispatch.make_biome_test ("WarmOcean")
	is_river = mcl_biome_dispatch.make_biome_test ("#more_frequent_drowned_spawns")
end)

local foods = {
	[pufferfish] = 2, [pufferfish_bucket] = 2, ["mcl_fishing:clownfish_raw"] = 2,
	["mcl_buckets:bucket_tropical_fish"] = 2, ["mcl_fishing:fish_raw"] = 4, ["mcl_fishing:salmon_raw"] = 4,
	["mcl_buckets:bucket_cod"] = 4, ["mcl_buckets:bucket_salmon"] = 4,
	["mcl_fishing:fish_cooked"] = 10, ["mcl_fishing:salmon_cooked"] = 12,
}

local function is_pufferfish (name)
	return name == pufferfish or name == pufferfish_bucket
end

local function in_water (pos)
	return core.get_item_group (core.get_node (pos).name, "water") > 0
end

local function refresh_appearance (self)
	local texture
	if self.child then
		texture = "mcl_nautilus_nautilus_baby.png"
	elseif self.name == zombie then
		texture = self._coral and "mcl_nautilus_zombie_nautilus_coral.png" or "mcl_nautilus_zombie_nautilus.png"
	else
		texture = "mcl_nautilus_nautilus.png"
	end
	local equipped = armor[ItemStack (self._nautilus_armor):get_name ()]
	local fitted = equipped and equipped.texture or "blank.png"
	local saddle_texture = self._nautilus_saddle and "mcl_nautilus_saddle.png" or "blank.png"
	self:set_textures ({texture, fitted, saddle_texture})
	if equipped and equipped.knockback > 0 then
		self:add_physics_factor ("knockback_resistance", "mcl_nautilus:armor", equipped.knockback, "add")
	else
		self:remove_physics_factor ("knockback_resistance", "mcl_nautilus:armor")
	end
end

local function dash (self, direction, power, target)
	if (self._dash_cooldown or 0) > 0 then return false end
	self._dash_cooldown = 2
	self._dash_time = 0.7
	self._dash_target = target
	self.object:add_velocity (vector.multiply (direction, power))
	self:set_animation ("run")
	core.sound_play ("mcl_nautilus_dash", {object = self.object, gain = 0.75, max_hear_distance = 18}, true)
	return true
end

local function hunt (self, pos, dtime)
	if self.driver or self.child or not in_water (pos) then return end
	local target = self._dash_target
	if target and self._dash_time and self._dash_time > 0 then return true end
	local rider = self._jockey_rider and self._jockey_rider:get_luaentity ()
	if self.name == zombie then
		target = rider and rider.attack
	else
		target = self._recent_attacker
		if not target and not self.tamed and self:check_timer ("hunt_pufferfish", 8) then
			for obj in core.objects_inside_radius (pos, 14) do
				local entity = obj:get_luaentity ()
				if entity and entity.name == "mobs_mc:pufferfish" and not entity.dead then target = obj; break end
			end
		end
	end
	if not target or not target:is_valid () or not target:get_pos () then return end
	if target:is_player () then
		local mode = mcl_gamemode.get_gamemode (target)
		if target:get_hp () <= 0 or mode == "creative" or mode == "spectator"
			or self.tamed and target:get_player_name () == self.owner then return end
	end
	local target_pos = mcl_util.target_eye_pos (target)
	if not in_water (target_pos) or vector.distance (pos, target_pos) > 14 then return end
	if self:target_visible (pos, target) then
		self:look_at (target_pos)
		if dash (self, vector.direction (pos, target_pos), 9, target) then return true end
	end
	if self:navigation_finished () then self:session_navigate (target:get_pos (), 0.75, 1, 1, 1) end
	self:poll_navigation_state (pos, dtime, 5, target:get_pos ())
	return true
end

local function return_home (self, pos, dtime)
	local home = self._home
	if not home or self.driver then return end
	if vector.distance (pos, home) <= (self._nautilus_saddle and 16 or 32) then return end
	if self:navigation_finished () then self:session_navigate (home, 1, 1, 1, 2) end
	self:poll_navigation_state (pos, dtime, 5, home)
	return true
end

local nautilus = {
	description = S ("Nautilus"),
	_nautilus = true,
	type = "animal",
	_spawn_category = "water_creature",
	hp_min = 15, hp_max = 15,
	xp_min = 1, xp_max = 3,
	visual = "mesh",
	mesh = "mcl_nautilus.b3d",
	_child_mesh = "mcl_nautilus_baby.b3d",
	textures = {{"mcl_nautilus_nautilus.png", "blank.png", "blank.png"}},
	use_texture_alpha = true,
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.4375, 0, -0.4375, 0.4375, 0.95, 0.4375},
	head_eye_height = 0.2751,
	knockback_resistance = 0.3,
	animation = {
		stand_start = 0, stand_end = 40, stand_speed = 16,
		walk_start = 41, walk_end = 81, walk_speed = 22,
		run_start = 82, run_end = 99, run_speed = 22, run_loop = false,
	},
	sounds = {random = "mcl_nautilus_ambient", damage = "mcl_nautilus_hurt", death = "mcl_nautilus_hurt"},
	breathes_in_water = true,
	_max_air_supply = 15,
	swims = true,
	flops = true,
	do_go_pos = mob_class.pitchswim_do_go_pos,
	movement_speed = 6,
	swim_speed_factor = 0.12,
	pace_chance = 14,
	pace_interval = 0.4,
	pace_bonus = 0.75,
	pace_height = 4,
	follow_bonus = 1.15,
	breed_bonus = 0.8,
	can_despawn = true,
	makes_footstep_sound = false,
	can_ride_boat = false,
	can_ride_cart = false,
	steer_class = "controls",
	drive_bonus = 1,
	driver_attach_at = vector.new (0, 11.375, 0),
	_jockey_bone = "",
	_jockey_pos = vector.new (0, 11.375, 0),
	_jockey_rot = vector.zero (),
	follow = {pufferfish, pufferfish_bucket},
	ai_functions = {hunt, return_home, mob_class.check_breeding, mob_class.check_following, mob_class.check_pace},
}

function nautilus:mob_activate (staticdata, dtime)
	if mob_class.mob_activate (self, staticdata, dtime) == false then return false end
	if self.name == zombie then
		if self._coral == nil then
			local biome = mcl_biome_dispatch.get_biome_name (self.object:get_pos ())
			self._coral = is_warm_ocean (biome)
		end
		if self._coral then self.object:set_properties ({mesh = "mcl_nautilus_coral.b3d"}) end
	end
	refresh_appearance (self)
	return true
end

function nautilus:on_grown ()
	refresh_appearance (self)
end

function nautilus:breeding_possible ()
	return self.name == normal and self.tamed and mob_class.breeding_possible (self)
end

function nautilus:on_breed ()
	local baby = mcl_mobs.spawn_child (self.object:get_pos (), normal)
	if baby then baby:get_luaentity ().persistent = true end
end

local function gear (self, stack)
	local name = stack:get_name ()
	if not self.tamed or self.child or self.driver or self._jockey_rider then return false end
	if name == saddle and not self._nautilus_saddle then
		self._nautilus_saddle = true
	elseif armor[name] and not self._nautilus_armor then
		self._nautilus_armor = stack:peek_item (1):to_string ()
	else
		return false
	end
	refresh_appearance (self)
	return true
end

local function remove_gear (self)
	local item = self._nautilus_armor or self._nautilus_saddle and saddle
	if not item or not core.add_item (self.object:get_pos (), item) then return false end
	if self._nautilus_armor then self._nautilus_armor = nil else self._nautilus_saddle = nil end
	refresh_appearance (self)
	return true
end

function nautilus:actionable_on_rightclick (player)
	if self._jockey_rider or self.driver then return false end
	local item = player:get_wielded_item ():get_name ()
	return self.tamed or is_pufferfish (item)
end

function nautilus:on_rightclick (player)
	if not player:is_player () or self.dead or self.removed then return end
	local player_name = player:get_player_name ()
	local pos = self.object:get_pos ()
	if core.is_protected (vector.round (pos), player_name) then
		core.record_protection_violation (vector.round (pos), player_name)
		return
	end
	self.persistent = true
	if self._jockey_rider or self.driver then return end
	local stack = player:get_wielded_item ()
	local item = stack:get_name ()
	local food = foods[item]
	local creative = core.is_creative_enabled (player_name)
	if not self.tamed and is_pufferfish (item) or self.tamed and food then
		local taming = not self.tamed
		local consumed = self:feed_tame (player, food, self.tamed and is_pufferfish (item), taming, true, 1 / 3)
		if consumed then
			if self.tamed and not self._home then self._home = pos end
			if not creative then
				if item:find ("^mcl_buckets:bucket_") then stack = ItemStack ("mcl_buckets:bucket_water")
				else stack:take_item () end
				player:set_wielded_item (stack)
			end
			return
		end
	end
	if not self.tamed or self.child then return end
	if gear (self, stack) then
		if not creative then stack:take_item (); player:set_wielded_item (stack) end
	elseif core.get_item_group (item, "shears") > 0 and remove_gear (self) then
		if not creative then mcl_util.use_item_durability (stack, 1); player:set_wielded_item (stack) end
	elseif self._nautilus_saddle and not player:get_attach () and not player:get_player_control ().sneak then
		if self:attach (player) then
			self._rider_breath = player:get_breath ()
			mcl_potions.give_effect_by_level (breath_effect, player, 1, 2, true)
		end
	end
end

function nautilus:_on_dispense (stack)
	if self.dead or self.removed or core.is_protected (vector.round (self.object:get_pos ()), "") then return end
	if gear (self, stack) then stack:take_item (); return stack end
	return mob_class._on_dispense (self, stack)
end

function nautilus:driver_detached (player, is_deactivation)
	mob_class.driver_detached (self, player, is_deactivation)
	if player:is_valid () then mcl_potions.clear_effect (player, breath_effect) end
	self._rider_breath, self._rider_jump, self._dash_charge, self._release_dash = nil, nil, nil, nil
	self._home = self.object:get_pos () or self._home
end

function nautilus:expel_underwater_drivers () end

function nautilus:apply_driver_input (speed, pos, result, dtime)
	mob_class.apply_driver_input (self, speed, pos, result, dtime)
	self._jump = false
	local look = self.driver:get_look_vertical ()
	local forward = self.acc_dir.z
	self.acc_dir.z = forward * math.cos (look) * 0.14
	self.acc_dir.y = -forward * math.sin (look) * 0.14
	self.acc_dir.x = self.acc_dir.x * 0.14
	self._acc_no_gravity = in_water (pos)
	local jump = self.driver:get_player_control ().jump
	if jump then self._dash_charge = math.min (0.5, (self._dash_charge or 0) + dtime) end
	if not jump and self._rider_jump then self._release_dash = true end
	self._rider_jump = jump
end

function nautilus:post_apply_driver_input ()
	if self._release_dash then
		local charge = self._dash_charge or 0
		self._release_dash, self._dash_charge = nil, nil
		local strength = 7 + 10 * charge
		if not in_water (self.object:get_pos ()) then strength = strength * 0.5 / 1.2 end
		dash (self, self.driver:get_look_dir (), strength)
	end
end

function nautilus:do_custom (dtime)
	self._dash_cooldown = math.max (0, (self._dash_cooldown or 0) - dtime)
	if self._dash_time then
		self:set_animation ("run")
		self._dash_time = self._dash_time - dtime
		local target = self._dash_target
		if target and target:is_valid () and target:get_pos () then
			local here = vector.offset (self.object:get_pos (), 0, 0.45, 0)
			local there = mcl_util.target_eye_pos (target)
			if vector.distance (here, there) < 1.45 and self:line_of_sight (here, there) then
				mcl_util.deal_damage (target, 3, {type = "mob", source = self.object, direct = self.object})
				self._dash_target = nil
			end
		end
		if self._dash_time <= 0 then self._dash_time, self._dash_target = nil, nil end
	end
	if self.driver and self.driver:is_valid () then
		if self.driver:get_player_control ().sneak then
			self:detach (self.driver, vector.new (0, 0.2, 0))
		elseif not mcl_potions.has_effect (self.driver, breath_effect) then
			mcl_potions.give_effect_by_level (breath_effect, self.driver, 1, 2, true)
		end
	end
	if self.name == zombie and not self._nautilus_armor and self:check_timer ("sunlight", 1)
		and not in_water (self.object:get_pos ()) then
		local pos = vector.offset (self.object:get_pos (), 0, 0.75, 0)
		local sunlight, direct, rain = self:get_weather_with_light (pos, mcl_util.get_current_time_of_day ())
		if direct >= 15 and sunlight >= 12 and not rain then self:fast_ignite (10) end
	end
end

function nautilus:item_drop (cooked, looting, reason)
	looting = looting or 0
	self.drops = {}
	if self.last_player_hit_time and core.get_gametime () - self.last_player_hit_time <= 5 then
		if self.name == normal then
			self.drops = {{name = "mcl_mobitems:nautilus_shell", chance = 20, looting = "rare"}}
		else
			self.drops = {{name = "mcl_mobitems:rotten_flesh", chance = 1, min = 0, max = 3, looting = "common"}}
		end
	end
	mob_class.item_drop (self, cooked, looting, reason)
	if mcl_vars.mobs_drop_items then
		local pos = self.object:get_pos ()
		if self._nautilus_armor then core.add_item (pos, self._nautilus_armor) end
		if self._nautilus_saddle then core.add_item (pos, saddle) end
	end
end

local undead = table.merge (nautilus, {
	description = S ("Zombie Nautilus"),
	_spawn_category = "monster",
	persist_in_peaceful = true,
	harmed_by_heal = true,
	textures = {{"mcl_nautilus_zombie_nautilus.png", "blank.png", "blank.png"}},
	does_not_prevent_sleep = true,
	step_drowning = function () end,
})

mcl_mobs.register_mob (normal, nautilus)
mcl_mobs.register_mob (zombie, undead)
mcl_mobs.register_egg (normal, S ("Nautilus"), "#bd714a", "#416363")
mcl_mobs.register_egg (zombie, S ("Zombie Nautilus"), "#657852", "#58a49f")
core.override_item (normal, {inventory_image = "mcl_nautilus_nautilus_spawn_egg.png"})
core.override_item (zombie, {inventory_image = "mcl_nautilus_zombie_nautilus_spawn_egg.png"})

mcl_damage.register_modifier (function (object, damage, reason)
	local mob = object:get_luaentity ()
	if not mob or not mob._nautilus or not mob._nautilus_armor or reason.flags.bypasses_armor then return end
	local equipped = armor[ItemStack (mob._nautilus_armor):get_name ()]
	if equipped then
		local points = math.min (20, math.max (equipped.points / 5, equipped.points - damage / (2 + equipped.toughness / 4)))
		return damage * (1 - points / 25)
	end
end, -30)

local warm = {"Ocean", "DeepOcean", "LukewarmOcean", "DeepLukewarmOcean", "WarmOcean"}
local cold = {"ColdOcean", "DeepColdOcean", "FrozenOcean", "DeepFrozenOcean"}
local spawner = table.merge (mcl_mobs.default_spawner, {
	name = normal, spawn_category = "water_creature", spawn_placement = "aquatic",
	weight = 5, pack_min = 1, pack_max = 1, biomes = warm,
})

function spawner:test_spawn_position (spawn_pos, node_pos, data, cache, flag)
	if node_pos.y < -25 or node_pos.y > -5 then return false end
	for dy = -1, 1 do
		if core.get_item_group (self:get_node (cache, dy, node_pos).name, "water") == 0 then return false end
	end
	return mcl_mobs.default_spawner.test_spawn_position (self, spawn_pos, node_pos, data, cache, flag)
end

mcl_mobs.register_spawner (spawner)
mcl_mobs.register_spawner (table.merge (spawner, {biomes = cold, weight = 2}))

-- Natural and ocean-ruin Drowned already roll their own equipment.
function mcl_nautilus.maybe_create_jockey (rider, structure_spawn)
	if rider.child or rider.jockey_vehicle or rider:get_wielditem ():get_name () ~= "mcl_tridents:trident"
		or math.random () >= 0.5 then return end
	local pos = rider.object:get_pos ()
	local biome = mcl_biome_dispatch.get_biome_name (pos)
	if is_river (biome) then return end
	local data = core.serialize ({_coral = is_warm_ocean (biome), persistent = structure_spawn or nil})
	local mount = core.add_entity (pos, zombie, data)
	if mount and mount:is_valid () then
		local entity = mount:get_luaentity ()
		-- Both mobs can attack. The mount runs its own charging goal.
		rider._dominant_in_jockeys = false
		rider:jock_to_existing (mount, entity._jockey_bone, entity._jockey_pos, entity._jockey_rot)
	end
end
