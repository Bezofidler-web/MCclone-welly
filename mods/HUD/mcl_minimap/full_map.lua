-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local formname = "mcl_minimap:full_map"
local enter_field = "__mcl_full_map"
local cells = 48
local steps = {1, 2, 4}
local range = 128
local map_depth = 32
local sample_start = 32
local blank = string.char(28, 42, 45, 255)
local views = {}
local last_open = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local band, rshift = bit.band, bit.rshift
local read_node = core.get_node_raw
local node_colour = mcl_maps.get_node_color
local block_size = core.MAP_BLOCKSIZE

-- Luanti has no server-side query for the displayed form. Stop live updates
-- as soon as another server form replaces this one, even before any input.
local show_formspec = core.show_formspec
function core.show_formspec(name, id, spec)
	if next(views) and ((spec ~= "" and id ~= formname) or (spec == "" and (id == "" or id == formname))) then
		local player = core.get_player_by_name(name)
		if player then views[player] = nil end
	end
	return show_formspec(name, id, spec)
end

local style = table.concat({
	"no_prepend[]bgcolor[;true;#101610EE]",
	"style_type[button;border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]",
	"style_type[button:hovered,button:focused;bgimg=mcl_options_button_highlighted.png]",
	"style_type[label;textcolor=#F1F4EC]",
	"style_type[textarea;border=false;textcolor=#D0DACC]",
})

local function sample_column(x, z, high, low)
	local y = high
	while y >= low do
		local cid, _, param2, loaded = read_node(x, y, z)
		if not loaded then
			-- Skip the rest of the unloaded mapblock. Never request map emergence.
			y = floor(y / block_size) * block_size - 1
		else
			local rgb = node_colour(cid, param2)
			if rgb and rgb ~= 0 then return rgb, y end
			y = y - 1
		end
	end
end

local function shade(rgb, difference)
	local relief = max(-32, min(32, difference * 8))
	return string.char(
		max(0, min(255, band(rshift(rgb, 16), 255) + relief)),
		max(0, min(255, band(rshift(rgb, 8), 255) + relief)),
		max(0, min(255, band(rgb, 255) + relief)),
		255
	)
end

