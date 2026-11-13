return function (camel)
	local mob_class = mcl_mobs.mob_class
	local front = vector.new (0, 18.1, 5)
	local rear = vector.new (0, 17.9, -7)
	local rotation = vector.zero ()
	local mounted = {}

	local function valid_rider (self, player)
		return player and player:is_valid () and player:get_attach () == self.object
	end

	local function seat_offset (self, is_front)
		local seat = is_front and front or rear
		return vector.offset (seat, 0, self._camel_sitting and -9.7 or 0, 0)
	end

	local function update_seats (self)
		self.driver_attach_at = seat_offset (self, true)
		if valid_rider (self, self.driver) then
			self.driver:set_attach (self.object, "", self.driver_attach_at, rotation)
		end
		if valid_rider (self, self._camel_passenger) then
			self._camel_passenger:set_attach (self.object, "", seat_offset (self, false), rotation)
		end
	end

	local function restore_player (player)
		mcl_attachments.remove_attachment_entity (player)
		if not player:is_valid () or player:get_attach () then return end
		local state = mcl_player.players[player]
		if state then state.attached = false end
		player:set_eye_offset (rotation, rotation)
		player:set_properties ({visual_size = {x = 1, y = 1}})
		mcl_player.player_set_animation (player, "stand", 30)
	end

	function camel:driver_detached (player, deactivation)
		mounted[player] = nil
		self._camel_charge = nil
		mob_class.driver_detached (self, player, deactivation)
		restore_player (player)
	end

	function camel:on_detach_child (child)
		if child == self._camel_passenger then
			self._camel_passenger = nil
			mounted[child] = nil
			restore_player (child)
		else
			mob_class.on_detach_child (self, child)
		end
	end

	local function reset_seat (self, player)
		if not player then return end
		if valid_rider (self, player) then player:set_detach () end
		if self.driver == player then
			self.driver = nil
			self:driver_detached (player, false)
		elseif self._camel_passenger == player then
			self._camel_passenger = nil
			mounted[player] = nil
			restore_player (player)
		end
	end

	local function dismount (self, player)
		local pos = self.object:get_pos ()
		local attached = valid_rider (self, player)
		reset_seat (self, player)
		if not attached or not pos then return end
		local side = core.yaw_to_dir (self:get_yaw () + math.pi / 2)
		for _, sign in ipairs ({1, -1}) do
			local destination = vector.add (pos, vector.multiply (side, 1.35 * sign))
			local feet = vector.round (vector.offset (destination, 0, 0.1, 0))
			local ground = core.registered_nodes[core.get_node (vector.offset (feet, 0, -1, 0)).name]
			if ground and ground.walkable and core.get_node (feet).name == "air"
				and core.get_node (vector.offset (feet, 0, 1, 0)).name == "air" then
				player:set_pos (destination)
				return
			end
		end
		-- Keep the attachment's height if there is no free landing spot beside the camel.
		player:set_pos (vector.offset (pos, 0, self.collisionbox[5] + 0.15, 0))
	end

	local function clear_players (self)
		if self.driver then dismount (self, self.driver) end
		if self._camel_passenger then dismount (self, self._camel_passenger) end
	end

	function camel:mount_player (player)
		if not mcl_player.players[player] or player:get_attach () then return false end
		if not self.driver then
			self.driver_attach_at = seat_offset (self, true)
			if not mob_class.attach (self, player, true) then return false end
			self:cancel_navigation ()
		elseif not self._camel_passenger then
			self._camel_passenger = player
			player:set_attach (self.object, "", seat_offset (self, false), rotation)
			mcl_attachments.spawn_attachment_entity (player)
			mcl_player.players[player].attached = true
			player:set_look_horizontal (self:get_yaw ())
			mcl_player.player_set_animation (player, "sit_mount", 30)
		else
			return false
		end
		mounted[player] = self
		return true
	end

	function camel:check_passenger ()
		if self.driver and valid_rider (self, self.driver) and self.driver:get_player_control ().sneak then
			dismount (self, self.driver)
		end
		local passenger = self._camel_passenger
		if not passenger then return end
		if not valid_rider (self, passenger) then
			reset_seat (self, passenger)
		elseif passenger:get_player_control ().sneak then
			dismount (self, passenger)
		elseif not self.driver then
			reset_seat (self, passenger)
			self:mount_player (passenger)
		end
	end

	local function unmount (player)
		local self = mounted[player]
		if self then reset_seat (self, player) end
	end
	core.register_on_dieplayer (unmount)
	core.register_on_leaveplayer (unmount)
	core.register_on_shutdown (function ()
		for player in pairs (mounted) do unmount (player) end
	end)

	return valid_rider, update_seats, clear_players
end
