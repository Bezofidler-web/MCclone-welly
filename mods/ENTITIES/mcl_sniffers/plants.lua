return function (shared)
	local S = shared.translate
	local torchflower = "mcl_flowers:torchflower"
	local pitcher = "mcl_flowers:pitcher_plant"
	local torch_stages = {"mcl_sniffers:torchflower_crop_1", "mcl_sniffers:torchflower_crop_2"}
	local pitcher_stages = {}
	local plant_groups = {dig_immediate = 3, plant = 1, not_in_creative_inventory = 1, attached_node = 1,
		dig_by_water = 1, destroy_by_lava_flow = 1, dig_by_piston = 1, unsticky = 1}
	local texture = "mcl_sniffers_"

	mcl_flowers.register_simple_flower ("torchflower", {
		desc = S ("Torchflower"),
		image = texture .. "torchflower.png",
		selection_box = {-5 / 16, -0.5, -5 / 16, 5 / 16, 0.42, 5 / 16},
		potted = true,
		sus_stew = {effect = "night_vision", duration = 5},
	}, {_mcl_crafting_output = {single = {output = "mcl_dyes:orange"}}})

	mcl_flowers.add_large_plant ("pitcher_plant", {
		desc = S ("Pitcher Plant"),
		longdesc = S ("This tall flower grows from an ancient pitcher pod and can be crafted into cyan dye."),
		tiles_bottom = {texture .. "pitcher_crop_bottom_stage_4.png"},
		tiles_top = {texture .. "pitcher_crop_top_stage_4.png"},
		inv_img = texture .. "pitcher_plant.png",
		is_flower = true,
		bottom = {_mcl_crafting_output = {single = {output = "mcl_dyes:cyan 2"}}},
	})

	local function place_seed (stack, player, pointed, crop)
		if not player or not player:is_player () or not pointed or pointed.type ~= "node" then return stack end
		local name = player:get_player_name ()
		if core.is_protected (pointed.above, name) then
			core.record_protection_violation (pointed.above, name)
			return stack
		end
		return mcl_farming:place_seed (stack, player, pointed, crop) or stack
	end

	local function register_seed (name, description, image, crop)
		core.register_craftitem (name, {
			description = description,
			_tt_help = S ("Grows on farmland"),
			inventory_image = texture .. image .. ".png",
			groups = {craftitem = 1, compostability = 30},
			_mcl_places_plant = crop,
			on_place = function (stack, player, pointed) return place_seed (stack, player, pointed, crop) end,
		})
	end

	local function crop_definition (description, image, seed, height)
		return {
			description = description,
			drawtype = "plantlike",
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			tiles = {texture .. image .. ".png"},
			selection_box = {type = "fixed", fixed = {-0.37, -0.5, -0.37, 0.37, height, 0.37}},
			groups = table.copy (plant_groups),
			sounds = mcl_sounds.node_sound_leaves_defaults (),
			drop = seed,
			_mcl_hardness = 0,
			_mcl_baseitem = seed,
			_doc_items_create_entry = false,
		}
	end

	for stage, name in ipairs (torch_stages) do
		local definition = crop_definition (S ("Torchflower Crop"), "torchflower_crop_stage" .. (stage - 1),
			shared.seeds, stage == 1 and -0.1 or 0.3)
		definition._on_bone_meal = function (stack, player, pointed, pos, node)
			return mcl_farming.on_bone_meal (stack, player, pointed, pos, node, "mcl_sniffers_torchflower", 1)
		end
		core.register_node (name, definition)
	end
	mcl_farming:add_plant ("mcl_sniffers_torchflower", torchflower, torch_stages, 25, 10)
	register_seed (shared.seeds, S ("Torchflower Seeds"), "torchflower_seeds", torch_stages[1])

	local function pitcher_top (pos)
		return vector.offset (pos, 0, 1, 0)
	end

	local top_stage = "mcl_sniffers:pitcher_crop_top"
	local function advance_pitcher (pos, stage, player)
		local floor = vector.offset (pos, 0, -1, 0)
		local soil = core.get_node_or_nil (floor)
		if not soil then return false end
		if core.get_item_group (soil.name, "soil") <= 1 then
			core.dig_node (pos)
			return false
		end
		local top = pitcher_top (pos)
		local upper = core.get_node (top).name
		if stage >= 3 and upper ~= "air" and upper ~= top_stage then return false end
		if stage >= 3 and player and core.is_protected (top, player:get_player_name ()) then return false end
		if stage == 4 then
			core.swap_node (pos, {name = pitcher})
			core.swap_node (top, {name = pitcher .. "_top"})
		else
			core.swap_node (pos, {name = pitcher_stages[stage + 1]})
			if stage == 3 then core.set_node (top, {name = top_stage}) end
		end
		return true
	end

	for stage = 1, 4 do pitcher_stages[stage] = "mcl_sniffers:pitcher_crop_" .. stage end
	local pitcher_images = {"pitcher_crop_bottom", "pitcher_crop_bottom_stage_1",
		"pitcher_crop_bottom_stage_2", "pitcher_crop_bottom_stage_3"}
	for stage, name in ipairs (pitcher_stages) do
		local definition = crop_definition (S ("Pitcher Crop"), pitcher_images[stage], shared.pod, stage < 3 and -0.1 or 0.5)
		definition._on_bone_meal = function (_, player, _, pos)
			return advance_pitcher (pos, stage, player)
		end
		if stage == 4 then
			definition.after_destruct = function (pos)
				local top = pitcher_top (pos)
				if core.get_node (top).name == top_stage then core.remove_node (top) end
			end
		end
		core.register_node (name, definition)
	end
	local top_definition = crop_definition (S ("Pitcher Crop"), "pitcher_crop_top_stage_3", "", 0.5)
	top_definition.groups.attached_node = nil
	top_definition.after_destruct = function (pos)
		local bottom = vector.offset (pos, 0, -1, 0)
		if core.get_node (bottom).name == pitcher_stages[4] then core.dig_node (bottom) end
	end
	top_definition._on_bone_meal = function (_, player, _, pos)
		local bottom = vector.offset (pos, 0, -1, 0)
		if core.get_node (bottom).name ~= pitcher_stages[4] then return false end
		return advance_pitcher (bottom, 4, player)
	end
	core.register_node (top_stage, top_definition)

	core.register_abm ({
		label = "Pitcher crop growth",
		nodenames = pitcher_stages,
		interval = 25,
		chance = 12,
		action = function (pos, node)
			if (core.get_node_light (pos) or 0) >= 9 then
				local soil = core.get_node (vector.offset (pos, 0, -1, 0))
				if soil.name == "mcl_farming:soil_wet" or math.random (3) == 1 then
					advance_pitcher (pos, table.indexof (pitcher_stages, node.name))
				end
			end
		end,
	})
	register_seed (shared.pod, S ("Pitcher Pod"), "pitcher_pod", pitcher_stages[1])
end
