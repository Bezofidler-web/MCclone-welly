local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape

local is_sp = core.is_singleplayer()
local straw_bed_pos = {}
local sleep_job

-- Helper functions

local function get_look_yaw(pos)
	local n = core.get_node(pos)
	local param = n.param2
	if param == 1 then
		return math.pi / 2, param
	elseif param == 3 then
		return -math.pi / 2, param
	elseif param == 0 then
		return math.pi, param
	else
		return 0, param
	end
end

local function players_in_bed_setting()
	return tonumber(core.settings:get("mcl_playersSleepingPercentage")) or 100
end

local function is_in_overworld(player)
	local pos = player:get_pos()
	return pos and mcl_worlds.pos_to_dimension(pos) == "overworld"
end

local function sleep_counts(leaving_name)
	local sleeping, total = 0, 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if name ~= leaving_name and is_in_overworld(player) then
			total = total + 1
			if mcl_beds.player[name] then
				sleeping = sleeping + 1
			end
		end
	end
	local percentage = players_in_bed_setting()
	local required = math.max(1, math.ceil(math.min(percentage, 100) * total / 100))
	return sleeping, required, percentage
end

function mcl_beds.is_night(tod)
	-- Values taken from Minecraft Wiki with offset of +600
	if not tod then
		tod = core.get_timeofday()
	end
	tod = ( tod * 24000 ) % 24000
	return  tod > 18541 or tod < 5458
end

-- monsters prevent sleep unless the "does_not_prevent_sleep" flag is
-- set other mobs *can* prevent sleep when hostile if the
-- "prevents_sleep_when_hostile" flag is set.
local function prevents_sleep(mob_def,mob_ent)
	if (mob_def.prevents_sleep_when_hostile and not mob_ent.attack)
		or mob_def.type ~= "monster"
		or mob_def.does_not_prevent_sleep then
		return false
	end
	return true
end

local function lay_down(player, pos, bed_pos, is_straw_bed)
	local name = player:get_player_name()
	local hud_flags = player:hud_get_flags()

	if not player or not name then
		return false
	end

	local yaw, param2, dir, bed_pos2, bed_center
	if bed_pos then
		yaw, param2 = get_look_yaw(bed_pos)
		dir = core.facedir_to_dir(param2)
		bed_pos2 = {x = bed_pos.x - dir.x, y = bed_pos.y, z = bed_pos.z - dir.z}
		bed_center = {x = bed_pos.x - dir.x/2, y = bed_pos.y + 0.1, z = bed_pos.z - dir.z/2}

		if not is_straw_bed then
			-- save respawn position when entering bed
			if mcl_spawn.set_spawn_pos(player, bed_pos, nil) then
				core.chat_send_player(name, S("New respawn position set!"))
			end
		end


		if not mcl_beds.is_night() and mcl_weather.get_weather() ~= "thunder" then
			return false, S("You can only sleep at night or during a thunderstorm.")
		end

		-- No sleeping if too far away
		if vector.distance(bed_pos, pos) > 3 and vector.distance(bed_pos2, pos) > 3 then
			return false, S("You can't sleep, the bed's too far away!")
		end

		for _, other_pos in pairs(mcl_beds.bed_pos) do
			if vector.distance(bed_pos2, other_pos) < 0.1 then
				return false,  S("This bed is already occupied!")
			end
		end

		-- No sleeping if monsters nearby.
		for obj in core.objects_inside_radius(bed_pos, 8) do
			if obj and not obj:is_player() then
				local ent = obj:get_luaentity()
				if ent then
					local mobname = ent.name
					local def = core.registered_entities[mobname]
					if def.is_mob and prevents_sleep(def,ent) then
						if math.abs(bed_pos.y - obj:get_pos().y) <= 5 then
							return false, S("You can't sleep now, monsters are nearby!")
						end
					end
				end
			end
		end
	end

	local n1 = core.get_node({x = bed_pos.x,	y = bed_pos.y + 1,	z = bed_pos.z})
	local n2 = core.get_node({x = bed_pos2.x,	y = bed_pos2.y + 1,	z = bed_pos2.z})
	local def1 = core.registered_nodes[n1.name]
	local def2 = core.registered_nodes[n2.name]
	if (def1 and def1.walkable) or (def2 and def2.walkable) then
		return false, S("You can't sleep, the bed is obstructed!")
	elseif (def1 and def1.damage_per_second and def1.damage_per_second > 0) or (def2 and def2.damage_per_second and def2.damage_per_second > 0) then
		return false, S("It's too dangerous to sleep here!")
	end

	mcl_beds.player[name] = 1
	mcl_beds.pos[name] = pos
	mcl_beds.bed_pos[name] = is_straw_bed and bed_pos or bed_pos2

	if is_straw_bed then
		straw_bed_pos[name] = bed_pos
	end

	-- physics, eye_offset, etc
	if not mcl_serverplayer.is_csm_capable (player) then
		player:set_eye_offset({x = 0, y = -13, z = 0}, {x = 0, y = 0, z = 0})
	end
	player:set_look_horizontal(yaw)

	-- With head tracking:
	player:set_look_vertical(0)
	-- Without head tracking:
	-- player:set_look_vertical(-(math.pi/2))

	player:get_meta():set_string("mcl_beds:sleeping", "true")
	playerphysics.add_physics_factor(player, "speed", "mcl_beds:sleeping", 0)
	playerphysics.add_physics_factor(player, "jump", "mcl_beds:sleeping", 0)
	player:add_velocity(-player:get_velocity())
	player:set_pos(bed_center)
	mcl_player.players[player].attached = true
	hud_flags.wielditem = false
	mcl_player.player_set_animation(player, "lay" , 0)
	mcl_serverplayer.override_pose (player, mcl_serverplayer.POSE_SLEEPING)
	awards.unlock(player:get_player_name(), "mcl:sweetDreams")

	player:hud_set_flags(hud_flags)
	return true
