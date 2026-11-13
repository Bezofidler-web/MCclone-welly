-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator(core.get_current_modname())
local dried_ghast = "mcl_happy_ghast:dried_ghast"
local empty_bucket = "mcl_buckets:bucket_empty"
local hydration_time = 300
local last_stage = 3

local waters = {
	{
		source = "mcl_core:water_source",
		bucket = "mcl_buckets:bucket_water",
		suffix = "_waterlogged",
		texture = "default_water_source_animated.png",
	},
	{
		source = "mclx_core:river_water_source",
		bucket = "mcl_buckets:bucket_river_water",
		suffix = "_river_waterlogged",
		texture = "default_river_water_source_animated.png",
	},
}
local water_by_source, water_by_bucket = {}, {}
for _, water in ipairs(waters) do
	water_by_source[water.source] = water
	water_by_bucket[water.bucket] = water
end

local function state_name(stage, water)
	if water then
		return dried_ghast .. water.suffix .. "_" .. stage
	end
	return stage == 0 and dried_ghast or dried_ghast .. "_" .. stage
end

local function change_state(pos, stage, water)
	local node = core.get_node(pos)
	node.name = state_name(stage, water)
	core.swap_node(pos, node)
	local timer = core.get_node_timer(pos)
	if stage > 0 or water then
		timer:start(hydration_time)
	else
		timer:stop()
	end
end

local function show_hydration(pos, growing)
	if core.global_exists("mcl_sculk") and mcl_sculk.emit_vibration then
		mcl_sculk.emit_vibration(pos, "block_change", nil, nil, 11)
	end
	if growing then
		core.add_particlespawner({
			amount = 14, time = 0.25,
			minpos = vector.offset(pos, -0.28, -0.13, -0.28),
			maxpos = vector.offset(pos, 0.28, 0.38, 0.28),
			minvel = vector.new(-0.07, 0.11, -0.07),
			maxvel = vector.new(0.07, 0.24, 0.07),
			minexptime = 0.6, maxexptime = 1.8,
			minsize = 0.8, maxsize = 1.8,
			texture = "mcl_particles_bonemeal.png^[colorize:#52b75c:125",
		})
	end
end

local function on_timer(pos, stage, water)
	if not water then
		change_state(pos, stage - 1)
		show_hydration(pos, false)
		return false
	end
	if stage < last_stage then
		change_state(pos, stage + 1, water)
		show_hydration(pos, true)
		return false
	end

	local old_node = core.get_node(pos)
	core.get_node_timer(pos):stop()
	core.set_node(pos, { name = water.source })
	if not mcl_mobs.spawn_child(vector.offset(pos, 0, 0.15, 0), "mobs_mc:happy_ghast") then
		core.set_node(pos, old_node)
		core.get_node_timer(pos):start(10)
	else
		show_hydration(pos, true)
	end
	return false
end

local function exchange_bucket(itemstack, player, output)
	if core.is_creative_enabled(player:get_player_name()) then
		return itemstack
	end
	if itemstack:get_count() == 1 then
		return ItemStack(output)
	end
	itemstack:take_item()
	local leftover = player:get_inventory():add_item("main", output)
	if not leftover:is_empty() then
		core.add_item(player:get_pos(), leftover)
	end
	return itemstack
end

local function can_waterlog(pos)
	return mcl_worlds.pos_to_dimension(pos) ~= "nether"
end

local function protected(pos, player)
	local name = player:get_player_name()
	if not core.is_protected(pos, name) then
		return false
	end
	core.record_protection_violation(pos, name)
	return true
end

local function fill_water(stage, itemstack, player, pointed)
	local water = water_by_bucket[itemstack:get_name()]
	local pos = pointed.under
	if not water or protected(pos, player) then
		return itemstack
	end
	if not can_waterlog(pos) then
		-- Match the regular water bucket's evaporation behaviour in the Nether.
		core.sound_play("fire_extinguish_flame", { pos = pos, gain = 0.4 }, true)
		return exchange_bucket(itemstack, player, empty_bucket)
	end
	change_state(pos, stage, water)
	return exchange_bucket(itemstack, player, empty_bucket)
end

local function drain_water(stage, water, itemstack, player, pointed)
	local pos = pointed.under
	if protected(pos, player) then
		return itemstack
	end
	change_state(pos, stage)
	return exchange_bucket(itemstack, player, water.bucket)
