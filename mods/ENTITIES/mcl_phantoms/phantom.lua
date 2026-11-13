return function (id, membrane, S)
	local mob_class = mcl_mobs.mob_class
	local phantom = {
		description = S ("Phantom"),
		type = "monster",
		_spawn_category = "monster",
		hp_min = 20,
		hp_max = 20,
		xp_min = 5,
		xp_max = 5,
		collisionbox = {-0.45, -0.15, -0.45, 0.45, 0.35, 0.45},
		head_eye_height = 0.15,
		visual = "mesh",
		mesh = "mcl_phantoms_phantom.obj",
		textures = {{"mcl_phantoms_phantom.png^(mcl_phantoms_phantom_eyes.png^[makealpha:0,0,0)"}},
		visual_size = {x = 1, y = 1},
		use_texture_alpha = true,
		rotate = 180,
		movement_speed = 7.0,
		view_range = 64,
		damage = 6,
		ignited_by_sunlight = true,
		_no_fall_damage = true,
		can_ride_boat = false,
		can_ride_cart = false,
		makes_footstep_sound = false,
		can_despawn = true,
		drops = {{name = membrane, chance = 1, min = 0, max = 1, looting = "common"}},
	}

	function phantom:mob_activate (data, dtime)
		if not mob_class.mob_activate (self, data, dtime) then return false end
		-- The shared sunlight routine uses an empty helmet slot to detect exposure.
		self.armor_list = {head = ""}
		return true
	end

	local function eligible (self, pos, object)
		if not object or not object:is_valid () or not object:is_player () or not self:attack_player_allowed (object) then
			return false
		end
		local target_pos = object:get_pos ()
		return target_pos and mcl_worlds.pos_to_dimension (target_pos) == mcl_worlds.pos_to_dimension (pos)
			and vector.distance (pos, target_pos) <= self.view_range
	end

	local function select_target (self, pos)
		local current = self._phantom_target
		if eligible (self, pos, current) then return current end
		self._phantom_target = nil
		if not self:check_timer ("phantom_target", 1.5) then return end
		local highest
		for _, player in ipairs (core.get_connected_players ()) do
			if eligible (self, pos, player) and self:target_visible (pos, player) then
				local height = player:get_pos ().y
				if not highest or height > highest then self._phantom_target, highest = player, height end
			end
		end
		return self._phantom_target
	end

	local function scared_of_cat (self, pos)
		if self._phantom_cat == nil or self:check_timer ("phantom_cats", 1) then
			self._phantom_cat = false
			for object in core.objects_inside_radius (pos, 16) do
				local entity = object:get_luaentity ()
				if entity and entity.name == "mobs_mc:cat" and not entity.dead then
					self._phantom_cat = true
					break
				end
			end
		end
		return self._phantom_cat
	end

	local function open (pos)
		local name = core.get_node (vector.round (pos)).name
		local def = core.registered_nodes[name]
		return def and not def.walkable and name ~= "ignore"
	end

	local function retreat (self, pos, target)
		self._phantom_diving = false
		self._phantom_attack_time = 5 + math.random () * 4
		local away = vector.normalize (vector.new (pos.x - target.x, 0, pos.z - target.z))
		self._phantom_retreat = vector.add (vector.offset (pos, 0, 8, 0), vector.multiply (away, 6))
	end

	function phantom:ai_step (dtime)
		mob_class.ai_step (self, dtime)
		local pos = self.object:get_pos ()
		if not pos then return end
		self._phantom_destination = nil
		local target = select_target (self, pos)
		local target_pos = target and target:get_pos ()
		self.attack = target
		if self._phantom_retreat then
			if vector.distance (pos, self._phantom_retreat) > 1.5 and open (self._phantom_retreat) then
				self._phantom_destination = self._phantom_retreat
				return
			end
			self._phantom_retreat = nil
		end
		if target_pos then
			if scared_of_cat (self, pos) or self._recent_attacker then
				retreat (self, pos, target_pos)
				return
			end
			self._phantom_attack_time = (self._phantom_attack_time or 6) - dtime
			local aim = vector.offset (target_pos, 0, 0.85, 0)
			if self._phantom_attack_time <= 0 and self:target_visible (pos, target) then
				self._phantom_diving = true
			end
			if self._phantom_diving then
				if not self:target_visible (pos, target) then
					retreat (self, pos, target_pos)
				elseif vector.distance (pos, aim) < 1.2 then
					local damage = mcl_vars.difficulty == 1 and 4 or mcl_vars.difficulty == 3 and 9 or self.damage
					mcl_util.deal_damage (target, damage, {type = "mob", source = self.object})
					retreat (self, pos, target_pos)
				else
					self._phantom_destination = aim
				end
				return
			end
		else
			self._phantom_diving = false
		end
		local anchor = target_pos and vector.offset (target_pos, 0, 10, 0) or self._phantom_anchor or pos
		self._phantom_anchor = anchor
		local phase = (self._phantom_orbit_phase or 0) + dtime * 0.65
		self._phantom_orbit_phase = phase % (math.pi * 2)
		local dest = vector.offset (anchor, math.cos (phase) * 8, math.sin (phase * 2) * 1.8, math.sin (phase) * 8)
		if open (dest) then self._phantom_destination = dest end
	end

	function phantom:item_drop (cooked, looting, reason)
		local hit_time = self.last_player_hit_time
		if hit_time and core.get_gametime () - hit_time <= 5 then
			mob_class.item_drop (self, cooked, looting, reason)
		end
	end

	function phantom:motion_step (dtime, moveresult, pos)
		local desired = vector.zero ()
		local target = self._phantom_destination
		if target then
			local speed = self._phantom_diving and 18 or self._phantom_retreat and 10 or self.movement_speed
			local delta = vector.subtract (target, pos)
			local distance = vector.length (delta)
			if distance > 0.1 then desired = vector.multiply (delta, math.min (speed / distance, 2.8)) end
		end
		if moveresult.collides and self._phantom_diving then
			local target_pos = self._phantom_target and self._phantom_target:get_pos ()
			retreat (self, pos, target_pos or pos)
			desired = vector.new (0, 4, 0)
		end
		local velocity = self.object:get_velocity ()
		velocity = vector.add (velocity, vector.multiply (vector.subtract (desired, velocity), math.min (1, dtime * 4)))
		self.object:set_velocity (velocity)
		if math.abs (velocity.x) + math.abs (velocity.z) > 0.15 then
			self:set_yaw (math.atan2 (velocity.z, velocity.x) - math.pi / 2)
			self:set_pitch (-math.atan2 (velocity.y, math.sqrt (velocity.x * velocity.x + velocity.z * velocity.z)))
		end
	end

	function phantom:get_staticdata_table ()
		local data = mob_class.get_staticdata_table (self)
		if data then
			data._phantom_target = nil
			data._phantom_destination = nil
			data._phantom_retreat = nil
			data._phantom_diving = nil
			data._phantom_cat = nil
		end
		return data
	end

	phantom.ai_functions = {}
	mcl_mobs.register_mob (id, phantom)
	mcl_mobs.register_egg (id, S ("Phantom"), "#384c72", "#88ff87", 0)
	core.override_item (id, {inventory_image = "mcl_phantoms_spawn_egg.png"})
end
