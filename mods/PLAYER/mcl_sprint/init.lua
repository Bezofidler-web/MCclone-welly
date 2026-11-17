--[[
Sprint mod for Minetest by GunshipPenguin

To the extent possible under law, the author(s)
have dedicated all copyright and related and neighboring rights
to this software to the public domain worldwide. This software is
distributed without any warranty.
]]

local S = core.get_translator(core.get_current_modname())
mcl_sprint = {}

mcl_sprint.SPEED = 1.3

local SPRINT_FACTOR = "mcl_sprint:sprint"
local PARTICLE_INTERVAL = 0.15
local SPRINT_WINDOW = "mcl_sprint:double_tap_window"
local DEFAULT_WINDOW_MS = 350
local MAX_WINDOW_MS = 500
local players = {}

local function sprint_window_seconds(value)
	return math.min(MAX_WINDOW_MS, math.max(0, tonumber(value) or DEFAULT_WINDOW_MS)) / 1000
end

mcl_player.register_player_setting(SPRINT_WINDOW, {
	type = "slider",
	section = "Accessibility",
	short_desc = S("Double-tap sprint window (ms)"),
	long_desc = S("Time between two presses of Forward. Set to 0 to use only the sprint key."),
	options = {{min = 0, max = MAX_WINDOW_MS, step = 50}},
	ui_default = tostring(DEFAULT_WINDOW_MS),
	on_change = function(player, _, value)
		local state = players[player:get_player_name()]
		if state then
			state.sprint_window = sprint_window_seconds(value)
			state.tap_remaining = 0
		end
	end,
})

-- Returns true if the player with the given name is sprinting, false if not.
-- Returns nil if player does not exist.
function mcl_sprint.is_sprinting(playername)
	local state = players[playername]
	if not state then return nil end
	local player = core.get_player_by_name(playername)
	if player and mcl_serverplayer.is_csm_capable(player) then
		return mcl_serverplayer.sprinting_locally(player) == true
	end
	return state.sprinting
end

core.register_on_joinplayer(function(player)
	players[player:get_player_name()] = {
		sprinting = false,
		last_pos = player:get_pos(),
		distance = 0,
		forward_held = false,
		tap_remaining = 0,
		sprint_window = sprint_window_seconds(mcl_player.get_player_setting(player, SPRINT_WINDOW)),
	}
	-- Old saves can retain these factors after disconnecting while sprinting.
	for _, attribute in ipairs({"speed", "fov"}) do
		if playerphysics.get_physics_factor(player, attribute, SPRINT_FACTOR) then
			playerphysics.remove_physics_factor(player, attribute, SPRINT_FACTOR)
		end
	end
end)
core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)

local function set_sprinting(player, state, sprinting)
	if state.sprinting == sprinting then return end
	state.sprinting = sprinting
	if sprinting then
		playerphysics.add_physics_factor(player, "speed", SPRINT_FACTOR, mcl_sprint.SPEED)
		playerphysics.add_physics_factor(player, "fov", SPRINT_FACTOR, 1.1)
	else
		playerphysics.remove_physics_factor(player, "speed", SPRINT_FACTOR)
		playerphysics.remove_physics_factor(player, "fov", SPRINT_FACTOR)
	end
end

-- Remove the stock-client sprint factors before custom movement takes over.
function mcl_sprint.stop_sprinting(player)
	local state = players[player:get_player_name()]
	if not state then return end
	state.tap_remaining = 0
	set_sprinting(player, state, false)
end

-- Given the param2 and paramtype2 of a node, returns the tile that is facing upwards
local function get_top_node_tile(param2, paramtype2)
	if paramtype2 == "colorwallmounted" then
		paramtype2 = "wallmounted"
		param2 = param2 % 8
	elseif paramtype2 == "colorfacedir" then
		paramtype2 = "facedir"
		param2 = param2 % 32
	end
	if paramtype2 == "wallmounted" then
		if param2 == 0 then
			return 2
		elseif param2 == 1 then
			return 1
		else
			return 5
		end
	elseif paramtype2 == "facedir" then
		if param2 >= 0 and param2 <= 3 then
			return 1
		elseif param2 == 4 or param2 == 10 or param2 == 13 or param2 == 19 then
			return 6
		elseif param2 == 5 or param2 == 11 or param2 == 14 or param2 == 16 then
			return 3
		elseif param2 == 6 or param2 == 8 or param2 == 15 or param2 == 17 then
			return 5
		elseif param2 == 7 or param2 == 9 or param2 == 12 or param2 == 18 then
			return 4
		elseif param2 >= 20 and param2 <= 23 then
			return 2
		else
			return 1
		end
	else
		return 1
	end
end
mcl_sprint.get_top_node_tile = get_top_node_tile

