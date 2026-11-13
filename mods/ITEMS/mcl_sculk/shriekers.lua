-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_sculk")
local warning_key = "mcl_sculk:warning_level"
local age_key = "mcl_sculk:last_warning"
local warning_cooldown = 10
local warning_decay = 600
local shriek_time = 4.5
local listener_range = 8
local shrieker_selector = {"group:sculk_shrieker_listening"}

function mcl_sculk.apply_darkness (pos, radius, duration)
	for player in mcl_util.connected_players (pos, radius) do
		if mcl_sculk.is_survival_player (player) then
			mcl_potions.give_effect_by_level ("darkness", player, 1, duration, true)
		end
	end
end

local function warden_near (pos)
	for object in core.objects_inside_radius (pos, 48) do
		local entity = object:get_luaentity ()
		if entity and entity.name == "mobs_mc:warden" then
			return true
		end
	end
	return false
end

local function can_summon ()
	return mcl_vars.difficulty > 0 and not mcl_vars.only_peaceful_mobs
		and core.registered_entities["mobs_mc:warden"]
end

local function get_warning (player, now)
	local meta = player:get_meta ()
	local level = meta:get_int (warning_key)
	local elapsed = math.max (0, now - meta:get_int (age_key))
	return math.max (0, level - math.floor (elapsed / warning_decay)), elapsed
end

local function warn_players (pos, source)
	if not can_summon () or warden_near (pos) then
		return 0
	end
	local now = core.get_gametime ()
	local affected = {[source] = true}
	for player in mcl_util.connected_players (pos, 16) do
		if mcl_sculk.is_survival_player (player) then
			affected[player] = true
		end
	end
	local level = 0
	for player in pairs (affected) do
		local warning, elapsed = get_warning (player, now)
		if warning > 0 and elapsed < warning_cooldown then
			return 0
		end
		level = math.max (level, warning)
	end
	level = math.min (4, level + 1)
	for player in pairs (affected) do
		local meta = player:get_meta ()
		meta:set_int (warning_key, level)
		meta:set_int (age_key, now)
	end
	return level
end

local function spawn_warden (pos)
	for _ = 1, 20 do
		local at = vector.offset (pos, math.random (-5, 5), 6, math.random (-5, 5))
		for _ = 0, 12 do
			local below = core.get_node (vector.offset (at, 0, -1, 0)).name
			if core.get_item_group (below, "opaque") > 0
				and mcl_mobs.spawn_abnormally (at, "mobs_mc:warden", {_emerging = 6.7}, "sculk_shrieker") then
				return true
			end
			at.y = at.y - 1
		end
	end
	return false
end

local function finish_shriek (pos, warning)
	if warning < 1 or not can_summon () then
		return
	end
	if warning >= 4 and not warden_near (pos) and spawn_warden (pos) then
		mcl_sculk.apply_darkness (pos, 40, 12)
		return
	end
	mcl_sculk.apply_darkness (pos, 40, 12)
	core.sound_play ("mcl_sculk_warning", {pos = pos, gain = 0.7,
		pitch = 0.63 + warning * 0.07, max_hear_distance = 40}, true)
end

function mcl_sculk.activate_shrieker (pos, source)
	if not mcl_sculk.is_survival_player (source) then
		return false
	end
	local node = core.get_node (pos)
	local kind = core.get_item_group (node.name, "sculk_shrieker_listening")
	if kind == 0 or core.get_node_timer (pos):is_started () then
		return false
	end
	local warning = kind == 2 and warn_players (pos, source) or 0
	if kind == 2 and can_summon () and warning == 0 then
		return false
	end
	core.get_meta (pos):set_int (warning_key, warning)
	core.swap_node (pos, {name = node.name .. "_shrieking", param2 = node.param2})
	core.get_node_timer (pos):start (shriek_time)
	core.sound_play ("mcl_sculk_shriek", {pos = pos, gain = 1.1, max_hear_distance = 32}, true)
	core.add_particlespawner ({
		amount = 7, time = shriek_time,
		minpos = vector.offset (pos, 0, 0, 0), maxpos = vector.offset (pos, 0, 0.2, 0),
		minvel = vector.new (0, 0.5, 0), maxvel = vector.new (0, 1, 0),
		minexptime = 0.6, maxexptime = 1.2, minsize = 4, maxsize = 6,
		glow = 3, texture = "mcl_sculk_vibration.png^[verticalframe:7:0",
	})
	return true
