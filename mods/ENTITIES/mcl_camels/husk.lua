return function (camel)
	local mob_class = mcl_mobs.mob_class
	local S = core.get_translator (core.get_current_modname ())
	local FRONT = "mobs_mc:husk"
	local REAR = "mobs_mc:parched"
	local ROTATION = vector.zero ()
	local FRONT_OFFSET = vector.new (0, 17.6, 5)
	local REAR_OFFSET = vector.new (0, 17.2, -7)
	local rear_owners = setmetatable ({}, {__mode = "k"})

	local husk = table.merge (camel, {
		description = S ("Camel Husk"),
		type = "monster",
		_spawn_category = "monster",
		can_despawn = true,
		persist_in_peaceful = true,
		ignited_by_sunlight = false,
		harmed_by_heal = true,
		armor = {undead = 100, fleshy = 100},
		drops = {{name = "mcl_mobitems:rotten_flesh", chance = 1, min = 2, max = 3, looting = "common"}},
		textures = {{"mcl_camels_camel_husk.png", "blank.png"}},
		follow = {"mcl_mobitems:rabbit_foot"},
	})

	local function rider_data (object)
		local rider = object and object:is_valid () and object:get_luaentity ()
		if rider and not rider.dead and not rider.removed then
			local data = rider:get_staticdata_table ()
			return data
		end
	end

	local function attach_back (self, object)
		local rider = object:get_luaentity ()
		if not rider then return end
		self._camel_back_rider = object
		rear_owners[object] = self
		rider._original_visual_size = object:get_properties ().visual_size
		-- Use Parched targeting and bow AI, but keep pathing local to the rear rider.
		-- Only the forward Husk can drive the mount.
		rider.mob_controlling_movement = function (entity) return entity end
		rider.select_arm_pose = function (entity)
			return entity.attack and "jockey_shoot" or "jockey_default"
		end
		local shoot_arrow = rider.shoot_arrow
		rider.shoot_arrow = function (entity, pos, dir)
			local arrow = shoot_arrow (entity, pos, dir)
			local projectile = arrow and arrow:get_luaentity ()
			if projectile then
				projectile._ignored = {self.object, self._jockey_rider}
			end
		end
		object:set_properties ({static_save = false})
		object:set_attach (self.object, "", REAR_OFFSET, ROTATION)
		mcl_attachments.spawn_attachment_entity (object)
	end

	local function detach_back (self, remove)
		local object = self._camel_back_rider or self._camel_detached_back
		self._camel_back_rider = nil
		self._camel_detached_back = nil
		if not object or not object:is_valid () then return end
		local rider = object:get_luaentity ()
		if not rider then return end
		rear_owners[object] = nil
		rider.mob_controlling_movement = nil
		rider.select_arm_pose = nil
		rider.shoot_arrow = nil
		if remove then
			object:remove ()
		else
			local pos = mcl_attachments.get_attachment_pos (object)
			rider:unjock ()
			if pos then object:set_pos (pos) end
		end
	end

	local function add_back (self, data)
		local object = core.add_entity (self.object:get_pos (), REAR, data and core.serialize (data))
		if object and object:is_valid () then attach_back (self, object) end
	end

	local function add_riders (self)
		local pos = self.object:get_pos ()
		local object = core.add_entity (pos, FRONT)
		local rider = object and object:is_valid () and object:get_luaentity ()
		if rider then
			local spear = "mcl_spears:spear_iron"
			local weapon = core.registered_items[spear] and spear or "mcl_tools:sword_iron"
			rider:set_wielditem (ItemStack (weapon))
			rider.reach = 3.4
			rider:jock_to_existing (self.object, "", FRONT_OFFSET, ROTATION)
		end
		add_back (self)
	end

	function husk:mob_activate (staticdata, dtime)
		if not camel.mob_activate (self, staticdata, dtime) then return false end
		local back = self._camel_back_data
		self._camel_back_data = nil
		if self._camel_generate_riders then
			self._camel_generate_riders = nil
			if mcl_vars.difficulty > 0 and not mcl_vars.only_peaceful_mobs then add_riders (self) end
		elseif back then
			add_back (self, back)
		end
		return true
	end

	function husk:breeding_possible ()
		return false
	end

	function husk:is_frightened ()
		return not self._jockey_rider and not self._camel_back_rider and mob_class.is_frightened (self)
	end

	function husk:do_custom ()
		local rear = self._camel_back_rider
		if rear and (not rear:is_valid () or rear:get_attach () ~= self.object) then
			self._camel_back_rider = nil
		elseif rear and not self._jockey_rider then
			local rider = rear:get_luaentity ()
			local target = rider and rider.attack
			if target and target:is_valid () and self:check_timer ("camel_husk_rear_target", 0.75) then
				self:gopath (target:get_pos (), 1.15)
			end
		end
		camel.do_custom (self)
	end

	local function follow_rear_target (self)
		local object = self._camel_back_rider
		local rider = object and object:is_valid () and object:get_luaentity ()
		return rider and rider.attack and rider.attack:is_valid () and not self._jockey_rider
	end
	husk.ai_functions = {follow_rear_target, mob_class.check_frightened, mob_class.check_pace}

	function husk:on_detach_child (child)
		if child == self._camel_back_rider then
			-- Luanti also detaches children when saving or deactivating a parent.
			-- The seat's owner decides whether it is a permanent release.
			self._camel_back_rider = nil
			self._camel_detached_back = child
			self._camel_back_data = rider_data (child)
			core.after (0, function ()
				if not self.object:is_valid () or self.removed or self.dead or rear_owners[child] ~= self then return end
				self._camel_back_data = nil
				self._camel_detached_back = nil
				rear_owners[child] = nil
				local rider = child:is_valid () and child:get_luaentity ()
				if not rider then return end
				rider.mob_controlling_movement = nil
				rider.select_arm_pose = nil
				rider.shoot_arrow = nil
				child:set_properties ({static_save = true})
			end)
		else
			camel.on_detach_child (self, child)
		end
	end

	function husk:get_staticdata_table ()
		local data = camel.get_staticdata_table (self)
		if data then data._camel_back_data = rider_data (self._camel_back_rider) or self._camel_back_data end
		return data
	end

	function husk:on_die (pos)
		detach_back (self, false)
		camel.on_die (self, pos)
	end

	function husk:on_deactivate (removal)
		detach_back (self, true)
		camel.on_deactivate (self, removal)
	end

	return husk
end