end

local function stand_up(player, leaving, keep_position)
	local name = player:get_player_name()
	local previous_pos = mcl_beds.pos[name]
	mcl_beds.player[name] = nil
	mcl_beds.pos[name] = nil
	mcl_beds.bed_pos[name] = nil
	if previous_pos and not keep_position then
		player:set_pos(previous_pos)
	end

	local straw_pos = straw_bed_pos[name]
	straw_bed_pos[name] = nil
	if straw_pos and core.get_node(straw_pos).name == "mcl_beds:straw_bed" then
		-- The node's after_destruct callback removes the other half.
		core.remove_node(straw_pos)
	end

	if leaving then
		return
	end

	-- physics, eye_offset, etc
	local hud_flags = player:hud_get_flags()
	player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	if player:get_look_vertical() > 0 then
		player:set_look_vertical(0)
	end
	mcl_player.players[player].attached = false
	playerphysics.remove_physics_factor(player, "speed", "mcl_beds:sleeping")
	playerphysics.remove_physics_factor(player, "jump", "mcl_beds:sleeping")
	player:get_meta():set_string("mcl_beds:sleeping", "false")
	hud_flags.wielditem = true
	mcl_player.player_set_animation(player, "stand" , 30)
	mcl_serverplayer.override_pose (player, nil)

	player:hud_set_flags(hud_flags)
	return true
end

mcl_player.register_globalstep_slow(function(player)
	local name = player:get_player_name()
	if mcl_beds.player[name] then
		if not is_in_overworld(player) then
			mcl_beds.kick_player(player)
			return
		end
		local bed_pos = mcl_beds.bed_pos[name]
		local bed_node = core.get_node(bed_pos)
		local bed_center_pos = bed_pos + vector.multiply(core.facedir_to_dir(bed_node.param2), 0.5)
		bed_center_pos.y = player:get_pos().y

		player:add_velocity(vector.multiply(-player:get_velocity(), 0.75))
		player:set_pos(bed_center_pos)
	end
end)

