local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local OPTIONS = "mcl_player:settings_formspec"
local FORM = "mcl_friends:server_controls"
local CONFIRM = FORM .. ":confirm"
local ACCOUNTS = FORM .. ":accounts"
local ACCOUNT_CONFIRM = ACCOUNTS .. ":confirm"
local INVITATION = ACCOUNTS .. ":invite"
local OPEN = "__mcl_friends_controls"
local invite = dofile(core.get_modpath("mcl_friends") .. "/invite.lua")

local style = table.concat({
	"no_prepend[]bgcolor[;true;#10130FDD]",
	"style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]",
	"style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png^[multiply:#CDEBBF]",
	"style_type[button:pressed;bgimg=mcl_options_button_highlighted.png^[multiply:#AAC7A3;content_offset=0,1]",
	"style_type[label;textcolor=#FFFFFF]",
	"style_type[textarea;border=false;textcolor=#C7D4C5]",
	"style[stop,accept;bgimg=mcl_options_button.png^[multiply:#D3AC93]",
	"style[stop:hovered,stop:focused,accept:hovered,accept:focused;bgimg=mcl_options_button_highlighted.png^[multiply:#F3C1A8]",
})

local function button(x, y, width, key, label)
	return ("button[%g,%g;%g,0.82;%s;%s]"):format(x, y, width, key, F(label))
end

local function label(x, y, value)
	return ("label[%g,%g;%s]"):format(x, y, F(value))
end

local function section(x, y, width, height)
	return ("box[%g,%g;%g,%g;#1A201C]"):format(x, y, width, height)
end

local function status()
	local minutes = math.floor(core.get_timeofday() * 1440) % 1440
	local time = ("%02d:%02d"):format(math.floor(minutes / 60), minutes % 60)
	if not mcl_weather then return S("World time  @1", time) end
	local names = { none = S("Clear"), rain = S("Rain"), thunder = S("Thunder") }
	local weather = mcl_weather.get_weather()
	return S("World time  @1   •   @2", time, names[weather] or weather or S("Unknown weather"))
end

