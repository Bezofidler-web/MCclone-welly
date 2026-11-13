-- SPDX-License-Identifier: GPL-3.0-or-later

-- Knockback, restitution, friction and drag adapted to Luanti's units.
local archetypes = {
	regular = {speed = 8, lift = 2.0, bounce = 0.50, friction = 3.0, drag = 0.22, buoyant = true},
	bouncy = {speed = 13, lift = 3.0, bounce = 0.90, friction = 3.0, drag = 0.04, buoyant = true},
	slow_bouncy = {speed = 4.5, lift = 4.8, bounce = 0.60, friction = 3.0, drag = 0.14},
	slow_flat = {speed = 3.6, lift = 2.1, bounce = 0.40, friction = 4.0, drag = 0.22},
	fast_flat = {speed = 16, lift = 1.8, bounce = 0.35, friction = 2.0, drag = 0.04},
	light = {speed = 6, lift = 3.6, bounce = 0.92, friction = 3.0, drag = 2.8, buoyant = true},
	fast_sliding = {speed = 10, lift = 1.8, bounce = 0.08, friction = 0.45, drag = 0.04},
	slow_sliding = {speed = 2.4, lift = 1.8, bounce = 0.08, friction = 0.45, drag = 0.04},
	high_resistance = {speed = 1.6, lift = 1.8, bounce = 0.20, friction = 10.0, drag = 0.04},
	sticky = {speed = 12, lift = 1.8, bounce = 0.0, friction = 20.0, drag = 0.04},
	explosive = {speed = 8, lift = 1.8, bounce = 0.50, friction = 3.0, drag = 0.58, buoyant = true},
	hot = {speed = 8, lift = 2.0, bounce = 0.50, friction = 3.0, drag = 0.22, buoyant = true},
}

local blocks = {}
local function allow (archetype, names)
	for _, name in ipairs (names) do
		blocks[name] = archetype
	end
end

allow ("explosive", {"mcl_tnt:tnt"})
allow ("hot", {"mcl_nether:magma"})
allow ("sticky", {"mcl_honey:honeycomb_block"})
allow ("high_resistance", {"mcl_nether:soul_sand", "mcl_blackstone:soul_soil"})
allow ("fast_sliding", {"mcl_core:blue_ice", "mcl_core:packed_ice", "mcl_core:snowblock"})
allow ("slow_sliding", {"mcl_core:mycelium", "mcl_mushrooms:brown_mushroom_block",
	"mcl_mushrooms:red_mushroom_block", "mcl_mushrooms:brown_mushroom_block_stem_full",
	"mcl_mushrooms:red_mushroom_block_stem_full", "mcl_nether:nether_wart_block",
	"mcl_crimson:warped_wart_block", "mcl_crimson:shroomlight"})
allow ("regular", {"mcl_mud:mud", "mcl_mud:packed_mud", "mcl_mangrove:mangrove_mud_roots",
	"mcl_core:coalblock", "mcl_core:dirt", "mcl_core:coarse_dirt", "mcl_core:dirt_with_grass",
	"mcl_core:podzol", "mcl_core:clay", "mcl_core:bone_block", "mcl_lush_caves:rooted_dirt"})
allow ("fast_flat", {"mcl_sponges:sponge", "mcl_sponges:sponge_wet", "mcl_sponges:sponge_wet_river_water", "mcl_ocean:dried_kelp_block",
	"mcl_lush_caves:moss", "mcl_pale_oak:pale_moss", "mcl_pale_oak:resin_block", "mcl_pale_oak:resin_bricks",
	"mcl_pale_oak:chiseled_resin_bricks", "mcl_farming:melon", "mcl_farming:hay_block",
	"mcl_farming:pumpkin", "mcl_farming:pumpkin_face", "mcl_farming:pumpkin_face_light",
	"mcl_frogs:ochre_froglight", "mcl_frogs:pearlescent_froglight", "mcl_frogs:verdant_froglight"})
allow ("bouncy", {"mcl_bamboo:bamboo_mosaic", "mcl_trees:tree_bamboo", "mcl_trees:stripped_bamboo"})
allow ("slow_flat", {"mcl_core:ironblock", "mcl_core:goldblock", "mcl_core:stone_with_iron",
	"mcl_core:stone_with_gold", "mcl_deepslate:deepslate_with_iron", "mcl_deepslate:deepslate_with_gold",
	"mcl_nether:netheriteblock", "mcl_nether:ancient_debris", "mcl_blackstone:nether_gold"})
allow ("slow_bouncy", {"mcl_core:stone", "mcl_core:cobble", "mcl_core:mossycobble", "mcl_core:stonebrick",
	"mcl_core:stonebrickcracked", "mcl_core:stonebrickmossy", "mcl_core:stonebrickcarved", "mcl_core:smooth_stone",
	"mcl_core:brick_block", "mcl_core:andesite", "mcl_core:andesite_smooth", "mcl_core:diorite", "mcl_core:diorite_smooth",
	"mcl_core:granite", "mcl_core:granite_smooth", "mcl_core:sandstone", "mcl_core:redsandstone",
	"mcl_core:lapisblock", "mcl_core:diamondblock", "mcl_core:emeraldblock", "mcl_core:obsidian",
	"mcl_core:crying_obsidian", "mcl_nether:netherrack", "mcl_nether:glowstone", "mcl_nether:nether_brick",
	"mcl_nether:quartz_ore", "mcl_nether:red_nether_brick", "mcl_nether:cracked_nether_brick", "mcl_nether:chiseled_nether_brick",
	"mcl_end:end_stone", "mcl_end:end_bricks", "mcl_end:purpur_block", "mcl_end:purpur_pillar",
	"mcl_amethyst:amethyst_block", "mcl_amethyst:calcite", "mcl_dripstone:dripstone_block",
	"mcl_sulfur:sulfur", "mcl_sulfur:sulfur_polished", "mcl_sulfur:sulfur_bricks", "mcl_sulfur:sulfur_chiseled",
	"mcl_sulfur:cinnabar", "mcl_sulfur:cinnabar_polished", "mcl_sulfur:cinnabar_bricks", "mcl_sulfur:cinnabar_chiseled"})

local function archetype_for (name)
	local def = core.registered_nodes[name]
	if not def or not def.walkable or (def.drawtype ~= "normal" and def.drawtype ~= "allfaces")
		or (def.groups.not_in_creative_inventory or 0) > 0 then
		return nil
	end
	if blocks[name] then return blocks[name] end
	local groups = def.groups
	if (groups.wool or 0) > 0 then return "light" end
	if (groups.wood or 0) > 0 or (groups.tree or 0) > 0 then return "bouncy" end
	if (groups.concrete_powder or 0) > 0 then return "regular" end
	if name:match ("^mcl_copper:") or name:match ("^mcl_raw_ores:raw_.*_block$") then return "slow_flat" end
	if name:match ("^mcl_ocean:.*coral_block") then return "fast_flat" end
	if name:match ("^mcl_colorblocks:") or name:match ("^mcl_deepslate:") or name:match ("^mcl_blackstone:")
		or name:match ("^mcl_core:stone_with_") or name:match ("^mcl_quartz:") then
		return "slow_bouncy"
	end
end

return archetypes, archetype_for
