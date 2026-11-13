-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_sculk")
local normal_name = "mcl_sculk:sensor"
local calibrated_name = "mcl_sculk:calibrated_sensor"
local source_key = "mcl_sculk:source"
local frequency_key = "mcl_sculk:frequency"
local power_key = "mcl_sculk:power"
local directions = {
	vector.new (1, 0, 0), vector.new (-1, 0, 0), vector.new (0, 1, 0),
	vector.new (0, -1, 0), vector.new (0, 0, 1), vector.new (0, 0, -1),
}

local function sensor_base (node)
	return core.get_item_group (node.name, "sculk_calibrated_sensor") > 0 and calibrated_name or normal_name
end

local function sensor_input_dir (node)
	return vector.multiply (core.facedir_to_dir (node.param2), -1)
end

local function sensor_timer (pos)
	local node = core.get_node (pos)
	local def = core.registered_nodes[node.name]
	local base = sensor_base (node)
	local meta = core.get_meta (pos)
	if def._mcl_sculk_power and def._mcl_sculk_power > 0 then
		meta:set_int (frequency_key, 0)
		mcl_redstone.swap_node (pos, {name = base .. "_cooldown", param2 = node.param2})
		core.get_node_timer (pos):start (0.5)
		core.sound_play ("mcl_sculk_click", {pos = pos, gain = 0.25, pitch = 0.8, max_hear_distance = 12}, true)
		return
	end
	if def._mcl_sculk_power == 0 then
		mcl_redstone.swap_node (pos, {name = base, param2 = node.param2})
		return
	end
	local power = meta:get_int (power_key)
	if power < 1 or power > 15 then
		return
	end
	local name = meta:get_string (source_key)
	local strength = meta:get_int (frequency_key)
	meta:set_int (power_key, 0)
	meta:set_string (source_key, "")
	mcl_redstone.swap_node (pos, {name = base .. "_active_" .. power, param2 = node.param2})
	core.get_node_timer (pos):start (base == calibrated_name and 0.5 or 1.5)
	core.sound_play ("mcl_sculk_click", {pos = pos, gain = 0.7, max_hear_distance = 16}, true)
	mcl_sculk.propagate_shriek (pos, name)
	for _, direction in ipairs (directions) do
		local neighbor = vector.add (pos, direction)
		if core.get_node (neighbor).name == "mcl_amethyst:amethyst_block" then
			mcl_sculk.emit_vibration (neighbor, "resonance", core.get_player_by_name (name), nil, strength)
		end
	end
end

function mcl_sculk.queue_sensor_vibration (pos, source_pos, distance, _, strength, source)
	local node = core.get_node (pos)
	if core.get_item_group (node.name, "sculk_sensor_listening") == 0
		or core.get_node_timer (pos):is_started () then
		return false
	end
	local calibrated = sensor_base (node) == calibrated_name
	local range = calibrated and 16 or 8
	if distance > range then
		return false
	end
	if calibrated then
		local filter = mcl_redstone.get_power (pos, sensor_input_dir (node))
		if filter ~= 0 and filter ~= strength then
			return false
		end
	end
	local meta = core.get_meta (pos)
	meta:set_int (power_key, math.max (1, 15 - math.floor (15 * distance / range)))
	meta:set_int (frequency_key, strength)
	meta:set_string (source_key, source and source:is_player () and source:get_player_name () or "")
	local travel_time = math.floor (distance) / 20
	mcl_sculk.show_vibration (source_pos, pos, travel_time)
	core.get_node_timer (pos):start (math.max (0.05, travel_time))
	return true
end

local function animated (name, period)
	return {name = name, animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = period}}
end

local function register_sensor (name, calibrated, power)
	local base = calibrated and calibrated_name or normal_name
	local groups = {handy = 1, hoey = 1, deco_block = 1, sculk = 1, unmovable_by_piston = 1,
		pathfinder_partial = 2, sculk_sensor = 1, sculk_calibrated_sensor = calibrated and 1 or nil}
	if power then
		groups.not_in_creative_inventory = 1
	else
		groups.sculk_sensor_listening = 1
	end
	local top = calibrated and "mcl_sculk_calibrated_sensor_top.png" or "mcl_sculk_sensor_top.png"
	local side = "mcl_sculk_sensor_side.png"
	local tendril = "mcl_sculk_sensor_tendril_" .. (power and "active" or "inactive") .. ".png"
	local tendril_tile = animated (tendril, power and 0.8 or 1.6)
	local tiles = {top, "mcl_sculk_sensor_bottom.png", side, tendril_tile}
	if calibrated then
		tiles[4] = "mcl_sculk_calibrated_sensor_input_side.png"
		tiles[5] = tendril_tile
		tiles[6] = "mcl_sculk_calibrated_sensor_amethyst.png"
	end
	core.register_node (name, {
		description = calibrated and S ("Calibrated Sculk Sensor") or S ("Sculk Sensor"),
		_doc_items_longdesc = S ("It detects vibrations and briefly emits redstone power. Wool blocks can stop vibrations from reaching it."),
		_doc_items_create_entry = not power,
		drawtype = "mesh",
		mesh = calibrated and "mcl_sculk_calibrated_sensor.obj" or "mcl_sculk_sensor.obj",
		tiles = tiles,
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		use_texture_alpha = "clip",
		light_source = power and power > 0 and 1 or 0,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}},
		collision_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}},
		groups = groups,
		drop = "",
		_mcl_hardness = 1.5,
		_mcl_blast_resistance = 1.5,
		_mcl_silk_touch_drop = {base},
		sounds = mcl_sculk.sounds,
		on_timer = sensor_timer,
		after_dig_node = function (pos, node, oldmeta, digger)
			mcl_sculk.drop_xp (pos, node, oldmeta, digger, 5)
		end,
		_mcl_sculk_power = power,
		_mcl_redstone = {
			connects_to = function () return true end,
			get_power = function (node, direction)
				if calibrated and direction == sensor_input_dir (node) then
					return 0
				end
				return power or 0, direction.y < 0
			end,
		},
	})
	mcl_redstone.register_comparator_measure_func (name, function (pos)
		return power and power > 0 and core.get_meta (pos):get_int (frequency_key) or 0
	end)
end

for _, calibrated in ipairs ({false, true}) do
	local base = calibrated and calibrated_name or normal_name
	register_sensor (base, calibrated)
	register_sensor (base .. "_cooldown", calibrated, 0)
	for power = 1, 15 do
		register_sensor (base .. "_active_" .. power, calibrated, power)
	end
end

core.register_craft ({
	output = calibrated_name,
	recipe = {{"", "mcl_amethyst:amethyst_shard", ""},
		{"mcl_amethyst:amethyst_shard", normal_name, "mcl_amethyst:amethyst_shard"}},
})
