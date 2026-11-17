-- SPDX-License-Identifier: GPL-3.0-or-later
-- Luanti's main-menu Lua environment. This runs before a world is loaded.
-- luacheck: globals core gamedata DIR_DELIM PLATFORM Settings ui dialog_create create_settings_dlg mm_game_theme
local F = core.formspec_escape
local S = core.gettext
local menu_path = assert(core.settings:get("main_menu_script"):match("^(.*[/\\])"))
local lan = dofile(menu_path .. "lan.lua")
local invite = dofile(menu_path .. "../mods/MISC/mcl_friends/invite.lua")
local pending_invite
local game_id = os.getenv("MCL_GAME_ID") or "mineclonia"
local function is_our_world(world)
	return world.gameid == game_id or world.gameid == "mineclonia"
end
local local_port = tonumber(os.getenv("MINECLONIA_PLAYTEST_PORT"))
local local_name = os.getenv("MINECLONIA_PLAYTEST_NAME")
local password_file = os.getenv("MINECLONIA_PLAYTEST_PASSWORD_FILE")
local quick_join = local_port and local_name and password_file
local message = gamedata.errormessage
local last_direct_join = "mcl_menu_last_direct_join"
local page = "title"
if message and message ~= "" then
	page = core.settings:get_bool(last_direct_join, false) and "server"
		or core.settings:get_bool("mcl_menu_last_lan", false) and "multiplayer" or "error"
end
-- These markers are valid for one host start only. Restoring on the next
-- menu load also handles a failed bind, a rejected login or a previous crash.
if core.settings:get("mcl_lan_session") then
	for _, setting in ipairs({"server_announce", "bind_address", "ipv6_server", "name", "mcl_playersSleepingPercentage"}) do
		local previous = core.settings:get("mcl_lan_before_" .. setting)
		if previous then core.settings:set(setting, previous) else core.settings:remove(setting) end
		core.settings:remove("mcl_lan_before_" .. setting)
	end
	for _, setting in ipairs({"session", "world_path", "id", "display_host", "solo_owner"}) do
		core.settings:remove("mcl_lan_" .. setting)
	end
end
local connection_focus = page == "server" and "mc_password" or "mc_address"
local stock_main, stock_title
local worlds, selected, creative = {}, 0, false
local nearby, nearby_index, discovery_error = {}, 0, nil
local hosting = false
local player_name = core.settings:get("mcl_lan_player_name") or core.settings:get("name") or ""
local pending_action, poll_active
local notify_port = tonumber(os.getenv("MCL_LAN_NOTIFY_PORT"))
local new_world = { name = S("New World"), seed = "", creative = false, flat = false }
local render
local connection = {
	address = core.settings:get("address") or "",
	port = core.settings:get("remote_port") or "30000",
	name = core.settings:get("name") or local_name or "",
}

local separator = PLATFORM == "Windows" and ";" or ":"
local widget_path = menu_path .. "../mods/PLAYER/mcl_player/textures/"
local function texture(name, fallback)
	for _, pack in ipairs((core.settings:get("texture_path") or ""):split(separator)) do
		local path = pack .. DIR_DELIM .. name
		local file = io.open(path, "rb")
		if file then
			file:close()
			return path
		end
	end
	return fallback
end

local function button(x, y, width, name, label)
	return ("button[%g,%g;%g,0.64;%s;%s]"):format(x, y, width, name, F(label))
end

local function centred(y, text, x, width)
	return ("label[%g,%g;%g,0.55;%s]"):format(x or 0, y, width or 11.4, F(text))
end

local function field(x, y, width, name, label, value)
	local input = value == nil and ("pwdfield[%g,%g;%g,0.66;%s;]"):format(x, y, width, name)
		or ("field[%g,%g;%g,0.66;%s;;%s]"):format(x, y, width, name, F(value))
	return ("label[%g,%g;%s]box[%g,%g;%g,0.66;#A0A0A0]box[%g,%g;%g,0.60;#000000]")
		:format(x, y - 0.27, F(label), x, y, width, x + 0.03, y + 0.03, width - 0.06)
		.. input .. "field_close_on_enter[" .. name .. ";false]"
