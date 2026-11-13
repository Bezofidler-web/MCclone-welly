return function (phantom)
	local REST = "mcl_phantoms:time_since_rest"
	local UPDATE = 0.5
	local threshold = tonumber (core.settings:get ("mcl_phantom_insomnia_seconds")) or 3600
	threshold = math.max (1, math.min (604800, threshold))
	local time_to_attempt = math.random (60, 119)
	local update_time = 0

	local function reset_rest (player)
		player:get_meta ():set_float (REST, 0)
	end
	core.register_on_dieplayer (reset_rest)
	core.register_on_respawnplayer (reset_rest)

	local function exposed (pos)
		return (core.get_natural_light (pos, 0.5) or 0) >= core.LIGHT_MAX
	end

	local function spawn_pack (player, pos)
		local difficulty = mcl_vars.difficulty
		local nearby = 0
		for object in core.objects_inside_radius (pos, 48) do
			local entity = object:get_luaentity ()
			if entity and entity.name == phantom and not entity.dead and not entity.removed then
				nearby = nearby + 1
			end
		end
		local count = math.min (math.random (1, difficulty + 1), difficulty + 1 - nearby)
		if count <= 0 then return end
		local anchor = vector.offset (pos, math.random (-10, 10), math.random (20, 34), math.random (-10, 10))
		for _ = 1, count do
			local spawn = vector.offset (anchor, math.random (-1, 1), 0, math.random (-1, 1))
			if core.get_node (spawn).name == "air" and exposed (spawn)
				and mcl_mobs.is_position_completely_generated (spawn) then
				local object = core.add_entity (spawn, phantom)
				if object and object:is_valid () then
					object:get_luaentity ()._phantom_target = player
				end
			end
		end
	end

	local function attempt (player, rest)
		local pos = player:get_pos ()
		if not pos or player:get_hp () <= 0 or core.is_creative_enabled (player:get_player_name ())
			or mcl_worlds.pos_to_dimension (pos) ~= "overworld" or pos.y < mobs_mc.water_level
			or not exposed (vector.round (vector.offset (pos, 0, 1.5, 0))) then
			return
		end
		if rest >= threshold and math.random () * rest >= threshold / 3
			and math.random () * 3 < mcl_worlds.get_regional_difficulty (pos) then
			spawn_pack (player, pos)
		end
	end

	core.register_globalstep (function (dtime)
		update_time = update_time + dtime
		if update_time < UPDATE then return end
		local elapsed = update_time
		update_time = 0
		time_to_attempt = time_to_attempt - elapsed
		local try_spawning = time_to_attempt <= 0
		if try_spawning then time_to_attempt = math.random (60, 119) end
		try_spawning = try_spawning and mcl_vars.mobs_spawn and mcl_vars.difficulty > 0
			and not mcl_vars.only_peaceful_mobs and core.settings:get_bool ("mcl_phantom_insomnia", true)
			and (mcl_beds.is_night () or mcl_weather.get_weather () == "thunder")
		for _, player in ipairs (core.get_connected_players ()) do
			if mcl_beds.player[player:get_player_name ()] then
				reset_rest (player)
			elseif player:get_hp () > 0 then
				local meta = player:get_meta ()
				local rest = math.min (604800, meta:get_float (REST) + elapsed)
				meta:set_float (REST, rest)
				if try_spawning and rest >= threshold then attempt (player, rest) end
			end
		end
	end)
end