local function sample_map(player_pos, left, top, step, dimension, data)
	local pixels, last_height = {}, {}
	local high = floor(player_pos.y) + sample_start
	local low = floor(player_pos.y) - map_depth
	while high > low and mcl_worlds.pos_to_dimension({y = high}) ~= dimension do high = high - 1 end
	while low < high and mcl_worlds.pos_to_dimension({y = low}) ~= dimension do low = low + 1 end
	data.bounds = {
		x1 = floor(max(left, player_pos.x - range) / block_size),
		x2 = floor(min(left + (cells - 1) * step, player_pos.x + range) / block_size),
		y1 = floor(low / block_size),
		y2 = floor(high / block_size),
		z1 = floor(max(top - (cells - 1) * step, player_pos.z - range) / block_size),
		z2 = floor(min(top, player_pos.z + range) / block_size),
	}

	for row = 1, cells do
		local z = top - (row - 1) * step
		for column = 1, cells do
			local x = left + (column - 1) * step
			local rgb, y
			if abs(x - player_pos.x) <= range and abs(z - player_pos.z) <= range then
				rgb, y = sample_column(x, z, high, low)
			end
			pixels[#pixels + 1] = rgb and shade(rgb, y - (last_height[column] or y)) or blank
			last_height[column] = y
		end
	end
	local png = core.encode_png(cells, cells, table.concat(pixels))
	return "[png:" .. core.encode_base64(png)
end

local function label(x, y, text)
	return ("label[%g,%g;%s]"):format(x, y, F(text))
end

local function button(x, y, width, field, text)
	return ("button[%g,%g;%g,0.8;%s;%s]"):format(x, y, width, field, F(text))
end

local function marker(x, y, image)
	return ("image[%g,%g;0.46,0.46;%s]"):format(x - 0.23, y - 0.23, F(image))
end

local function player_arrow(player)
	local angle = (floor(player:get_look_horizontal() / (math.pi / 4) + 0.5) % 8) * 45
	-- Both sprites point north before rotations.
	local sprite = angle % 90 == 0 and "mcl_maps_player_arrow.png" or "mcl_maps_player_arrow_diagonal.png"
	return sprite .. "^[transformR" .. (angle - angle % 90)
end

local function add_player_markers(fs, player, dimension, pos, map_x, map_y, side, left, top, step)
	local name = player:get_player_name()
	local span = cells * step
	local function add(other_pos, image)
		local dx = (other_pos.x - left + step / 2) / span
		local dz = (top - other_pos.z + step / 2) / span
		if dx >= 0.022 and dx <= 0.978 and dz >= 0.022 and dz <= 0.978 then
			fs[#fs + 1] = marker(map_x + dx * side, map_y + dz * side, image)
		end
	end
	for _, other in ipairs(core.get_connected_players()) do
		if other ~= player and other:get_properties().show_on_minimap then
			local other_pos = other:get_pos()
			local observers = other.get_effective_observers and other:get_effective_observers()
			if (not observers or observers[name]) and other_pos
				and mcl_worlds.pos_to_dimension(other_pos) == dimension
				and abs(pos.y - other_pos.y) <= map_depth
				and abs(pos.x - other_pos.x) <= range and abs(pos.z - other_pos.z) <= range then
				add(other_pos, "object_marker_red.png")
			end
		end
	end
	add(pos, player_arrow(player))
end

local function allowed(player)
	return player:is_player() and player:hud_get_flags().minimap
end

local function render(player, data)
	local pos = player:get_pos()
	if not pos or not allowed(player) then return false end
	local dimension = mcl_worlds.pos_to_dimension(pos)
	if data.dimension ~= dimension then
		data.dimension = dimension
		local block = vector.round(pos)
		data.home_x, data.home_z = block.x, block.z
		data.pan_x, data.pan_z = 0, 0
	end
	local step = steps[data.zoom]
	local centre_x, centre_z = data.home_x + data.pan_x, data.home_z + data.pan_z
	local left = centre_x - floor(cells / 2) * step
	local top = centre_z + (floor(cells / 2) - 1) * step
	-- Only movement that changes the sampled depth or the clipped terrain
	-- rectangle requires a fresh PNG. Marker movement and facing use the cache.
	local terrain_key = table.concat({dimension, left, top, step, floor(pos.y),
		max(0, math.ceil((pos.x - range - left) / step)),
		min(cells - 1, floor((pos.x + range - left) / step)),
		max(0, math.ceil((top - pos.z - range) / step)),
		min(cells - 1, floor((top - pos.z + range) / step))}, "/")
	if data.terrain_key ~= terrain_key then
		data.image = sample_map(pos, left, top, step, dimension, data)
		data.terrain_key = terrain_key
	end
	local window = core.get_player_window_information(player:get_player_name())
	local portrait = window and window.size.x / max(window.size.y, 1) < 1.2
	local width, height = 22, 15.35
	local map_x, map_y, side = 0.45, 1.55, 12.9
	local control_x, control_y, control_width = 14.0, 1.55, 7.5
	if portrait then
		width, height = 12.1, 18.55
		side = 10.7
		control_x, control_y, control_width = 0.45, 13.05, 11.2
	end
	local fs = {
		("formspec_version[8]size[%g,%g]padding[0.02,0.02]"):format(width, height), style,
		("box[0,0;%g,%g;#202721]"):format(width, height),
		"style_type[label;font_size=*1.25]",
		label(0.45, 0.52, S("World Map")),
		"style_type[label;font_size=*1]",
		label(0.45, 1.08, S("Centre  X @1   Z @2   ·   @3 blocks across", centre_x, centre_z, step * cells)),
		("box[%g,%g;%g,%g;#68725F]"):format(map_x - 0.045, map_y - 0.045, side + 0.09, side + 0.09),
		("image[%g,%g;%g,%g;%s]"):format(map_x, map_y, side, side, F(data.image)),
		("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;thumbsize=%d;arrows=show]")
			:format(range * 2, step * 4, step * 12, min(range, step * cells)),
		("scrollbar[%g,%g;%g,0.37;horizontal;pan_x;%d]"):format(map_x, map_y + side + 0.12, side, range + data.pan_x),
		("scrollbar[%g,%g;0.37,%g;vertical;pan_z;%d]"):format(map_x + side + 0.12, map_y, side, range - data.pan_z),
	}
	add_player_markers(fs, player, dimension, pos, map_x, map_y, side, left, top, step)
	local half = (control_width - 0.16) / 2
	local third = (control_width - 0.32) / 3
	local right = control_x + half + 0.16
	fs[#fs + 1] = button(control_x, control_y, half, "zoom_in", S("Zoom in"))
	fs[#fs + 1] = button(right, control_y, half, "zoom_out", S("Zoom out"))
	fs[#fs + 1] = button(control_x, control_y + 1, third, "west", S("West"))
	fs[#fs + 1] = button(control_x + third + 0.16, control_y + 1, third, "north", S("North"))
	fs[#fs + 1] = button(control_x + 2 * (third + 0.16), control_y + 1, third, "east", S("East"))
	fs[#fs + 1] = button(control_x, control_y + 1.91, third, "refresh", S("Refresh"))
	fs[#fs + 1] = button(control_x + third + 0.16, control_y + 1.91, third, "south", S("South"))
	fs[#fs + 1] = button(control_x + 2 * (third + 0.16), control_y + 1.91, third, "centre", S("Centre on me"))
	fs[#fs + 1] = marker(control_x + 0.24, control_y + 3.08, player_arrow(player))
	fs[#fs + 1] = label(control_x + 0.57, control_y + 3.08, S("You"))
	fs[#fs + 1] = marker(control_x + 2.07, control_y + 3.08, "object_marker_red.png")
	fs[#fs + 1] = label(control_x + 2.40, control_y + 3.08, S("Nearby players"))
	fs[#fs + 1] = ("textarea[%g,%g;%g,0.78;;;%s]"):format(control_x, control_y + 3.46, control_width,
		F(S("North is up. Blank areas have no loaded terrain at this depth.")))
	fs[#fs + 1] = button(control_x, height - 1.08, control_width, "back", data.inventory and S("Back to inventory") or S("Close map"))
	local formspec = table.concat(fs)
	data.last_render = core.get_us_time()
	if data.last_formspec ~= formspec then
		data.last_formspec = formspec
		core.show_formspec(player:get_player_name(), formname, formspec)
	end
	return true
end

local function open(player, inventory)
	if not allowed(player) then return false, S("The map is disabled on this server.") end
	local now = core.get_us_time()
	if last_open[player] and now - last_open[player] < 500000 then
		return false, S("Wait a moment before reopening the map.")
	end
	last_open[player] = now
	local data = { inventory = inventory, zoom = 2 }
	views[player] = data
	if render(player, data) then return true end
	views[player] = nil
	return false, S("Your position is not available yet.")
end

core.register_chatcommand("map", {
	description = S("Open the nearby world map"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false end
		return open(player, false)
	end,
})

local function queue_update(player, data, delay)
	if data.pending then return end
	data.pending = true
	core.after(delay, function()
		if views[player] == data then
			data.pending = nil
			if not render(player, data) then
				views[player] = nil
				core.close_formspec(player:get_player_name(), formname)
			end
		end
	end)
end

core.register_on_player_receive_fields(function(player, form, fields)
	if form == "" and fields[enter_field] and not fields.quit then
		local ok, message = open(player, true)
		if not ok then core.chat_send_player(player:get_player_name(), message) end
		return true
	end
	local data = views[player]
	if form ~= formname then
		views[player] = nil
		return false
	end
	if not data then return false end
	if fields.quit or fields.back then
		views[player] = nil
		if fields.back and data.inventory and mcl_inventory then
			mcl_inventory.show_inventory(player)
		elseif fields.back then
			core.close_formspec(player:get_player_name(), formname)
		end
		return true
	end
	if not allowed(player) then
		views[player] = nil
		core.close_formspec(player:get_player_name(), formname)
		return true
	end

	local x_event = core.explode_scrollbar_event(fields.pan_x)
	local z_event = core.explode_scrollbar_event(fields.pan_z)
	local n = steps[data.zoom] * 12
	if fields.centre then
		data.dimension = nil
	elseif fields.zoom_in then
		data.zoom = max(1, data.zoom - 1)
	elseif fields.zoom_out then
		data.zoom = min(#steps, data.zoom + 1)
	elseif fields.west then
		data.pan_x = data.pan_x - n
	elseif fields.east then
		data.pan_x = data.pan_x + n
	elseif fields.north then
		data.pan_z = data.pan_z + n
	elseif fields.south then
		data.pan_z = data.pan_z - n
	elseif x_event.type == "CHG" then
		data.pan_x = floor(x_event.value) - range
	elseif z_event.type == "CHG" then
		data.pan_z = range - floor(z_event.value)
	elseif not fields.refresh then
		return true
	end
	data.pan_x = max(-range, min(range, data.pan_x))
	data.pan_z = max(-range, min(range, data.pan_z))
	if fields.refresh then data.terrain_key = nil end
	queue_update(player, data, 0.18)
	return true
end)

local function intersects(bounds, block)
	return bounds and block.x >= bounds.x1 and block.x <= bounds.x2
		and block.y >= bounds.y1 and block.y <= bounds.y2
		and block.z >= bounds.z1 and block.z <= bounds.z2
end

local function update_edited_view(player, data)
	data.terrain_key = nil
	local elapsed = (core.get_us_time() - data.last_render) / 1000000
	queue_update(player, data, max(0.35, 0.8 - elapsed))
end

if core.register_on_mapblocks_changed then
	core.register_on_mapblocks_changed(function(modified)
		if not next(views) then return end
		for player, data in pairs(views) do
			for hash in pairs(modified) do
				if intersects(data.bounds, core.get_position_from_hash(hash)) then
					update_edited_view(player, data)
					break
				end
			end
		end
	end)
else
	-- Older servers still refresh for visible edits from other players.
	local function node_edited(pos)
		local block = {
			x = floor(pos.x / block_size),
			y = floor(pos.y / block_size),
			z = floor(pos.z / block_size),
		}
		for player, data in pairs(views) do
			if intersects(data.bounds, block) then update_edited_view(player, data) end
		end
	end
	core.register_on_placenode(node_edited)
	core.register_on_dignode(node_edited)
end

local marker_elapsed = 0
core.register_globalstep(function(dtime)
	marker_elapsed = marker_elapsed + dtime
	if marker_elapsed < 0.5 then return end
	marker_elapsed = 0
	for player, data in pairs(views) do
		if not data.pending and not render(player, data) then
			views[player] = nil
			core.close_formspec(player:get_player_name(), formname)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	views[player] = nil
	last_open[player] = nil
end)
