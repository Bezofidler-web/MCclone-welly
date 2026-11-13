-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_nautilus")
local armor = {}
local materials = {
	{"copper", "copper", S ("Copper Nautilus Armor"), 4, 0},
	{"iron", "iron", S ("Iron Nautilus Armor"), 5, 0},
	{"golden", "gold", S ("Golden Nautilus Armor"), 7, 0},
	{"diamond", "diamond", S ("Diamond Nautilus Armor"), 11, 2},
	{"netherite", "netherite", S ("Netherite Nautilus Armor"), 19, 3, 0.1},
}

for _, data in ipairs (materials) do
	local name, layer, description, points, toughness, knockback = unpack (data)
	local id = "mcl_nautilus:" .. name .. "_nautilus_armor"
	armor[id] = {points = points, toughness = toughness, knockback = knockback or 0,
		     texture = "mcl_nautilus_armor_" .. layer .. ".png"}
	core.register_craftitem (id, {
		description = description,
		_doc_items_usagehelp = S ("Use it on a tamed Nautilus to equip it."),
		inventory_image = "mcl_nautilus_" .. name .. "_nautilus_armor.png",
		stack_max = 1,
		groups = {nautilus_armor = 1, fire_immune = name == "netherite" and 1 or nil},
		_mcl_upgradable = name == "diamond" and true or nil,
	})
end

return armor
