return function (shared)
	local S = shared.translate
	local mob_class = mcl_mobs.mob_class
	local warm_biome, cold_biome
	core.register_on_mods_loaded (function ()
		warm_biome = mcl_biome_dispatch.make_biome_test ({
			"Desert", "WarmOcean", "#is_jungle", "#is_savannah", "#is_badlands", "MangroveSwamp",
		})
		cold_biome = mcl_biome_dispatch.make_biome_test ({
			"SnowyPlains", "IceSpikes", "FrozenPeaks", "JaggedPeaks", "SnowySlopes", "FrozenOcean",
			"DeepFrozenOcean", "Grove", "DeepDark", "FrozenRiver", "SnowyTaiga", "SnowyBeach",
		})
	end)

	local frog = {
		description = S ("Frog"),
		type = "animal",
		_spawn_category = "creature",
		hp_min = 10,
		hp_max = 10,
		xp_min = 1,
		xp_max = 3,
		drops = {},
		visual = "mesh",
		mesh = "mcl_frogs_frog.obj",
		rotate = 180,
		textures = {{"mcl_frogs_frog_temperate.png"}},
		use_texture_alpha = true,
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.25, 0, -0.25, 0.25, 0.50, 0.25},
		head_eye_height = 0.36,
		amphibious = true,
		do_go_pos = mob_class.pitchswim_do_go_pos,
		movement_speed = 4,
		fixed_grounded_speed = 4.0,
		grounded_speed_factor = 0.8,
		swim_speed_factor = 0.8,
		_airborne_agile = true,
		jump_height = 6,
		follow = {shared.slimeball},
		view_range = 10,
		makes_footstep_sound = false,
	}

	local function variant_at (pos)
		local dimension = mcl_worlds.pos_to_dimension (pos)
		if dimension == "nether" then return "warm" end
		if dimension == "end" then return "cold" end
		local name = mcl_biome_dispatch.get_biome_name (pos)
		if warm_biome (name) then return "warm" end
		if cold_biome (name) then return "cold" end
		return "temperate"
	end

	function frog:on_spawn ()
		if not shared.lights[self._frog_variant] then
			self._frog_variant = variant_at (self.object:get_pos ())
		end
		self.base_texture = {"mcl_frogs_frog_" .. self._frog_variant .. ".png"}
		self:set_textures (self.base_texture)
		return true
	end

	function frog:step_drowning (dtime, in_water)
		-- Frogs breathe in water and on land.
	end

	function frog:actionable_on_rightclick (player)
		return player:get_wielded_item ():get_name () == shared.slimeball
			or mob_class.actionable_on_rightclick (self, player)
	end

	function frog:breeding_possible ()
		return not self._frog_gravid and mob_class.breeding_possible (self)
	end

	function frog:on_rightclick (player)
		if player:is_player () and player:get_wielded_item ():get_name () == shared.slimeball
			and self:feed_tame (player, nil, true, false) then
			self._frog_breeder = player:get_player_name ()
		end
	end

	function frog:on_breed (mate)
		self._frog_gravid = true
		mate._frog_breeder = nil
	end

	local function can_lay (self, water)
		local spawn = vector.offset (water, 0, 1, 0)
		local name = self._frog_breeder or ""
		return shared.is_source_water (core.get_node (water))
			and core.get_node (spawn).name == "air"
			and not core.is_protected (water, name) and not core.is_protected (spawn, name)
	end

	local function seek_water (self, pos)
		local minp = vector.offset (pos, -12, -3, -12)
		local maxp = vector.offset (pos, 12, 3, 12)
		local nearest, distance
		for _, water in ipairs (core.find_nodes_in_area (minp, maxp, {"group:water"})) do
			local d = vector.distance (pos, water)
			if (not distance or d < distance) and can_lay (self, water) then
				nearest, distance = water, d
			end
		end
		return nearest
	end

	local function lay_eggs (self, pos)
		if not self._frog_gravid then return false end
		local water = self._frog_water
		if not water or not can_lay (self, water) then
			if not self:check_timer ("frog_find_water", 1) then return false end
			water = seek_water (self, pos)
			self._frog_water = water
			if not water then return false end
		end
		if vector.distance (pos, water) <= 1.3 then
			core.set_node (vector.offset (water, 0, 1, 0), {name = shared.spawn})
			self._frog_gravid, self._frog_water, self._frog_breeder = nil, nil, nil
			self:cancel_navigation ()
			self:halt_in_tracks ()
			return true
		end
		if self:check_timer ("frog_water_path", 1) and not self:gopath (water, 1.0) then
			self._frog_water = nil
			return false
		end
		return "_frog_laying"
	end

	local tiny_slime, tiny_cube = "mobs_mc:slime_tiny", "mobs_mc:magma_cube_tiny"
	local function is_prey (self, pos, object, entity)
		return entity and not entity.dead and not entity.removed and (entity.name == tiny_slime or entity.name == tiny_cube)
	end

	local function hunt (self, pos, dtime)
		local target = self:get_active_target (pos)
		local prey = target and target:is_valid () and target:get_luaentity ()
		if not is_prey (self, pos, target, prey) then
			self._frog_tongue_target, self._frog_tongue_time = nil, nil
			return false
		end
		local where = target:get_pos ()
		if self._frog_tongue_target ~= target then
			self._frog_tongue_target, self._frog_tongue_time = nil, nil
		end
		if vector.distance (pos, where) > 1.75 or not self:target_visible (pos, target) then
			self._frog_tongue_target, self._frog_tongue_time = nil, nil
			if self:check_timer ("frog_hunt_path", 0.45) then self:gopath (where, 1.2) end
			return "_frog_hunting"
		end
		if not self._frog_tongue_target then
			self:cancel_navigation ()
			self:halt_in_tracks ()
			self:look_at (where)
			self._frog_tongue_target, self._frog_tongue_time = target, 0.3
			local pull = vector.multiply (vector.subtract (pos, where), 5)
			target:set_velocity (pull)
		else
			self._frog_tongue_time = self._frog_tongue_time - dtime
			if self._frog_tongue_time <= 0 then
				self._frog_tongue_target, self._frog_tongue_time = nil, nil
				local drop = prey.name == tiny_cube and shared.lights[self._frog_variant] or shared.slimeball
				local reward = core.add_item (where, drop)
				if reward and reward:is_valid () then prey:safe_remove () end
			end
		end
		return "_frog_hunting"
	end

	function frog:do_go_pos (dtime, moveresult)
		mob_class.pitchswim_do_go_pos (self, dtime, moveresult)
		if self._liquidtype == nil and moveresult.touching_ground and self:check_timer ("frog_hop", 0.5) then
			self._jump = true
		end
	end

	frog.ai_functions = {mob_class.check_frightened, lay_eggs, mob_class.check_breeding, hunt,
		mob_class.check_following, mob_class.check_pace}
	frog._targeting_rules = {mcl_mobs.build_nearest_target_rule (tiny_slime, is_prey, nil, nil, false)}
	mcl_mobs.register_mob (shared.frog, frog)
	shared.register_egg (shared.frog, S ("Frog"), "mcl_frogs_frog_spawn_egg.png")

	local spawner = table.merge (mobs_mc.animal_spawner, {
		name = shared.frog,
		weight = 10,
		pack_min = 2,
		pack_max = 5,
		biomes = {"Swamp", "MangroveSwamp"},
	})

	function spawner:test_supporting_node (node)
		local name = node.name
		return core.get_item_group (name, "grass_block") > 0 or name == "mcl_mud:mud"
			or name == "mcl_mangrove:mangrove_roots" or name == "mcl_mangrove:mangrove_mud_roots"
	end

	function spawner:describe_supporting_nodes ()
		return S ("on grass blocks, mud, mangrove roots, or muddy mangrove roots")
	end

	function spawner:test_spawn_position (spawn_pos, node_pos, data, cache, flag)
		if flag == "spawner" then
			return mcl_mobs.default_spawner.test_spawn_position (self, spawn_pos, node_pos, data, cache, flag)
		end
		-- Mud has a lowered collision surface and mangrove roots are transparent.
		-- The ordinary animal spawner requires a full opaque cube underneath.
		return (core.get_node_light (node_pos) or 0) > 8
			and self:test_supporting_node (self:get_node (cache, -1, node_pos))
			and self:is_valid_spawn_ceiling (self:get_node (cache, 0, node_pos).name)
			and self:is_valid_spawn_ceiling (self:get_node (cache, 1, node_pos).name)
	end

	mcl_mobs.register_spawner (spawner)
end
