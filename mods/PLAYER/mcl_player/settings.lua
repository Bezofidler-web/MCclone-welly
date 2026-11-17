local S = core.get_translator(core.get_current_modname())
local D = mcl_util.get_dynamic_translator(core.get_current_modname())
local F = core.formspec_escape

local SETTINGS_PREFIX ="mcl_player_settings:"
local setting_types = { boolean = true, enum = true, slider = true }

mcl_player.registered_player_settings_buttons = {}
local player_settings_buttons = mcl_player.registered_player_settings_buttons

function mcl_player.register_player_settings_button(new_def)
	-- maintain buttons in descending def priority order
	if #player_settings_buttons == 0
		or new_def.priority <= player_settings_buttons[#player_settings_buttons].priority then
		-- insert at end
		player_settings_buttons[#player_settings_buttons+1] = new_def
	else
		-- search for insert position
		for i, def in ipairs(player_settings_buttons) do
			if def.priority < new_def.priority then
				table.insert(player_settings_buttons, i, new_def)
				break
			end
		end
	end
end

mcl_player.registered_player_settings = {}
local player_settings = mcl_player.registered_player_settings

function mcl_player.register_player_setting(name, def)
	if player_settings[name] then
		core.log("error", "[mcl_player] duplicate player setting registration for " .. name .. ": " .. debug.traceback())
	elseif not def.short_desc then
		core.log("error", "[mcl_player] player setting " .. name .. " has no description:" .. debug.traceback())
	elseif not (def.type and setting_types[def.type]) then
		core.log("error", "[mcl_player] player setting " .. name .. " has invalid type " .. tostring(def.type) .. ":" .. debug.traceback())
	elseif (def.type == "enum" or def.type == "slider") and not def.options then
		core.log("error", "[mcl_player] enum/slider player setting " .. name .. " has no options:" .. debug.traceback())
	else
		if def.type == "slider" then
			local options = {}
			for _, option in ipairs(def.options) do
				if option.min and option.max then
					for i = option.min, option.max, option.step or 1 do
						options[#options+1] = { name = tostring(i) }
					end
				else
					options[#options+1] = option
				end
			end
			def.options = options
		end
		def._translated_section = def.section and D(def.section) or S("Misc")
		def.section = def.section or "Misc"
		player_settings[name] = def
	end
end

-- TODO: settings cache

function mcl_player.get_player_setting(player, name, default)
	local def = player_settings[name]
	if not def then return nil end

	local setting = SETTINGS_PREFIX .. name
	local value = player:get_meta():get(setting)
	if value == nil then
		return default
	elseif def.type == "boolean" then
		return value == "true"
	else
		return value
	end
end

function mcl_player.set_player_setting(player, name, value)
	local def = player_settings[name]
	if not def then return end
	if value == mcl_player.get_player_setting(player, name) then return end

	local meta = player:get_meta()
	local setting = SETTINGS_PREFIX .. name
	if def.type == "boolean" then
		meta:set_string(setting, value == nil and "" or (value and "true" or "false"))
	else
		meta:set_string(setting, value == nil and "" or value)
	end

	-- report change
	if def.on_change then
		def.on_change(player, name, value)
	end
end

mcl_player.register_player_setting("mcl_player:mobile_ui", {
	type = "boolean",
	section = "Accessibility",
	short_desc = S("Touch-friendly menus"),
	long_desc = S("May enlarge elements, add additional space, and change elements, e.g. add buttons to replace the missing enter key.\nNote that currently this is only implemented for a very limited number of formspecs."),
	ui_default = "false",
})

local FORMNAME = "mcl_player:settings_formspec"
local SECTION_FORMNAME = FORMNAME .. ":section"
local SCROLL_FIELD = "__settings_scroll"
local SECTION_FIELD = "__section__"
local RESET_FIELD = "__reset__"

local section_names = {
	Graphics = S("Video Settings"),
	HUD = S("HUD Settings"),
	Inventory = S("Inventory Settings"),
	Accessibility = S("Accessibility Settings"),
}

local menu_style = table.concat({
	"no_prepend[]",
	"bgcolor[;true;#141318D8]",
	"style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]",
	"style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png]",
	"style_type[button:pressed;bgimg=mcl_options_button_highlighted.png;content_offset=0,1]",
	"style_type[label;textcolor=#FFFFFF;halign=center;valign=center]",
	"style_type[textarea;border=false;textcolor=#EFEFEF;halign=center;valign=center]",
})

local function menu_frame(width, height, title)
	return {
		("formspec_version[8]size[%g,%g]"):format(width, height),
		menu_style,
		("label[0,0.12;%g,0.76;%s]"):format(width, F(title)),
	}
end

local function get_sections()
	local sections = {}
	local named = {}
	for name, def in pairs(player_settings) do
		local section = named[def.section]
		if not section then
			section = {
				id = def.section,
				label = section_names[def.section] or def._translated_section,
				settings = {},
			}
			named[def.section] = section
			sections[#sections + 1] = section
		end
		section.settings[#section.settings + 1] = name
	end
	table.sort(sections, function(a, b)
		if a.id == "Graphics" or b.id == "Graphics" then
			return a.id == "Graphics" and b.id ~= "Graphics"
		end
		return a.id < b.id
	end)
	return sections
end

local function text_area(fs, x, y, width, height, text)
	fs[#fs + 1] = ("textarea[%g,%g;%g,%g;;;%s]"):format(x, y, width, height, F(text))
end

local function button(fs, x, y, width, height, field, text, tooltip, exit)
	fs[#fs + 1] = ("%s[%g,%g;%g,%g;%s;%s]"):format(exit and "button_exit" or "button",
		x, y, width, height, F(field), F(text))
	if tooltip then
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(F(field), F(tooltip))
	end
end

local section_pages = {}

local function use_single_column(player)
	local window = core.get_player_window_information(player:get_player_name())
	return mcl_player.get_player_setting(player, "mcl_player:mobile_ui", false)
		or (window and (window.touch_controls or window.size.x < window.size.y))
end

local function show_root(player, focus)
	section_pages[player] = nil
	local entries = {}
	for _, section in ipairs(get_sections()) do
		entries[#entries + 1] = { field = SECTION_FIELD .. section.id, label = S("@1…", section.label) }
	end
	local done_field = "__settings_close"
	local host_entry
	for _, def in ipairs(player_settings_buttons) do
		if def.field == "__mcl_inventory" then
			done_field = def.field
		elseif not def.visible or def.visible(player) then
			local entry = {
				field = def.field,
				label = def.field == "__mcl_skins" and S("Player Skin…") or def.description,
				description = def.description,
			}
			if def.field == "__mcl_friends_controls" then
				host_entry = entry
			else
				entries[#entries + 1] = entry
			end
		end
	end

	local single_column = use_single_column(player)
	local columns = single_column and 1 or 2
	local menu_width = single_column and 8.5 or 13
	local first_row = host_entry and 2.48 or 1.42
	local footer_y = first_row + math.ceil(#entries / columns) + 0.22
	local fs = menu_frame(menu_width, footer_y + 1.2, S("Options"))
	if host_entry then
		button(fs, 0.5, 1.42, menu_width - 1, 0.81, host_entry.field, S("Server Controls"),
			S("Manage players and the world"))
	end
	for i, entry in ipairs(entries) do
		local x = 0.5 + ((i - 1) % columns) * 6.15
		local y = first_row + math.floor((i - 1) / columns)
		local width = single_column and menu_width - 1 or 5.85
		button(fs, x, y, width, 0.81, entry.field, entry.label, entry.description)
	end
	local close = done_field == "__settings_close"
	button(fs, 0.5, footer_y, menu_width - 1, 0.81, done_field, close and S("Done") or S("Back to Inventory"), nil, close)
	focus = focus or (entries[1] and entries[1].field)
	if focus then
		fs[#fs + 1] = "set_focus[" .. F(focus) .. ";true]"
	end
	core.show_formspec(player:get_player_name(), FORMNAME, table.concat(fs))
end

local function setting_supported(def, protocol)
	return not def.min_protocol_version or protocol >= def.min_protocol_version
end

local function get_value(player, name, def)
	local raw_value = mcl_player.get_player_setting(player, name)
	if raw_value == nil then return def.ui_default end
	return raw_value
end

local function get_option_index(def, value)
	for i, option in ipairs(def.options) do
		if option.name == value then return i end
	end
end

local function boolean_value(value)
	return value == true or value == "true"
end

local function setting_input(fs, name, def, value, x, y, width)
	local tooltip = def.long_desc or def.short_desc
	if def.type == "boolean" then
		local state = boolean_value(value) and S("On") or S("Off")
		button(fs, x, y, width, 0.82, name, S("@1: @2", def.short_desc, state), tooltip)
		return
	end

	local selected = get_option_index(def, value) or get_option_index(def, def.ui_default) or 1
	if def.type == "enum" then
		local option = def.options[selected]
		local state = option and (option.description or option.name) or ""
		button(fs, x, y, width, 0.82, name, S("@1: @2", def.short_desc, state), tooltip)
		return
	end

	if #def.options == 0 then return end
	text_area(fs, x, y - 0.06, width, 0.49, def.short_desc)
	-- Scroll the value label and the native slider together. This avoids
	-- redrawing the form while the player is dragging the slider.
	fs[#fs + 1] = ("scroll_container[%g,%g;1.55,0.44;%s;vertical;1]"):format(
		x + width - 1.55, y + 0.48, F(name))
	fs[#fs + 1] = "style_type[textarea;font_size=*0.85]"
	for i, option in ipairs(def.options) do
		text_area(fs, 0, i, 1.55, 0.44, option.description or option.name)
	end
	fs[#fs + 1] = "scroll_container_end[]style_type[textarea;font_size=*1]"
	fs[#fs + 1] = ("scrollbaroptions[min=1;max=%d;smallstep=1;largestep=1;arrows=hide;thumbsize=1]"):format(
		#def.options)
	fs[#fs + 1] = ("scrollbar[%g,%g;%g,0.43;horizontal;%s;%d]"):format(
		x, y + 0.48, width - 1.6, F(name), selected)
	fs[#fs + 1] = ("tooltip[%g,%g;%g,0.44;%s]"):format(x, y, width, F(tooltip))
end

local function setting_control(fs, player, name, x, y, width, protocol)
	local def = player_settings[name]
	if not setting_supported(def, protocol) then
		text_area(fs, x, y, width, 1.05, S("@1 requires a newer Luanti client", def.short_desc))
		return
	end
	local has_reset = def.type == "slider" or mcl_player.get_player_setting(player, name) ~= nil
	local input_width = has_reset and width - 1.24 or width
	setting_input(fs, name, def, get_value(player, name, def), x, y, input_width)
	if has_reset then
		local reset_field = RESET_FIELD .. name
		fs[#fs + 1] = ("style[%s;font_size=*0.83]"):format(F(reset_field))
		button(fs, x + input_width + 0.12, y, 1.12, 0.82, reset_field, S("Reset"), S("Revert to default"))
	end
end

local function show_section(player, section, scroll, focus)
	local info = core.get_player_information(player:get_player_name())
	local protocol = info and info.protocol_version or 0
	local single_column = use_single_column(player)
	local menu_width = single_column and 8.5 or 13
	local content_width = menu_width - 1
	-- Leave room for the longer HUD setting labels.
	local columns = (single_column or section.id == "HUD") and 1 or 2
	local width = columns == 1 and content_width or 5.85
	local rows = math.ceil(#section.settings / columns)
	local row_height = 1.16
	local content_height = rows * row_height
	local view_height = math.min(content_height, 5)
	local scroll_max = math.ceil((content_height - view_height) * 100)
	local hint_height = section.id == "Graphics" and 0.8 or 0
	local content_y = 1.36
	local footer_y = content_y + view_height + 0.32 + hint_height
	local fs = menu_frame(menu_width, footer_y + 1.19, section.label)

	if scroll_max > 0 then
		local thumb = math.max(1, math.floor(view_height / content_height * scroll_max))
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=42;largestep=116;thumbsize=%d;arrows=hide]"):format(
			scroll_max, thumb)
		fs[#fs + 1] = ("scrollbar[%g,%g;0.34,%g;vertical;%s;%d]"):format(
			menu_width - 0.46, content_y, view_height, SCROLL_FIELD, math.max(0, math.min(scroll or 0, scroll_max)))
		fs[#fs + 1] = ("scroll_container[0.5,%g;%g,%g;%s;vertical;0.01]"):format(
			content_y, content_width, view_height, SCROLL_FIELD)
	else
		fs[#fs + 1] = ("container[0.5,%g]"):format(content_y)
	end
	for i, name in ipairs(section.settings) do
		setting_control(fs, player, name, ((i - 1) % columns) * 6.15,
			0.07 + math.floor((i - 1) / columns) * row_height, width, protocol)
	end
	fs[#fs + 1] = scroll_max > 0 and "scroll_container_end[]" or "container_end[]"

	if section.id == "Graphics" then
		fs[#fs + 1] = "style_type[textarea;font_size=*0.88;textcolor=#D7D7D7]"
		text_area(fs, 0.5, content_y + 0.08 + view_height, content_width, hint_height,
			S("Render distance and shaders are in Luanti's pause settings."))
	end
	button(fs, 0.5, footer_y, content_width, 0.81, "__settings_back", S("Back to Options"))
	if focus then
		fs[#fs + 1] = "set_focus[" .. F(focus) .. ";true]"
	end

	section_pages[player] = section
	core.show_formspec(player:get_player_name(), SECTION_FORMNAME, table.concat(fs))
end

function mcl_player.show_player_settings(player)
	if player and player:is_player() then
		show_root(player)
	end
end

core.register_on_leaveplayer(function(player)
	section_pages[player] = nil
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if fields.__mcl_player_settings then
		mcl_player.show_player_settings(player)
		return true
	end
	if formname == FORMNAME then
		for _, section in ipairs(get_sections()) do
			if fields[SECTION_FIELD .. section.id] then
				table.sort(section.settings, function(a, b)
					local title_a, title_b = player_settings[a].short_desc, player_settings[b].short_desc
					if title_a == title_b then return a < b end
					return title_a < title_b
				end)
				show_section(player, section)
				return true
			end
		end
		-- Other mods handle the registered customisation buttons.
		return false
	end

	local section = section_pages[player]
	if formname ~= SECTION_FORMNAME or not section then return false end
	if fields.quit then
		section_pages[player] = nil
		return false
	end
	if fields.__settings_back then
		show_root(player, SECTION_FIELD .. section.id)
		return true
	end

	local info = core.get_player_information(player:get_player_name())
	local protocol = info and info.protocol_version or 0
	for _, name in ipairs(section.settings) do
		local def = player_settings[name]
		if setting_supported(def, protocol) then
			local reset = fields[RESET_FIELD .. name]
			local event = fields[name]
			if reset then
				mcl_player.set_player_setting(player, name, nil)
			elseif event and def.type == "boolean" then
				mcl_player.set_player_setting(player, name, not boolean_value(get_value(player, name, def)))
			elseif event and def.type == "enum" and #def.options > 0 then
				local i = get_option_index(def, get_value(player, name, def)) or 0
				mcl_player.set_player_setting(player, name, def.options[i % #def.options + 1].name)
			elseif event and def.type == "slider" then
				local changed = core.explode_scrollbar_event(event)
				local option = def.options[changed.value]
				if changed.type == "CHG" and option then
					mcl_player.set_player_setting(player, name, option.name)
					-- The slider uses a live value label. Leave it in place.
				end
			end

			if reset or (event and def.type ~= "slider") then
				local scroll = core.explode_scrollbar_event(fields[SCROLL_FIELD]).value
				show_section(player, section, scroll, name)
				return true
			end
		end
	end
	return false
end)
