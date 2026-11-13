local RESIDENTS = "mcl_beehives:residents"
local INITIALIZED = "mcl_beehives:initialized"
local BEE = "mobs_mc:bee"
local CAPACITY = 3
local STEP = 5

local function read_residents(meta)
	local fields = meta:get_string(RESIDENTS)
	local stored = fields ~= "" and core.deserialize(fields, true)
	return type(stored) == "table" and stored or {}
end

local function save_residents(meta, residents)
	meta:set_string(RESIDENTS, #residents > 0 and core.serialize(residents) or "")
end

function mcl_beehives.is_home(name)
	return core.get_item_group(name, "beehive") > 0 or core.get_item_group(name, "bee_nest") > 0
end

function mcl_beehives.base_node(name)
	return core.get_item_group(name, "beehive") > 0 and "mcl_beehives:beehive" or "mcl_beehives:bee_nest"
end

function mcl_beehives.set_honey_level(pos, node, level)
	node.name = mcl_beehives.base_node(node.name) .. (level > 0 and "_" .. level or "")
	mcl_redstone.swap_node(pos, node)
end

function mcl_beehives.can_forage(pos)
	if mcl_worlds.pos_to_dimension(pos) ~= "overworld" then
		return true
	end
	local time = core.get_timeofday()
	local weather = mcl_weather.get_weather()
	return time > 0.23 and time < 0.77 and weather ~= "rain" and weather ~= "thunder"
end

function mcl_beehives.is_smoky(pos)
	for distance = 1, 5 do
		local node = core.get_node(vector.offset(pos, 0, -distance, 0)).name
		if core.get_item_group(node, "lit_campfire") > 0 then
			return true
		elseif node ~= "air" and core.get_item_group(node, "carpet") == 0 then
			local def = core.registered_nodes[node]
			if not def or def.walkable or def.liquidtype ~= "none" then
				return false
			end
		end
	end
	return false
end

function mcl_beehives.entrance(pos, node)
	local dir = core.facedir_to_dir(node.param2)
	local entrance = vector.subtract(pos, dir)
	local name = core.get_node(entrance).name
	local def = core.registered_nodes[name]
	if def and name ~= "ignore" and not def.walkable and def.liquidtype == "none" then
		return vector.offset(entrance, 0, -0.20, 0)
	end
end

function mcl_beehives.initialize(pos, node)
	local meta = core.get_meta(pos)
	if meta:get_int(INITIALIZED) == 0 then
		meta:set_int(INITIALIZED, 1)
		if core.get_item_group(node.name, "bee_nest") > 0 and meta:get_string(RESIDENTS) == "" then
			local residents = {}
			for _ = 1, math.random(2, 3) do
				residents[#residents + 1] = {wait = math.random(0, 15)}
			end
			save_residents(meta, residents)
		end
	end
	local timer = core.get_node_timer(pos)
	if meta:get_string(RESIDENTS) ~= "" and not timer:is_started() then
		timer:start(STEP)
	end
	return meta
end

function mcl_beehives.after_place(pos, _, itemstack)
	local meta = core.get_meta(pos)
	meta:set_int(INITIALIZED, 1)
	local residents = read_residents(itemstack:get_meta())
	while #residents > CAPACITY do
		table.remove(residents)
	end
	save_residents(meta, residents)
	mcl_beehives.initialize(pos, core.get_node(pos))
end

function mcl_beehives.has_room(pos, node)
	return #read_residents(mcl_beehives.initialize(pos, node)) < CAPACITY
end

function mcl_beehives.admit(pos, node, bee)
	local meta = mcl_beehives.initialize(pos, node)
	local residents = read_residents(meta)
	if #residents >= CAPACITY then
		return false
	end
	residents[#residents + 1] = {
		wait = bee._bee_nectar and 120 or 30,
		nectar = bee._bee_nectar,
		child = bee.child,
		age = bee._mob_age,
		breeding = bee._mob_breeding,
		name = bee.nametag,
		health = bee.health,
	}
	save_residents(meta, residents)
	mcl_beehives.initialize(pos, node)
	bee.object:remove()
	return true
end

local function release(resident, exit, home, attacker)
	local state = {
		_bee_home = home,
		_bee_nectar = not home and resident.nectar or false,
		child = resident.child,
		_mob_age = resident.age,
		_mob_breeding = resident.breeding,
		nametag = resident.name,
		health = resident.health,
		persistent = true,
	}
	local object = core.add_entity(exit, BEE, core.serialize(state))
	if object and object:is_valid() then
		if attacker then
			object:get_luaentity():anger_at(attacker)
		end
		return true
	end
	return false
end

function mcl_beehives.on_timer(pos, elapsed)
	local node = core.get_node(pos)
	if not mcl_beehives.is_home(node.name) then
		return false
	end
	local meta = core.get_meta(pos)
	local residents = read_residents(meta)
	local exit = mcl_beehives.can_forage(pos) and mcl_beehives.entrance(pos, node)
	local remaining = {}
	local honey = core.get_item_group(node.name, "honey_level")
	local original_honey = honey
	for _, resident in ipairs(residents) do
		resident.wait = math.max(0, (resident.wait or 0) - elapsed)
		if resident.wait == 0 and exit and release(resident, exit, pos) then
			if resident.nectar then
				honey = math.min(5, honey + (math.random(100) == 1 and 2 or 1))
			end
		else
			remaining[#remaining + 1] = resident
		end
	end
	save_residents(meta, remaining)
	if honey ~= original_honey then
		mcl_beehives.set_honey_level(pos, node, honey)
	end
	return #remaining > 0
end

function mcl_beehives.disturb(pos, node, attacker, broken_fields)
	local meta = core.get_meta(pos)
	local fields = broken_fields and broken_fields[RESIDENTS] or meta:get_string(RESIDENTS)
	local residents = core.deserialize(fields or "", true)
	residents = type(residents) == "table" and residents or {}
	local exit = mcl_beehives.entrance(pos, node)
		or (broken_fields and vector.offset(pos, 0, -0.20, 0))
	local remaining = {}
	for _, resident in ipairs(residents) do
		if not exit or not release(resident, exit, not broken_fields and pos or nil, attacker) then
			remaining[#remaining + 1] = resident
		end
	end
	if not broken_fields then
		save_residents(meta, remaining)
	end
	mcl_beehives.alert_bees(pos, attacker)
end

function mcl_beehives.silk_drop(pos, node, fields)
	local stack = ItemStack(node.name)
	local residents = core.deserialize(fields[RESIDENTS] or "", true)
	if type(residents) == "table" and #residents > 0 then
		save_residents(stack:get_meta(), residents)
	end
	core.add_item(pos, stack)
	return type(residents) == "table" and #residents or 0
end

core.register_abm({
	label = "Initialize bee nest inhabitants",
	nodenames = {"group:bee_nest", "group:beehive"},
	interval = 8,
	chance = 1,
	catch_up = false,
	action = mcl_beehives.initialize,
})
