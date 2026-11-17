local S = core.get_translator(core.get_current_modname())

local function get_fpos(placer, pointed_thing)
	local finepos = core.pointed_thing_to_face_pos(placer, pointed_thing)
	return finepos.y % 1 or 0
end

local function	on_rotate(pos, node, _, mode, _)
	-- Flip trapdoor vertically
	if mode == screwdriver.ROTATE_AXIS then
		local minor = node.param2
		if node.param2 >= 20 then
			minor = node.param2 - 20
			if minor == 3 then minor = 1 elseif minor == 1 then minor = 3 end

			node.param2 = minor
		else
			if minor == 3 then minor = 1 elseif minor == 1 then minor = 3 end

			node.param2 = minor
			node.param2 = node.param2 + 20
		end
		core.set_node(pos, node)

		return true
	end
end

function mcl_doors:register_trapdoor(name, def)
	local groups = table.copy(def.groups)
	if groups == nil then groups = {} end

	local sound_open_family = def._java_sound_family or (not def.sound_open and "wooden_trapdoor")
	local sound_close_family = def._java_sound_family or (not def.sound_close and "wooden_trapdoor")

	local function set_open(pos, node, opening)
		local node_def = core.registered_nodes[node.name]
		local next_node = opening and node_def._mcl_trapdoor_open_name or nil
		local family = sound_open_family
		local sound = def.sound_open or "doors_door_open"
		if not opening then
			next_node = node_def._mcl_trapdoor_closed_name
			family = sound_close_family
			sound = def.sound_close or "doors_door_close"
		end
		if not next_node then return end

		node.name = next_node
		core.swap_node(pos, node)
		mcl_redstone._notify_observer_neighbours(pos)
		local event = family and ("block." .. family .. (opening and ".open" or ".close")) or nil
		mcl_sounds.play_door_event(pos, event, sound, 0.3)
	end

	local function toggle(pos, node)
		set_open(pos, node, core.get_item_group(node.name, "trapdoor") == 1)
	end

	local function on_redstone_update(pos)
		local meta = core.get_meta(pos)
		local previous_power = meta:get_int("redstone_power")
		local power = mcl_redstone.get_power(pos)

		if (power ~= 0) ~= (previous_power ~= 0) then
			set_open(pos, core.get_node(pos), power ~= 0)
		end

		meta:set_int("redstone_power", power)
	end

	local on_rightclick
	if not def.only_redstone_can_open then
		on_rightclick = toggle
	end

	-- Default help texts
	local longdesc, usagehelp, tt_help
	longdesc = def._doc_items_longdesc
	usagehelp = def._doc_items_usagehelp

	if not longdesc then
		if def.only_redstone_can_open then
			longdesc = S("Trapdoors are horizontal barriers which can be opened or closed and climbed like a ladder when open. They occupy the upper or lower part of a block, depending on how they have been placed. This trapdoor can only be opened or closed by redstone power.")
		else
			longdesc = S("Trapdoors are horizontal barriers which can be opened or closed and climbed like a ladder when open. They occupy the upper or lower part of a block, depending on how they have been placed. This trapdoor can be opened or closed by hand or redstone power.")
		end
	end

	if not usagehelp and not def.only_redstone_can_open then
		usagehelp = S("To open or close this trapdoor, rightclick it or send a redstone signal to it.")
	end

	if def.only_redstone_can_open then
        tt_help = S("Openable by redstone power")
    else
        tt_help = S("Openable by players and redstone power")
    end
	-- Closed trapdoor
	local tile_front = def.tile_front
	local tile_side = def.tile_side

	if not tile_side then tile_side = tile_front end

	local tiles_closed = {
		tile_front,
		tile_front .. "^[transformFY",
		tile_side, tile_side,
		tile_side, tile_side,
	}

	local groups_closed = groups
	groups_closed.trapdoor = 1
	groups_closed.deco_block = 1

	local tpl_trapdoor = {
		_mcl_blast_resistance = def._mcl_blast_resistance,
		_mcl_hardness = def._mcl_hardness,
		_on_wind_charge_hit = function(pos)
			if not def.only_redstone_can_open then toggle(pos, core.get_node(pos)) end
			return true
		end,
		_pathfinding_class = "TRAPDOOR",
		drawtype = "nodebox",
		is_ground_content = false,
		on_rightclick = on_rightclick,
		on_rotate = on_rotate,
		paramtype = "light",
		paramtype2 = "facedir",
		sounds = def.sounds,
		sunlight_propagates = true,
		use_texture_alpha = "clip"
	}

	core.register_node(":"..name, table.merge(tpl_trapdoor, {
		_doc_items_longdesc = longdesc,
		_doc_items_usagehelp = usagehelp,
		_mcl_burntime = def._mcl_burntime,
		_mcl_redstone = {
			init = function() end,
			update = on_redstone_update,
		},
		_mcl_trapdoor_open_name = name.."_open",
		_tt_help = tt_help,
		description = def.description,
		groups = groups_closed,
		inventory_image = def.inventory_image,
		node_box = {
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, -0.3125, 0.5}
			},
			type = "fixed"
		},
		on_place = function(itemstack, placer, pointed_thing)
			if not placer or not placer:is_player() then return itemstack end

			local p0 = pointed_thing.under
			local p1 = pointed_thing.above
			local param2 = 0

			local placer_pos = placer:get_pos()
			if placer_pos then param2 = core.dir_to_facedir(vector.subtract(p1, placer_pos)) end

			local fpos = get_fpos(placer, pointed_thing)

			if p0.y - 1 == p1.y or (fpos > 0 and fpos < 0.5)
			or (fpos < -0.5 and fpos > -0.999999999) then
				param2 = param2 + 20

				if param2 == 21 then param2 = 23 elseif param2 == 23 then param2 = 21 end
			end

			return core.item_place(itemstack, placer, pointed_thing, param2)
		end,
		tiles = tiles_closed,
		wield_image = def.wield_image
	}))
	-- Open trapdoor
	local groups_open = table.copy(groups)

	local tiles_open = {
		tile_side,
		tile_side .. "^[transformR180",
		tile_side .. "^[transformR270",
		tile_side .. "^[transformR90",
		tile_front .. "^[transform46",
		tile_front .. "^[transformFY",
	}

	groups_open.trapdoor = 2
	groups_open.not_in_creative_inventory = 1

	core.register_node(":"..name.."_open", table.merge(tpl_trapdoor, {
		_mcl_baseitem = name,
		_mcl_redstone = {
			init = function() end,
			update = on_redstone_update
		},
		_mcl_trapdoor_closed_name = name,
		-- TODO: Implement Minecraft behaviour: Climbable if directly above
		-- ladder w/ matching orientation.
		-- Current behavour: Always climbable
		climbable = true,
		drop = name,
		groups = groups_open,
		node_box = {
			fixed = {-0.5, -0.5, 0.3125, 0.5, 0.5, 0.5},
			type = "fixed"
		},
		tiles = tiles_open
	}))

	doc.add_entry_alias("nodes", name, "nodes", name.."_open")
end
