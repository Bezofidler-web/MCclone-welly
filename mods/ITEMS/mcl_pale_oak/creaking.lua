local S = core.get_translator (core.get_current_modname ())
local mob_class = mcl_mobs.mob_class
local mob_name = "mobs_mc:creaking"
local heart_name = "mcl_pale_oak:creaking_heart"
local pale_log = "mcl_trees:tree_pale_oak"
local resin = "mcl_pale_oak:resin_clump"
local max_distance = 32
local active_creakings = {}
local directions = {
	vector.new (1, 0, 0), vector.new (-1, 0, 0),
	vector.new (0, 1, 0), vector.new (0, -1, 0),
	vector.new (0, 0, 1), vector.new (0, 0, -1),
}
local axes = {[0] = directions[3], [4] = directions[5], [12] = directions[1]}

local function live_survival_player (player)
	return player:is_player () and player:get_hp () > 0
		and not core.is_creative_enabled (player:get_player_name ())
end

local function is_night ()
	local time = core.get_timeofday ()
	return time <= 0.22 or time >= 0.78
end

local function get_linked (pos)
	local key = core.hash_node_position (pos)
	local object = active_creakings[key]
	if object and object:is_valid () then return object end
	active_creakings[key] = nil
end

local function try_bind (pos, object)
	local existing = get_linked (pos)
	if existing and existing ~= object then return false end
	active_creakings[core.hash_node_position (pos)] = object
	return true
end

local function unbind (pos, object)
	local key = core.hash_node_position (pos)
	if active_creakings[key] == object then active_creakings[key] = nil end
end

local function remove_linked (pos)
	local object = get_linked (pos)
	if object then
		unbind (pos, object)
		object:remove ()
	end
end

local function heart_aligned (pos, node)
	local axis = node.param2 - node.param2 % 4
	local dir = axes[axis]
	if not dir then return false end
	local a = core.get_node_or_nil (vector.add (pos, dir))
	local b = core.get_node_or_nil (vector.subtract (pos, dir))
	return a and b and a.name == pale_log and b.name == pale_log
		and a.param2 - a.param2 % 4 == axis and b.param2 - b.param2 % 4 == axis
end