local function update_formspecs(sleeping, required, percentage)
	local form_n = "size[12,5;true]"
	local night_skip = percentage <= 100
	local button_leave = "button_exit[4,3;4,0.75;leave;"..F(S("Leave bed")).."]"
	local button_abort = "button_exit[4,3;4,0.75;leave;"..F(S("Abort sleep")).."]"
	local bg_presleep = "bgcolor[#00000080;true]"
	local bg_sleep = "bgcolor[#000000FF;true]"
	local chatbox = "field[0.2,4.5;9,1;chatmessage;"..F(S("Chat:"))..";]"
	local chatsubmit  = "button[9.2,3.75;1,2;chatsubmit;"..F(S("send!")).."]"
	local defaultmessagebutton = "button[10.2,3.75;1,2;defaultmessage;zzZzzZ]"

	form_n = form_n .. chatbox .. chatsubmit --because these should be in the formspec in ANY case, they might as well be added here already

	if not is_sp then
		local text = S("Players in bed: @1/@2", sleeping, required)
		if not night_skip then
			text = text .. "\n" .. S("Note: Night skip is disabled.")
			form_n = form_n .. bg_presleep
			form_n = form_n .. button_leave
		elseif sleeping >= required then
			text = text .. "\n" .. S("You're sleeping.")
			form_n = form_n .. bg_sleep
			form_n = form_n .. button_abort
		else
			local comment
			if percentage == 100 then
				comment = S("You will fall asleep when all players are in bed.")
			else
				comment = S("You will fall asleep when @1% of all players are in bed.", percentage)
			end
			text = text .. "\n" .. comment
			form_n = form_n .. bg_presleep
			form_n = form_n .. button_leave
			form_n = form_n .. defaultmessagebutton --Players should only be able to see that button when: -Skipping the night is possible  -There aren't enoght players sleeping yet
		end
		form_n = form_n .. "label[0.5,1;"..F(text).."]"
	else
		local text
		if night_skip then
			text = S("You're sleeping.")
			form_n = form_n .. bg_sleep
			form_n = form_n .. button_abort
		else
			text = S("You're in bed.") .. "\n" .. S("Note: Night skip is disabled.")
			form_n = form_n .. bg_presleep
			form_n = form_n .. button_leave
		end
		form_n = form_n .. "label[0.5,1;"..F(text).."]"
	end

	for name,_ in pairs(mcl_beds.player) do
		core.show_formspec(name, "mcl_beds_form", form_n)
	end
end

local function cancel_sleep_job()
	if sleep_job then
		sleep_job:cancel()
		sleep_job = nil
	end
end

local function refresh_sleep(leaving_name)
	if not next(mcl_beds.player) then
		cancel_sleep_job()
		return
	end

	local sleeping, required, percentage = sleep_counts(leaving_name)
	if percentage > 100 or sleeping < required then
		cancel_sleep_job()
	elseif not sleep_job then
		sleep_job = core.after(5, function()
			sleep_job = nil
			if not mcl_beds.sleep() then
				refresh_sleep()
			end
		end)
	end
	update_formspecs(sleeping, required, percentage)
	return sleeping, required
end

-- Public functions

-- Handle environment stuff related to sleeping: skip night and thunderstorm
function mcl_beds.sleep()
	local sleeping, required, percentage = sleep_counts()
	if percentage > 100 or sleeping < required then
		return false
	end

	local thunder = mcl_weather.get_weather() == "thunder"
	if thunder then
		local endtime = (mcl_weather.end_time - core.get_gametime()) * 72 / 24000
		core.set_timeofday((core.get_timeofday() + endtime) % 1)
	end
	local night = mcl_beds.is_night()
	if night then
		mcl_beds.skip_night()
	end
	-- Wake the sleepers even if the sun rose during the countdown.
	mcl_beds.kick_players()
	if thunder or night then
		mcl_weather.change_weather("none")
	end
	return true
end

-- Throw all players out of bed
function mcl_beds.kick_players()
	cancel_sleep_job()
	for name, _ in pairs(mcl_beds.player) do
		local player = core.get_player_by_name(name)
		if player then
			stand_up(player, false, not is_in_overworld(player))
			core.close_formspec(name, "mcl_beds_form")
		end
	end
end

-- Throw a player out of bed
function mcl_beds.kick_player(player)
	local name = player:get_player_name()
	if mcl_beds.player[name] then
		stand_up(player, false, not is_in_overworld(player))
		core.close_formspec(name, "mcl_beds_form")
		refresh_sleep()
	end
end

function mcl_beds.skip_night()
	core.set_timeofday(0.25) -- tod = 6000
end

function mcl_beds.get_bed_top (pos)
	local node = core.get_node(pos)
	local dir = core.facedir_to_dir(node.param2)
	local bed_top_pos = vector.add(pos, dir)

	return bed_top_pos
end

function mcl_beds.get_bed_bottom (pos)
	local node = core.get_node(pos)
	local dir = core.facedir_to_dir(node.param2)
	local bed_bottom = vector.add(pos, -dir)
	return bed_bottom
end

