-- SPDX-License-Identifier: GPL-3.0-or-later
local path = core.get_modpath(core.get_current_modname())
local storage = core.get_mod_storage()
local definitions, locations = {}, {}
mcl_expeditions = {definitions = definitions}

local function record_site(id, pos)
	local key = "site/" .. id .. "/" .. core.pos_to_string(pos)
	storage:set_string(key, "1")
	locations[id] = locations[id] or {}
	locations[id][key] = pos
end

for key in pairs(storage:to_table().fields) do
	local id, coordinates = key:match("^site/([^/]+)/(.+)$")
	local pos = coordinates and core.string_to_pos(coordinates)
	if pos then
		locations[id] = locations[id] or {}
		locations[id][key] = pos
	end
end

function mcl_expeditions.nearest(id, origin, excluded)
	local nearest, distance = nil, math.huge
	local dimension = mcl_worlds.pos_to_dimension(origin)
	for _, pos in pairs(locations[id] or {}) do
		if (not excluded or not vector.equals(pos, excluded)) and mcl_worlds.pos_to_dimension(pos) == dimension then
			local d = vector.distance(origin, pos)
			if d < distance then nearest, distance = pos, d end
		end
	end
	return nearest
end

function mcl_expeditions.register(id, def)
	assert(not definitions[id], "Duplicate expedition site " .. id)
	def.id = id
	definitions[id] = def
end

local context = {}
local function local_position(self, x, y, z)
	local lo, hi = self.bounds.min, self.bounds.max
	assert(x >= lo.x and x <= hi.x and y >= lo.y and y <= hi.y and z >= lo.z and z <= hi.z,
		"Expedition write outside declared footprint")
	return vector.offset(self.pos, x, y, z)
end

function context:set(x, y, z, name, param2)
	local pos = local_position(self, x, y, z)
	assert(core.registered_nodes[name], "Unknown expedition node " .. name)
	self.nodes[core.hash_node_position(pos)] = {pos = pos, name = name, param2 = param2 or 0}
end

function context:fill(x1, y1, z1, x2, y2, z2, name, param2)
	for z = z1, z2 do
		for y = y1, y2 do
			for x = x1, x2 do self:set(x, y, z, name, param2) end
		end
	end
end

function context:after(callback)
	self.callbacks[#self.callbacks + 1] = callback
end

function context:chest(x, y, z, stacks)
	local pos = local_position(self, x, y, z)
	self:set(x, y, z, "mcl_chests:chest_small")
	local loot = {}
	for i, item in ipairs(stacks) do
		local stack = ItemStack(item)
		assert(not stack:is_empty() and stack:is_known(), "Unknown expedition loot " .. stack:to_string())
		loot[i] = stack
	end
	self:after(function()
		local inv = core.get_meta(pos):get_inventory()
		for _, stack in ipairs(loot) do inv:add_item("main", stack) end
	end)
end

function context:sign(x, y, z, text, param2)
	local pos = local_position(self, x, y, z)
	self:set(x, y, z, "mcl_signs:standing_sign_oak", param2)
	self:after(function()
		local plain = core.strip_escapes(text)
		core.get_meta(pos):set_string("utext", core.serialize(mcl_signs.string_to_ustring(plain)))
		mcl_signs.update_sign(pos)
	end)
end

function context:spawn(x, y, z, entity, staticdata)
	local pos = local_position(self, x, y, z)
	assert(core.registered_entities[entity], "Unknown expedition entity " .. entity)
	if type(staticdata) == "table" then staticdata = core.serialize(staticdata) end
	self:after(function() core.add_entity(pos, entity, staticdata) end)
end

function mcl_expeditions.place(id, pos, pr)
	local def = assert(definitions[id])
	local ctx = setmetatable({
		pos = pos, pr = pr, bounds = def.bounds, nodes = {}, callbacks = {},
	}, {__index = context})
	def.build(ctx)
	local minp = vector.add(pos, def.bounds.min)
	local maxp = vector.add(pos, def.bounds.max)
	local vm = core.get_voxel_manip(minp, maxp)
	local lo, hi = vm:get_emerged_area()
	local area = VoxelArea:new({MinEdge = lo, MaxEdge = hi})
	local data, param2 = vm:get_data(), vm:get_param2_data()
	for _, node in pairs(ctx.nodes) do
		local i = area:indexp(node.pos)
		data[i] = core.get_content_id(node.name)
		param2[i] = node.param2
	end
	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:write_to_map(true)
	vm:update_liquids()
	if vm.close then vm:close() end
	for _, node in pairs(ctx.nodes) do
		local on_construct = core.registered_nodes[node.name].on_construct
		if on_construct then
			local current = core.get_node(node.pos)
			if current.name ~= node.name or current.param2 ~= node.param2 then
				core.swap_node(node.pos, {name = node.name, param2 = node.param2})
			end
			on_construct(node.pos)
		end
	end
	for _, callback in ipairs(ctx.callbacks) do callback() end
	record_site(id, pos)
	core.log("info", "[mcl_expeditions] Placed " .. id .. " at " .. core.pos_to_string(pos))
	return true
end

dofile(path .. "/surface.lua")
dofile(path .. "/water.lua")
dofile(path .. "/nether.lua")
dofile(path .. "/lift_relay.lua")
dofile(path .. "/coast_baths.lua")
dofile(path .. "/floodplain_quarry.lua")
dofile(path .. "/mapgen.lua")