end

local function place_dried_ghast(itemstack, player, pointed)
	if not pointed or pointed.type ~= "node" then
		return itemstack
	end
	local rightclick = mcl_util.call_on_rightclick(itemstack, player, pointed)
	if rightclick then
		return rightclick
	end
	local under = core.get_node(pointed.under)
	local under_def = core.registered_nodes[under.name]
	local target = under_def and under_def.buildable_to and pointed.under or pointed.above
	local water = water_by_source[core.get_node(target).name]
	local remaining, placed_pos = core.item_place_node(itemstack, player, pointed)
	if placed_pos and water and can_waterlog(placed_pos) then
		change_state(placed_pos, 0, water)
	end
	return remaining
end

local function water_tile(water)
	return {
		name = water.texture .. "^[opacity:137",
		animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 5 },
	}
end

local function stage_tiles(stage, water)
	local prefix = "mcl_happy_ghast_dried_ghast_hydration_" .. stage .. "_"
	local function atlas(first, second)
		return "[combine:32x16:0,0=" .. prefix .. first .. ".png:16,0=" .. prefix .. second .. ".png"
	end
	return {
		prefix .. "top.png",
		"[combine:64x32:0,0=" .. prefix .. "bottom.png:16,0=" .. prefix .. "tentacles.png",
		atlas("east", "west"),
		prefix .. "north.png",
		prefix .. "south.png",
		water and water_tile(water) or nil,
	}
end

local bounds = { type = "fixed", fixed = { -5/16, -0.5, -5/16, 5/16, 2/16, 5/16 } }

local function register_stage(stage, water)
	local base = stage == 0 and not water
	local groups = { handy = 1, deco_block = 1, dig_by_piston = 1 }
	if not base then
		groups.not_in_creative_inventory = 1
	end
	if water then
		groups.water = 4
		groups.liquid = 3
		groups.puts_out_fire = 1
		groups.dig_by_piston = 0
	end
	core.register_node(state_name(stage, water), {
		description = S("Dried Ghast"),
		_doc_items_longdesc = S("Waterlog this block with a water bucket or place it in a water source. It gradually rehydrates and hatches into a Ghastling."),
		_doc_items_create_entry = base,
		drawtype = "mesh",
		mesh = water and "mcl_happy_ghast_dried_ghast_waterlogged.obj" or "mcl_happy_ghast_dried_ghast.obj",
		tiles = stage_tiles(stage, water),
		use_texture_alpha = water and "blend" or "clip",
		paramtype = "light",
		paramtype2 = "4dir",
		is_ground_content = false,
		groups = groups,
		drop = dried_ghast,
		sounds = mcl_sounds.node_sound_stone_defaults(),
		_mcl_hardness = 1,
		_mcl_blast_resistance = 1,
		node_placement_prediction = "",
		selection_box = bounds,
		collision_box = bounds,
		pointabilities = base and { nodes = { ["group:water"] = true } } or nil,
		on_place = base and place_dried_ghast or nil,
		on_construct = (stage > 0 or water) and function(pos)
			core.get_node_timer(pos):start(hydration_time)
		end or nil,
		on_timer = (stage > 0 or water) and function(pos)
			return on_timer(pos, stage, water)
		end or nil,
		_on_bucket_place = not water and function(itemstack, player, pointed)
			return fill_water(stage, itemstack, player, pointed)
		end or nil,
		_on_bucket_place_empty = water and function(itemstack, player, pointed)
			return drain_water(stage, water, itemstack, player, pointed)
		end or nil,
		on_destruct = (stage > 0 or water) and function(pos)
			core.get_node_timer(pos):stop()
		end or nil,
		after_dig_node = water and function(pos)
			if core.get_node(pos).name == "air" then
				core.set_node(pos, { name = water.source })
			end
		end or nil,
	})
end

for stage = 0, last_stage do
	register_stage(stage)
	for _, water in ipairs(waters) do
		register_stage(stage, water)
	end
end

local tear = "mcl_mobitems:ghast_tear"
core.register_craft({
	output = dried_ghast,
	recipe = {
		{ tear, tear, tear },
		{ tear, "mcl_nether:soul_sand", tear },
		{ tear, tear, tear },
	},
})
