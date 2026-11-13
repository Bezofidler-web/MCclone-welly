local S = core.get_translator(core.get_current_modname())
mcl_beehives = {}
local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/hive.lua")
dofile(path .. "/bee.lua")

local function honey_harvest(pos, node, player, itemstack)
	if not player or not player:is_player() then
		return itemstack
	end
	local name = player:get_player_name()
	local wield_name = itemstack:get_name()
	local shears = core.get_item_group(wield_name, "shears") > 0
	local bottle = wield_name == "mcl_potions:glass_bottle"
	if not shears and not bottle then
		return itemstack
	end
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return itemstack
	end

	local creative = core.is_creative_enabled(name)
	local smoky = mcl_beehives.is_smoky(pos)
	mcl_beehives.initialize(pos, node)
	if bottle then
		local honey = ItemStack("mcl_honey:honey_bottle")
		if not creative and itemstack:get_count() == 1 then
			itemstack = honey
		else
			local left = player:get_inventory():add_item("main", honey)
			if not left:is_empty() then
				core.add_item(pos, left)
			end
			if not creative then itemstack:take_item() end
		end
		if smoky then awards.unlock(name, "mcl:bee_our_guest") end
	else
		core.add_item(pos, "mcl_honey:honeycomb 3")
		if not creative then
			local def = itemstack:get_definition()
			itemstack:add_wear_by_uses(mcl_util.calculate_durability(itemstack))
			if itemstack:is_empty() and def.sound and def.sound.breaks then
				core.sound_play(def.sound.breaks, {pos = player:get_pos(), gain = 0.5}, true)
			end
		end
	end
	if not smoky then mcl_beehives.disturb(pos, node, player) end
	mcl_beehives.set_honey_level(pos, node, 0)
	return mcl_util.return_itemstack_if_alive(player, itemstack)
end

local function dig_hive(pos, node, old_meta, digger)
	local player = digger and digger:is_player() and digger or nil
	local base = mcl_beehives.base_node(node.name)
	local fields = old_meta.fields or {}
	if player then
		local name = player:get_player_name()
		if core.is_creative_enabled(name) then
			local inv = player:get_inventory()
			if inv:room_for_item("main", base) and not inv:contains_item("main", base) then
				inv:add_item("main", base)
			end
			mcl_beehives.disturb(pos, node, nil, fields)
			return
		end
		local tool = player:get_wielded_item()
		if not mcl_enchanting.is_book(tool:get_name()) and mcl_enchanting.has_enchantment(tool, "silk_touch") then
			local count = mcl_beehives.silk_drop(pos, node, fields)
			if count >= 3 then awards.unlock(name, "mcl:total_beelocation") end
			return
		end
	end
	mcl_beehives.disturb(pos, node, player, fields)
	if core.get_item_group(node.name, "beehive") > 0 then
		core.add_item(pos, base)
	end
end

-- Beehive
core.register_node("mcl_beehives:beehive", {
	description = S("Beehive"),
	_doc_items_longdesc = S("Artificial bee nest."),
	tiles = {
		"mcl_beehives_beehive_end.png", "mcl_beehives_beehive_end.png",
		"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_side.png",
		"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_front.png",
	},
	paramtype2 = "facedir",
	groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 5, material_wood = 1, beehive = 1, unmovable_by_piston = 1, comparator_signal = 0},
	sounds = mcl_sounds.node_sound_wood_defaults(),
	_mcl_hardness = 0.6,
	_mcl_burntime = 15,
	drop = "",
	after_dig_node = dig_hive,
	after_place_node = mcl_beehives.after_place,
	on_timer = mcl_beehives.on_timer,
})

for l = 1, 4 do
	local name = "mcl_beehives:beehive_" .. l
	core.register_node(name, {
		description = S("Beehive"),
		_doc_items_longdesc = S("Artificial bee nest."),
		tiles = {
			"mcl_beehives_beehive_end.png", "mcl_beehives_beehive_end.png",
			"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_side.png",
			"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_front.png",
		},
		paramtype2 = "facedir",
		groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 5, material_wood = 1, not_in_creative_inventory = 1, beehive = 1, honey_level = l, unmovable_by_piston = 1, comparator_signal = l},
		sounds = mcl_sounds.node_sound_wood_defaults(),
		_mcl_hardness = 0.6,
		_mcl_baseitem = "mcl_beehives:beehive",
		drop = "",
		after_dig_node = dig_hive,
		after_place_node = mcl_beehives.after_place,
		on_timer = mcl_beehives.on_timer,
	})
