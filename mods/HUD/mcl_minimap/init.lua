-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local setting = "mcl_minimap:visible"

local hidden_mode = { type = "off", label = S("Minimap hidden") }
local surface_modes = {
	hidden_mode,
	{ type = "surface", size = 64, label = S("Minimap: Nearby") },
	{ type = "surface", size = 128, label = S("Minimap: Wide") },
}

-- Reuse Luanti's HUD element and projected object markers. The engine keeps
-- them in sync with streamed mapblocks, world rotation and player visibility.
if core.hud_replace_builtin then
	core.hud_replace_builtin("minimap", {
		type = "minimap",
		position = { x = 1, y = 0 },
		alignment = { x = -1, y = 1 },
		offset = { x = -16, y = 50 },
		size = { x = 0, y = -25 },
	})
end

local function update_modes(player)
	local enabled = mcl_player.get_player_setting(player, setting, true)
	if enabled then
		player:set_minimap_modes(surface_modes, 1)
	else
		player:set_minimap_modes({hidden_mode}, 0)
	end
end

mcl_player.register_player_setting(setting, {
	type = "boolean",
	section = "HUD",
	short_desc = S("Corner minimap"),
	long_desc = S("Show a map of nearby terrain and visible players. Use the minimap key to change zoom or hide it."),
	ui_default = "true",
	on_change = update_modes,
})

core.register_on_joinplayer(update_modes)
dofile(core.get_modpath(core.get_current_modname()) .. "/full_map.lua")
