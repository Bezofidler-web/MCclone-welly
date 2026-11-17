local S = core.get_translator(core.get_current_modname())
local SETTING = "mcl_info:coordinates"
local ROW_HEIGHT = 20
local LEFT = 5
-- Luanti reserves the top-left for its native debug text and recent chat.
local TOP = 172
local ROW_NAMES = {"xyz", "block", "facing"}
local DIRECTIONS = {
	{"south", "positive Z"},
	{"west", "negative X"},
	{"north", "negative Z"},
	{"east", "positive X"},
}
local huds = {}

local function coordinates(block)
	return S("X: @1  Y: @2  Z: @3", block.x, block.y, block.z)
end

local function debug_lines(player, pos, compact)
	-- Luanti nodes are centred at integers. Java positions start at the
	-- block corner and positive Z points south.
	local x, z = pos.x + 0.5, 0.5 - pos.z
	local y = mcl_worlds.y_to_layer(pos.y + 0.5) or pos.y + 0.5
	local yaw = (-math.deg(player:get_look_horizontal())) % 360 - 180
	local pitch = math.deg(player:get_look_vertical())
	local direction = DIRECTIONS[math.floor(yaw / 90 + 0.5) % 4 + 1]
	local facing = compact and ("Facing: %s (%.1f / %.1f)"):format(direction[1], yaw, pitch)
		or ("Facing: %s (Towards %s) (%.1f / %.1f)"):format(direction[1], direction[2], yaw, pitch)
	return {
		("XYZ: %.3f / %.5f / %.3f"):format(x, y, z),
		("Block: %d %d %d"):format(math.floor(x), math.floor(y), math.floor(z)),
		facing,
	}
end

local function add_row(player, index, text, width, height, y)
	local name = "mcl_info:coordinates:" .. ROW_NAMES[index]
	return {
		background = player:hud_add({
			type = "image",
			name = name .. ":background",
			position = {x = 0, y = 0},
			alignment = {x = 1, y = 1},
			offset = {x = LEFT, y = y},
			scale = {x = width, y = height},
			text = "[fill:1x1:#50505090",
			z_index = 8,
		}),
		label = player:hud_add({
			type = "text",
			name = name,
			position = {x = 0, y = 0},
			alignment = {x = 1, y = 1},
			offset = {x = LEFT + 2, y = y},
			text = text,
			number = 0xE0E0E0,
			style = 4,
			size = {x = 1, y = 1},
			z_index = 9,
		}),
		text = text,
		width = width,
		height = height,
		y = y,
	}
end

local function update(player)
	local hud = huds[player]
	if not mcl_player.get_player_setting(player, SETTING, true) then
		if hud then
			for _, row in ipairs(hud) do
				player:hud_remove(row.background)
				player:hud_remove(row.label)
			end
			huds[player] = nil
		end
		return
	end

	local pos = player:get_pos()
	if not pos then return end
	local window = core.get_player_window_information(player:get_player_name())
	local gui_scale = window and window.real_gui_scaling or 1
	local hud_scale = window and window.real_hud_scaling or 1
	local scale = gui_scale / hud_scale
	local width = window and window.size.x / gui_scale or math.huge
	local height = window and window.size.y / gui_scale or math.huge
	local top = math.min(TOP, math.floor(height * 0.35))
	local row_height = (ROW_HEIGHT - 1) * scale
	local lines = debug_lines(player, pos, width < 520)
	if not hud then
		hud = {}
		huds[player] = hud
	end
	for index, text in ipairs(lines) do
		local row = hud[index]
		local row_width = math.max(1, math.min(width * scale - LEFT * 2, (#text * 10 + 4) * scale))
		local y = (top + (index - 1) * ROW_HEIGHT) * scale
		if not row then
			hud[index] = add_row(player, index, text, row_width, row_height, y)
		else
			if row.text ~= text then
				player:hud_change(row.label, "text", text)
				row.text = text
			end
			if row.width ~= row_width or row.height ~= row_height then
				player:hud_change(row.background, "scale", {x = row_width, y = row_height})
				row.width = row_width
				row.height = row_height
			end
			if row.y ~= y then
				player:hud_change(row.background, "offset", {x = LEFT, y = y})
				player:hud_change(row.label, "offset", {x = LEFT + 2, y = y})
				row.y = y
			end
		end
	end
end

mcl_player.register_player_setting(SETTING, {
	type = "boolean",
	section = "HUD",
	short_desc = S("Coordinates"),
	long_desc = S("Show Java-style XYZ, block position and facing. Use /coords for server command coordinates."),
	ui_default = "true",
	on_change = update,
})

core.register_on_joinplayer(function(player)
	-- The native Java interface needs world-specific Y origins for its F3
	-- readout. This element lives outside the viewport on stock clients.
	player:hud_add({
		type = "text",
		name = "mcl_info:java_debug_bounds_v1",
		position = { x = -1, y = -1 },
		text = table.concat({
			mcl_vars.mg_overworld_min, mcl_vars.mg_overworld_min_old,
			mcl_vars.mg_nether_min, mcl_vars.mg_nether_max + 128,
			mcl_vars.mg_end_min, mcl_vars.mg_end_max,
		}, " "),
	})
	update(player)
end)
core.register_on_leaveplayer(function(player)
	huds[player] = nil
end)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.2 then return end
	elapsed = 0
	for player in mcl_util.connected_players() do
		update(player)
	end
end)

core.register_chatcommand("coords", {
	description = S("Show your current block coordinates"),
	func = function(name)
		local player = core.get_player_by_name(name)
		local pos = player and player:get_pos()
		if not pos then return false, S("Only connected players have a position.") end
		return true, coordinates(vector.round(pos))
	end,
})
