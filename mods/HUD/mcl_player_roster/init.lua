local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local FORM = "mcl_player_roster:online"
local OPEN = "__mcl_online_players"
local opened = {}

local style = table.concat({
	"formspec_version[8]size[8.4,7]no_prepend[]",
	"bgcolor[;true;#101410C4]",
	"box[0,0;8.4,7;#202620]",
	"box[0,0;8.4,1.02;#151B16]",
	"box[0,1.02;8.4,0.035;#65735E]",
	"style_type[label;textcolor=#F2F5EF]",
	"style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]",
	"style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png]",
})

local function describe(player, name, viewer)
	local host = mcl_friends and mcl_friends.is_host(player)
	if player == viewer then
		return host and S("@1 (you, host)", name) or S("@1 (you)", name)
	end
	return host and S("@1 (host)", name) or name
end

local function show(viewer)
	local viewer_name = viewer:get_player_name()
	local others = {}
	for _, player in ipairs(core.get_connected_players()) do
		if player ~= viewer then
			local observers = player.get_effective_observers and player:get_effective_observers()
			if not observers or observers[viewer_name] then
				local name = player:get_player_name()
				others[#others + 1] = {name = name, label = describe(player, name, viewer)}
			end
		end
	end
	table.sort(others, function(a, b) return a.name < b.name end)

	local rows = {F(describe(viewer, viewer_name, viewer))}
	for _, entry in ipairs(others) do
		rows[#rows + 1] = F(entry.label)
	end
	core.show_formspec(viewer_name, FORM, table.concat({
		style,
		"style_type[label;font_size=*1.25]",
		"label[0.45,0.52;", F(S("Online Players")), "]",
		"style_type[label;font_size=*1]",
		"label[0.45,1.45;", F(S("@1 online", #rows)), "]",
		"textlist[0.45,1.86;7.5,3.66;names;", table.concat(rows, ","), ";0;false]",
		"button[0.45,6.02;3.65,0.76;back;", F(opened[viewer] == "inventory" and S("Back to Inventory") or S("Done")), "]",
		"button[4.3,6.02;3.65,0.76;refresh;", F(S("Refresh")), "]",
		"set_focus[refresh;true]",
	}))
end

core.register_chatcommand("players", {
	description = S("Open the online player list"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, S("This command opens an in-game menu.") end
		opened[player] = "chat"
		show(player)
		return true
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "" and fields[OPEN] and not fields.quit then
		opened[player] = "inventory"
		show(player)
		return true
	end
	if formname ~= FORM then return false end
	local origin = opened[player]
	if not origin then return true end

	if fields.quit then
		opened[player] = nil
	elseif fields.back then
		opened[player] = nil
		if origin == "inventory" then
			mcl_inventory.show_inventory(player)
		else
			core.close_formspec(player:get_player_name(), FORM)
		end
	elseif fields.refresh then
		show(player)
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	opened[player] = nil
end)
