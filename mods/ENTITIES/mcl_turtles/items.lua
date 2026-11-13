return function (shared)
	local S = shared.translate
	local scute = shared.scute
	local shell = "mcl_turtles:turtle_helmet"
	local shell_texture = "mcl_turtles_turtle_helmet_worn.png"
	local head = mcl_armor.elements.head
	core.register_craftitem (scute, {
		description = S ("Turtle Scute"),
		_doc_items_longdesc = S ("Baby turtles drop a turtle scute when they grow up. Five scutes can be crafted into a turtle shell."),
		inventory_image = "mcl_turtles_turtle_scute.png",
	})
	core.register_tool (shell, {
		description = S ("Turtle Shell"),
		_doc_items_longdesc = S ("An equippable helmet that provides a short period of Water Breathing after entering water."),
		_doc_items_usagehelp = mcl_armor.usage,
		inventory_image = "mcl_turtles_turtle_helmet.png",
		groups = {armor = 1, armor_head = 1, combat_armor = 1, combat_armor_head = 1,
			mcl_armor_points = 2, mcl_armor_uses = 276, enchantability = 9, brewing_ingredient = 1},
		_repair_material = scute,
		_mcl_armor_element = "head",
		_mcl_armor_texture = function (_, stack)
			local texture = shell_texture
			if mcl_enchanting.is_enchanted (stack:get_name ()) then
				texture = texture .. mcl_enchanting.overlay
			end
			return texture .. stack:get_meta ():get_string ("mcl_armor:trim_overlay")
		end,
		sounds = {_mcl_armor_equip = "mcl_armor_equip_leather", _mcl_armor_unequip = "mcl_armor_unequip_leather"},
		on_place = mcl_armor.equip_on_use,
		on_secondary_use = mcl_armor.equip_on_use,
	})
	mcl_armor.trims.core_textures[shell] = shell_texture
	core.register_craft ({output = shell, recipe = head.craft (scute)})
	mcl_potions.register_awkward_brew (shell, "mcl_potions:turtle_master")

	mcl_player.register_globalstep_slow (function (player)
		if player:get_hp () <= 0 then return end
		local item = player:get_inventory ():get_stack ("armor", head.index):get_name ()
		if item ~= shell and item ~= shell .. "_enchanted" then return end
		local head_node = mcl_player.players[player].nodes.head
		if head_node == "ignore" or core.get_item_group (head_node, "water") > 0 then return end
		local effect = mcl_potions.get_effect (player, "water_breathing")
		if not effect or effect.dur - effect.timer < 9.5 then
			mcl_potions.give_effect ("water_breathing", player, 0, 10, true)
		end
	end)
end
