return function (shared)
	local S = shared.translate
	local colors = {
		{"ochre", S ("Ochre Froglight")},
		{"verdant", S ("Verdant Froglight")},
		{"pearlescent", S ("Pearlescent Froglight")},
	}
	for _, entry in ipairs (colors) do
		local stem = entry[1] .. "_froglight"
		local top = "mcl_frogs_" .. stem .. "_top.png"
		core.register_node ("mcl_frogs:" .. stem, {
			description = entry[2],
			tiles = {top, top, "mcl_frogs_" .. stem .. "_side.png"},
			paramtype = "light",
			paramtype2 = "facedir",
			light_source = core.LIGHT_MAX,
			on_place = mcl_util.rotate_axis,
			groups = {handy = 1, building_block = 1, solid = 1, opaque = 1},
			sounds = mcl_sounds.node_sound_wood_defaults (),
			_mcl_hardness = 0.3,
			_mcl_blast_resistance = 0.3,
		})
	end

	function shared.is_source_water (node)
		local def = core.registered_nodes[node.name]
		return def and def.liquidtype == "source" and core.get_item_group (node.name, "water") > 0
	end

	local function hatch (pos)
		local water = vector.offset (pos, 0, -1, 0)
		local below = core.get_node_or_nil (water)
		if not below or below.name == "ignore" then return true end
		if not shared.is_source_water (below) then
			core.remove_node (pos)
			return false
		end
		local meta = core.get_meta (pos)
		local left = meta:get_int ("tadpoles_left")
		if left == 0 then left = math.random (2, 5) end
		while left > 0 do
			local spawn = vector.offset (water, math.random () * 0.5 - 0.25, 0, math.random () * 0.5 - 0.25)
			local tadpole = core.add_entity (spawn, shared.tadpole)
			if not tadpole or not tadpole:is_valid () then
				meta:set_int ("tadpoles_left", left)
				return true
			end
			left = left - 1
		end
		core.remove_node (pos)
		return false
	end

	core.register_node (shared.spawn, {
		description = S ("Frogspawn"),
		_doc_items_longdesc = S ("Frog eggs hatch into tadpoles on the surface of still water."),
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = {-0.5, -0.48, -0.5, 0.5, -0.458, 0.5}},
		tiles = {"mcl_frogs_frogspawn.png"},
		inventory_image = "mcl_frogs_frogspawn.png",
		wield_image = "mcl_frogs_frogspawn.png",
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		drop = "",
		_mcl_silk_touch_drop = false,
		_mcl_hardness = 0,
		_mcl_blast_resistance = 0,
		groups = {dig_immediate = 3, deco_block = 1, dig_by_water = 1, destroy_by_lava_flow = 1,
			dig_by_piston = 1, floating_node = 3},
		on_construct = function (pos)
			core.get_node_timer (pos):start (math.random (3600, 11999) / 20)
		end,
		on_place = function (stack, placer, pointed)
			local result = mcl_util.call_on_rightclick (stack, placer, pointed)
			if result then return result end
			if placer and pointed.type == "node" and pointed.above.y == pointed.under.y + 1
				and shared.is_source_water (core.get_node (pointed.under))
				and core.get_node (pointed.above).name == "air" then
				local name = placer:get_player_name ()
				if core.is_protected (pointed.above, name) then
					core.record_protection_violation (pointed.above, name)
					return stack
				end
				core.set_node (pointed.above, {name = shared.spawn})
				if not core.is_creative_enabled (name) then stack:take_item () end
			end
			return stack
		end,
		pointabilities = {nodes = {["group:water"] = true}},
		on_timer = hatch,
	})
end
