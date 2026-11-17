-- SPDX-License-Identifier: GPL-3.0-or-later
-- Server results for the Java client pause menu.
local S = core.get_translator("mcl_player")
local F = core.formspec_escape
local WORLD = "mcl_player:java_pause_world"
local STATS = "mcl_player:java_pause_stats"

local names = { S("Peaceful"), S("Easy"), S("Normal"), S("Hard") }
local difficulties = { "peaceful", "easy", "normal", "hard" }

local style = "formspec_version[8]size[7.6,5.4]no_prepend[]bgcolor[;true;#00000080]"
	.. "style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]"
	.. "style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png]"
	.. "style_type[label;textcolor=#FFFFFF;halign=center;valign=center]"

local function title(text)
	return style .. "label[0,0.32;7.6,0.54;" .. F(text) .. "]"
end

local function done()
	return "button_exit[1.7,4.5;4.2,0.63;done;" .. F(S("Done")) .. "]"
end

local function show_stats(name)
	local awards_api = rawget(_G, "awards")
	if not awards_api then return false, S("Statistics are unavailable in this game.") end
	local data = awards_api.player_or_nil(name) or {}
	local function total(category)
		return data[category] and data[category].__total or 0
	end
	local lines = {
		S("Blocks mined: @1", total("dig")),
		S("Blocks placed: @1", total("place")),
		S("Items crafted: @1", total("craft")),
		S("Items eaten: @1", total("eat")),
		S("Deaths: @1", total("death")),
	}
	local form = { title(S("Statistics")) }
	for index, line in ipairs(lines) do
		form[#form + 1] = ("label[0.9,%g;%s]"):format(0.64 + 0.58 * index, F(line))
	end
	form[#form + 1] = done()
	core.show_formspec(name, STATS, table.concat(form))
	return true
end

local function may_edit_world(name)
	return core.is_singleplayer() and core.check_player_privs(name, "server")
end

local function personal_mode(name)
	return core.is_creative_enabled(name) and S("Creative") or S("Survival")
end

local function show_world(name)
	local mode = S("Personal Game Mode: @1", personal_mode(name))
	local difficulty = S("Difficulty: @1", names[mcl_vars.difficulty + 1])
	local form = { title(S("World Options")) }
	if may_edit_world(name) then
		-- An engine-level Creative world overrides per-player Survival.
		if rawget(_G, "mcl_gamemode") and not core.settings:get_bool("creative_mode") then
			form[#form + 1] = "button[0.8,1.4;6,0.65;mode;" .. F(mode) .. "]"
		else
			form[#form + 1] = "label[0.8,1.45;6,0.55;" .. F(mode) .. "]"
		end
		form[#form + 1] = "button[0.8,2.18;6,0.65;difficulty;" .. F(difficulty) .. "]"
	else
		form[#form + 1] = "label[0.8,1.45;6,0.55;" .. F(mode) .. "]"
		form[#form + 1] = "label[0.8,2.2;6,0.55;" .. F(difficulty) .. "]"
	end
	form[#form + 1] = done()
	core.show_formspec(name, WORLD, table.concat(form))
end

core.register_chatcommand("mcl_java_pause", {
	params = "statistics | world | server",
	description = S("Open a client pause submenu"),
	func = function(name, page)
		if page == "statistics" then
			return show_stats(name)
		elseif page == "world" then
			show_world(name)
			return true
		elseif page == "server" then
			local panel = core.registered_chatcommands.servercontrols
			-- The existing handler verifies the configured host.
			if panel then return panel.func(name, "") end
			return false, S("Server controls are unavailable in this world.")
		end
		return false, S("Choose statistics, world or server.")
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= WORLD then return end
	local name = player:get_player_name()
	if fields.quit or not may_edit_world(name) then return true end
	local mode_api = rawget(_G, "mcl_gamemode")
	if fields.mode and mode_api and not core.settings:get_bool("creative_mode") then
		local mode = core.is_creative_enabled(name) and "survival" or "creative"
		mode_api.set_gamemode(player, mode)
	elseif fields.difficulty then
		local next_difficulty = difficulties[(mcl_vars.difficulty + 1) % #difficulties + 1]
		core.registered_chatcommands.difficulty.func(name, next_difficulty)
	end
	show_world(name)
	return true
end)
