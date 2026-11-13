-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_nautilus")
local breath = "breath_of_the_nautilus"

local function current_mount (player)
	local object = player:get_attach ()
	local entity = object and object:get_luaentity ()
	if entity and entity._nautilus and entity.driver == player and not entity.dead and not entity.removed then
		return entity
	end
end

mcl_potions.register_effect ({
	name = breath,
	description = S ("Breath of the Nautilus"),
	icon = "mcl_nautilus_breath_of_the_nautilus.png",
	get_tt = function () return S ("Pauses oxygen consumption underwater") end,
	on_start = function (player)
		local mount = player:is_player () and current_mount (player)
		if mount and not mount._rider_breath then mount._rider_breath = player:get_breath () end
	end,
	on_step = function (_, player)
		local mount = player:is_player () and current_mount (player)
		if not mount then return end
		local current = player:get_breath ()
		local previous = mount._rider_breath or current
		if current < previous then
			local max_breath = player:get_properties ().breath_max
			current = math.min (previous, max_breath)
			player:set_breath (current)
		end
		mount._rider_breath = current
	end,
})

-- Players who mounted with no oxygen still retain zero oxygen and are safe from drowning.
mcl_damage.register_modifier (function (player, _, reason)
	if reason.type == "drown" and player:is_player () and current_mount (player) then return 0 end
end, -80)

return breath
