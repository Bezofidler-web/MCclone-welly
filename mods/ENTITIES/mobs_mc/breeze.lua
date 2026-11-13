local S = core.get_translator ("mobs_mc")
local mob_class = mcl_mobs.mob_class
local charge_name = "mobs_mc:breeze_wind_charge"
local charge_speed = 19

local trial_mobs = {
	["mobs_mc:breeze"] = true,
	["mobs_mc:bogged"] = true,
	["mobs_mc:cave_spider"] = true,
	["mobs_mc:husk"] = true,
	["mobs_mc:slime_big"] = true,
	["mobs_mc:slime_small"] = true,
	["mobs_mc:slime_tiny"] = true,
	["mobs_mc:skeleton"] = true,
	["mobs_mc:spider"] = true,
	["mobs_mc:stray"] = true,
	["mobs_mc:zombie"] = true,
	["mobs_mc:baby_zombie"] = true,
}

mcl_damage.register_type ("breeze_wind_charge", {is_projectile = true})

local function burst (self, pos, hit_pos, target)
	local shooter = self._shooter
	if shooter and not shooter:is_valid () then
		shooter = nil
	end
	if target then
		local ent = target:get_luaentity ()
		-- Damage other trial mobs without inciting retaliation.
		local friendly = ent and trial_mobs[ent.name] and shooter and not shooter:is_player ()
		mcl_util.deal_damage (target, 1, {
			type = "breeze_wind_charge",
			source = not friendly and shooter or nil,
			direct = not friendly and self.object or nil,
		})
	end

	mcl_charges.wind_burst (pos, 4)
	core.add_particlespawner (table.merge (mcl_charges.wind_burst_spawner, {
		minpos = vector.offset (pos, -0.55, -0.15, -0.55),
		maxpos = vector.offset (pos, 0.55, 0.45, 0.55),
	}))
	core.sound_play ("tnt_explode", {pos = pos, gain = 0.4, pitch = 2.5}, true)

	local protected_as = shooter and shooter:is_player () and shooter:get_player_name () or ""
	local doors_toggled = {}
	local function affect_node (node_pos, direct)
		local node = core.get_node (node_pos)
		local def = core.registered_nodes[node.name]
		if not def or node.name == "air" or core.is_protected (node_pos, protected_as) then
			return
		end
		if core.get_item_group (node.name, "door_iron") > 0 then
			return
		end
		local door_top = core.get_item_group (node.name, "door_top") > 0
		if door_top or core.get_item_group (node.name, "door_bottom") > 0 then
			local base = door_top and vector.offset (node_pos, 0, -1, 0) or node_pos
			local top = vector.offset (base, 0, 1, 0)
			local hash = core.hash_node_position (base)
			if doors_toggled[hash] or core.is_protected (base, protected_as)
				or core.is_protected (top, protected_as) or mcl_redstone.get_power (base) > 0
				or mcl_redstone.get_power (top) > 0 then
				return
			end
			doors_toggled[hash] = true
		elseif (core.get_item_group (node.name, "trapdoor") > 0
			or core.get_item_group (node.name, "fence_gate") > 0)
			and mcl_redstone.get_power (node_pos) > 0 then
			return
		end
		if def._on_wind_charge_hit then
			def._on_wind_charge_hit (node_pos, self)
		elseif core.get_item_group (node.name, "button") == 1 then
			mcl_buttons.push_button (node_pos, node)
		elseif node.name == "mcl_lever:lever_off" or node.name == "mcl_lever:lever_on" then
			def.on_rightclick (node_pos, node)
		elseif core.get_item_group (node.name, "bell") > 0 then
			mcl_bells.ring_once (node_pos)
		elseif direct and (node.name == "mcl_end:chorus_flower"
				or node.name == "mcl_end:chorus_flower_dead"
				or node.name == "mcl_pottery_sherds:pot") then
			core.dig_node (node_pos)
		end
	end
	if hit_pos then
		affect_node (hit_pos, true)
	end
	local center = vector.round (pos)
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local node_pos = vector.offset (center, x, y, z)
				if not hit_pos or not vector.equals (node_pos, hit_pos) then
					affect_node (node_pos, false)
				end
			end
		end
	end
	self.object:remove ()
end

core.register_entity (charge_name, {
	initial_properties = {
		visual = "mesh",
		mesh = "wind_charge.obj",
		visual_size = {x = 2, y = 1.5},
		textures = {"mcl_charges_wind_charge_entity.png"},
		collisionbox = {-0.18, -0.18, -0.18, 0.18, 0.18, 0.18},
		pointable = true,
		physical = false,
		static_save = false,
	},
	_age = 0,
	on_activate = function (self)
		self._last_pos = self.object:get_pos ()
		self.object:set_armor_groups ({immortal = 1})
	end,
	on_punch = function (self, hitter)
		if hitter and hitter:is_player () then
			self._shooter = hitter
			self.object:set_velocity (vector.multiply (hitter:get_look_dir (), charge_speed))
			self._last_pos = self.object:get_pos ()
		end
	end,
	on_step = function (self, dtime)
		self._age = self._age + dtime
		if self._age > 5 then
			self.object:remove ()
			return
		end
		local pos = self.object:get_pos ()
		for hit in core.raycast (self._last_pos, pos, true, false) do
			local impact = hit.intersection_point or pos
			if hit.type == "node" then
				burst (self, impact, hit.under)
				return
			end
			local obj = hit.ref
			if obj ~= self.object and obj ~= self._shooter and obj:is_valid () then
				local ent = obj:get_luaentity ()
				if obj:is_player () or ent and ent.is_mob and not ent.dead then
					burst (self, impact, nil, obj)
					return
				end
			end
		end
		self._last_pos = pos
	end,
})

