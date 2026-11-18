-- SPDX-License-Identifier: GPL-3.0-or-later
local ids = {
	"caravan_waystation", "cliffside_air_dock", "mountain_rescue_shelter", "overgrown_glasshouse",
	"flooded_observatory", "tide_locked_smuggler_cave", "buried_canal_lock", "nether_ferry_piers",
	"abandoned_lift_mine", "storm_lighthouse", "end_relay_tower", "ruined_bathhouse",
	"floodplain_village", "quarry_workshop",
}

local function log(message)
	core.log("action", "[expeditions test] " .. message)
end

local function assert_water(pos)
	assert(core.get_item_group(core.get_node(pos).name, "water") > 0,
		"Expected water at " .. core.pos_to_string(pos))
end

local function click(pos, player, stack)
	local node = core.get_node(pos)
	local handler = assert(core.registered_nodes[node.name].on_rightclick)
	return handler(pos, node, player, stack or ItemStack())
end

local function test_lift(pos, player)
	local panel = vector.offset(pos, 1, 0, 0)
	local obstruction = vector.offset(pos, 0, -5, 0)
	player:set_pos(pos)
	assert(click(panel, player, ItemStack("mcl_core:iron_ingot 3")):get_count() == 3)
	assert(click(panel, player, ItemStack("mcl_core:iron_ingot 4")):is_empty())
	assert(core.get_meta(panel):get_int("repaired") == 1)

	local function choose(stop)
		click(panel, player)
		local check = core.check_player_privs
		local send = core.chat_send_player
		local refusal
		core.check_player_privs = function() return true end
		core.chat_send_player = function(_, text) refusal = core.strip_escapes(text) end
		local ok, err = pcall(function()
			for _, callback in ipairs(core.registered_on_player_receive_fields) do
				callback(player, "mcl_expeditions:lift_controls", {[stop] = true})
			end
		end)
		core.check_player_privs = check
		core.chat_send_player = send
		assert(ok, err)
		return refusal
	end
	core.set_node(obstruction, {name = "mcl_core:cobble"})
	choose("stop3")
	assert(vector.equals(player:get_pos(), pos), "lift passed through a blocked shaft")
	core.remove_node(obstruction)
	for y = -20, 0 do
		local want = (y == -10 or y == -1) and "mcl_core:stonebrickcarved" or "air"
		local actual = core.get_node(vector.offset(pos, 0, y, 0)).name
		assert(actual == want, ("lift shaft at %s should be %s, found %s"):format(y, want, actual))
	end
	local refusal = choose("stop3")
	assert(vector.equals(player:get_pos(), vector.offset(pos, 0, -20, 0)),
		"lift did not reach the quarry: " .. tostring(refusal))
	for y = -20, -1 do
		assert(core.get_node(vector.offset(pos, 4, y, 0)).name == "mcl_core:ladder")
	end
end

local function test_relays(pos, player)
	local other = vector.offset(pos, 0, 0, 36)
	assert(mcl_expeditions.place("end_relay_tower", other, PcgRandom(5432)))
	local a, b = vector.offset(pos, 0, 11, 0), vector.offset(other, 0, 11, 0)
	assert(click(a, player, ItemStack("mcl_throwing:ender_pearl")):is_empty())
	assert(click(b, player, ItemStack("mcl_throwing:ender_pearl")):is_empty())
	assert(core.get_node(a).name == "mcl_expeditions:relay_beacon_lit")
	assert(core.get_node(vector.offset(a, 0, 5, 0)).name == "mcl_expeditions:relay_signal")
	local message
	local send = core.chat_send_player
	core.chat_send_player = function(_, text) message = core.strip_escapes(text) end
	local ok, err = pcall(click, a, player)
	core.chat_send_player = send
	assert(ok, err)
	assert(message and message:find(core.pos_to_string(b), 1, true), "lit relay did not report the next tower")
end

