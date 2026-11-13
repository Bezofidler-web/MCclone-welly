-- SPDX-License-Identifier: GPL-3.0-or-later

local frequency = {
	step = 1,
	land = 2,
	projectile_land = 2,
	projectile_shoot = 3,
	container_close = 9,
	container_open = 10,
	block_destroy = 12,
	block_place = 13,
}

local quiet_while_sneaking = {step = true, land = true, projectile_shoot = true}
local listeners = {}
local footstep_positions = {}
local sensor_selectors = {"group:sculk_sensor_listening"}
local calibrated_selectors = {"group:sculk_calibrated_sensor"}
local all_sensor_selectors = {"group:sculk_sensor"}
local sensor_sections = {}

local function for_sensor_section (pos, range, callback)
	for x = math.floor ((pos.x - range) / 16), math.floor ((pos.x + range) / 16) do
		for y = math.floor ((pos.y - range) / 16), math.floor ((pos.y + range) / 16) do
			for z = math.floor ((pos.z - range) / 16), math.floor ((pos.z + range) / 16) do
				local origin = vector.new (x * 16, y * 16, z * 16)
				local section = core.hash_node_position (origin)
				if not sensor_sections[section] then
					local far = vector.add (origin, 15)
					-- Avoid caching an unloaded section as empty.
					if core.get_node_or_nil (origin) then
						sensor_sections[section] = {
							normal = #core.find_nodes_in_area (origin, far, all_sensor_selectors) > 0,
							calibrated = #core.find_nodes_in_area (origin, far, calibrated_selectors) > 0,
						}
					end
				end
				local data = sensor_sections[section]
				if data and callback (data) then
					return true
				end
			end
		end
	end
	return false
end

local function invalidate_sensor_cache (pos)
	local section = vector.apply (pos, function (n) return math.floor (n / 16) * 16 end)
	sensor_sections[core.hash_node_position (section)] = nil
end

-- Map generation and direct mods can place nodes without a player callback.
local cache_time = 0
core.register_globalstep (function (dtime)
	cache_time = cache_time + dtime
	if cache_time >= 1 then
		cache_time = 0
		sensor_sections = {}
	end
end)

function mcl_sculk.is_dampening (name)
	return core.get_item_group (name, "wool") > 0
		or core.get_item_group (name, "carpet") > 0
		or core.get_item_group (name, "wool_stair") > 0
		or core.get_item_group (name, "wool_slab") > 0
end

function mcl_sculk.is_survival_player (player)
	if not player or not player:is_valid () or not player:is_player () or player:get_hp () <= 0 then
		return false
	end
	local mode = mcl_gamemode.get_gamemode (player)
	return mode ~= "creative" and mode ~= "spectator"
end

function mcl_sculk.vibration_occluded (source, receiver)
	local from, dest = vector.round (source), vector.round (receiver)
	if vector.equals (from, dest) then
		return false
	end
	for hit in core.raycast (from, dest, false, false) do
		if not vector.equals (hit.under, from) and not vector.equals (hit.under, dest)
			and core.get_item_group (core.get_node (hit.under).name, "wool") > 0 then
			return true
		end
	end
	return false
end

function mcl_sculk.show_vibration (source, receiver, travel_time)
	if travel_time == 0 then
		return
	end
	core.add_particle ({
		pos = source,
		velocity = vector.divide (vector.subtract (receiver, source), travel_time),
		expirationtime = travel_time,
		size = 1.5,
		glow = 8,
		texture = "mcl_sculk_vibration.png^[verticalframe:7:0",
	})
end

function mcl_sculk.listen_for_vibrations (object, receive)
	listeners[object] = receive
end

function mcl_sculk.stop_listening (object)
	listeners[object] = nil
end

function mcl_sculk.find_vibration_receivers (pos, range, selector, receive)
	local minp, maxp = vector.subtract (vector.round (pos), range), vector.add (vector.round (pos), range)
	for _, target in ipairs (core.find_nodes_in_area (minp, maxp, selector)) do
		local distance = vector.distance (pos, target)
		if distance <= range and not mcl_sculk.vibration_occluded (pos, target) then
			receive (target, distance)
		end
	end
end

function mcl_sculk.emit_vibration (pos, event, source, source_node, resonance)
	local strength = frequency[event] or resonance
	if not strength or source_node and mcl_sculk.is_dampening (source_node) then
		return
	end
	if source and not source:is_valid () then
		source = nil
	end
	if source and source:is_player () then
		if not mcl_sculk.is_survival_player (source)
			or quiet_while_sneaking[event] and source:get_player_control ().sneak then
			return
		end
	end
	local function notify_sensor (target, distance)
		mcl_sculk.queue_sensor_vibration (target, pos, distance, event, strength, source)
	end
	-- Cache section presence to avoid rescanning empty neighbourhoods at every step.
	if for_sensor_section (pos, 8, function (data) return data.normal end) then
		mcl_sculk.find_vibration_receivers (pos, 8, sensor_selectors, notify_sensor)
	end
	if for_sensor_section (pos, 16, function (data) return data.calibrated end) then
		mcl_sculk.find_vibration_receivers (pos, 16, calibrated_selectors, function (target, distance)
			if distance > 8 then
				notify_sensor (target, distance)
			end
		end)
	end
	for listener, receive in pairs (listeners) do
		local target = listener:get_pos ()
		if not target then
			listeners[listener] = nil
		elseif source ~= listener and vector.distance (pos, target) <= 16
			and not mcl_sculk.vibration_occluded (pos, target) then
			receive (listener, pos, event, source)
		end
	end
end

mcl_walkover.register_global (function (pos, node, player)
	if not mcl_sculk.is_survival_player (player) or player:get_attach () then
		footstep_positions[player] = nil
		return
	end
	local player_pos = player:get_pos ()
	local state = footstep_positions[player]
	local grounded = core.registered_nodes[node.name] and core.registered_nodes[node.name].walkable
	local feet = core.get_node (vector.offset (player_pos, 0, 0.05, 0)).name
	local surface = mcl_sculk.is_dampening (feet) and feet or node.name
	if not state or vector.distance (state.pos, player_pos) > 12 then
		footstep_positions[player] = {pos = player_pos, grounded = grounded}
		return
	end
	if grounded and not state.grounded and math.abs (player_pos.y - state.pos.y) > 0.6 then
		state.pos = player_pos
		mcl_sculk.emit_vibration (player_pos, "land", player, surface)
	elseif grounded and vector.distance (state.pos, player_pos) >= 0.65 then
		state.pos = player_pos
		mcl_sculk.emit_vibration (player_pos, "step", player, surface)
	end
	state.grounded = grounded
end)

core.register_on_leaveplayer (function (player)
	footstep_positions[player] = nil
end)

core.register_on_placenode (function (pos, node, player)
	if core.get_item_group (node.name, "sculk_sensor") > 0 then
		invalidate_sensor_cache (pos)
	end
	mcl_sculk.emit_vibration (pos, "block_place", player, node.name)
end)

core.register_on_dignode (function (pos, node, player)
	if core.get_item_group (node.name, "sculk_sensor") > 0 then
		invalidate_sensor_cache (pos)
	end
	mcl_sculk.emit_vibration (pos, "block_destroy", player, node.name)
end)