end

local function style(width, height, title)
	local function widget(name)
		return F(texture(name, widget_path .. name))
	end
	return ("formspec_version[8]size[%g,%g]padding[0.025,0.04]no_prepend[]"):format(width, height)
		.. (title and "bgcolor[;neither]" or "bgcolor[;true;#16141BB8]")
		.. "style_type[button;border=false;bgimg=" .. widget("mcl_options_button.png")
		.. ";bgimg_middle=3;textcolor=#FFFFFF]"
		.. "style_type[button:hovered,button:focused,button:pressed;bgimg="
		.. widget("mcl_options_button_highlighted.png") .. "]"
		.. "style_type[label;halign=center;valign=center;textcolor=#FFFFFF]"
		.. "style_type[textarea;border=false;textcolor=#E0E0E0;halign=center]"
		.. "style_type[field,pwdfield;border=false;textcolor=#FFFFFF]"
end

local function dialog_header(title)
	return style(11.4, 8.3) .. centred(0.25, title)
		.. "box[0.3,0.95;10.8,0.035;#747179]"
end

local function notice(text, y)
	if not text or text == "" then return "" end
	return ("textarea[0.65,%g;10.1,0.8;;;%s]"):format(y, F(text))
end

local function title_formspec()
	local top = 3.23
	local footer = quick_join and 5.82 or 5.04
	local fs = {
		style(11.4, 8.3, true),
		"image[1.75,0.68;7.9,0.9875;" .. F(menu_path .. "header.png") .. "]",
		"image[7.39,1.17;2.45,0.88;" .. F(menu_path .. "splash.png") .. "]",
		button(2.83, top, 5.74, "mc_local", S("Singleplayer")),
		button(2.83, top + 0.78, 5.74, "mc_server", S("Multiplayer")),
		button(2.83, footer, 2.8, "mc_options", S("Options…")),
		button(5.77, footer, 2.8, "mc_quit", S("Quit Game")),
	}
	if quick_join then
		fs[#fs + 1] = button(2.83, top + 1.56, 5.74, "mc_playtest", S("Join Playtest"))
	end
	return table.concat(fs)
end

local function server_formspec()
	return table.concat({
		dialog_header(S("Join a Server")),
		notice(S("Paste the address your host sent, including the port if provided."), 1.18),
		field(2.13, 2.23, 5.3, "mc_address", S("Server Address"), connection.address),
		field(7.58, 2.23, 1.69, "mc_port", S("Port"), connection.port),
		field(2.13, 3.45, 3.47, "mc_name", S("Player Name"), connection.name),
		field(5.8, 3.45, 3.47, "mc_password", S("Password")),
		"textarea[1.2,4.4;9,1.53;;;" ..
			F(message or S("Ask your host to invite your chosen player name. Use the exact name and password from the invite. After your first login, go to Esc → Change Password.")) .. "]",
		button(2.13, 6.14, 7.14, "mc_connect", S("Join Server")),
		button(2.13, 6.96, 3.47, "mc_browse", S("Server List…")),
		button(5.8, 6.96, 3.47, "mc_back", S("Back")),
		"set_focus[" .. connection_focus .. ";true]",
	})
end

local function refresh_nearby()
	local previous = nearby[nearby_index]
	local old, old_error = nearby, discovery_error
	nearby, discovery_error = lan.worlds()
	nearby_index = #nearby > 0 and 1 or 0
	for i, world in ipairs(nearby) do
		if previous and previous.id == world.id and previous.address == world.address and previous.port == world.port then
			nearby_index = i
		end
	end
	if old_error ~= discovery_error or #old ~= #nearby then return true end
	for i, row in ipairs(nearby) do
		local last = old[i]
		if row.id ~= last.id or row.address ~= last.address or row.port ~= last.port
				or row.world ~= last.world or row.host ~= last.host then return true end
	end
	return false
end

local function poll_nearby(retries)
	if poll_active or not notify_port or notify_port < 1 or notify_port > 65535 or not lan.available then return end
	if not core.handle_async then dofile(core.get_mainmenu_path() .. DIR_DELIM .. "async_event.lua") end
	poll_active = true
	core.handle_async(function(port)
		local http = core.get_http_api()
		if not http then return false end
		local result = http.fetch_sync({url = "http://127.0.0.1:" .. port .. "/wait", timeout = 6})
		return result and result.succeeded and result.code == 204
	end, notify_port, function(ok)
		poll_active = false
		if page ~= "multiplayer" then return end
		if ok then
			if refresh_nearby() then render() end
			poll_nearby()
		elseif (retries or 2) > 0 then
			poll_nearby((retries or 2) - 1)
		else
			refresh_nearby()
			discovery_error = discovery_error or S("Automatic refresh paused. Select Refresh to try again.")
			render()
		end
	end)
end

local function multiplayer_formspec()
	local fs = {dialog_header(S("Multiplayer")), centred(1.02, S("Worlds on your local network")),
		"box[0.65,1.67;10.1,2.61;#070709B8]",
		button(1.34, 5.0, 5.17, "mc_edit_name", lan.valid_name(player_name)
			and S("Player: ") .. player_name or S("Choose player name…")),
		button(6.75, 5.0, 3.31, "mc_refresh", S("Refresh")),
		notice(message or discovery_error, 5.87),
		button(5.83, 6.63, 4.23, "mc_host", S("Host World")),
		button(0.65, 7.41, 3.55, "mc_invite", S("Join with Invite…")),
		button(4.36, 7.41, 3.46, "mc_direct", S("Direct Connect…")),
		button(7.98, 7.41, 2.77, "mc_back", S("Back"))}
	if #nearby > 0 then
		local rows = {}
		for i, world in ipairs(nearby) do rows[i] = F(world.world .. "  ·  " .. world.host) end
		fs[#fs + 1] = ("textlist[0.83,1.8;9.74,2.32;mc_nearby;%s;%d;true]"):format(table.concat(rows, ","), nearby_index)
		fs[#fs + 1] = button(1.34, 6.63, 4.23, "mc_join_lan", S("Join World"))
	else
		fs[#fs + 1] = centred(2.32, S("No nearby worlds found"))
		fs[#fs + 1] = centred(2.97, S("Ask a friend on the same network to host a world, then refresh."))
	end
	return table.concat(fs)
end

local function select_world(index)
	local world = worlds[index]
	if not world then return end
	selected = index
	creative = Settings(world.path .. DIR_DELIM .. "world.mt"):get_bool("creative_mode", false)
	message = nil
end

local function load_worlds()
	local previous = tonumber(core.settings:get("mainmenu_last_selected_world"))
	local initial = 1
	worlds, selected, creative = {}, 0, false
	for index, world in ipairs(core.get_worlds()) do
		if is_our_world(world) then
			worlds[#worlds + 1] = world
			if index == previous then initial = #worlds end
		end
	end
	select_world(initial)
end

local function singleplayer_formspec()
	local rows = {}
	for i, world in ipairs(worlds) do
		rows[i] = F(world.name)
	end
	local fs = {
		dialog_header(hosting and S("Host World") or S("Select World")),
		"box[0.3,1;10.8,4.48;#070709B8]",
		"box[0.3,5.48;10.8,0.035;#747179]",
		notice(message or (hosting and lan.host_description(worlds[selected])), 5.64),
		button(5.77, 6.59, 4.33, "mc_new_world", S("Create New World")),
		button(7.25, 7.37, 2.85, "mc_back", S("Cancel")),
	}
	if selected == 0 then
		fs[#fs + 1] = centred(3.03, S("No saved worlds"))
		fs[#fs + 1] = "set_focus[mc_new_world;true]"
		return table.concat(fs)
	end

	fs[#fs + 1] = ("textlist[1.3,1.19;8.8,4.1;mc_worlds;%s;%d;true]"):format(table.concat(rows, ","), selected)
	fs[#fs + 1] = hosting and button(1.3, 6.59, 4.33, "mc_open_lan", S("Open to LAN"))
		or button(1.3, 6.59, 4.33, "mc_play_world", S("Play Selected World"))
	if not hosting then
		fs[#fs + 1] = button(1.3, 7.37, 4.36, "mc_change_mode",
			creative and S("Game Mode: Creative") or S("Game Mode: Survival"))
		fs[#fs + 1] = button(5.8, 7.37, 1.3, "mc_manage_worlds", S("Edit…"))
	end
	return table.concat(fs)
end

local function create_world_formspec()
	return table.concat({
		dialog_header(S("Create New World")),
		field(2.13, 1.83, 7.14, "mc_world_name", S("World Name"), new_world.name),
		button(2.13, 2.75, 7.14, "mc_new_mode",
			new_world.creative and S("Game Mode: Creative") or S("Game Mode: Survival")),
		button(2.13, 3.53, 7.14, "mc_new_type",
			new_world.flat and S("World Type: Superflat") or S("World Type: Default")),
		field(2.13, 4.75, 7.14, "mc_world_seed", S("Seed for the World Generator"), new_world.seed),
		notice(message, 5.7),
		button(2.13, 6.77, 3.93, "mc_create_world", S("Create New World")),
		button(6.2, 6.77, 3.07, "mc_back", S("Cancel")),
		"set_focus[mc_world_name;false]",
	})
end

local settings_pages = {
	mc_controls = "controls_keyboard_and_mouse",
	mc_video = "graphics_and_audio_graphics",
	mc_audio = "graphics_and_audio_audio",
	mc_accessibility = "accessibility",
}

local function options_formspec()
	return table.concat({
		dialog_header(S("Options")),
		button(2.13, 2.4, 3.5, "mc_video", S("Video Settings…")),
		button(5.77, 2.4, 3.5, "mc_audio", S("Music & Sounds…")),
		button(2.13, 3.18, 3.5, "mc_controls", S("Controls…")),
		button(5.77, 3.18, 3.5, "mc_accessibility", S("Accessibility Settings…")),
		button(2.13, 3.96, 7.14, "mc_resource_packs", S("Resource Packs…")),
		button(2.13, 6.42, 7.14, "mc_back", S("Done")),
	})
end

local function use_loading_style()
	core.set_sky_color("#19171D")
end

local function world_index(path)
	for index, world in ipairs(core.get_worlds()) do
		if is_our_world(world) and world.path == path then return index end
	end
end

local function play_world()
	local chosen = worlds[selected]
	if not chosen then return end
	local index = world_index(chosen.path)
	if not index then
		load_worlds()
		message = S("This world is no longer available.")
		render()
		return
	end

	local settings = Settings(chosen.path .. DIR_DELIM .. "world.mt")
	if not hosting and settings:get_bool("creative_mode") ~= creative then
		settings:set_bool("creative_mode", creative)
		if not settings:write() then
			message = S("Could not save this world's game mode.")
			render()
			return
		end
	end
	core.settings:set_bool("creative_mode", creative)
	core.settings:set_bool("enable_damage", settings:get_bool("enable_damage", true))
	local account
	if hosting then
		account, message = lan.host(chosen, player_name)
		if not account then render() return end
		for _, setting in ipairs({"server_announce", "bind_address", "ipv6_server", "name", "mcl_playersSleepingPercentage"}) do
			local before = core.settings:get(setting)
			if before then core.settings:set("mcl_lan_before_" .. setting, before) end
		end
		core.settings:set_bool("server_announce", false)
		core.settings:set("bind_address", os.getenv("MCL_LAN_BIND_ADDRESS") == "127.0.0.1" and "127.0.0.1" or "0.0.0.0")
		core.settings:set_bool("ipv6_server", false)
		core.settings:set("mcl_playersSleepingPercentage", "0")
	end
	core.settings:set("menu_last_game", game_id)
	core.settings:set("mainmenu_last_selected_world", tostring(index))
	if not hosting then core.settings:set("mcl_singleplayer_reset_gamemode", chosen.path) end
	core.settings:set_bool("mcl_menu_last_lan", hosting)
	core.settings:remove(last_direct_join)
	gamedata.mode = hosting and "host" or "singleplayer"
	gamedata.selected_world = index
	gamedata.address = ""
	gamedata.password = account and account.password or ""
	gamedata.playername = account and account.name or nil
	gamedata.port = account and tostring(account.port) or nil
	gamedata.allow_login_or_register = "any"
	gamedata.errormessage = nil
	use_loading_style()
	core.start()
end

local function save_mapgen_flag(world, flag)
	-- create_world only copies native mapgen settings. Keep Mineclonia's
	-- per-world flag with the other mapgen settings, before the terminator.
	local path = world.path .. DIR_DELIM .. "map_meta.txt"
	local file = io.open(path, "rb")
	if not file then return false end
	local contents = file:read("*a")
	file:close()
	local updated, count = contents:gsub("(\r?\n)(%[end_of_params%])", "%1" .. flag .. " = true%1%2", 1)
	return count == 1 and core.safe_file_write(path, updated)
end

local function create_world()
	local name = new_world.name:trim()
	if name == "" or name == "." or name == ".." or name:find('[%c/\\:*?"<>|]') then
		message = S("Enter a valid world name.")
	elseif new_world.flat and table.indexof(core.get_mapgen_names(), "flat") == -1 then
		message = S("Superflat is unavailable in this client.")
	else
		for _, world in ipairs(core.get_worlds()) do
			if world.name == name then
				message = S("A world with that name already exists.")
				render()
				return
			end
		end
		-- The engine creates the world with its usual safe path handling.
		message = core.create_world(name, game_id, {
			fixed_map_seed = new_world.seed:trim(),
			mg_name = new_world.flat and "flat" or "singlenode",
			enable_damage = "true",
			creative_mode = tostring(new_world.creative),
		})
		if not message then
			page = "singleplayer"
			load_worlds()
			for index, world in ipairs(worlds) do
				if world.name == name then
					selected = index
					local flag = new_world.flat and "mcl_superflat_classic" or "mcl_singlenode_mapgen"
					if save_mapgen_flag(world, flag) then
						creative = new_world.creative
						play_world()
					else
						message = S("Could not save the new world's terrain settings.")
						render()
					end
					return
				end
			end
			message = S("The new world could not be found.")
		end
	end
	render()
end

local function error_formspec()
	return table.concat({
		style(11.4, 8.3), centred(2.2, S("Disconnected")),
		"textarea[1.1,3.0;9.2,1.9;;;" .. F(message or "") .. "]",
		button(2.83, 5.42, 5.74, "mc_back", S("Back to Title Screen")),
		"set_focus[mc_back;true]",
	})
end

local function get_formspec()
	if page == "name" then
		return table.concat({dialog_header(S("Choose Player Name")),
			field(2.13, 2.59, 7.14, "mc_name", S("Your player name"), player_name),
			notice(message, 3.67),
			button(2.13, 5.35, 3.48, "mc_save_name", S("Continue")),
			button(5.79, 5.35, 3.48, "mc_back", S("Cancel")), "set_focus[mc_name;true]"})
	elseif page == "multiplayer" then
		return multiplayer_formspec()
	elseif page == "invite" then
		return table.concat({dialog_header(S("Join with Invite")),
			notice(S("Paste the private invite from your host."), 1.35),
			field(1.3, 2.75, 8.8, "mc_invite_text", S("Private invite")),
			notice(message, 3.67), button(1.3, 5.35, 4.25, "mc_invite_review", S("Review Invite")),
			button(5.85, 5.35, 4.25, "mc_back", S("Cancel")), "set_focus[mc_invite_text;true]"})
	elseif page == "confirm_invite" then
		return table.concat({dialog_header(S("Join this world?")),
			centred(1.52, S("Host named in the invite: ") .. pending_invite.host),
			centred(2.28, S("Your player name: ") .. pending_invite.name),
			"textarea[0.7,3;10,1.5;;;" .. F(S("Destination: ") .. pending_invite.destination) .. "]",
			notice(S("Check the destination with your host. After joining, use Esc → Change Password."), 4.6),
			button(1.3, 5.65, 4.25, "mc_invite_join", S("Join World")),
			button(5.85, 5.65, 4.25, "mc_back", S("Cancel")), "set_focus[mc_back;true]"})
	elseif page == "server" then
		return server_formspec()
	elseif page == "singleplayer" then
		return singleplayer_formspec()
	elseif page == "create" then
		return create_world_formspec()
	elseif page == "options" then
		return options_formspec()
	elseif page == "error" then
		return error_formspec()
	end
	return title_formspec()
end

render = function()
	if stock_title then
		ui.update()
	else
		core.update_formspec(get_formspec())
	end
end

local function connect(address, port, name, password, login_mode)
	gamedata.mode = "join"
	gamedata.selected_world = 0
	gamedata.address = address
	gamedata.port = port
	gamedata.playername = name
	gamedata.password = password
	gamedata.allow_login_or_register = login_mode
	gamedata.errormessage = nil
	gamedata.reconnect_requested = false
	-- The engine takes over here and reports actual connection and media progress.
	use_loading_style()
	core.start()
end

local function launch_playtest()
	local file = io.open(password_file, "r")
	local password = file and file:read("*l")
	if file then file:close() end
	if not password or password == "" then
		page = "error"
		message = S("The local playtest password file is missing or empty. Open the playtest with its launcher.")
		render()
		return
	end
	core.settings:remove(last_direct_join)
	core.settings:remove("mcl_menu_last_lan")
	connect("127.0.0.1", local_port, local_name, password, "any")
end

local function remember_server(address, port, name)
	connection.address, connection.port, connection.name = address, tostring(port), name
	core.settings:set("address", connection.address)
	core.settings:set("remote_port", connection.port)
	core.settings:set("name", connection.name)
	core.settings:set_bool(last_direct_join, true)
end

local function launch_manual(fields)
	connection.address = (fields.mc_address or ""):trim()
	connection.port = (fields.mc_port or ""):trim()
	connection.name = (fields.mc_name or ""):trim()
	local address, port_text = connection.address:match("^%[([^%]]+)%]:(.*)$")
	if not address then
		address, port_text = connection.address:match("^([^:]+):([^:]*)$")
	end
	address = address or connection.address:match("^%[([^%]]+)%]$") or connection.address
	local ipv6 = address:match("^[%x:.]+$") and address:match(":.*:")
	local port = tonumber(port_text or connection.port)
	if connection.address:find("://", 1, true) or (not ipv6 and not address:match("^[A-Za-z0-9_.%-]+$")) then
		message, connection_focus = S("Enter the server's hostname or IP address."), "mc_address"
	elseif not (port_text or connection.port):match("^%d+$") or not port or port < 1 or port > 65535 then
		message, connection_focus = S("Enter a port between 1 and 65535."), port_text and "mc_address" or "mc_port"
	else
		connection.address, connection.port = address, tostring(port)
		if #connection.name > 20 or not connection.name:match("^[A-Za-z0-9_%-]+$")
				or connection.name:lower() == "singleplayer" then
			message = S("Use your invited name. Player names use 1–20 letters, digits, hyphens or underscores.")
			connection_focus = "mc_name"
		else
			remember_server(connection.address, connection.port, connection.name)
			local login_mode = core.settings:get_bool("enable_split_login_register", true) and "login" or "any"
			connect(connection.address, port, connection.name, fields.mc_password or "", login_mode)
			return
		end
	end
	render()
end

local function set_title_background()
	core.set_topleft_text("")
	for _, layer in ipairs({"header", "footer", "overlay"}) do
		core.set_background(layer, "")
	end
	core.set_clouds(false)
	core.set_sky_color("#19171D")
	core.set_background("background", texture("mcl_menu_panorama.png", menu_path .. "overlay.png"))
end

local function go_back()
	pending_invite = nil
	if page == "create" then
		page = "singleplayer"
	elseif page == "server" or page == "name" or page == "invite" or page == "confirm_invite" or (page == "singleplayer" and hosting) then
		page, hosting = "multiplayer", false
		pending_action = nil
		refresh_nearby()
		poll_nearby()
	else
		page, hosting = "title", false
	end
	message = nil
	render()
end

local handle_title_buttons
local function title_events(event)
	if event == "MenuQuit" then
		if page == "title" then
			core.close()
		else
			go_back()
		end
		return true
	elseif event == "DialogShow" then
		mm_game_theme.stop_music()
		mm_game_theme.gameid = nil
		set_title_background()
	end
	return false
end

local function open_stock(tab, settings_page)
	core.settings:remove(last_direct_join)
	if not stock_main then
		core.settings:set("maintab_LAST", "local")
		local pending_jobs = core.async_jobs
		dofile(core.get_mainmenu_path() .. DIR_DELIM .. "init.lua")
		-- Stock initialisation creates a new async callback table. Keep the
		-- outstanding LAN wait until its callback arrives from the worker.
		for id, callback in pairs(pending_jobs or {}) do core.async_jobs[id] = callback end
		stock_main = ui.find_by_name("maintab")
		stock_title = dialog_create("mineclonia_title", get_formspec, function(_, fields)
			handle_title_buttons(fields)
			return true
		end, title_events)
		stock_main:add({
			name = "mineclonia_title",
			caption = F(S("Title")),
			cbf_formspec = function() return "" end,
			on_change = function(event)
				if event == "ENTER" then
					stock_main:hide()
					stock_title:show()
					core.settings:set("maintab_LAST", "local")
				end
			end,
		})
		-- Let stock first-run dialogs finish before replacing their parent.
		if stock_main.hidden then return end
	end
	stock_title:hide()
	stock_main:set_tab(tab)
	if settings_page then
		stock_main:hide()
		local dialog = create_settings_dlg(settings_page)
		dialog:set_parent(stock_title)
		dialog:show()
	else
		stock_main:show()
	end
	ui.update()
end

handle_title_buttons = function(fields)
	if page == "multiplayer" and fields.mc_name then player_name = fields.mc_name:trim() end
	if fields.mc_quit or (fields.try_quit and page == "title") then
		core.close()
	elseif fields.mc_back or fields.try_quit then
		go_back()
	elseif page == "title" and fields.mc_playtest and quick_join then
		launch_playtest()
	elseif page == "title" and fields.mc_server then
		page, message = "multiplayer", nil
		refresh_nearby()
		poll_nearby()
		render()
	elseif page == "name" and (fields.mc_save_name or fields.key_enter_field) then
		local name = (fields.mc_name or ""):trim()
		if lan.valid_name(name) then
			local action = pending_action
			player_name, page, message, pending_action = name, "multiplayer", nil, nil
			core.settings:set("mcl_lan_player_name", player_name)
			if action then handle_title_buttons({[action] = true}) return end
			refresh_nearby()
			poll_nearby()
		else
			message = S("Use 1–20 letters, digits, hyphens or underscores. The name singleplayer is reserved.")
		end
		render()
	elseif page == "invite" and (fields.mc_invite_review or fields.key_enter_field == "mc_invite_text") then
		pending_invite = invite.read(fields.mc_invite_text)
		if pending_invite then
			page, message = "confirm_invite", nil
		else
			message = S("Invalid invite. Paste the whole code supplied by your host.")
		end
		render()
	elseif page == "confirm_invite" and fields.mc_invite_join and pending_invite then
		local details = pending_invite
		pending_invite = nil
		remember_server(details.address, details.port, details.name)
		connect(details.address, tostring(details.port), details.name, details.password, "login")
	elseif page == "multiplayer" then
		local event = fields.mc_nearby and core.explode_textlist_event(fields.mc_nearby)
		if event and nearby[event.index] then nearby_index = event.index end
		if fields.mc_invite then
			page, message, pending_invite = "invite", nil, nil
		elseif fields.mc_edit_name then
			page, message, pending_action = "name", nil, nil
		elseif fields.mc_direct then
			page, message = "server", nil
			connection_focus = connection.address == "" and "mc_address" or connection.name == "" and "mc_name" or "mc_password"
		elseif fields.mc_refresh then
			message = nil
			refresh_nearby()
			poll_nearby()
		elseif fields.mc_host or fields.mc_join_lan or fields.key_enter_field or (event and event.type == "DCL") then
			if not lan.available then
				message = discovery_error or S("Open Play Mineclonia to use local multiplayer.")
			elseif not lan.valid_name(player_name) then
				page, message = "name", nil
				pending_action = fields.mc_host and "mc_host" or "mc_join_lan"
			else
				core.settings:set("mcl_lan_player_name", player_name)
				if fields.mc_host then
					hosting, page, message = true, "singleplayer", nil
					load_worlds()
				elseif nearby[nearby_index] then
					local choice = nearby[nearby_index]
					refresh_nearby()
					local current = nearby[nearby_index]
					if current and current.id == choice.id and current.address == choice.address and current.port == choice.port then
						core.settings:remove(last_direct_join)
						core.settings:set_bool("mcl_menu_last_lan", true)
						connect(choice.address, choice.port, player_name, lan.password(choice.id, choice.host, player_name), "any")
						return
					end
					message = S("That world is no longer available.")
				end
			end
		elseif event then return end
		render()
	elseif page == "title" and fields.mc_local then
		hosting, page, message = false, "singleplayer", nil
		load_worlds()
		render()
	elseif page == "title" and fields.mc_options then
		page, message = "options", nil
		render()
	elseif page == "options" then
		for field_name, settings_page in pairs(settings_pages) do
			if fields[field_name] then
				open_stock("local", settings_page)
				return
			end
		end
		if fields.mc_resource_packs then
			open_stock("content")
		end
	elseif page == "singleplayer" and fields.mc_worlds then
		local event = core.explode_textlist_event(fields.mc_worlds)
		if event.type == "DCL" and worlds[event.index] then
			if event.index ~= selected then select_world(event.index) end
			play_world()
		elseif event.type == "CHG" and event.index ~= selected then
			select_world(event.index)
			render()
		end
	elseif page == "singleplayer" and not hosting and fields.mc_change_mode then
		creative = not creative
		message = nil
		render()
	elseif page == "singleplayer" and (fields.mc_play_world or (hosting and fields.mc_open_lan)) then
		play_world()
	elseif page == "singleplayer" and fields.mc_manage_worlds then
		local world = worlds[selected]
		local index = world and world_index(world.path)
		if index then core.settings:set("mainmenu_last_selected_world", tostring(index)) end
		page, message = "title", nil
		core.settings:set("menu_last_game", game_id)
		open_stock("local")
	elseif page == "singleplayer" and fields.mc_new_world then
		page, message = "create", nil
		new_world = { name = S("New World"), seed = "", creative = false, flat = false }
		render()
	elseif page == "create" then
		new_world.name = fields.mc_world_name or new_world.name
		new_world.seed = fields.mc_world_seed or new_world.seed
		message = nil
		if fields.mc_create_world or fields.key_enter_field then
			create_world()
		elseif fields.mc_new_mode or fields.mc_new_type then
			if fields.mc_new_mode then new_world.creative = not new_world.creative end
			if fields.mc_new_type then new_world.flat = not new_world.flat end
			render()
		end
	elseif page == "server" and fields.mc_browse then
		page, message = "title", nil
		open_stock("online")
	elseif page == "server" and (fields.mc_connect or fields.key_enter_field) then
		launch_manual(fields)
	end
end

core.button_handler = handle_title_buttons
core.event_handler = title_events

gamedata.errormessage = nil
gamedata.reconnect_requested = false
if page == "multiplayer" then refresh_nearby() poll_nearby() end
if lan.available then
	local index = tonumber(core.settings:get("mainmenu_last_selected_world"))
	local last = index and core.get_worlds()[index]
	if last and is_our_world(last) and lan.consume_open_request(last) then
		load_worlds()
		if lan.valid_name(player_name) then
			hosting, page, message = true, "singleplayer", nil
		else
			page, message = "multiplayer", S("Choose your player name and select Host World.")
			refresh_nearby()
			poll_nearby()
		end
	end
end
set_title_background()
local packs = (core.settings:get("texture_path") or ""):split(separator)
local loading_pack = menu_path .. "loading"
if table.indexof(packs, loading_pack) < 0 then
	-- Preserve the order and priority of the player's selected texture packs.
	packs[#packs + 1] = loading_pack
	core.settings:set("texture_path", table.concat(packs, separator))
end
render()