local function test()
	local rewards = core.create_detached_inventory("expedition_test_rewards", {})
	rewards:set_size("main", 1)
	local player_pos
	local player = {
		is_player = function() return true end,
		get_player_name = function() return "ExpeditionTest" end,
		get_inventory = function() return rewards end,
		get_attach = function() end,
		get_pos = function() return player_pos end,
		set_pos = function(_, pos) player_pos = pos end,
	}
	for i, id in ipairs(ids) do
		local pos = vector.new(i * 36, 29, 0)
		local def = assert(mcl_expeditions.definitions[id])
		assert(mcl_expeditions.place(id, pos, PcgRandom(5432)))
		assert(vector.equals(mcl_expeditions.nearest(id, pos), pos))
		local lo, hi = vector.add(pos, def.bounds.min), vector.add(pos, def.bounds.max)
		local chests = core.find_nodes_in_area(lo, hi, {"mcl_chests:chest_small"})
		assert(#chests > 0, id .. " has no supply chest")
		for _, chest in ipairs(chests) do
			assert(not core.get_meta(chest):get_inventory():is_empty("main"), id .. " has an empty chest")
		end

		if id == "tide_locked_smuggler_cave" then
			local gate = vector.offset(pos, 1, -9, 5)
			assert(core.get_node(gate).name == "mcl_expeditions:copper_bulkhead")
			click(vector.offset(pos, 0, -5, 0), player)
			assert(core.get_node(gate).name == "mcl_expeditions:copper_bulkhead")
			for _, x in ipairs({-2, 0, -1}) do click(vector.offset(pos, x, -5, 0), player) end
			assert_water(gate)
		elseif id == "buried_canal_lock" then
			local winch = vector.offset(pos, -3, -10, -1)
			local gate = vector.offset(pos, -2, -13, 1)
			assert(core.get_item_group(core.get_node(gate).name, "water") == 0)
			local single = click(winch, player, ItemStack("mcl_core:iron_ingot"))
			assert(single:get_count() == 1 and core.get_item_group(core.get_node(gate).name, "water") == 0)
			assert(click(winch, player, ItemStack("mcl_core:iron_ingot 3")):is_empty())
			assert_water(gate)
			assert(core.get_node(vector.offset(pos, -2, -11, 1)).name == "air")
			assert(click(winch, player, ItemStack("mcl_core:iron_ingot 3")):get_count() == 3)
		elseif id == "flooded_observatory" then
			assert_water(vector.offset(pos, 0, 0, -3))
			assert(core.get_node(vector.offset(pos, 0, 3, -3)).name == "air")
		elseif id == "cliffside_air_dock" then
			local counter = vector.offset(pos, -5, 1, -2)
			assert(click(counter, player, ItemStack("mcl_core:emerald 2")):get_count() == 2)
			local payment = click(counter, player, ItemStack("mcl_core:emerald 4"))
			assert(payment:get_count() == 1)
			assert(rewards:contains_item("main", "mcl_happy_ghast:red_harness"))
		elseif id == "overgrown_glasshouse" then
			assert_water(vector.offset(pos, 0, 0, 0))
			assert(core.get_node(vector.offset(pos, -4, 0, 0)).name == "mcl_farming:soil_wet")
		elseif id == "nether_ferry_piers" then
			assert(core.get_node(vector.offset(pos, 0, 0, 0)).name ~= "mcl_nether:nether_brick",
				"Ferry platforms bridged the strider lane")
			assert(core.get_node(vector.offset(pos, 12, 4, 2)).name == "mcl_nether:nether_brick")
		elseif id == "storm_lighthouse" then
			local lamp = vector.offset(pos, 0, 15, 0)
			assert(click(lamp, player, ItemStack("mcl_copper:copper_ingot 2")):get_count() == 2)
			assert(core.get_node(lamp).name == "mcl_expeditions:storm_lighthouse_lamp_broken")
			assert(click(lamp, player, ItemStack("mcl_copper:copper_ingot 3")):is_empty())
			assert(core.get_node(lamp).name == "mcl_expeditions:storm_lighthouse_lamp")
			assert(core.registered_nodes[core.get_node(lamp).name].light_source == core.LIGHT_MAX)
		elseif id == "ruined_bathhouse" then
			local hot, cold = vector.offset(pos, -2, 0, 3), vector.offset(pos, 2, 0, 3)
			local warm, cool = vector.offset(pos, -5, -1, 0), vector.offset(pos, 5, -1, 0)
			local seal = vector.offset(pos, 0, 1, 4)
			click(cold, player)
			assert(core.get_node(seal).name == "mcl_expeditions:bathhouse_pressure_seal")
			assert(core.get_node(cool).name == "air")
			click(hot, player)
			assert_water(warm)
			click(cold, player)
			assert_water(cool)
			assert(core.get_node(seal).name == "air")
		elseif id == "abandoned_lift_mine" then
			test_lift(pos, player)
		elseif id == "end_relay_tower" then
			test_relays(pos, player)
		elseif id == "floodplain_village" then
			assert(core.get_node(vector.offset(pos, -5, 2, -11)).name == "mcl_trees:wood_oak")
			assert(core.get_node(vector.offset(pos, 0, 4, -8)).name == "air", "boat lane has an obstruction")
			assert(core.get_node(vector.offset(pos, 0, 9, 3)).name == "mcl_trees:wood_spruce")
		elseif id == "quarry_workshop" then
			local cutter = vector.offset(pos, 3, 0, -5)
			assert(click(cutter, player, ItemStack("mcl_core:iron_ingot 2")):get_count() == 2)
			assert(core.get_node(cutter).name == "mcl_expeditions:damaged_quarry_cutter")
			assert(click(cutter, player, ItemStack("mcl_core:iron_ingot 3")):is_empty())
			local output = click(cutter, player, ItemStack("mcl_core:andesite 3"))
			assert(output:to_string() == "mcl_core:andesite_smooth 3")
		end
		log("PASS " .. id)
	end
	log("ALL STRUCTURES PASSED")
	core.request_shutdown("Expedition test complete", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		if core.settings:get_bool("mcwelly_test_natural_expeditions", false) then
			local lo, hi = vector.new(-200, -8, -200), vector.new(200, 64, 280)
			local region = core.settings:get("mcwelly_test_expedition_region")
			local origin = vector.zero()
			local expected = ids
			if region == "nether" then
				origin.y = mcl_vars.mg_lava_nether_max
				lo, hi = vector.new(-320, origin.y - 8, -320), vector.new(320, origin.y + 8, 320)
				expected = {"nether_ferry_piers"}
			elseif region == "ocean" then
				origin = vector.new(672, -14, -1761)
				lo, hi = vector.offset(origin, -240, -40, -240), vector.offset(origin, 240, 18, 240)
				expected = {"flooded_observatory"}
			elseif region == "end" then
				origin = vector.new(2281, mcl_vars.mg_end_min + 90, -781)
				lo, hi = vector.offset(origin, -240, -32, -240), vector.offset(origin, 240, 32, 240)
				expected = {"end_relay_tower"}
			elseif region == "river" then
				origin = vector.new(420, 0, 550)
				lo, hi = vector.offset(origin, -360, -8, -360), vector.offset(origin, 360, 32, 360)
				expected = {"floodplain_village"}
			end
			if mcl_levelgen.levelgen_enabled then
				mcl_levelgen.generate_area(lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, function() end)
			else
				core.emerge_area(lo, hi)
			end
			local attempts = 0
			local function check()
				for _, id in ipairs(expected) do
					local pos = mcl_expeditions.nearest(id, origin)
					if pos then
						log("Found naturally generated " .. id .. " at " .. core.pos_to_string(pos))
						log("NATURAL GENERATION PASSED")
						core.request_shutdown("Expedition test complete", false, 0)
						return
					end
				end
				attempts = attempts + 1
				assert(attempts < 75, "No expedition sites generated in the test area")
				core.after(2, check)
			end
			core.after(2, check)
			return
		end
		core.emerge_area(vector.new(-24, 0, -24), vector.new(#ids * 36 + 24, 64, 48), function(_, _, remaining)
			if remaining == 0 then core.after(1, test) end
		end)
	end)
end)
