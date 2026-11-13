return function (shared)
	local S = shared.translate
	local mob_class = mcl_mobs.mob_class
	local food = "mcl_mobitems:spider_eye"
	local mesh = "mcl_armadillos_armadillo"
	local baby_texture = {"mcl_armadillos_armadillo_baby.png"}
	local rolled_scale = 0.82

	local armadillo = {
		description = S ("Armadillo"),
		type = "animal",
		_spawn_category = "creature",
		hp_min = 12,
		hp_max = 12,
		xp_min = 1,
		xp_max = 3,
		drops = {},
		visual = "mesh",
		mesh = mesh .. ".obj",
		_child_mesh = mesh .. "_baby.obj",
		textures = {{"mcl_armadillos_armadillo.png"}},
		use_texture_alpha = true,
		backface_culling = false,
		rotate = 180,
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.35, 0, -0.35, 0.35, 0.65, 0.35},
		head_eye_height = 0.35,
		movement_speed = 2.8,
		follow = {food},
		follow_distance = 10,
		runaway = true,
		can_ride_boat = false,
		can_ride_cart = false,
	}

	local function update_appearance (self)
		local suffix = (self.child and "_baby" or "") .. (self._armadillo_rolled and "_rolled" or "")
		local size = self.child and 0.55 or 1
		local box = table.copy (self.base_colbox)
		for i = 1, 6 do box[i] = box[i] * size end
		if self._armadillo_rolled then box[5] = box[5] * rolled_scale end
		self.collisionbox = box
		self:set_properties ({mesh = mesh .. suffix .. ".obj", collisionbox = box, selectionbox = box})
		self:set_textures (self.child and baby_texture or self.base_texture)
	end

	function armadillo:after_activate ()
		update_appearance (self)
	end

	function armadillo:on_grown ()
		self._armadillo_shed_time = math.random (300, 599)
		update_appearance (self)
	end

	local function drop_scute (self)
		return core.add_item (vector.offset (self.object:get_pos (), 0, 0.3, 0), shared.scute)
	end

	function armadillo:do_custom (dtime)
		if self.child then return end
		self._armadillo_shed_time = (self._armadillo_shed_time or math.random (300, 599)) - dtime
		if self._armadillo_shed_time <= 0 then
			if drop_scute (self) then self._armadillo_shed_time = math.random (300, 599) end
		end
	end

	function armadillo:_on_brush (stack, player)
		if self.dead or self.removed or self.child then return stack end
		if not drop_scute (self) then return stack end
		if not core.is_creative_enabled (player:get_player_name ()) then
			stack:add_wear_by_uses (4)
		end
		return stack
	end

	function armadillo:actionable_on_rightclick (player)
		return core.get_item_group (player:get_wielded_item ():get_name (), "brush") > 0
			or (not self._armadillo_rolled and self:follow_holding (player))
			or mob_class.actionable_on_rightclick (self, player)
	end

	function armadillo:on_rightclick (player)
		if not player:is_player () or self.dead or self.removed then return end
		local stack = player:get_wielded_item ()
		if core.get_item_group (stack:get_name (), "brush") > 0 then
			player:set_wielded_item (self:_on_brush (stack, player))
		elseif not self._armadillo_rolled and self:follow_holding (player) then
			self:feed_tame (player, nil, true, false)
		end
	end

	function armadillo:breeding_possible ()
		return not self._armadillo_rolled and mob_class.breeding_possible (self)
	end

	function armadillo:can_mate_with (object)
		local other = object:get_luaentity ()
		return other and not other._armadillo_rolled and mob_class.can_mate_with (self, object)
	end

	function armadillo:on_breed ()
		mcl_mobs.spawn_child (self.object:get_pos (), self.name)
	end

	function armadillo:receive_damage (reason, damage)
		if self._armadillo_rolled and damage > 0 then
			damage = math.max (0, (damage - 1) / 2)
			if damage == 0 then return false end
		end
		return mob_class.receive_damage (self, reason, damage)
	end

	local function threat_nearby (self, pos)
		local minp = vector.offset (pos, -7, -2, -7)
		local maxp = vector.offset (pos, 7, 2, 7)
		for object in core.objects_in_area (minp, maxp) do
			if object ~= self.object and object:get_hp () > 0 then
				if object == self._recent_attacker then return true end
				if object:is_player () then
					if object:get_attach () or mcl_sprint.is_sprinting (object:get_player_name ()) then return true end
				elseif (object:get_armor_groups ().undead or 0) > 0 then
					local entity = object:get_luaentity ()
					if entity and not entity.dead and not entity.removed then return true end
				end
			end
		end
		return false
	end

	local function hide (self, pos, dtime, moveresult)
		local on_ground = moveresult and moveresult.touching_ground
		local can_roll = on_ground and not self._liquidtype and not self:is_frightened ()
			and not self.object:get_attach ()
		if not can_roll then
			self._armadillo_calm_time = 0
		elseif self:check_timer ("armadillo_threat", 0.25) and threat_nearby (self, pos) then
			self._armadillo_calm_time = 3
		end
		local time_left = math.max (0, (self._armadillo_calm_time or 0) - dtime)
		self._armadillo_calm_time = time_left
		local rolled = time_left > 0
		if rolled ~= (self._armadillo_rolled == true) then
			self._armadillo_rolled = rolled
			update_appearance (self)
		end
		if rolled then
			self:cancel_navigation ()
			self:halt_in_tracks (true)
			return "armadillo_hiding"
		end
		return false
	end

	armadillo.ai_functions = {hide, mob_class.check_frightened, mob_class.check_breeding,
		mob_class.check_following, mob_class.check_pace}
	mcl_mobs.register_mob (shared.mob, armadillo)
	mcl_mobs.register_egg (shared.mob, S ("Armadillo"), "#a77d70", "#73444a", 0)
	core.override_item (shared.mob, {inventory_image = "mcl_armadillos_armadillo_spawn_egg.png"})

	local savanna = table.merge (mobs_mc.animal_spawner, {
		name = shared.mob,
		weight = 10,
		pack_min = 2,
		pack_max = 3,
		biomes = {"#is_savannah"},
	})
	function savanna:test_supporting_node (node)
		local name = node.name
		return core.get_item_group (name, "grass_block") > 0 or core.get_item_group (name, "hardened_clay") > 0
			or name == "mcl_core:redsand" or name == "mcl_core:coarse_dirt"
	end
	function savanna:describe_supporting_nodes ()
		return S ("on grass blocks, terracotta, red sand or coarse dirt")
	end
	mcl_mobs.register_spawner (savanna)
	mcl_mobs.register_spawner (table.merge (savanna, {
		weight = 6,
		pack_min = 1,
		pack_max = 2,
		biomes = {"#is_badlands"},
	}))

	core.register_craftitem (shared.scute, {
		description = S ("Armadillo Scute"),
		_doc_items_longdesc = S ("Adult armadillos shed these scutes over time. You can also collect one with a brush."),
		inventory_image = "mcl_armadillos_armadillo_scute.png",
	})
end
