-- SPDX-License-Identifier: GPL-3.0-or-later
local saddle = "mcl_mobitems:saddle"
local cases = {
	{id = "mobs_mc:horse", gear = saddle, tame = true},
	{id = "mobs_mc:donkey", gear = saddle, tame = true},
	{id = "mobs_mc:mule", gear = saddle, tame = true},
	{id = "mobs_mc:skeleton_horse", gear = saddle, tame = true},
	{id = "mobs_mc:zombie_horse", gear = saddle, tame = true},
	{id = "mobs_mc:llama", tame = true},
	{id = "mobs_mc:trader_llama", tame = true},
	{id = "mobs_mc:pig", gear = saddle},
	{id = "mobs_mc:strider", gear = saddle},
	{id = "mobs_mc:camel", gear = saddle, passenger = true},
	{id = "mobs_mc:camel_husk", gear = saddle, passenger = true},
	{id = "mobs_mc:nautilus", gear = saddle, tame = true},
	{id = "mobs_mc:zombie_nautilus", gear = saddle, tame = true},
	{id = "mobs_mc:happy_ghast", gear = "mcl_happy_ghast:red_harness", passenger = true},
	{id = "mcl_boats:boat", passenger = true},
	{id = "mcl_boats:chest_boat", passenger = false},
	{id = "mcl_boats:boat", passenger = true, raft = true},
	{id = "mcl_boats:chest_boat", passenger = false, raft = true},
	{id = "mcl_minecarts:minecart"},
}

local start = vector.new(0, 10, 0)
local failures = 0
local function log(message)
	core.log("action", "[mount test] " .. message)
end

local function assert_detached(player)
	assert(not player:get_attach(), "removal left a rider attached")
	assert(not mcl_player.players[player].attached, "removal left a stale riding state")
end

local function test(index, driver, passenger)
	local case = cases[index]
	if not case then
		log("TOTAL FAILURES " .. failures)
		core.request_shutdown("Mount test complete", false, 0)
		return
	end

	driver:set_pos(start)
	passenger:set_pos(vector.offset(start, 1, 0, 0))
	driver:set_wielded_item(ItemStack())
	passenger:set_wielded_item(ItemStack())
	local object, entity
	local passed, err = pcall(function()
		local pos = vector.offset(start, 0, 0, 2)
		local data
		if case.raft then
			local item = case.passenger and "mcl_boats:boat_bamboo" or "mcl_boats:boat_bamboo_chest"
			data = core.serialize({
				v = 0, variant = mcl_boats.variant.RAFT, itemstring = item,
				textures = {"mcl_boats_texture_bamboo_boat.png", case.passenger and "blank.png" or "mcl_chests_normal.png"},
			})
		elseif case.id == "mcl_minecarts:minecart" then
			core.set_node(pos, {name = "mcl_minecarts:rail"})
		end

		object = assert(core.add_entity(pos, case.id, data), "could not spawn mount")
		entity = assert(object:get_luaentity())
		if case.id == "mobs_mc:zombie_horse" then
			entity:on_rightclick(driver)
			assert(driver:get_attach() == object and not entity.tamed, "untamed zombie horse cannot be mounted")
			entity:detach(driver, vector.zero())
		end
		if case.tame then
			entity.tamed = true
			entity.owner = driver:get_player_name()
		end
		if case.gear then
			driver:set_wielded_item(ItemStack(case.gear))
			entity:on_rightclick(driver)
			assert(driver:get_wielded_item():is_empty(), "could not equip mount")
		end
		if case.id == "mobs_mc:strider" and entity._jockey_rider then
			entity:on_rightclick(driver)
			assert(not driver:get_attach(), "strider allowed a rider while carrying a jockey")
			local jockey = entity._jockey_rider
			jockey:get_luaentity():dismount_jockey()
			jockey:remove()
		end

		entity:on_rightclick(driver)
		assert(driver:get_attach() == object, "driver did not mount")
		if case.passenger ~= nil then
			if case.id == "mcl_boats:boat" then entity._csm_driving = true end
			entity:on_rightclick(passenger)
			assert((passenger:get_attach() ~= nil) == case.passenger, "incorrect passenger capacity")
			if case.id == "mcl_boats:boat" then
				assert(entity._csm_driving, "passenger boarding disabled client steering")
				entity._csm_driving = false
			end
		end
	end)

	core.after(0.35, function()
		if passed then
			passed, err = pcall(function()
				assert(driver:get_attach() == object, "driver attachment did not persist")
				if case.passenger then assert(passenger:get_attach(), "passenger attachment did not persist") end
				local props = object:get_properties()
				assert(props.mesh ~= "" and #props.textures > 0, "missing media references")
				if case.raft then assert(props.mesh == "mcl_boats_raft.b3d", "wrong raft mesh") end
				if case.raft and case.passenger then
					-- Remove the raft before its next step can process the empty seat.
					passenger:set_detach()
				end
				if case.id == "mcl_minecarts:minecart" then
					driver:set_detach()
					entity:on_rightclick(passenger)
					assert(passenger:get_attach() == object, "old driver blocked the next rider")
				end
			end)
		end

		if object and object:is_valid() then object:remove() end
		core.after(0.2, function()
			if passed then
				passed, err = pcall(function()
					assert_detached(driver)
					assert_detached(passenger)
				end)
			end
			local label = case.id .. (case.raft and " (raft)" or "")
			if passed then
				log("PASS " .. label)
			else
				failures = failures + 1
				log("FAIL " .. label .. ": " .. tostring(err))
				mcl_util.detach_object(driver)
				mcl_util.detach_object(passenger)
			end
			test(index + 1, driver, passenger)
		end)
	end)
end

local started = false
core.register_on_joinplayer(function()
	local driver = core.get_player_by_name("MountTestA")
	local passenger = core.get_player_by_name("MountTestB")
	if not started and driver and passenger then
		started = true
		core.after(2, test, 1, driver, passenger)
	end
end)
