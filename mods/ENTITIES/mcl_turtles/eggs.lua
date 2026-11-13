return function (shared)
	local S = shared.translate
	local eggs = {}
	local faces = {
		{-0.1875, -0.5, -0.25, 0.0625, -0.0625, 0},
		{-0.4375, -0.5, -0.0625, -0.1875, -0.1875, 0.1875},
		{0.1875, -0.5, -0.0625, 0.375, -0.25, 0.125},
		{-0.125, -0.5, 0.0625, 0.125, -0.25, 0.3125},
	}
	local textures = {"", "_slightly_cracked", "_very_cracked"}
	local egg_item = "mcl_turtles_turtle_egg_item.png"
	local tick_interval = 5
	local time_speed = tonumber (core.settings:get ("time_speed")) or 72
	local day_rate = time_speed > 0 and time_speed / 20 or 1

	local function egg_node (count, cracks)
		return shared.egg .. (count == 1 and "" or "_" .. count) .. textures[cracks + 1]
	end

	local function change_clutch (pos, count, cracks)
		if count > 0 then
			core.swap_node (pos, {name = egg_node (count, cracks)})
		else
			core.remove_node (pos)
		end
	end

	function shared.lay_clutch (pos, count)
		core.set_node (pos, {name = egg_node (count, 0)})
	end

	local function hatch (pos, count, cracks)
		local time = core.get_timeofday ()
		-- Java's day starts at sunrise. Luanti starts its day at midnight.
		local dawn = time >= 0.1276 and time < 0.1627
		-- Scale Java random ticks to the length of this world's day.
		local chance = 1 - math.exp (-tick_interval * day_rate / 68.3 * (dawn and 1 or 0.002))
		if math.random () >= chance or not shared.is_sand (core.get_node (vector.offset (pos, 0, -1, 0))) then
			return true
		end
		if cracks < 2 then
			change_clutch (pos, count, cracks + 1)
			return true
		end
		while count > 0 do
			local box = faces[count]
			local spawn = vector.offset (pos, (box[1] + box[4]) / 2, -0.48, (box[3] + box[6]) / 2)
			local object = core.add_entity (spawn, shared.turtle,
				core.serialize ({child = true, _turtle_home = pos}))
			if not object or not object:is_valid () then return true end
			count = count - 1
			change_clutch (pos, count, cracks)
		end
		return false
	end

	local function place_egg (stack, player, pointed)
		local handled = mcl_util.call_on_rightclick (stack, player, pointed)
		if handled then return handled end
		if not player or not player:is_player () or not pointed or pointed.type ~= "node" then return stack end
		for _, pos in ipairs ({pointed.under, pointed.above}) do
			local clutch = eggs[core.get_node (pos).name]
			if clutch and clutch.count < 4 then
				local name = player:get_player_name ()
				if core.is_protected (pos, name) then
					core.record_protection_violation (pos, name)
					return stack
				end
				change_clutch (pos, clutch.count + 1, clutch.cracks)
				if not core.is_creative_enabled (name) then stack:take_item () end
				return stack
			end
		end
		return core.item_place_node (stack, player, pointed)
	end

	local function dig_egg (pos, node, digger)
		local clutch = eggs[node.name]
		local timer = core.get_node_timer (pos)
		local elapsed = timer:get_elapsed ()
		core.node_dig (pos, node, digger)
		if clutch.count > 1 and core.get_node (pos).name == "air" then
			core.set_node (pos, {name = egg_node (clutch.count - 1, clutch.cracks)})
			core.get_node_timer (pos):set (tick_interval, elapsed)
		end
	end

	for count = 1, 4 do
		local boxes = {}
		for i = 1, count do boxes[i] = faces[i] end
		for cracks = 0, 2 do
			local name = egg_node (count, cracks)
			eggs[name] = {count = count, cracks = cracks}
			core.register_node (name, {
				description = S ("Turtle Egg"),
				_doc_items_longdesc = S ("Turtle eggs hatch on sand, usually just before sunrise. They can be moved using Silk Touch."),
				drawtype = "mesh",
				mesh = "mcl_turtles_eggs_" .. count .. ".obj",
				tiles = {"mcl_turtles_turtle_egg" .. textures[cracks + 1] .. ".png"},
				inventory_image = egg_item,
				wield_image = egg_item,
				paramtype = "light",
				sunlight_propagates = true,
				selection_box = {type = "fixed", fixed = boxes},
				collision_box = {type = "fixed", fixed = boxes},
				groups = {handy = 1, deco_block = 1, turtle_egg = 1, dig_by_piston = 1,
					not_in_creative_inventory = name ~= shared.egg and 1 or nil},
				drop = "",
				_mcl_baseitem = name ~= shared.egg and shared.egg or nil,
				_mcl_silk_touch_drop = {shared.egg},
				_mcl_hardness = 0.5,
				_mcl_blast_resistance = 0.5,
				sounds = mcl_sounds.node_sound_stone_defaults (),
				on_construct = function (pos) core.get_node_timer (pos):start (tick_interval) end,
				on_timer = function (pos) return hatch (pos, count, cracks) end,
				on_place = place_egg,
				on_dig = dig_egg,
			})
		end
	end

	local previous_step = {}
	core.register_on_leaveplayer (function (player) previous_step[player] = nil end)
	mcl_player.register_globalstep_slow (function (player)
		if player:get_hp () <= 0 then return end
		local feet = vector.round (vector.offset (player:get_pos (), 0, -0.15, 0))
		local last = previous_step[player]
		previous_step[player] = feet
		if not last or vector.equals (last, feet) or player:get_player_control ().sneak then return end
		local clutch = eggs[core.get_node (feet).name]
		if not clutch or core.is_protected (feet, player:get_player_name ()) then return end
		local chance = last.y > feet.y and 3 or 100
		if math.random (chance) == 1 then change_clutch (feet, clutch.count - 1, clutch.cracks) end
	end)
end
