return function (shared)
	local S = shared.translate
	local mob_class = mcl_mobs.mob_class
	local mesh = "mcl_sniffers_sniffer"
	local baby_texture = {"mcl_sniffers_snifflet.png"}
	local diggable = {"group:dirt", "group:grass_block", "mcl_mud:mud", "mcl_mud:packed_mud",
		"mcl_lush_caves:moss", "mcl_pale_oak:pale_moss", "mcl_lush_caves:rooted_dirt"}
	local dig_blocks = {}
	for _, name in ipairs (diggable) do dig_blocks[name] = true end

	local sniffer = {
		description = S ("Sniffer"),
		type = "animal",
		_spawn_category = "creature",
		hp_min = 14,
		hp_max = 14,
		xp_min = 1,
		xp_max = 3,
		drops = {},
		visual = "mesh",
		mesh = mesh .. ".obj",
		_child_mesh = "mcl_sniffers_snifflet.obj",
		textures = {{"mcl_sniffers_sniffer.png"}},
		visual_size = {x = 1, y = 1},
		use_texture_alpha = true,
		backface_culling = false,
		rotate = 180,
		collisionbox = {-0.95, 0, -0.95, 0.95, 1.75, 0.95},
		head_eye_height = 1.12,
		movement_speed = 2.7,
		follow = {shared.seeds},
		follow_distance = 10,
		stop_distance = 2.5,
		runaway = true,
		can_ride_boat = false,
		can_ride_cart = false,
	}

	function sniffer:after_activate ()
		if self.child then
			self:set_textures (baby_texture)
		elseif self._sniffer_dig_time then
			self:set_properties ({mesh = mesh .. "_digging.obj"})
		end
	end

	function sniffer:actionable_on_rightclick (player)
		return self:follow_holding (player) or mob_class.actionable_on_rightclick (self, player)
	end

	function sniffer:on_rightclick (player)
		if player:is_player () and not self._sniffer_dig_time and self:follow_holding (player) then
			self:feed_tame (player, nil, true, false)
		end
	end

	function sniffer:on_breed ()
		core.add_item (vector.offset (self.object:get_pos (), 0, 0.3, 0), shared.egg)
	end

	local function can_dig (pos)
		local node = core.get_node (pos)
		return not core.is_protected (pos, "") and core.get_node (vector.offset (pos, 0, 1, 0)).name == "air"
			and (core.get_item_group (node.name, "dirt") > 0 or core.get_item_group (node.name, "grass_block") > 0
				or dig_blocks[node.name])
	end

	local function find_dig_site (self, pos)
		local minp = vector.offset (pos, -7, -2, -7)
		local maxp = vector.offset (pos, 7, 1, 7)
		local candidates = core.find_nodes_in_area_under_air (minp, maxp, diggable)
		table.shuffle (candidates)
		local explored = self._sniffer_explored or {}
		for _, site in ipairs (candidates) do
			local distance = vector.distance (site, pos)
			if distance > 2.2 and distance <= 8 and can_dig (site)
				and table.indexof (explored, core.hash_node_position (site)) == -1
				and self:gopath (vector.offset (site, 0, 1, 0), 1, "walk") then
				return site
			end
		end
	end

	local function reset_search (self, delay)
		if self._sniffer_dig_time then self:set_properties ({mesh = mesh .. ".obj"}) end
		self:cancel_navigation ()
		self:halt_in_tracks ()
		self._sniffer_site, self._sniffer_dig_time = nil, nil
		self._sniffer_scan = delay
	end

	local function search (self, pos, dtime, moveresult)
		if self.child then return false end
		if self._liquidtype or self:is_frightened () or self:is_breeding () or self.following then
			if self._sniffer_site then reset_search (self, 6) end
			return false
		end
		local site = self._sniffer_site
		if not site then
			self._sniffer_scan = (self._sniffer_scan or math.random (12, 30)) - dtime
			if self._sniffer_scan > 0 or not moveresult or not moveresult.touching_ground then return false end
			site = find_dig_site (self, pos)
			self._sniffer_site = site
			if not site then reset_search (self, 8); return false end
			return "sniffer_search"
		end
		if not can_dig (site) then reset_search (self, 8); return false end
		local surface = vector.offset (site, 0, 0.5, 0)
		if vector.distance (surface, pos) > 1.85 then
			if self:check_timer ("sniffer_search_path", 2) and self:navigation_finished ()
				and not self:gopath (vector.offset (site, 0, 1, 0), 1, "walk") then
				reset_search (self, 8)
				return false
			end
			return "sniffer_search"
		end
		if not self._sniffer_dig_time then
			self:cancel_navigation ()
			self:halt_in_tracks (true)
			self:look_at (site)
			self._sniffer_dig_time = 0
			self:set_properties ({mesh = mesh .. "_digging.obj"})
		end
		self._sniffer_dig_time = self._sniffer_dig_time + dtime
		if self:check_timer ("sniffer_dig_particles", 0.3) then
			local node = core.get_node (site)
			core.add_particlespawner ({
				amount = 9, time = 0.25,
				minpos = vector.offset (surface, -0.2, 0.03, -0.2), maxpos = vector.offset (surface, 0.2, 0.10, 0.2),
				minvel = vector.new (-0.8, 1.4, -0.8), maxvel = vector.new (0.8, 2.4, 0.8),
				minacc = vector.new (0, -9, 0), maxacc = vector.new (0, -7, 0),
				minexptime = 0.2, maxexptime = 0.6, minsize = 0.5, maxsize = 1.4, node = node,
			})
			local sounds = core.registered_nodes[node.name].sounds
			if sounds and sounds.dig then core.sound_play (sounds.dig, {pos = site, gain = 0.35}, true) end
		end
		if self._sniffer_dig_time >= 6 then
			local reward = math.random (2) == 1 and shared.seeds or shared.pod
			if core.add_item (vector.offset (surface, 0, 0.24, 0), reward) then
				local explored = self._sniffer_explored or {}
				table.insert (explored, 1, core.hash_node_position (site))
				explored[21] = nil
				self._sniffer_explored = explored
				reset_search (self, 480)
			end
		end
		return "sniffer_search"
	end

	local function follow (self, pos, dtime)
		if self._sniffer_dig_time then return false end
		return mob_class.check_following (self, pos, dtime)
	end

	sniffer.ai_functions = {mob_class.check_frightened, mob_class.check_breeding, follow, search, mob_class.check_pace}
	mcl_mobs.register_mob (shared.sniffer, sniffer)
	mcl_mobs.register_egg (shared.sniffer, S ("Sniffer"), "#89712d", "#942c19", 0)
	core.override_item (shared.sniffer, {inventory_image = "mcl_sniffers_sniffer_spawn_egg.png"})
end