local function add_resin (pos, name)
	local logs = {pos}
	local seen = {[core.hash_node_position (pos)] = true}
	local target_count = math.random (2, 3)
	local index = 1
	while index <= #logs and index <= 64 and target_count > 0 do
		local current = logs[index]
		local order = table.copy (directions)
		table.shuffle (order)
		for _, dir in ipairs (order) do
			local neighbour = vector.add (current, dir)
			local key = core.hash_node_position (neighbour)
			local node = core.get_node (neighbour).name
			if node == pale_log and not seen[key] and vector.distance (pos, neighbour) <= 3 then
				seen[key] = true
				logs[#logs + 1] = neighbour
			elseif index > 1 and node == "air" and not core.is_protected (neighbour, name) then
				core.set_node (neighbour, {name = resin, param2 = core.dir_to_wallmounted (vector.multiply (dir, -1))})
				target_count = target_count - 1
				if target_count == 0 then break end
			end
		end
		index = index + 1
	end
end

local function echo_hit (heart, object, name)
	local pos = object:get_pos ()
	local node = core.get_node (heart)
	if not pos or core.get_item_group (node.name, "creaking_heart") == 0 then return end
	local meta = core.get_meta (heart)
	local now = core.get_gametime ()
	if meta:get_int ("next_resin") > now then return end
	meta:set_int ("next_resin", now + 5)
	add_resin (heart, name)
	local velocity = vector.multiply (vector.subtract (heart, pos), 2.5)
	for i = 1, 8 do
		core.add_particle ({pos = vector.add (pos, vector.new (0, 1, 0)), velocity = velocity,
			expirationtime = i / 20, size = 1.3, glow = 8,
			texture = "mcl_pale_oak_resin_clump.png"})
	end
end

local function watching (self, pos, player)
	local eyes = mcl_util.target_eye_pos (player)
	local helmet = player:get_inventory ():get_stack ("armor", 2)
	if helmet:get_name () == "mcl_farming:pumpkin_face" then return false end
	local target = vector.offset (pos, 0, 1.35, 0)
	local direction = vector.direction (eyes, target)
	return vector.dot (player:get_look_dir (), direction) >= 0.89 and self:line_of_sight (eyes, target)
end

local creaking = {
	description = S ("Creaking"),
	type = "monster",
	_spawn_category = "misc",
	hp_min = 1,
	hp_max = 1,
	can_despawn = false,
	can_ride_boat = false,
	can_ride_cart = false,
	visual = "mesh",
	mesh = "mcl_pale_oak_creaking.obj",
	textures = {"mcl_pale_oak_creaking.png"},
	visual_size = {x = 1, y = 1},
	use_texture_alpha = true,
	backface_culling = false,
	collisionbox = {-0.45, 0, -0.45, 0.45, 2.65, 0.45},
	head_eye_height = 2.15,
	view_range = 32,
	movement_speed = 4,
	attack_type = "melee",
	reach = 1.7,
	damage = 3,
	knockback_resistance = 1,
	fire_damage = 0,
	lava_damage = 0,
	xp_min = 0,
	xp_max = 0,
	drops = {},
}

local function update_eyes (self)
	self:set_textures ({self._creaking_awake and "mcl_pale_oak_creaking.png^mcl_pale_oak_creaking_eyes.png"
		or "mcl_pale_oak_creaking.png"})
end

function creaking:after_activate ()
	update_eyes (self)
	if self._creaking_heart then
		self.ignores_nametag = true
		self._forbid_portal_teleportation = true
		if not try_bind (self._creaking_heart, self.object) then self:safe_remove () end
	end
end

function creaking:on_deactivate (removal)
	if self._creaking_heart then unbind (self._creaking_heart, self.object) end
	return mob_class.on_deactivate (self, removal)
end

function creaking:receive_damage (reason, damage)
	if not self._creaking_heart then return mob_class.receive_damage (self, reason, damage) end
	local source = reason.source
	if damage > 0 and source and source:is_valid () then
		local entity = source:get_luaentity ()
		local name = source:is_player () and source:get_player_name () or entity and entity.tamed and entity.owner
		if name and name ~= "" then echo_hit (self._creaking_heart, self.object, name) end
	end
	return false
end

function creaking:get_active_target ()
	return self._creaking_target
end

local function update_behaviour (self, pos, dtime)
	local heart = self._creaking_heart
	if heart and self:check_timer ("check_heart", 0.5) then
		local node = core.get_node_or_nil (heart)
		if not is_night () or vector.distance (pos, heart) > max_distance
				or node and core.get_item_group (node.name, "creaking_heart") == 0 then
			self:safe_remove ()
			return "inactive"
		end
	end
	local nearest, distance, being_watched
	for _, player in ipairs (core.get_connected_players ()) do
		if live_survival_player (player) then
			local d = vector.distance (pos, player:get_pos ())
			if d <= max_distance and (not distance or d < distance) then nearest, distance = player, d end
			if d <= (self._creaking_awake and max_distance or 12) and watching (self, pos, player) then
				being_watched = true
			end
		end
	end
	local awake = nearest and (being_watched or self._creaking_awake) and true or false
	if awake ~= self._creaking_awake then
		self._creaking_awake = awake
		update_eyes (self)
	end
	self._creaking_target = awake and nearest or nil
	if not awake or being_watched then
		self:cancel_navigation ()
		self:halt_in_tracks (true)
		return "frozen"
	end
	return mob_class.check_attack (self, pos, dtime)
end

creaking.ai_functions = {update_behaviour}

mcl_mobs.register_mob (mob_name, creaking)
mcl_mobs.register_egg (mob_name, S ("Creaking"), "#665941", "#ed8e20", 0)
core.override_item (mob_name, {inventory_image = "mcl_pale_oak_creaking_egg.png"})

local function spawn_site (pos)
	for _ = 1, 12 do
		local start = vector.offset (pos, math.random (-12, 12), 3, math.random (-12, 12))
		for dy = 0, -10, -1 do
			local site = vector.offset (start, 0, dy, 0)
			local floor = core.get_node_or_nil (vector.offset (site, 0, -1, 0))
			local def = floor and core.registered_nodes[floor.name]
			if def and def.walkable and core.get_node (site).name == "air"
					and core.get_node (vector.offset (site, 0, 1, 0)).name == "air"
					and core.get_node (vector.offset (site, 0, 2, 0)).name == "air" then
				return vector.offset (site, 0, -0.45, 0)
			end
		end
	end
end

local function set_signal (pos, signal)
	local meta = core.get_meta (pos)
	if signal ~= meta:get_int ("signal") then
		meta:set_int ("signal", signal)
		mcl_redstone.update_comparators (pos)
	end
end

local function heart_tick (pos)
	local node = core.get_node (pos)
	local meta = core.get_meta (pos)
	local suffix = meta:get_int ("natural") == 1 and "_natural" or ""
	local aligned = heart_aligned (pos, node)
	local active = aligned and is_night ()
	local state = aligned and (active and "_awake" or "_dormant") or ""
	local variant = heart_name .. suffix .. state
	if variant ~= node.name then
		core.swap_node (pos, {name = variant, param2 = node.param2})
	end
	if not active then
		remove_linked (pos)
		set_signal (pos, 0)
		return true
	end
	local linked = get_linked (pos)
	if not linked and mcl_vars.difficulty > 0 and not mcl_vars.only_peaceful_mobs then
		for _, player in ipairs (core.get_connected_players ()) do
			if live_survival_player (player) and vector.distance (pos, player:get_pos ()) <= max_distance then
				local site = spawn_site (pos)
				if site then
					linked = core.add_entity (site, mob_name, core.serialize ({_creaking_heart = pos, persistent = true}))
				end
				break
			end
		end
	end
	local other = linked and linked:get_pos ()
	set_signal (pos, other and math.max (0, 15 - math.floor (15 * vector.distance (pos, other) / max_distance)) or 0)
	return true
end

local function start_heart (pos, node)
	if node.name:find ("_natural", 1, true) then core.get_meta (pos):set_int ("natural", 1) end
	local timer = core.get_node_timer (pos)
	if not timer:is_started () then timer:start (2) end
end

for _, family in ipairs ({"", "_natural"}) do
	for _, state in ipairs ({"", "_dormant", "_awake"}) do
		local name = heart_name .. family .. state
		local face = "mcl_pale_oak_creaking_heart" .. state .. ".png"
		local top = "mcl_pale_oak_creaking_heart_top" .. state .. ".png"
		core.register_node (name, {
			description = S ("Creaking Heart"),
			tiles = {top, top, face},
			paramtype2 = "facedir",
			groups = {axey = 1, material_wood = 1, creaking_heart = 1, unmovable_by_piston = 1,
				not_in_creative_inventory = name ~= heart_name and 1 or nil},
			drop = {max_items = 1, items = {{items = {resin .. " 3"}, rarity = 3},
				{items = {resin .. " 2"}, rarity = 2}, {items = {resin}}}},
			_mcl_silk_touch_drop = {heart_name},
			_mcl_fortune_drop = {discrete_uniform_distribution = true, items = {resin}, min_count = 1, max_count = 3, cap = 9},
			_mcl_hardness = 10,
			_mcl_blast_resistance = 10,
			sounds = mcl_sounds.node_sound_wood_defaults (),
			on_place = mcl_util.rotate_axis,
			on_construct = function (pos) start_heart (pos, {name = name}) end,
			on_destruct = remove_linked,
			on_timer = heart_tick,
			after_dig_node = function (pos, _, _, digger)
				if family ~= "" and digger and live_survival_player (digger) then
					mcl_experience.throw_xp (pos, math.random (20, 24))
				end
			end,
		})
		mcl_redstone.register_comparator_measure_func (name, function (pos) return core.get_meta (pos):get_int ("signal") end)
	end
end

core.register_lbm ({name = "mcl_pale_oak:start_creaking_heart", nodenames = {"group:creaking_heart"},
	run_at_every_load = true, action = start_heart})
core.register_craft ({output = heart_name, recipe = {{pale_log}, {"mcl_pale_oak:block_of_resin"}, {pale_log}}})
