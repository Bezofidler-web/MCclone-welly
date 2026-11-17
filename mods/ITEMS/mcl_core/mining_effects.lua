local S = core.get_translator(core.get_current_modname())
local setting = "mcl_core:block_break_debris"
local fragment_radius = 18
local spread = vector.new(0.4, 0.4, 0.4)
local gravity = vector.new(0, -12, 0)

mcl_player.register_player_setting(setting, {
	type = "boolean",
	section = "Graphics",
	short_desc = S("Extra block debris"),
	long_desc = S("Add a burst of larger fragments to the usual mining particles."),
	ui_default = "true",
})

core.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then return end
	local def = core.registered_nodes[oldnode.name]
	if not def or def.drawtype == "airlike" then return end

	-- Use the original node so fragments keep its texture pack and palette colour.
	-- This supplements Luanti's smaller dig particles after the confirmed break.
	local fragments = {
		amount = 20,
		time = 0.05,
		node = oldnode,
		minpos = pos - spread,
		maxpos = pos + spread,
		minvel = vector.new(-1.45, 0.3, -1.45),
		maxvel = vector.new(1.45, 2.25, 1.45),
		minacc = gravity,
		maxacc = gravity,
		minexptime = 0.22,
		maxexptime = 0.52,
		minsize = 0.55,
		maxsize = 1.15,
		collisiondetection = true,
	}
	for player in mcl_util.connected_players(pos, fragment_radius) do
		if mcl_player.get_player_setting(player, setting, true) then
			fragments.playername = player:get_player_name()
			core.add_particlespawner(fragments)
		end
	end
end)