local breeze = {
	description = S ("Breeze"),
	type = "monster",
	_spawn_category = "monster",
	hp_min = 30,
	hp_max = 30,
	xp_min = 10,
	xp_max = 10,
	collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	head_eye_height = 1.45,
	visual = "mesh",
	mesh = "mobs_mc_breeze.obj",
	textures = {{"mobs_mc_breeze.png^mobs_mc_breeze_eyes.png", "mobs_mc_breeze_wind.png"}},
	visual_size = {x = 1, y = 1},
	use_texture_alpha = true,
	backface_culling = false,
	view_range = 24,
	tracking_distance = 24,
	attack_type = "null",
	movement_speed = 5,
	fall_damage = 0,
	ai_functions = {mob_class.check_attack, mob_class.check_pace},
	_targeting_rules = {
		mcl_mobs.build_nearest_target_rule ("player"),
	},
}

function breeze:_mcl_deflect_projectile (projectile, intersection)
	local velocity = projectile:get_velocity ()
	if vector.length (velocity) == 0 then
		return false
	end
	local direction = vector.normalize (velocity)
	projectile:set_pos (vector.subtract (intersection or projectile:get_pos (),
					    vector.multiply (direction, 0.12)))
	projectile:set_velocity (vector.multiply (velocity, -0.5))
	return true
end

function breeze:receive_damage (reason, damage)
	local projectile = reason.direct and reason.direct:get_luaentity ()
	if projectile and reason.flags and reason.flags.is_projectile
		and projectile.name ~= charge_name and projectile.name ~= "mcl_charges:wind_charge_flying" then
		self:_mcl_deflect_projectile (reason.direct)
		return false
	end
	return mob_class.receive_damage (self, reason, damage)
end

function breeze:item_drop (cooked, looting, reason)
	if mcl_vars.mobs_drop_items and self.last_player_hit_time
		and core.get_gametime () - self.last_player_hit_time <= 5 then
		looting = looting or 0
		local rods = math.random (1, 2)
		if looting > 0 then
			rods = rods + math.floor (looting * (1 + math.random ()) + 0.5)
		end
		core.add_item (self.object:get_pos (), "mcl_mobitems:breeze_rod " .. rods)
	end
	mob_class.item_drop (self, cooked, looting, reason)
end

local function leap (self, pos, target_pos)
	local toward = vector.subtract (target_pos, pos)
	toward.y = 0
	local distance = vector.length (toward)
	if distance < 0.05 then
		toward = vector.new (1, 0, 0)
	else
		toward = vector.divide (toward, distance)
	end
	local lateral = vector.new (-toward.z, 0, toward.x)
	local sign = math.random (0, 1) == 1 and 1 or -1
	local forward = distance > 9 and 4 or distance < 4 and -3 or 1
	for _, side in ipairs ({sign, -sign}) do
		local offset = vector.add (vector.multiply (toward, forward), vector.multiply (lateral, 3 * side))
		local landing = vector.round (vector.offset (vector.add (pos, offset), 0, 0.5, 0))
		local floor_pos = vector.offset (landing, 0, -1, 0)
		local feet = core.registered_nodes[core.get_node (landing).name]
		local head = core.registered_nodes[core.get_node (vector.offset (landing, 0, 1, 0)).name]
		if feet and not feet.walkable and head and not head.walkable
			and self:is_up_face_sturdy (floor_pos) then
			self.object:set_velocity (vector.new (offset.x * 2.5, 9, offset.z * 2.5))
			return
		end
	end
	self.object:add_velocity (vector.new (0, 6, 0))
end

function breeze:attack_null (pos, _, dtime, target_pos, visible)
	if not self.attacking then
		self.attacking = true
		self._breeze_cooldown = 0.65
		self._breeze_leap = false
	end
	self._breeze_cooldown = self._breeze_cooldown - dtime
	if not visible then
		self:go_to_pos (target_pos)
		return
	end
	self:look_at (target_pos)
	self:halt_in_tracks ()
	if self._breeze_cooldown > 0 or not self._was_touching_ground then
		return
	end
	if self._breeze_leap then
		leap (self, pos, target_pos)
		self._breeze_cooldown = 0.6
	else
		local origin = vector.offset (pos, 0, 1.25, 0)
		local target = vector.offset (target_pos, 0, mcl_util.target_eye_height (self.attack) * 0.7, 0)
		local dir = vector.direction (origin, target)
		local obj = core.add_entity (vector.add (origin, vector.multiply (dir, 0.42)), charge_name)
		if obj then
			obj:get_luaentity ()._shooter = self.object
			obj:set_velocity (vector.multiply (dir, charge_speed))
		end
		self._breeze_cooldown = 1.35
	end
	self._breeze_leap = not self._breeze_leap
end

mcl_mobs.register_mob ("mobs_mc:breeze", breeze)
mcl_mobs.register_egg ("mobs_mc:breeze", S ("Breeze"), "#659c9b", "#a3eff1", 0)
core.override_item ("mobs_mc:breeze", {inventory_image = "mobs_mc_breeze_spawn_egg.png"})

-- This gives trial spawners the monster clearance and difficulty checks.
-- The empty biome and structure lists keep Breezes out of random spawn packs.
mcl_mobs.register_spawner (table.merge (mobs_mc.monster_spawner, {
	name = "mobs_mc:breeze",
	biomes = {},
	is_canonical = true,
}))
