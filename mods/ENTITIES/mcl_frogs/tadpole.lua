return function (shared)
	local S = shared.translate
	local mob_class = mcl_mobs.mob_class
	local AGE = 1200
	local BUCKET = "mcl_buckets:bucket_tadpole"
	local EMPTY_BUCKET = "mcl_buckets:bucket_empty"
	local tadpole = {
		description = S ("Tadpole"),
		type = "animal",
		_spawn_category = "water_ambient",
		hp_min = 6,
		hp_max = 6,
		xp_min = 0,
		xp_max = 0,
		drops = {},
		visual = "mesh",
		mesh = "mcl_frogs_tadpole.obj",
		rotate = 180,
		textures = {{"mcl_frogs_tadpole.png"}},
		use_texture_alpha = true,
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.20, 0, -0.20, 0.20, 0.30, 0.20},
		head_eye_height = 0.12,
		breathes_in_water = true,
		swims = true,
		flops = true,
		_max_air_supply = 5.0,
		do_go_pos = mob_class.fish_do_go_pos,
		movement_speed = 6,
		pace_height = 1.0,
		pace_chance = 40,
		makes_footstep_sound = false,
		can_ride_boat = false,
		can_ride_cart = false,
		can_despawn = false,
		follow = {shared.slimeball},
		_tadpole_age = 0,
	}

	local function is_capture_bucket (stack)
		return core.get_item_group (stack:get_name (), "water_bucket") > 0
	end

	function tadpole:actionable_on_rightclick (player)
		local stack = player:get_wielded_item ()
		return is_capture_bucket (stack) or stack:get_name () == shared.slimeball
			or mob_class.actionable_on_rightclick (self, player)
	end

	function tadpole:on_rightclick (player)
		if self.removed or self.dead or not player:is_player () then return end
		local stack = player:get_wielded_item ()
		local name = player:get_player_name ()
		if is_capture_bucket (stack) then
			local pos = vector.round (self.object:get_pos ())
			if core.is_protected (pos, name) then
				core.record_protection_violation (pos, name)
				return
			end
			local bucket = ItemStack (BUCKET)
			local meta = bucket:get_meta ()
			meta:set_string ("properties", core.serialize ({
				_tadpole_age = self._tadpole_age,
				nametag = self:get_nametag (),
				health = self.health,
			}))
			if player:set_wielded_item (bucket) then self:safe_remove () end
		elseif stack:get_name () == shared.slimeball then
			local remaining = AGE - self._tadpole_age
			if remaining <= 0 then return end
			self._tadpole_age = self._tadpole_age + remaining * 0.1
			if not core.is_creative_enabled (name) then
				stack:take_item ()
				player:set_wielded_item (stack)
			end
			mcl_mobs.effect (self.object:get_pos (), 5, "mcl_particles_smoke.png", 1, 2, 2, 2, 2)
		end
	end

	function tadpole:ai_step (dtime)
		mob_class.ai_step (self, dtime)
		self._tadpole_age = math.min (AGE, self._tadpole_age + dtime)
		if self._tadpole_age >= AGE then
			self:replace_with (shared.frog, false)
		end
	end

	tadpole.ai_functions = {mob_class.check_following, mob_class.check_pace}
	mcl_mobs.register_mob (shared.tadpole, tadpole)
	shared.register_egg (shared.tadpole, S ("Tadpole"), "mcl_frogs_tadpole_spawn_egg.png")

	local function release (stack, pos, player)
		local node = core.get_node (pos)
		local def = core.registered_nodes[node.name]
		local water = shared.is_source_water (node)
		if node.name == "ignore" or not def or (not water and not def.buildable_to)
			or (def.liquidtype ~= "none" and core.get_item_group (node.name, "water") == 0) then
			return stack
		end
		local name = player and player:get_player_name () or ""
		if core.is_protected (pos, name) then
			if player then core.record_protection_violation (pos, name) end
			return stack
		end
		local meta = stack:get_meta ()
		local data = meta:get_string ("properties")
		local props = data ~= "" and core.deserialize (data, true)
		if type (props) ~= "table" then props = {} end
		local renamed = meta:get_string ("name")
		local state = {
			persistent = true,
			_tadpole_age = math.max (0, math.min (AGE, tonumber (props._tadpole_age) or 0)),
			nametag = renamed ~= "" and renamed or (type (props.nametag) == "string" and props.nametag or nil),
			health = tonumber (props.health),
		}
		-- Activate the tadpole before mutating the node or the item.
		local object = core.add_entity (pos, shared.tadpole, core.serialize (state))
		if not object or not object:is_valid () then return stack end
		if mcl_worlds.pos_to_dimension (pos) == "nether" then
			core.sound_play ("fire_extinguish_flame", {pos = pos, gain = 0.25, max_hear_distance = 16}, true)
		elseif not water then
			core.set_node (pos, {name = "mcl_core:water_source"})
		end
		return player and core.is_creative_enabled (name) and stack or ItemStack (EMPTY_BUCKET)
	end

	local function on_place (stack, player, pointed)
		local result = mcl_util.call_on_rightclick (stack, player, pointed)
		if result then return result end
		if pointed.type ~= "node" then return stack end
		local under = core.get_node (pointed.under)
		local pos = shared.is_source_water (under) and pointed.under or pointed.above
		return release (stack, pos, player)
	end

	core.register_craftitem (":" .. BUCKET, {
		description = S ("Bucket of Tadpole"),
		inventory_image = "mcl_frogs_tadpole_bucket.png",
		stack_max = 1,
		groups = {bucket = 1, fish_bucket = 1},
		pointabilities = {nodes = {["group:water"] = true}},
		on_place = on_place,
		on_secondary_use = on_place,
		_on_dispense = function (stack, _, pos) return release (stack, pos, nil) end,
	})
end
