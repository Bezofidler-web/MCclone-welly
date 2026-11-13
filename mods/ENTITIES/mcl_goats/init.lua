-- SPDX-License-Identifier: GPL-3.0-or-later

local S = core.get_translator ("mcl_goats")
local mob_class = mcl_mobs.mob_class
local goat_name = "mobs_mc:goat"
local wheat = "mcl_farming:wheat_item"
local milk = "mcl_mobitems:milk_bucket"
local horn_names = {"Ponder", "Sing", "Seek", "Feel", "Admire", "Call", "Yearn", "Dream"}

local function horn_item (index)
	return "mcl_goats:goat_horn_" .. horn_names[index]:lower ()
end

for index, label in ipairs (horn_names) do
	local sound = "mcl_goats_" .. label:lower ()
	core.register_craftitem (horn_item (index), {
		description = S ("Goat Horn") .. "\n" .. S (label),
		inventory_image = "mcl_goats_goat_horn.png",
		stack_max = 1,
		on_use = function (stack, player)
			if not player or not player:is_player () then return stack end
			local meta = player:get_meta ()
			local now = core.get_gametime ()
			if meta:get_int ("mcl_goats:horn_ready") <= now then
				meta:set_int ("mcl_goats:horn_ready", now + 7)
				core.sound_play (sound, {object = player, max_hear_distance = 256}, true)
			end
			return stack
		end,
	})
end

local goat = {
	description = S ("Goat"),
	type = "animal",
	_spawn_category = "creature",
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	collisionbox = {-0.45, 0, -0.45, 0.45, 1.3, 0.45},
	head_eye_height = 0.94,
	visual = "mesh",
	mesh = "mcl_goats_goat.b3d",
	_child_mesh = "mcl_goats_baby.b3d",
	child_texture = {{"mcl_goats_goat_baby.png"}},
	textures = {"mcl_goats_goat.png"},
	use_texture_alpha = true,
	backface_culling = false,
	movement_speed = 4,
	_safe_fall_distance = 13,
	jump_height = 7.5,
	_can_freeze = false,
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 10,
		walk_start = 12, walk_end = 50, walk_speed = 28,
		run_start = 12, run_end = 50, run_speed = 40,
	},
	sounds = {
		random = "mcl_goats_bleat", damage = "mcl_goats_bleat",
		eat = "mobs_mc_animal_eat_generic", distance = 16,
	},
	follow = {wheat},
	runaway = true,
	drops = {},
}

local function update_horns (self)
	for index, bone in ipairs ({"horn_left", "horn_right"}) do
		local hidden = (self._lost_horns or 0) >= index
		self.object:set_bone_override (bone, hidden and {scale = {vec = vector.new (0.001, 0.001, 0.001)}} or nil)
	end
end

function goat:on_spawn ()
	if self._screaming_goat == nil then self._screaming_goat = math.random (100) <= 2 end
	self._lost_horns = self._lost_horns or (not self.child and math.random (50) == 1 and 1 or 0)
	return true
end

function goat:after_activate ()
	update_horns (self)
end

function goat:on_grown ()
	self.base_texture = {"mcl_goats_goat.png"}
	self:set_textures (self.base_texture)
	update_horns (self)
end

function goat:on_breed (mate)
	local chance = (self._screaming_goat or mate._screaming_goat) and 50 or 2
	core.add_entity (self.object:get_pos (), goat_name, core.serialize ({
		child = true,
		persistent = true,
		_screaming_goat = math.random (100) <= chance,
	}))
end

function goat:on_rightclick (player)
	local stack = player:get_wielded_item ()
	if stack:get_name () == wheat then
		self:feed_tame (player, nil, true)
	elseif not self.child and stack:get_name () == "mcl_buckets:bucket_empty" then
		if not core.is_creative_enabled (player:get_player_name ()) then
			stack:take_item ()
			player:set_wielded_item (stack)
		end
		local left = player:get_inventory ():add_item ("main", milk)
		if not left:is_empty () then core.add_item (self.object:get_pos (), left) end
		core.sound_play ("mobs_mc_cow_milk", {object = self.object, gain = 0.6}, true)
	end
end

local horn_blocks = {
	["mcl_core:stone"] = true, ["mcl_core:packed_ice"] = true,
	["mcl_core:stone_with_iron"] = true, ["mcl_core:stone_with_coal"] = true,
	["mcl_copper:stone_with_copper"] = true, ["mcl_core:stone_with_emerald"] = true,
}

local function drop_horn (self, pos, block)
	local node = core.get_node (block).name
	local trunk = core.get_item_group (node, "tree") > 0 and not node:find ("stripped", 1, true)
	if not self.child and (self._lost_horns or 0) < 2 and (horn_blocks[node] or trunk)
		and core.add_item (vector.offset (pos, 0, 0.6, 0), horn_item (math.random (4) + (self._screaming_goat and 4 or 0))) then
		self._lost_horns = (self._lost_horns or 0) + 1
		update_horns (self)
	end
end

local function valid_target (self, obj)
	if not obj or obj == self.object or not obj:is_valid () then return false end
	if obj:is_player () then
		return obj:get_hp () > 0 and not core.is_creative_enabled (obj:get_player_name ())
	end
	local entity = obj:get_luaentity ()
	return entity and entity.name ~= goat_name and not entity.dead and entity.is_mob
