if not core.settings:get_bool("enable_damage", true) then return end

local fall = {}

local function landing_surface(pos, box)
	local feet = pos.y + box[2]
	local min_x, max_x = pos.x + box[1], pos.x + box[4]
	local min_z, max_z = pos.z + box[3], pos.z + box[6]
	local top, landed
	-- Check the collision boxes under the whole footprint, including slabs
	-- and the neighbouring block a player may land on with only one edge.
	for x = math.floor(min_x + 0.5), math.floor(max_x + 0.5) do
		for z = math.floor(min_z + 0.5), math.floor(max_z + 0.5) do
			for y = math.floor(feet - 1.5), math.floor(feet + 0.5) do
				local point = vector.new(x, y, z)
				local node = core.get_node_or_nil(point)
				local def = node and core.registered_nodes[node.name]
				if def and def.walkable then
					for _, shape in ipairs(core.get_node_boxes("collision_box", point, node)) do
						local surface = y + shape[5]
						if (not top or surface > top) and math.abs(feet - surface) <= 0.09
							and x + shape[1] < max_x and x + shape[4] > min_x
							and z + shape[3] < max_z and z + shape[6] > min_z then
							top, landed = surface, node.name
						end
					end
				end
			end
		end
	end
	return top, landed
end

local function update(player)
	if mcl_serverplayer.is_csm_capable(player) or player:get_attach()
		or player:get_hp() <= 0 or core.is_creative_enabled(player:get_player_name()) then
		fall[player] = nil
		return
	end
	local pos = player:get_pos()
	local velocity = player:get_velocity()
	local state = fall[player]
	if state and vector.equals(pos, state.pos) and velocity.y == state.vy and not state.pending then
		return
	end
	local speed = vector.length(velocity)
	if not state then
		fall[player] = {pos = pos, peak = pos.y, vy = velocity.y, speed = speed}
		return
	end

	local downward = state.pos.y - pos.y
	local teleported = vector.distance(pos, state.pos) > math.max(2, math.max(speed, state.speed) * 0.35 + 0.5)
	state.pos = pos
	local previously_descending = state.vy < -0.1
	state.vy, state.speed = velocity.y, speed
	if teleported then
		state.peak, state.pending = pos.y, nil
		return
	end

	local node = core.get_node_or_nil(vector.offset(pos, 0, 0.1, 0))
	local def = node and core.registered_nodes[node.name]
	if not def then return end
	if node.name == "ignore" or def.climbable or (def.groups.water or 0) > 0
		or node.name == "mcl_core:cobweb" or node.name == "mcl_powder_snow:powder_snow"
		or node.name == "mcl_portals:portal_end" or mcl_potions.has_effect(player, "slow_falling") then
		state.peak, state.pending = pos.y, nil
		return
	end
	state.peak = math.max(state.peak, pos.y)
	local now = core.get_us_time()
	if velocity.y >= -0.1 and (previously_descending or downward > 0 or state.pending) then
		local box = player:get_properties().collisionbox
		local top, landed = landing_surface(pos, box)
		if top then
			local safe_distance = 3 + mcl_potions.get_effect_level(player, "leaping")
			local multiplier = 1 + core.get_item_group(landed, "fall_damage_add_percent") / 100
			local damage = math.floor((state.peak + box[2] - top - safe_distance + 0.001) * multiplier)
			state.peak, state.pending = pos.y, nil
			state.handled_until = now + 500000
			if damage > 0 then
				mcl_damage.damage_player(player, damage, {type = "fall", stock_fall_distance = true})
			end
			return
		end
		-- A bounce can reach the next position packet already heading up
		-- above the support. Begin tracking its new ascent from there.
		if previously_descending and velocity.y > 0.1 then
			state.peak = pos.y
		end
	end
	if state.pending and now >= state.pending.deadline then
		-- The stock client can report an impact before its final position
		-- packet. Retain the native amount if the landing couldn't be resolved.
		local damage = state.pending.damage
		state.peak, state.pending = pos.y, nil
		state.handled_until = now + 500000
		mcl_damage.damage_player(player, damage, {type = "fall"})
	end
end

mcl_player.register_globalstep(update)

mcl_damage.register_modifier(function(player, damage, reason)
	if not reason.native_fall then return end
	local state = fall[player]
	if not state then return end
	local now = core.get_us_time()
	if not state.handled_until or now > state.handled_until then
		state.pending = {damage = damage, deadline = now + 350000}
	end
	return 0
end, -201)

core.register_on_leaveplayer(function(player) fall[player] = nil end)
core.register_on_dieplayer(function(player) fall[player] = nil end)