function mcl_sprint.spawn_particles (player, self_pos)
	-- Sprint node particles
	local playerNode = core.get_node (vector.offset (self_pos, 0, -1, 0))
	local def = core.registered_nodes[playerNode.name]
	if def and def.walkable then
		core.add_particlespawner({
			amount = math.random(1, 2),
			time = 1,
			minpos = {x=-0.5, y=0.1, z=-0.5},
			maxpos = {x=0.5, y=0.1, z=0.5},
			minvel = {x=0, y=5, z=0},
			maxvel = {x=0, y=5, z=0},
			minacc = {x=0, y=-13, z=0},
			maxacc = {x=0, y=-13, z=0},
			minexptime = 0.1,
			maxexptime = 1,
			minsize = 0.5,
			maxsize = 1.5,
			collisiondetection = true,
			attached = player,
			vertical = false,
			node = playerNode,
			node_tile = get_top_node_tile(playerNode.param2, def.paramtype2),
		})
	end
end

local function track_sprint_distance(player, name, state, pos, dtime, emit_particles)
	local dx, dz = pos.x - state.last_pos.x, pos.z - state.last_pos.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance == 0 then return end

	-- Leave room for delayed position packets and faster movement effects.
	-- Larger discontinuities come from teleports or position corrections.
	local velocity = player:get_velocity()
	local speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
	if distance > math.max(2, speed * (dtime + 0.25)) then return end

	state.distance = state.distance + distance
	local blocks = math.floor(state.distance)
	if blocks > 0 then
		mcl_hunger.exhaust(name, mcl_hunger.EXHAUST_SPRINT * blocks)
		state.distance = state.distance - blocks
	end
	if emit_particles then
		mcl_sprint.spawn_particles(player, pos)
	end
end

local function stopped_by_full_wall(player, pos, ctrl)
	-- Stock clients resolve player collisions locally. A full cube directly
	-- ahead of a stalled player is a reliable case to recognise on the server.
	if ctrl.jump or ctrl.left or ctrl.right or math.abs(ctrl.movement_x or 0) > 0.05 then return false end
	local velocity = player:get_velocity()
	if math.abs(velocity.x) > 0.1 or math.abs(velocity.y) > 0.1 or math.abs(velocity.z) > 0.1 then
		return false
	end

	local props = player:get_properties()
	local box = props.collisionbox
	local probe_height = box[2] + (props.stepheight or 0.6) + 0.05
	if probe_height >= box[5] then return false end
	local feet = core.get_node_or_nil(vector.offset(pos, 0, box[2] + 0.1, 0))
	if not feet or core.get_item_group(feet.name, "liquid") > 0 then return false end

	local dir = core.yaw_to_dir(player:get_look_horizontal())
	local rx = (dir.x < 0 and -box[1] or box[4]) / math.max(math.abs(dir.x), 0.001)
	local rz = (dir.z < 0 and -box[3] or box[6]) / math.max(math.abs(dir.z), 0.001)
	local reach = math.min(rx, rz) + 0.04
	local point = vector.round(vector.offset(pos, dir.x * reach, probe_height, dir.z * reach))
	local node = core.get_node_or_nil(point)
	local def = node and core.registered_nodes[node.name]
	if not def or not def.walkable then return false end
	local shapes = core.get_node_boxes("collision_box", point, node)
	local cube = shapes[1]
	return #shapes == 1 and cube[1] == -0.5 and cube[2] == -0.5 and cube[3] == -0.5
		and cube[4] == 0.5 and cube[5] == 0.5 and cube[6] == 0.5
end

local function wants_to_sprint(player, state, pos, dtime)
	local ctrl = player:get_player_control()
	local impulse = ctrl.movement_y
	if impulse == nil then
		impulse = (ctrl.up and 1 or 0) - (ctrl.down and 1 or 0)
	end
	-- A pure sideways input can have a tiny forward component from rounding.
	local forward = impulse > 0.001
	local pressed_forward = forward and not state.forward_held
	state.forward_held = forward
	state.tap_remaining = math.max(0, state.tap_remaining - dtime)

	if ctrl.sneak or ctrl.down or impulse < -0.001 or player:get_hp() <= 0
		or player:get_attach() or (mcl_hunger.active and mcl_hunger.get_hunger(player) <= 6)
		or player:get_meta():get_string("mcl_beds:sleeping") == "true" then
		state.tap_remaining = 0
		return false
	end
	if not forward then return false end
	if state.sprinting or ctrl.aux1 or (pressed_forward and state.tap_remaining > 1e-6) then
		state.tap_remaining = 0
		return not stopped_by_full_wall(player, pos, ctrl)
	end
	if pressed_forward then
		state.tap_remaining = state.sprint_window
	end
	return false
end

local particle_time = 0
core.register_globalstep(function(dtime)
	particle_time = particle_time + dtime
	local emit_particles = particle_time >= PARTICLE_INTERVAL
	if emit_particles then particle_time = 0 end

	for name, state in pairs(players) do
		local player = core.get_player_by_name(name)
		if player and not mcl_serverplayer.is_csm_capable(player) then
			local pos = player:get_pos()
			local sprinting = wants_to_sprint(player, state, pos, dtime)
			if sprinting and state.sprinting then
				track_sprint_distance(player, name, state, pos, dtime, emit_particles)
			end
			set_sprinting(player, state, sprinting)
			state.last_pos = pos
		end
	end
end)