end

local function find_target (self, pos)
	local nearest, range = nil, 16
	for obj in core.objects_inside_radius (pos, 16) do
		if valid_target (self, obj) then
			local target = obj:get_pos ()
			local distance = vector.distance (pos, target)
			if distance >= 4 and distance < range and math.abs (target.y - pos.y) < 1.5
				and core.line_of_sight (vector.offset (pos, 0, 0.5, 0), vector.offset (target, 0, 0.5, 0)) then
				nearest, range = obj, distance
			end
		end
	end
	return nearest
end

local function next_ram (self)
	self._ram = nil
	self._ram_target = nil
	self._ram_ready = self._screaming_goat and math.random (5, 15) or math.random (30, 300)
	self.object:set_bone_override ("head", nil)
end

local function check_ram (self, pos, dtime)
	if self._ram then
		local ram = self._ram
		ram.time = ram.time - dtime
		if ram.time <= 0 then
			next_ram (self)
			return false
		end
		if ram.windup then
			self:halt_in_tracks ()
			if not valid_target (self, self._ram_target) then
				next_ram (self)
				return false
			end
			local target = self._ram_target:get_pos ()
			self:look_at (target)
			if ram.time < 1.3 then
				if vector.distance (ram.target, target) > 1.5 then
					next_ram (self)
					return false
				end
				local delta = vector.subtract (target, pos)
				ram.direction = vector.normalize (vector.new (delta.x, 0, delta.z))
				ram.windup = false
			end
		else
			for _, collision in ipairs (self._moveresult.collisions) do
				if collision.type == "node" and collision.axis ~= "y" then
					drop_horn (self, pos, collision.node_pos)
					next_ram (self)
					self:halt_in_tracks (true)
					return false
				end
			end
			for obj in core.objects_inside_radius (pos, 1.05) do
				if valid_target (self, obj) then
					local strength = self.child and 6 or 11
					obj:add_velocity (vector.add (vector.multiply (ram.direction, strength), vector.new (0, 3.5, 0)))
					next_ram (self)
					self:halt_in_tracks (true)
					return false
				end
			end
			self:go_to_pos (vector.add (pos, vector.multiply (ram.direction, 8)), 9, "run")
		end
		return "ram"
	end
	self._ram_ready = math.max (0, (self._ram_ready or 5) - dtime)
	if self._ram_ready == 0 and self._moveresult.touching_ground and self:check_timer ("goat_target", 1) then
		local target = find_target (self, pos)
		if target then
			self:cancel_navigation ()
			self:halt_in_tracks ()
			self._ram_target = target
			self._ram = {windup = true, time = 2.3, target = target:get_pos ()}
			self.object:set_bone_override ("head", {rotation = {vec = vector.new (-0.45, 0, 0), interpolation = 0.2}})
			core.sound_play ("mcl_goats_bleat", {object = self.object, max_hear_distance = 20,
				pitch = self._screaming_goat and 1.5 or 1, gain = self._screaming_goat and 1.2 or 0.8}, true)
			return "ram"
		end
	end
	return false
end

local function check_leap (self, pos)
	if not self._moveresult.touching_ground or not self:navigation_finished ()
		or not self:check_timer ("goat_leap", 22) then return false end
	local yaw = math.random () * 2 * math.pi
	local dir = core.yaw_to_dir (yaw)
	local goal = vector.round (vector.add (pos, vector.multiply (dir, 5)))
	for dy = 4, -1, -1 do
		local target = vector.offset (goal, 0, dy, 0)
		local floor_name = core.get_node (vector.offset (target, 0, -1, 0)).name
		local floor = core.registered_nodes[floor_name]
		if floor and floor.walkable and floor_name ~= "mcl_powder_snow:powder_snow"
			and core.get_node (target).name == "air"
			and core.get_node (vector.offset (target, 0, 1, 0)).name == "air"
			and core.line_of_sight (vector.offset (pos, 0, 2, 0), vector.offset (target, 0, 1.5, 0)) then
			self:look_at (target)
			self:halt_in_tracks ()
			self.object:set_velocity (vector.add (vector.multiply (dir, 7.5), vector.new (0, 12.5, 0)))
			return "leap"
		end
	end
	return false
end

function goat:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if data then
		data._ram = nil
		data._ram_target = nil
	end
	return data
end

goat.ai_functions = {mob_class.check_frightened, check_ram, mob_class.check_breeding,
	mob_class.check_following, check_leap, mob_class.check_pace}

mcl_mobs.register_mob (goat_name, goat)
mcl_mobs.register_egg (goat_name, S ("Goat"), "#dfd7c9", "#7d6a55", 0)
core.override_item (goat_name, {inventory_image = "mcl_goats_goat_spawn_egg.png"})

local animal_spawner = mobs_mc.animal_spawner
local goat_spawner = table.merge (animal_spawner, {
	name = goat_name,
	biomes = {"FrozenPeaks", "JaggedPeaks", "SnowySlopes"},
	weight = 5, pack_min = 1, pack_max = 3,
})

function goat_spawner:test_supporting_node (node)
	local name = node.name
	return animal_spawner.test_supporting_node (self, node) or name == "mcl_core:stone"
		or name == "mcl_core:packed_ice" or name == "mcl_core:snowblock"
end

mcl_mobs.register_spawner (goat_spawner)
