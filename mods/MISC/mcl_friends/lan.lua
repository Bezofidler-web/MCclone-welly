-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator("mcl_friends")
local session = os.getenv("MCL_LAN_SESSION_ID")
if not session or #session ~= 32 or session:find("[^a-fA-F0-9]") then return end
local world = core.get_worldpath()

if core.is_singleplayer() then
	local function offer()
		core.show_formspec("singleplayer", "mcl_friends:open_lan",
			"formspec_version[8]size[8,3.7]label[0.5,0.55;" .. core.formspec_escape(S("Open to LAN")) .. "]"
			.. "textarea[0.5,1;7,1.35;;;" .. core.formspec_escape(S("Save this world and choose your LAN host settings. Players on your local network can join once you open it.")) .. "]"
			.. "button_exit[0.5,2.68;3.35,0.65;cancel;" .. core.formspec_escape(S("Cancel")) .. "]"
			.. "button_exit[4.15,2.68;3.35,0.65;share;" .. core.formspec_escape(S("Save and continue")) .. "]")
	end
	core.register_chatcommand("openlan", {description = S("Share this world on your local network"),
		func = function(name)
			if name == "singleplayer" then offer() return true end
		end})
	mcl_player.register_player_settings_button({field = "__mcl_open_lan", description = S("Open to LAN…"), priority = 1})
	core.register_on_player_receive_fields(function(player, form, fields)
		if player:get_player_name() ~= "singleplayer" then return end
		if (form == "mcl_player:settings_formspec" or form == "") and fields.__mcl_open_lan then
			offer()
			return true
		elseif form == "mcl_friends:open_lan" and fields.share then
			if core.safe_file_write(world .. "/mcl_open_lan.json", core.write_json({session = session})) then
				core.request_shutdown(S("Preparing to share your world."), false, 0)
			else
				core.chat_send_player("singleplayer", S("Could not save the sharing request."))
			end
			return true
		end
	end)
	return
end

if core.settings:get("mcl_lan_session") ~= session or core.settings:get("mcl_lan_world_path") ~= world then return end
local id = core.settings:get("mcl_lan_id")
local host = core.settings:get("mcl_lan_display_host")
local solo = core.settings:get_bool("mcl_lan_solo_owner")
local owner = solo and "singleplayer" or host
if not id or #id ~= 32 or id:find("[^a-fA-F0-9]") or core.settings:get("name") ~= owner then
	error("Invalid local multiplayer session. Reopen the world from Multiplayer.")
end
dofile(core.get_modpath("mcl_friends") .. "/controls.lua")(owner)

local saved_path = world .. "/mcl_lan_world.json"
local ready_path = world .. "/mcl_lan_ready.json"
local storage = core.get_mod_storage()
local compatible, saved_owner
local function can_open()
	if storage:get_int("private_world") == 1 then return false end
	for key in pairs(storage:to_table().fields) do
		if key:sub(1, 7) == "access:" then return false end
	end
	local file = io.open(saved_path, "rb")
	if file then
		local contents = file:read(2049)
		file:close()
		local saved = contents and #contents <= 2048 and core.parse_json(contents)
		saved_owner = type(saved) == "table" and saved.id == id and saved.owner == host and saved.solo == solo
		return saved_owner
	end
	for name in core.get_auth_handler().iterate() do
		if name ~= "singleplayer" then return false end
	end
	return true
end

local host_connected = false
local local_peer = dofile(core.get_modpath("mcl_friends") .. "/lan_networks.lua")(os.getenv("MCL_LAN_NETWORKS"))
core.register_on_prejoinplayer(function(name, ip)
	if not local_peer(ip) then return S("This world is open to players on the host's local network.") end
	if compatible == nil then compatible = can_open() end
	if not compatible then
		return S("This world already has multiplayer accounts. Reopen it with its original server settings.")
	end
	if name == owner then
		if ip ~= "127.0.0.1" and ip ~= "::1" then return S("The host plays on the computer sharing this world.") end
		-- Persist identity before first account creation. A crash during media
		-- loading must still leave the original owner able to reopen the world.
		if not saved_owner then
			saved_owner = core.safe_file_write(saved_path, core.write_json({id = id, owner = host, solo = solo}))
			if not saved_owner then return S("Could not save this world's multiplayer settings.") end
		end
	elseif not host_connected or name:lower() == host:lower() then
		return S("The host has not opened this world for this player name.")
	end
end)

local function heartbeat()
	return core.safe_file_write(ready_path, core.write_json({session = session, time = os.time()}))
end
core.register_on_joinplayer(function(player)
	if player:get_player_name() ~= owner then return end
	if not heartbeat() then
		core.request_shutdown(S("The world could not save its multiplayer settings."), false, 0)
		return
	end
	host_connected = true
	core.chat_send_player(owner, S("World open to LAN. Friends can choose it from Multiplayer."))
end)
local elapsed = 0
core.register_globalstep(function(dtime)
	if not host_connected then return end
	elapsed = elapsed + dtime
	if elapsed >= 2 then
		elapsed = 0
		heartbeat()
	end
end)
local function close()
	host_connected = false
	os.remove(ready_path)
end
core.register_on_leaveplayer(function(player)
	if player:get_player_name() == owner then close() end
end)
core.register_on_shutdown(close)