function mcl_beds.on_rightclick(pos, player, is_top, is_straw_bed)
	-- Anti-Inception: Don't allow to sleep while you're sleeping
	local name = player:get_player_name()
	if mcl_beds.player[name] or player:get_meta():get_string("mcl_beds:sleeping") == "true" then
		return
	end
	local dim = mcl_worlds.pos_to_dimension(pos)
	if dim == "nether" or dim == "end" then
		-- Bed goes BOOM in the Nether or End.
		local node = core.get_node(pos)
		local dir = core.facedir_to_dir(node.param2)

		core.remove_node(pos)
		core.remove_node(core.get_item_group(node.name, "bed_top") > 0 and vector.subtract(pos, dir) or vector.add(pos, dir))

		if not is_straw_bed then
			mcl_explosions.explode(pos, 5, {fire = true})
		end
		return mcl_util.return_itemstack_if_alive(player)
		-- returning the old itemstack here would result in it still being in hand *after* death
	end
	local bed_pos = is_top and pos or mcl_beds.get_bed_top(pos)
	local entered, message = lay_down(player, player:get_pos(), bed_pos, is_straw_bed)
	if not entered then
		if message then
			mcl_title.set(player, "actionbar", {text=message, color="white", stay=60})
		end
		return
	end

	local sleeping, required = refresh_sleep()
	local sleep_hud_message = S("@1/@2 players currently in bed.", sleeping, required)
	for _, connected in ipairs(core.get_connected_players()) do
		if not mcl_beds.player[connected:get_player_name()] and is_in_overworld(connected) then
			if mcl_title.params_get(connected) then mcl_title.clear(connected) end
			mcl_title.set(connected, "actionbar", {text=sleep_hud_message, color="white", stay=60})
		end
	end
end

-- Callbacks
core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_string("mcl_beds:sleeping") == "true" then
		-- Make player awake on joining server
		meta:set_string("mcl_beds:sleeping", "false")
	end

	playerphysics.remove_physics_factor(player, "speed", "mcl_beds:sleeping")
	playerphysics.remove_physics_factor(player, "jump", "mcl_beds:sleeping")
	refresh_sleep()
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if mcl_beds.player[name] then
		stand_up(player, true)
	end
	refresh_sleep(name)
end)

mcl_worlds.register_on_dimension_change(function(player)
	if mcl_beds.player[player:get_player_name()] and not is_in_overworld(player) then
		mcl_beds.kick_player(player)
	else
		refresh_sleep()
	end
end)

local message_rate_limit = tonumber(core.settings:get("chat_message_limit_per_10sec")) or 8 --NEVER change this! if this was java, i would've declared it as final
local playermessagecounter = {}
--[[
	This table stores how many messages a player XY has sent (only while being in a bed) within 10 secs
	It gets reset after 10 secs using a globalstep
--]]

local chatbuttonused = false
local globalstep_timer = 0
core.register_globalstep(function(dtime)
	globalstep_timer = globalstep_timer + dtime
	if globalstep_timer >= 10 then
		globalstep_timer = 0
		playermessagecounter = {}
		chatbuttonused = false
	end
end)

local function exceeded_rate_limit(playername) --Note: will also take care of increasing value and sending feedback message if needed
	if playermessagecounter[playername] == nil then
		playermessagecounter[playername] = 0
	end
	if playermessagecounter[playername] >= message_rate_limit then -- == should do as well
		core.chat_send_player(playername,S("You exceeded the maximum number of messages per 10 seconds!") .. " (" .. tostring(message_rate_limit) .. ")")
		return true
	end
	playermessagecounter[playername] = playermessagecounter[playername] + 1
	return false
end

local function shout_priv_check(player)
	if not core.check_player_privs(player,"shout") then
		core.chat_send_player(player:get_player_name(),S("You are missing the 'shout' privilege! It's required in order to talk in chat..."))
		return false
	end
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "mcl_beds_form" then
		return
	end

	local custom_sleep_message
	if fields.chatsubmit and fields.chatmessage ~= "" then
		custom_sleep_message = fields.chatmessage
	end

	if custom_sleep_message or fields.defaultmessage then
		if chatbuttonused then
			local time_to_wait = math.ceil(10-globalstep_timer)
			core.chat_send_player(player:get_player_name(),S("Sorry, but you have to wait @1 seconds until you may use this button again!", tostring(time_to_wait)))
			return
		end

		if (not exceeded_rate_limit(player:get_player_name())) and shout_priv_check(player) then
			chatbuttonused = true
			local message = custom_sleep_message or S("Hey! Would you guys mind sleeping?")
			core.chat_send_all(core.format_chat_message(player:get_player_name(), message))
		end
		return
	end

	if fields.quit or fields.leave then
		mcl_beds.kick_player(player)
	end
end)

core.register_on_player_hpchange(function(player, hp_change)
	if hp_change < 0 then
		mcl_beds.kick_player(player)
	end
end)