end

function mcl_sculk.propagate_shriek (pos, player_name)
	if player_name == "" then
		return
	end
	mcl_sculk.find_vibration_receivers (pos, listener_range, shrieker_selector, function (target, distance)
		local travel_time = math.floor (distance) / 20
		mcl_sculk.show_vibration (pos, target, travel_time)
		local timer = core.get_node_timer (target)
		if not timer:is_started () then
			core.get_meta (target):set_string ("mcl_sculk:pending_source", player_name)
			timer:start (math.max (0.05, travel_time))
		end
	end)
end

local function shrieker_timer (pos)
	local node = core.get_node (pos)
	local meta = core.get_meta (pos)
	local def = core.registered_nodes[node.name]
	if not def._mcl_sculk_shrieking then
		local source = meta:get_string ("mcl_sculk:pending_source")
		meta:set_string ("mcl_sculk:pending_source", "")
		core.get_node_timer (pos):stop ()
		mcl_sculk.activate_shrieker (pos, core.get_player_by_name (source))
		return
	end
	local warning = meta:get_int (warning_key)
	meta:set_int (warning_key, 0)
	core.swap_node (pos, {name = def._mcl_sculk_base, param2 = node.param2})
	finish_shriek (pos, warning)
end

local function stepped_on (pos, _, player)
	local player_pos = player:get_pos ()
	if player_pos and player_pos.y >= pos.y - 0.05 and player_pos.y < pos.y + 0.4 then
		mcl_sculk.activate_shrieker (vector.round (pos), player)
	end
end

local function register_shrieker (base, natural, shrieking)
	local id = shrieking and base .. "_shrieking" or base
	local groups = {handy = 1, hoey = 1, deco_block = 1, sculk = 1, unmovable_by_piston = 1,
		sculk_shrieker = natural and 2 or 1, pathfinder_partial = 2}
	if natural or shrieking then
		groups.not_in_creative_inventory = 1
	end
	if not shrieking then
		groups.sculk_shrieker_listening = groups.sculk_shrieker
	end
	local inner = natural and "mcl_sculk_shrieker_can_summon_inner_top.png" or "mcl_sculk_shrieker_inner_top.png"
	core.register_node (id, {
		description = S ("Sculk Shrieker"),
		_doc_items_longdesc = S ("It shrieks when stepped on or alerted by a sculk sensor. Naturally generated shriekers can summon a Warden."),
		_doc_items_create_entry = not natural and not shrieking,
		drawtype = "mesh",
		mesh = "mcl_sculk_shrieker.obj",
		tiles = {
			"mcl_sculk_shrieker_top.png", "mcl_sculk_shrieker_bottom.png", "mcl_sculk_shrieker_side.png",
			{name = inner, animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = natural and 1.5 or 3}},
		},
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}},
		collision_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}},
		groups = groups,
		drop = "",
		_mcl_hardness = 3,
		_mcl_blast_resistance = 3,
		_mcl_silk_touch_drop = {"mcl_sculk:shrieker"},
		_mcl_sculk_base = base,
		_mcl_sculk_shrieking = shrieking,
		sounds = mcl_sculk.sounds,
		on_timer = shrieker_timer,
		_on_object_over = stepped_on,
		_on_object_in = stepped_on,
		after_dig_node = function (pos, oldnode, oldmeta, digger)
			local fields = oldmeta and oldmeta.fields
			finish_shriek (pos, fields and tonumber (fields[warning_key]) or 0)
			mcl_sculk.drop_xp (pos, oldnode, oldmeta, digger, 5)
		end,
		on_blast = function (pos)
			local warning = core.get_meta (pos):get_int (warning_key)
			core.remove_node (pos)
			finish_shriek (pos, warning)
		end,
	})
end

register_shrieker ("mcl_sculk:shrieker", false)
register_shrieker ("mcl_sculk:shrieker_natural", true)
register_shrieker ("mcl_sculk:shrieker", false, true)
register_shrieker ("mcl_sculk:shrieker_natural", true, true)
