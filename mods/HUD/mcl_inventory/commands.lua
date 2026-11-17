local S = core.get_translator("mcl_inventory")
local F = core.formspec_escape
local FORM = "mcl_inventory:command_bar"
local OPEN = "__mcl_inventory_commands"
local INPUT = "command_text"

local sessions = {}
local submissions = {}
local suggestions = {
	"coords", "map", "players", "help", "list", "whereami", "status", "spawn", "home", "sethome", "msg",
	"gamemode", "giveme", "give", "teleport", "time", "weather", "servercontrols",
}

local function show(player, from_inventory, message, selected)
	local name = player:get_player_name()
	local names, rows = {}, {}
	local index, initial, syntax = 0, "/", ""
	for _, command in ipairs(suggestions) do
		local def = core.registered_chatcommands[command]
		local visible = command ~= "servercontrols" or (mcl_friends and mcl_friends.is_host(player))
		if visible and def and core.check_player_privs(name, def.privs) then
			names[#names + 1] = command
			rows[#rows + 1] = F("/" .. command)
			if command == selected then
				index = #names
				initial = "/" .. command .. (def.params == "" and "" or " ")
				syntax = initial .. def.params
			end
		end
	end
	sessions[name] = { from_inventory = from_inventory, commands = names }
	local window = core.get_player_window_information(name)
	local width = window and window.max_formspec_size.x - 0.2 or 12
	width = math.max(6.5, width)
	local show_run = not window or window.touch_controls
	local prompt_width = width - (show_run and 1.74 or 0.1)
	local back_width = from_inventory and 3.7 or 1.56
	local feedback = ""
	if message or syntax ~= "" then
		local text = core.colorize(message and "#FF7777" or "#FFFF55", message or syntax)
		feedback = ("box[0.1,2.34;%.3f,0.48;#000000B0]textarea[0.19,2.34;%.3f,0.48;;;%s]")
			:format(width - 0.1, width - 0.2, F(text))
	end
	local fs = table.concat({
		("formspec_version[8]size[%.3f,3.5]position[0,1]anchor[0,1]padding[0,0]"):format(width),
		"no_prepend[]bgcolor[;neither]",
		"style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]",
		"style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png]",
		"style_type[textarea;border=false;textcolor=#FFFFFF;valign=center]",
		"style_type[field;border=false;textcolor=#FFFFFF]",
		"box[0.1,0.1;4.6,2.16;#000000D8]",
		"tableoptions[background=#00000000;border=false;color=#FFFFFF;highlight=#00000040;highlight_text=#FFFF55]",
		"tablecolumns[text]",
		"table[0.1,0.1;4.6,2.16;suggestions;", table.concat(rows, ","), ";", index, "]",
		("button[%.3f,1.64;%.2f,0.62;back;%s]"):format(width - back_width - 0.1, back_width,
			F(from_inventory and S("Back to Inventory") or S("Done"))),
		feedback,
		("box[0.1,2.9;%.3f,0.49;#00000080]"):format(prompt_width),
		"set_focus[", INPUT, ";true]",
		("field[0.21,2.9;%.3f,0.49;%s;;%s]"):format(prompt_width - 0.2, INPUT, F(initial)),
		"field_close_on_enter[", INPUT, ";false]",
		"field_enter_after_edit[", INPUT, ";true]",
		show_run and ("button[%.3f,2.82;1.56,0.62;run;%s]"):format(width - 1.66, F(S("Run"))) or "",
	})
	core.show_formspec(name, FORM, fs)
end

-- Forms don't pass through the native chat rate limiter.
local function can_submit(name)
	local now = core.get_us_time()
	local limit = tonumber(core.settings:get("chat_message_limit_per_10sec")) or 8
	limit = math.max(1, math.floor(limit))
	local record = submissions[name]
	if not record or now - record.start >= 10000000 then
		record = { start = now, count = 0 }
		submissions[name] = record
	end
	if record.count >= limit then return false end
	record.count = record.count + 1
	return true
end

local function submit(player, session, value)
	local name = player:get_player_name()
	local maximum = tonumber(core.settings:get("chat_message_max_size")) or 500
	local function fail(message)
		show(player, session.from_inventory, message)
	end
	if type(value) ~= "string" or (maximum > 0 and #value > maximum) or value:find("%c") then
		return fail(S("Enter a single command within the server's chat length limit."))
	end
	value = value:trim()
	local command = value:match("^/?([%w_%-]+) ") or value:match("^/?([%w_%-]+)$")
	if not command then
		return fail(S("Enter a command, such as /help."))
	end
	local def = core.registered_chatcommands[command]
	if not def then
		return fail(S("Unknown command. Try /help."))
	end
	if command == "setpassword" or command == "clearpassword" or def.privs.password then
		return fail(S("Password commands are unavailable in this panel."))
	end
	local permitted, missing = core.check_player_privs(name, def.privs)
	if not permitted then
		table.sort(missing)
		return fail(S("Missing privileges: @1", table.concat(missing, ", ")))
	end
	if value:sub(1, 1) ~= "/" then value = "/" .. value end
	if maximum > 0 and #value > maximum then
		return fail(S("Enter a single command within the server's chat length limit."))
	end
	if not can_submit(name) then
		return fail(S("Too many commands. Wait a few seconds and try again."))
	end
	sessions[name] = nil
	core.close_formspec(name, FORM)
	-- This is the Lua entry point used by the server for chat. It includes
	-- command interception, the stock privilege check, and normal chat replies.
	local ok, handled = pcall(core.run_callbacks, core.registered_on_chat_messages, 5, name, value)
	if not ok or not handled then
		core.chat_send_player(name, S("The server could not run this command."))
	end
end

core.register_on_player_receive_fields(function(player, form, fields)
	if form == "" and fields[OPEN] and not fields.quit then
		show(player, true)
		return true
	end
	if form ~= FORM then return end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return true end
	if fields.quit then
		sessions[name] = nil
	elseif fields.back then
		sessions[name] = nil
		if session.from_inventory then
			mcl_inventory.show_inventory(player)
		else
			core.close_formspec(name, FORM)
		end
	elseif fields.run or fields.key_enter_field == INPUT then
		submit(player, session, fields[INPUT])
	elseif fields.suggestions then
		local event = core.explode_table_event(fields.suggestions)
		local selected = session.commands[event.row]
		if selected and (event.type == "CHG" or event.type == "DCL") then
			show(player, session.from_inventory, nil, selected)
		end
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	sessions[name] = nil
	submissions[name] = nil
end)

core.register_chatcommand("commandbar", {
	description = S("Open the command bar"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, S("Join the world to open the command bar.") end
		show(player, false)
		return true
	end,
})
