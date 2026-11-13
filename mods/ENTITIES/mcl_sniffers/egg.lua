return function (shared)
	local S = shared.translate
	local variants = {"", "_slightly_cracked", "_very_cracked"}
	local appearance = {"not_cracked", "slightly_cracked", "very_cracked"}
	local box = {type = "fixed", fixed = {-7 / 16, -0.5, -6 / 16, 7 / 16, 0.5, 6 / 16}}
	local image = "mcl_sniffers_sniffer_egg_item.png"

	local function start_next_stage (pos)
		local floor = core.get_node_or_nil (vector.offset (pos, 0, -1, 0))
		local seconds = floor and floor.name == "mcl_lush_caves:moss" and 200 or 400
		core.get_node_timer (pos):start (seconds + math.random (0, 299) / 20)
	end

	local function hatch (pos, stage)
		if stage < 3 then
			local node = core.get_node (pos)
			core.swap_node (pos, {name = shared.egg .. variants[stage + 1], param2 = node.param2})
			start_next_stage (pos)
			return false
		end
		local above = core.get_node_or_nil (vector.offset (pos, 0, 1, 0))
		if not above or not core.registered_nodes[above.name] or core.registered_nodes[above.name].walkable then
			core.get_node_timer (pos):start (15)
			return false
		end
		local baby = core.add_entity (vector.offset (pos, 0, -0.48, 0), shared.sniffer,
			core.serialize ({child = true, persistent = true}))
		if baby and baby:is_valid () then
			core.remove_node (pos)
		else
			core.get_node_timer (pos):start (15)
		end
		return false
	end

	for stage, suffix in ipairs (variants) do
		local name = shared.egg .. suffix
		local textures = {}
		for _, side in ipairs ({"top", "bottom", "east", "west", "north", "south"}) do
			textures[#textures + 1] = "mcl_sniffers_sniffer_egg_" .. appearance[stage] .. "_" .. side .. ".png"
		end
		core.register_node (name, {
			description = S ("Sniffer Egg"),
			_doc_items_longdesc = S ("Hatches into a baby Sniffer. It hatches in about ten minutes on a moss block and about twenty minutes elsewhere."),
			inventory_image = image,
			wield_image = image,
			drawtype = "nodebox",
			node_box = box,
			selection_box = box,
			paramtype = "light",
			paramtype2 = "facedir",
			tiles = textures,
			drop = shared.egg,
			groups = {handy = 1, deco_block = 1, not_in_creative_inventory = stage > 1 and 1 or nil},
			_mcl_baseitem = stage > 1 and shared.egg or nil,
			_mcl_hardness = 0.5,
			_mcl_blast_resistance = 0.5,
			sounds = mcl_sounds.node_sound_stone_defaults (),
			on_construct = start_next_stage,
			on_timer = function (pos) return hatch (pos, stage) end,
		})
	end
end
