return function (shared)
	local S = shared.translate
	local mob_class = mcl_mobs.mob_class
	local seagrass = "mcl_ocean:seagrass"
	local baby_texture = {"mcl_turtles_turtle_baby.png"}
	local turtle = {
		description = S ("Turtle"),
		type = "animal",
		_spawn_category = "creature",
		hp_min = 30,
		hp_max = 30,
		xp_min = 1,
		xp_max = 3,
		drops = {{name = seagrass, chance = 1, min = 0, max = 2, looting = "common"}},
		visual = "mesh",
		mesh = "mcl_turtles_turtle.obj",
		_child_mesh = "mcl_turtles_turtle_baby.obj",
		textures = {{"mcl_turtles_turtle.png"}},
		use_texture_alpha = true,
		backface_culling = false,
		rotate = 180,
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.56, 0, -0.56, 0.56, 0.42, 0.56},
		head_eye_height = 0.30,
		amphibious = true,
		do_go_pos = mob_class.pitchswim_do_go_pos,
		breathes_in_water = true,
		can_ride_boat = false,
		can_ride_cart = false,
		movement_speed = 5,
		fixed_grounded_speed = 1.8,
		grounded_speed_factor = 0.7,
		swim_speed_factor = 1.1,
		pace_chance = 10,
		pace_interval = 1.5,
		runaway = true,
		follow = {seagrass},
		follow_distance = 10,
		stop_distance = 1.8,
		makes_footstep_sound = false,
	}

	function turtle:on_spawn ()
		self._turtle_home = self._turtle_home or vector.round (self.object:get_pos ())
		return true
	end

	function turtle:after_activate ()
		if self.child then self:set_textures (baby_texture) end
	end

	function turtle:scale_size_of_child ()
		mob_class.scale_size_of_child (self, 0.19)
	end

	function turtle:step_drowning ()
		-- Sea turtles breathe on land and underwater.
	end

	function turtle:actionable_on_rightclick (player)
		return self:follow_holding (player) or mob_class.actionable_on_rightclick (self, player)
	end

	function turtle:breeding_possible ()
		return not self._turtle_clutch and mob_class.breeding_possible (self)
	end

	function turtle:on_rightclick (player)
		if player:is_player () and self:follow_holding (player)
			and self:feed_tame (player, nil, true, false) and not self.child then
			self._turtle_breeder = player:get_player_name ()
		end
	end

	function turtle:on_breed (mate)
		self._turtle_clutch = math.random (1, 4)
		mate._turtle_breeder = nil
	end

	function turtle:on_grown ()
		core.add_item (vector.offset (self.object:get_pos (), 0, 0.25, 0), shared.scute)
	end

	function turtle:on_die (pos, reason)
		if reason and reason.type == "lightning_bolt" then core.add_item (pos, "mcl_core:bowl") end
	end

	local function can_lay (pos, breeder)
		local sand = vector.offset (pos, 0, -1, 0)
		return shared.is_sand (core.get_node (sand)) and core.get_node (pos).name == "air"
			and not core.is_protected (sand, breeder) and not core.is_protected (pos, breeder)
	end

	local function find_nest (home, pos, breeder)
		local minp = vector.offset (home, -8, -4, -8)
		local maxp = vector.offset (home, 8, 4, 8)
		local nearest, distance
		for _, sand in ipairs (core.find_nodes_in_area_under_air (minp, maxp, {"group:sand"})) do
			local site = vector.offset (sand, 0, 1, 0)
			local d = vector.distance (site, pos)
			if (not distance or d < distance) and vector.distance (home, site) <= 9 and can_lay (site, breeder) then
				nearest, distance = site, d
			end
		end
		return nearest
	end

	local function lay_eggs (self, pos, dtime)
		if not self._turtle_clutch then return false end
		local home = self._turtle_home
		local breeder = self._turtle_breeder or ""
		local nest = self._turtle_nest
		if nest and not can_lay (nest, breeder) then
			self._turtle_nest = nil
			self._turtle_dig_time = nil
			nest = nil
		end
		local distance_home = vector.distance (home, pos)
		if not nest and distance_home <= 16 and self:check_timer ("turtle_find_nest", 2) then
			nest = find_nest (home, pos, breeder)
			self._turtle_nest = nest
		end
		if nest and vector.distance (nest, pos) <= 1.35 then
			self:cancel_navigation ()
			self:halt_in_tracks ()
			self._turtle_dig_time = (self._turtle_dig_time or 0) + dtime
			if self._turtle_dig_time >= 3 then
				shared.lay_clutch (nest, self._turtle_clutch)
				self._turtle_clutch, self._turtle_nest, self._turtle_dig_time, self._turtle_breeder = nil, nil, nil, nil
			end
			return "turtle_laying"
		end
		self._turtle_dig_time = nil
		if (nest or distance_home > 3) and self:check_timer ("turtle_home_path", 1.5) then
			self:gopath (nest or home, 1, "walk", nest and 0 or 2)
		end
		return "turtle_laying"
	end

	local function seek_water (self, pos)
		if self._turtle_swimming then
			if not self:navigation_finished () then return true end
			return false
		end
		local in_water = core.get_item_group (self.standing_in, "water") > 0
		if self:check_timer ("turtle_find_water", self.child and 2 or 8) and not in_water then
			local water = core.find_node_near (pos, 8, {"group:water"})
			if water and self:gopath (water, 1) then
				self._turtle_swimming = true
				return "_turtle_swimming"
			end
		end
		return false
	end

	function turtle:pacing_target (pos, width, height, groups)
		if core.get_item_group (self.standing_in, "water") > 0 then
			return mob_class.aquatic_pacing_target (self, pos, width, height, {"group:water"})
		end
		return mob_class.pacing_target (self, pos, width, height, groups)
	end

	turtle.ai_functions = {mob_class.check_frightened, lay_eggs, mob_class.check_breeding,
		mob_class.check_following, seek_water, mob_class.check_pace}
	mcl_mobs.register_mob (shared.turtle, turtle)
	mcl_mobs.register_egg (shared.turtle, S ("Turtle"), "#e7e7e1", "#00a000", 0)
	core.override_item (shared.turtle, {inventory_image = "mcl_turtles_turtle_spawn_egg.png"})

	local beaches = {"Beach"}
	if not mcl_biome_dispatch.use_detailed_spawning_mechanics () and not mcl_vars.superflat then
		-- Legacy mapgens represent warm beaches as separate biome variants.
		for name, biome in pairs (core.registered_biomes) do
			if name:match ("_beach$") and biome.node_top == "mcl_core:sand"
				and biome._mcl_biome_type ~= "snowy" and biome._mcl_biome_type ~= "cold" then
				beaches[#beaches + 1] = name
			end
		end
		table.sort (beaches)
	end

	local spawner = table.merge (mobs_mc.animal_spawner, {
		name = shared.turtle,
		weight = 5,
		pack_min = 2,
		pack_max = 5,
		biomes = beaches,
	})
	spawner.test_supporting_node = function (_, node) return shared.is_sand (node) end
	spawner.describe_supporting_nodes = function () return S ("on sand") end
	mcl_mobs.register_spawner (spawner)
end
