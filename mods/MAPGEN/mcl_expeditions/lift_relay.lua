-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local V, offset = vector.new, vector.offset
local brick = "mcl_core:stonebrick"
local lift_floor = "mcl_core:stonebrickcarved"
local ladder = "mcl_core:ladder"
local beam = "mcl_trees:tree_spruce"
local lantern = "mcl_lanterns:lantern_floor"
local lift_panel = "mcl_expeditions:lift_panel"
local lift_form = "mcl_expeditions:lift_controls"
local levels = {
	{y = 0, name = S("Surface")},
	{y = -9, name = S("Workshop")},
	{y = -20, name = S("Deep quarry")},
}
local floor_heights = {}
for _, stop in ipairs(levels) do floor_heights[stop.y - 1] = true end
local open_lifts = {}

local function panel_position(origin, level)
	return offset(origin, 1, levels[level].y, 0)
end

local function lift_address(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name ~= lift_panel then return end
	local meta = core.get_meta(pos)
	local origin = core.string_to_pos(meta:get_string("shaft_origin"))
	local level = meta:get_int("shaft_level")
	if origin and levels[level] and vector.equals(pos, panel_position(origin, level)) then
		return origin, level
	end
end

local function repaired_lift(origin)
	local panel = panel_position(origin, 1)
	local address = lift_address(panel)
	if address and vector.equals(address, origin) then return core.get_meta(panel) end
end

core.register_node(lift_panel, {
	description = S("Mine Lift Panel"),
	tiles = {"default_steel_block.png", "default_steel_block.png",
		"default_steel_block.png^mcl_copper_block_bulb_off.png"},
	groups = {pickaxey = 1, not_in_creative_inventory = 1},
	_mcl_hardness = 3,
	is_ground_content = false,
	drop = "",
	on_rightclick = function(pos, _, player, stack)
		if not player or not player:is_player() then return stack end
		local name = player:get_player_name()
		local origin, level = lift_address(pos)
		local controller = origin and repaired_lift(origin)
		if not controller then
			core.chat_send_player(name, S("The lift has lost its surface controller. Use the emergency ladder."))
			return stack
		end
		if controller:get_int("repaired") ~= 1 then
			if level ~= 1 or stack:get_name() ~= "mcl_core:iron_ingot" or stack:get_count() < 4 then
				core.chat_send_player(name, S("Use four iron ingots on the surface panel to repair this lift."))
				return stack
			end
			if core.is_protected(pos, name) then
				core.record_protection_violation(pos, name)
				return stack
			end
			controller:set_int("repaired", 1)
			if not core.is_creative_enabled(name) then stack:take_item(4) end
			core.chat_send_player(name, S("Lift repaired. Use a panel and choose a stop."))
			return stack
		end
		open_lifts[name] = pos
		local escape = core.formspec_escape
		local form = {"formspec_version[4]size[7,5.5]",
			"label[0.5,0.5;", escape(S("Mine lift")), "]",
			"label[0.5,1.15;", escape(S("Current stop: @1", levels[level].name)), "]"}
		for i, stop in ipairs(levels) do
			form[#form + 1] = ("button_exit[0.5,%.2f;6,0.75;stop%d;%s]")
				:format(1.4 + i * 0.95, i, escape(stop.name))
		end
		core.show_formspec(name, lift_form, table.concat(form))
		return stack
	end,
})

local function usable_landing(origin, level)
	local destination = offset(origin, 0, levels[level].y, 0)
	local feet = core.get_node_or_nil(destination)
	local head = core.get_node_or_nil(offset(destination, 0, 1, 0))
	local floor = core.get_node_or_nil(offset(destination, 0, -1, 0))
	local address = lift_address(panel_position(origin, level))
	return address and vector.equals(origin, address) and feet and feet.name == "air"
		and head and head.name == "air" and floor and floor.name == lift_floor and destination
end

core.register_on_player_receive_fields(function(player, form, fields)
	if form ~= lift_form then return end
	local name = player:get_player_name()
	local panel = open_lifts[name]
	open_lifts[name] = nil
	if not panel or not core.check_player_privs(name, {interact = true}) or player:get_attach()
		or vector.distance(player:get_pos(), panel) > 4 then return true end
	local origin, source = lift_address(panel)
	local controller = origin and repaired_lift(origin)
	if not controller or controller:get_int("repaired") ~= 1 then return true end
	for level in ipairs(levels) do
		if fields["stop" .. level] and level ~= source then
			local destination = usable_landing(origin, level)
			if not destination then
				core.chat_send_player(name, S("That lift landing is blocked or unavailable."))
				return true
			end
			local lo, hi = math.min(levels[source].y, levels[level].y), math.max(levels[source].y, levels[level].y)
			for y = lo, hi do
				local position = offset(origin, 0, y, 0)
				local node = core.get_node_or_nil(position)
				if not node or (node.name ~= "air" and (not floor_heights[y] or node.name ~= lift_floor)) then
					core.chat_send_player(name, S("The lift shaft is blocked or unavailable."))
					return true
				end
				if core.is_protected(position, name) then
					core.chat_send_player(name, S("Part of the lift shaft is protected."))
					return true
				end
			end
			local intended_panel = panel_position(origin, level)
			if core.is_protected(panel, name) or core.is_protected(intended_panel, name)
				or core.is_protected(offset(destination, 0, 1, 0), name) then
				core.chat_send_player(name, S("That lift landing is protected."))
				return true
			end
			for occupant in core.objects_inside_radius(destination, 0.8) do
				if occupant ~= player and occupant:is_player() then
					core.chat_send_player(name, S("Someone is already on that lift landing."))
					return true
				end
			end
			player:set_pos(destination)
			return true
		end
	end
	return true
end)

core.register_on_leaveplayer(function(player) open_lifts[player:get_player_name()] = nil end)

mcl_expeditions.register("abandoned_lift_mine", {
	title = S("Abandoned Lift Mine"),
	environment = "land",
	biomes = {"Forest", "BirchForest", "Taiga", "Plains", "Savannah", "Meadow", "StonyPeaks",
		"WindsweptHills", "WindsweptGravellyHills"},
	bounds = {min = V(-9, -23, -7), max = V(9, 7, 9)},
	build = function(ctx)
		ctx:fill(-2,-23,-2,5,-1,2,brick)
		ctx:fill(-1,-20,-1,1,-1,1,"air")
		ctx:fill(3,-20,-1,4,-1,0,"air")
		local wall = core.dir_to_wallmounted(V(0,0,1))
		ctx:fill(4,-20,0,4,-1,0,ladder,wall)

		-- Each landing joins the main lift to a separate ladder shaft.
		for i, stop in ipairs(levels) do
			local y = stop.y
			ctx:fill(-1,y-1,-1,1,y-1,1,brick)
			ctx:fill(-1,y-1,-1,4,y-1,-1,brick)
			ctx:fill(2,y,-1,4,y+2,-1,"air")
			ctx:set(0,y-1,0,lift_floor)
			ctx:set(1,y,0,lift_panel)
			local pos = panel_position(ctx.pos, i)
			ctx:after(function()
				local meta = core.get_meta(pos)
				meta:set_string("shaft_origin", core.pos_to_string(ctx.pos))
				meta:set_int("shaft_level", i)
				meta:set_string("infotext", S("Mine lift — @1", stop.name))
			end)
		end

		-- Surface engine house with a rear emergency ladder.
		ctx:fill(-7,-2,-6,7,-1,4,brick)
		ctx:fill(-6,0,-5,6,5,3,"air")
		ctx:fill(-6,0,-5,-6,3,3,brick)
		ctx:fill(6,0,-5,6,3,3,brick)
		ctx:fill(-6,0,3,6,3,3,brick)
		ctx:fill(-6,0,-5,6,3,-5,brick)
		ctx:fill(-2,0,-5,0,2,-5,"air")
		for _, x in ipairs({-6,6}) do
			ctx:fill(x,0,-5,x,4,-5,beam)
			ctx:fill(x,0,3,x,4,3,beam)
		end
		ctx:fill(-7,4,-6,7,4,4,"mcl_trees:wood_spruce")
		ctx:fill(-4,5,-5,4,5,3,"mcl_trees:wood_spruce")
		ctx:fill(-2,6,-5,2,6,3,"mcl_trees:wood_spruce")
		ctx:fill(4,-2,0,4,-1,0,ladder,wall)
		ctx:set(1,0,0,lift_panel)
		ctx:set(0,-1,0,lift_floor)
		ctx:set(0,-2,0,"air")
		ctx:set(5,0,0,brick)
		ctx:set(4,0,1,brick)
		ctx:sign(5,0,-1,S("Emergency ladder\nAll three stops"))
		ctx:sign(2,0,1,S("Abandoned lift\nRepair: 4 iron"))
		ctx:set(-4,0,0,lantern)
		ctx:chest(-4,0,-3,{"mcl_core:iron_ingot 4","mcl_torches:torch 12","mcl_farming:bread 3"})

		-- A side workshop and a lower quarry give each stop a reason to visit.
		ctx:fill(-9,-11,-4,-2,-4,4,brick)
		ctx:fill(-8,-9,-3,-2,-5,3,"air")
		ctx:fill(-3,-9,-1,-1,-7,1,"air")
		ctx:fill(-3,-10,-1,-1,-10,1,brick)
		ctx:set(-6,-9,-2,"mcl_core:stone_with_coal")
		ctx:set(-7,-9,-2,"mcl_core:stone_with_iron")
		ctx:set(-8,-9,-3,lantern)
		ctx:set(-6,-9,2,"mcl_crafting_table:crafting_table")
		ctx:chest(-7,-9,2,{"mcl_tools:pick_iron","mcl_core:coal_lump 6","mcl_torches:torch 6"})

		ctx:fill(-6,-23,2,6,-15,9,brick)
		ctx:fill(-5,-20,2,5,-16,8,"air")
		ctx:fill(-1,-20,1,1,-17,3,"air")
		ctx:fill(-1,-21,1,1,-21,3,brick)
		for _, x in ipairs({-5,5}) do
			ctx:fill(x,-20,6,x,-16,6,beam)
			ctx:set(x,-20,4,lantern)
		end
		for x = -3, 3 do
			local ore = ctx.pr:next(1,3) == 1 and "mcl_core:stone_with_gold" or "mcl_core:stone_with_iron"
			ctx:set(x,-20,8,ore)
		end
		ctx:chest(3,-20,7,{"mcl_core:gold_ingot 4","mcl_core:iron_ingot 4","mcl_redstone:redstone 6"})
	end,
})

local relay_off = "mcl_expeditions:relay_beacon"
local relay_on = "mcl_expeditions:relay_beacon_lit"
local relay_signal = "mcl_expeditions:relay_signal"
local storage = core.get_mod_storage()
local active_relays = {}

for key in pairs(storage:to_table().fields) do
	local serialized = key:match("^active_relay/(.+)$")
	local pos = serialized and core.string_to_pos(serialized)
	if pos then active_relays[key] = pos end
end

local function relay_key(pos)
	return "active_relay/" .. core.pos_to_string(pos)
end

local function tell_relay_route(pos, player)
	local nearest, distance = nil, math.huge
	local dimension = mcl_worlds.pos_to_dimension(pos)
	for _, other in pairs(active_relays) do
		if not vector.equals(pos, other) and mcl_worlds.pos_to_dimension(other) == dimension then
			local node = core.get_node_or_nil(other)
			local d = vector.distance(pos, other)
			if (not node or node.name == "ignore" or node.name == relay_on) and d < distance then
				nearest, distance = other, d
			end
		end
	end
	if not nearest then
		core.chat_send_player(player, S("Relay active. Restore another tower in this dimension to mark a route."))
		return
	end
	local dx, dz = nearest.x - pos.x, nearest.z - pos.z
	local heading = math.abs(dx) > math.abs(dz) and (dx > 0 and S("east") or S("west"))
		or (dz > 0 and S("north") or S("south"))
	core.chat_send_player(player, S("Next lit relay: @1, @2 blocks @3. Watch for gaps between islands.",
		core.pos_to_string(nearest), math.floor(distance + 0.5), heading))
end

local relay_base = {
	tiles = {"mcl_end_purpur_block.png^[colorize:#294451:105"},
	groups = {pickaxey = 1, not_in_creative_inventory = 1},
	_mcl_hardness = 3,
	is_ground_content = false,
	drop = "",
}

core.register_node(relay_signal, {
	description = S("End Relay Signal"),
	drawtype = "glasslike",
	tiles = {"default_glass.png^[colorize:#67D9FF:145"},
	paramtype = "light",
	sunlight_propagates = true,
	use_texture_alpha = "blend",
	light_source = 14,
	walkable = false,
	pointable = false,
	is_ground_content = false,
	groups = {not_in_creative_inventory = 1},
	drop = "",
})

core.register_node(relay_off, table.merge(relay_base, {
	description = S("Unlit End Relay"),
	on_rightclick = function(pos, _, player, stack)
		if not player or not player:is_player() then return stack end
		local name = player:get_player_name()
		if stack:get_name() ~= "mcl_throwing:ender_pearl" then
			core.chat_send_player(name, S("Fit an ender pearl to restore the relay."))
			return stack
		end
		for y = 0, 5 do
			local here = offset(pos, 0, y, 0)
			if core.is_protected(here, name) then
				core.record_protection_violation(here, name)
				return stack
			end
			local node = core.get_node_or_nil(here)
			if y > 0 and (not node or node.name ~= "air") then
				core.chat_send_player(name, S("Clear the space directly above the relay."))
				return stack
			end
		end
		core.swap_node(pos, {name = relay_on})
		for y = 1, 5 do core.set_node(offset(pos, 0, y, 0), {name = relay_signal}) end
		local key = relay_key(pos)
		active_relays[key] = vector.copy(pos)
		storage:set_string(key, "1")
		if not core.is_creative_enabled(name) then stack:take_item(1) end
		tell_relay_route(pos, name)
		return stack
	end,
}))

core.register_node(relay_on, table.merge(relay_base, {
	description = S("Lit End Relay"),
	tiles = {"mcl_end_purpur_block.png^[colorize:#67D9FF:180"},
	paramtype = "light",
	light_source = 14,
	on_rightclick = function(pos, _, player, stack)
		if player and player:is_player() then tell_relay_route(pos, player:get_player_name()) end
		return stack
	end,
	on_destruct = function(pos)
		local key = relay_key(pos)
		active_relays[key] = nil
		storage:set_string(key, "")
		for y = 1, 5 do
			local signal = offset(pos, 0, y, 0)
			if core.get_node(signal).name == relay_signal then core.remove_node(signal) end
		end
	end,
}))

mcl_expeditions.register("end_relay_tower", {
	title = S("End Relay Tower"),
	environment = "end",
	biomes = {"TheEnd", "EndHighlands", "EndMidlands", "EndBarrens", "SmallEndIslands"},
	bounds = {min = V(-5,-5,-5), max = V(5,16,5)},
	build = function(ctx)
		local end_brick = "mcl_end:end_bricks"
		local purpur = "mcl_end:purpur_block"
		ctx:fill(-4,-5,-4,4,-1,4,end_brick)
		ctx:fill(-3,0,-3,3,9,3,end_brick)
		ctx:fill(-2,0,-2,2,9,2,"air")
		ctx:fill(-1,0,-4,1,2,-3,"air")
		ctx:fill(-2,-1,-5,2,-1,-4,purpur)
		for _, x in ipairs({-3,3}) do
			for _, z in ipairs({-3,3}) do
				ctx:fill(x,0,z,x,12,z,"mcl_end:purpur_pillar")
				ctx:set(x,13,z,"mcl_end:end_rod")
			end
		end
		for _, y in ipairs({2,6}) do
			ctx:fill(-3,y,-1,-3,y+1,1,"mcl_core:glass")
			ctx:fill(-1,y,3,1,y+1,3,"mcl_core:glass")
		end
		ctx:fill(-4,10,-4,4,10,4,purpur)
		ctx:set(3,10,0,end_brick)
		ctx:fill(2,0,0,2,10,0,ladder,core.dir_to_wallmounted(V(1,0,0)))
		ctx:fill(-3,11,-4,3,11,-4,end_brick)
		ctx:fill(-3,11,4,3,11,4,end_brick)
		ctx:fill(-4,11,-3,-4,11,3,end_brick)
		ctx:fill(4,11,-3,4,11,3,end_brick)
		ctx:set(0,11,0,relay_off)
		ctx:fill(0,12,0,0,16,0,"air")
		ctx:sign(-4,0,-4,S("End Relay Tower\nClimb to repair it"))
		ctx:sign(1,11,2,S("Relay core\nFit an ender pearl"))
		ctx:set(-2,0,1,lantern)
		ctx:chest(-1,0,2,{"mcl_throwing:ender_pearl","mcl_end:end_bricks 8","mcl_end:end_rod 2"})
	end,
})