end

core.register_node("mcl_beehives:beehive_5", {
	description = S("Beehive"),
	_doc_items_longdesc = S("Artificial bee nest."),
	tiles = {
		"mcl_beehives_beehive_end.png", "mcl_beehives_beehive_end.png",
		"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_side.png",
		"mcl_beehives_beehive_side.png", "mcl_beehives_beehive_front_honey.png",
	},
	paramtype2 = "facedir",
	groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 5, material_wood = 1, not_in_creative_inventory = 1, beehive = 1, honey_level = 5, comparator_signal = 5 },
	sounds = mcl_sounds.node_sound_wood_defaults(),
	_mcl_hardness = 0.6,
	_mcl_baseitem = "mcl_beehives:beehive",
	on_rightclick = honey_harvest,
	drop = "",
	after_dig_node = dig_hive,
	after_place_node = mcl_beehives.after_place,
	on_timer = mcl_beehives.on_timer,
})

-- Bee Nest
core.register_node("mcl_beehives:bee_nest", {
	description = S("Bee Nest"),
	_doc_items_longdesc = S("A naturally generating block that houses bees and a tasty treat...if you can get it."),
	tiles = {
		"mcl_beehives_bee_nest_top.png", "mcl_beehives_bee_nest_bottom.png",
		"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_side.png",
		"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_front.png",
	},
	paramtype2 = "facedir",
	groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 30, bee_nest = 1, comparator_signal = 0 },
	sounds = mcl_sounds.node_sound_wood_defaults(),
	_mcl_hardness = 0.3,
	_mcl_burntime = 15,
	drop = "",
	after_dig_node = dig_hive,
	after_place_node = mcl_beehives.after_place,
	on_timer = mcl_beehives.on_timer,
})

for i = 1, 4 do
	local name = "mcl_beehives:bee_nest_"..i
	core.register_node(name, {
		description = S("Bee Nest"),
		_doc_items_longdesc = S("A naturally generating block that houses bees and a tasty treat...if you can get it."),
		tiles = {
			"mcl_beehives_bee_nest_top.png", "mcl_beehives_bee_nest_bottom.png",
			"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_side.png",
			"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_front.png",
		},
		paramtype2 = "facedir",
		groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 30, not_in_creative_inventory = 1, bee_nest = 1, honey_level = i, comparator_signal = i },
		sounds = mcl_sounds.node_sound_wood_defaults(),
		_mcl_hardness = 0.3,
		_mcl_baseitem = "mcl_beehives:bee_nest",
		drop = "",
		after_dig_node = dig_hive,
		after_place_node = mcl_beehives.after_place,
		on_timer = mcl_beehives.on_timer,
	})
end

core.register_node("mcl_beehives:bee_nest_5", {
	description = S("Bee Nest"),
	_doc_items_longdesc = S("A naturally generating block that houses bees and a tasty treat...if you can get it."),
	tiles = {
		"mcl_beehives_bee_nest_top.png", "mcl_beehives_bee_nest_bottom.png",
		"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_side.png",
		"mcl_beehives_bee_nest_side.png", "mcl_beehives_bee_nest_front_honey.png",
	},
	paramtype2 = "facedir",
	groups = { axey = 1, deco_block = 1, flammable = 0, fire_flammability = 30, not_in_creative_inventory = 1, bee_nest = 1, honey_level = 5, comparator_signal = 5 },
	sounds = mcl_sounds.node_sound_wood_defaults(),
	_mcl_hardness = 0.3,
	_mcl_honey_level = 5,
	_mcl_baseitem = "mcl_beehives:bee_nest",
	on_rightclick = honey_harvest,
	drop = "",
	after_dig_node = dig_hive,
	after_place_node = mcl_beehives.after_place,
	on_timer = mcl_beehives.on_timer,
})

-- Crafting
core.register_craft({
	output = "mcl_beehives:beehive",
	recipe = {
		{ "group:wood", "group:wood", "group:wood" },
		{ "mcl_honey:honeycomb", "mcl_honey:honeycomb", "mcl_honey:honeycomb" },
		{ "group:wood", "group:wood", "group:wood" },
	},
})