return function(host, accounts)
	-- Only the configured host can open the panel or execute actions.
	local function is_host(player)
		return player:get_player_name() == host
	end

	mcl_friends.is_host = is_host
	local panel
	local origin
	local account_panel
	local function show(selected, message, disconnected, focus)
		account_panel = nil
		local window = core.get_player_window_information(host)
		local portrait = window and (window.touch_controls or window.size.x < window.size.y)
		local width, height = portrait and 8.2 or 12.6, portrait and 10.9 or 7.2
		local list_width = portrait and 7.3 or 7.0
		local world_x, world_y, world_width = portrait and 0.45 or 7.65, portrait and 5.62 or 1.55, portrait and 7.3 or 4.5
		local footer_y = height - 1.2

		local guests = {}
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			if name ~= host and name ~= disconnected then
				guests[#guests + 1] = name
			end
		end
		table.sort(guests)
		local rows = {F(S("@1 (host)", host))}
		local index = 1
		for i, name in ipairs(guests) do
			rows[#rows + 1] = F(name)
			if name == selected then index = i + 1 end
		end
		panel = {guests = guests, selected = guests[index - 1]}
		local fs = {
			("formspec_version[8]size[%g,%g]"):format(width, height), style,
			"style_type[label;font_size=*1.35]",
			label(0.5, 0.58, S("Server Controls")),
			"style_type[label;font_size=*1]",
			label(0.5, 1.08, status()),
			section(0.45, 1.55, list_width, 3.85),
			label(0.72, 1.93, S("Players online (@1)", #rows)),
			("textlist[0.72,2.24;%g,1.86;players;%s;%d;false]"):format(
				list_width - 0.54, table.concat(rows, ","), index),
			button(0.72, 4.27, 2.65, "refresh", S("Refresh")),
			section(world_x, world_y, world_width, portrait and 3.65 or 3.85),
			label(world_x + 0.26, world_y + 0.38, S("World")),
			button(world_x + 0.26, world_y + 0.77, world_width - 0.52, "day", S("Set day")),
			button(world_x + 0.26, world_y + 1.68, world_width - 0.52, "night", S("Set night")),
		}
		if panel.selected then
			fs[#fs + 1] = button(list_width - 3.25, 4.27, 3.4, "kick", S("Disconnect guest…"))
		end
		if mcl_weather then
			fs[#fs + 1] = button(world_x + 0.26, world_y + 2.59, world_width - 0.52, "clear", S("Clear weather"))
		end
		fs[#fs + 1] = label(0.5, footer_y - 0.29, message or "")
		fs[#fs + 1] = button(0.45, footer_y, 1.75, "back", origin == "chat" and S("Done") or S("Back"))
		if accounts then fs[#fs + 1] = button(2.35, footer_y, 2.3, "accounts", S("Accounts…")) end
		fs[#fs + 1] = button(width - 3.3, footer_y, 2.85, "stop", S("Save and stop…"))
		fs[#fs + 1] = "set_focus[" .. (focus or "players") .. ";true]"
		core.show_formspec(host, FORM, table.concat(fs))
	end

	local function show_accounts(name, message)
		local names, is_allowed = accounts.list()
		local rows, selected = {}, 0
		for i, entry in ipairs(names) do
			rows[i] = F(is_allowed(entry) and entry or S("@1 (access removed)", entry))
			if entry == name then selected = i end
		end
		account_panel = {names = names, name = name or "", form = ACCOUNTS}
		core.show_formspec(host, ACCOUNTS, table.concat({
			"formspec_version[8]size[8.2,9.15]", style,
			"style_type[label;font_size=*1.35]", label(0.45, 0.53, S("Player Accounts")),
			"style_type[label;font_size=*1]",
			label(0.45, 1.08, S("Enter the name your friend wants to use.")),
			"textlist[0.45,1.48;7.3,2.5;account_list;", table.concat(rows, ","), ";", selected, ";false]",
			"field[0.45,4.56;7.3,0.75;account_name;", F(S("Exact player name")), ";", F(account_panel.name), "]",
			"field_close_on_enter[account_name;false]",
			button(0.45, 5.58, 3.55, "invite", S("Invite")),
			button(4.2, 5.58, 3.55, "allow", S("Allow existing account")),
			button(0.45, 6.52, 3.55, "reset", S("Reset password…")),
			button(4.2, 6.52, 3.55, "remove", S("Remove access…")),
			"textarea[0.45,7.46;7.3,0.76;;;", F(message or ""), "]",
			button(0.45, 8.08, 2.2, "back", S("Back")),
			"set_focus[account_name;true]",
		}))
	end

	local function manage_account(action, name)
		local ok, message, password = accounts.manage(host, action, name)
		if ok and password then
			account_panel.form = INVITATION
			local address = core.settings:get("mcl_friends_invite_address")
			local code = address and invite.create(address:trim(), core.settings:get("port") or 30000, host, name, password)
			if code then
				core.show_formspec(host, INVITATION, table.concat({
					"formspec_version[8]size[8.2,6.7]", style,
					label(0.45, 0.55, S("Private invite for @1", name)),
					label(0.45, 1.05, message),
					label(0.45, 1.65, S("Send this code privately. It contains the temporary login.")),
					"field[0.45,2.02;7.3,0.76;copy_invite;;", F(code), "]field_close_on_enter[copy_invite;false]",
					label(0.45, 3.15, S("Your friend can paste it in Multiplayer → Join with Invite.")),
					label(0.45, 4, S("Temporary password for Direct Connect")),
					"field[0.45,4.35;7.3,0.7;copy_password;;", F(password), "]field_close_on_enter[copy_password;false]",
					button(0.45, 5.65, 2.2, "back", S("Done")), "set_focus[copy_invite;true]",
				}))
				return
			end
			core.show_formspec(host, INVITATION, table.concat({
				"formspec_version[8]size[8.2,4.55]", style,
				label(0.45, 0.55, S("Temporary password for @1", name)),
				label(0.45, 1.05, message),
				"field[0.45,1.55;7.3,0.8;copy_password;;", F(password), "]",
				"field_close_on_enter[copy_password;false]",
				label(0.45, 2.7, address and address:trim() ~= "" and S("Invalid invite address. Share the login privately for Direct Connect.")
					or S("Send the password privately. Ask them to change it after joining.")),
				button(0.45, 3.45, 2.2, "back", S("Done")),
				"set_focus[copy_password;true]",
			}))
		else
			show_accounts(name, message)
		end
	end

	local function handle_accounts(form, fields)
		if not account_panel or account_panel.form ~= form then return true end
		local name = account_panel.name
		if form == ACCOUNT_CONFIRM then
			if fields.accept and not fields.quit and not fields.cancel then
				manage_account(account_panel.pending, name)
			elseif fields.cancel or fields.quit then
				show_accounts(name)
			end
		elseif form == INVITATION then
			if fields.back or fields.quit then show_accounts(name) end
		elseif fields.quit or fields.back then
			account_panel = nil
			show()
		elseif fields.invite or fields.allow or fields.reset or fields.remove then
			name = (fields.account_name or ""):trim()
			if fields.reset or fields.remove then
				account_panel.form = ACCOUNT_CONFIRM
				account_panel.pending = fields.reset and "reset" or "remove"
				account_panel.name = name
				local title = fields.reset and S("Reset the password for @1?", name) or S("Remove access for @1?", name)
				local detail = fields.reset and S("The player will need the new password to log in again.")
					or S("This player will be disconnected and their world progress will be kept.")
				core.show_formspec(host, ACCOUNT_CONFIRM, table.concat({
					"formspec_version[8]size[8.2,3.6]", style,
					label(0.5, 0.6, title),
					"textarea[0.45,1.12;7.3,1.05;;;", F(detail), "]",
					button(0.45, 2.48, 3.55, "cancel", S("Cancel")),
					button(4.2, 2.48, 3.55, "accept", fields.reset and S("Reset password") or S("Remove access")),
					"set_focus[cancel;true]",
				}))
			else
				account_panel.name = name
				manage_account(fields.invite and "invite" or "allow", name)
			end
		elseif fields.account_list then
			local event = core.explode_textlist_event(fields.account_list)
			if account_panel.names[event.index] then show_accounts(account_panel.names[event.index]) end
		end
		return true
	end

	local function confirm(action, target)
		panel.pending = action
		panel.target = target
		local title = action == "kick" and S("Disconnect @1?", target:get_player_name()) or S("Save and stop the server?")
		local description = action == "kick" and S("The guest can rejoin after disconnecting.")
			or (accounts and S("The world will save and all players will disconnect. Use the launcher to start it again.")
				or S("The world will save and all players will disconnect. Choose Host World to share it again."))
		core.show_formspec(host, CONFIRM, table.concat({
			"formspec_version[8]size[8.2,3.55]", style,
			section(0.25, 0.25, 7.7, 2.05),
			label(0.55, 0.72, title),
			"textarea[0.51,1.05;7.18,1.02;;;", F(description), "]",
			button(0.55, 2.53, 3.45, "cancel", S("Cancel")),
			button(4.2, 2.53, 3.45, "accept", action == "kick" and S("Disconnect") or S("Save and stop")),
			"set_focus[cancel;true]",
		}))
	end

	mcl_player.register_player_settings_button({
		field = OPEN,
		description = S("Server Controls…"),
		priority = 0,
		visible = is_host,
	})

	core.register_chatcommand("servercontrols", {
		description = S("Open the host's server controls"),
		func = function(name)
			if name ~= host or not core.get_player_by_name(name) then
				return false, S("Server Controls are available to the host.")
			end
			origin = "chat"
			show()
			return true
		end,
	})

	core.register_on_leaveplayer(function(player)
		if is_host(player) then panel, origin, account_panel = nil, nil, nil end
	end)

	core.register_on_player_receive_fields(function(player, form, fields)
		if not is_host(player) then return false end
		if form == ACCOUNTS or form == ACCOUNT_CONFIRM or form == INVITATION then
			return handle_accounts(form, fields)
		end
		if (form == OPTIONS or form == "") and fields[OPEN] and not fields.quit then
			origin = form
			show()
			return true
		end
		if (form ~= FORM and form ~= CONFIRM) or not panel or account_panel then return false end

		local selected = panel.selected
		if form == CONFIRM then
			if not panel.pending then return true end
			if fields.accept and not fields.quit and not fields.cancel then
				local action, target = panel.pending, panel.target
				panel = nil
				if action == "stop" then
					core.log("action", "[mcl_friends] " .. host .. " is saving and stopping the server.")
					core.request_shutdown(S("The host stopped the server."), false, 0)
				elseif action == "kick" then
					local name = target:get_player_name()
					local removed = name and name ~= "" and name ~= host and core.get_player_by_name(name) == target
						and core.kick_player(name, S("The host removed you from this session."))
					-- Disconnection is queued by the engine. Hide that row immediately.
					show(nil, removed and S("Guest disconnected.") or S("Guest is no longer online."), removed and name)
				end
			elseif fields.cancel or fields.quit then
				show(selected)
			end
			return true
		end
		if panel.pending then return true end

		if fields.quit then
			panel, origin = nil, nil
		elseif fields.back then
			local source = origin
			panel, origin = nil, nil
			if source == "" then
				if mcl_inventory then
					mcl_inventory.show_inventory(player)
				else
					core.show_formspec(host, "", player:get_inventory_formspec())
				end
			elseif source == OPTIONS then
				mcl_player.show_player_settings(player)
			else
				core.close_formspec(host, FORM)
			end
		elseif fields.players then
			local event = core.explode_textlist_event(fields.players)
			if event.type == "CHG" or event.type == "DCL" then
				show(panel.guests[event.index - 1])
			end
		elseif fields.refresh then
			show(selected, nil, nil, "refresh")
		elseif fields.accounts and accounts then
			show_accounts()
		elseif fields.kick and selected then
			local target = core.get_player_by_name(selected)
			if target and not is_host(target) then
				confirm("kick", target)
			else
				show(nil, S("Guest is no longer online."))
			end
		elseif fields.stop then
			confirm("stop")
		elseif fields.day or fields.night then
			core.set_timeofday(fields.day and 0.5 or 0)
			show(selected, fields.day and S("Time set to day.") or S("Time set to night."), nil, fields.day and "day" or "night")
		elseif fields.clear and mcl_weather then
			local changed = mcl_weather.change_weather("none", nil, host)
			show(selected, changed and S("Weather cleared.") or S("Weather could not be changed."), nil, "clear")
		end
		return true
	end)
end
