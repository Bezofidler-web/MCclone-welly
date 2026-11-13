-- SPDX-License-Identifier: GPL-3.0-or-later

local modpath = core.get_modpath (core.get_current_modname ())
local S = core.get_translator ("mcl_sulfur_cube")
local archetypes, archetype_for = dofile (modpath .. "/archetypes.lua")
local mob_class = mcl_mobs.mob_class
local big_id, small_id = "mobs_mc:sulfur_cube", "mobs_mc:sulfur_cube_small"
local filled_bucket, empty_bucket = "mcl_buckets:bucket_sulfur_cube", "mcl_buckets:bucket_empty"
local slimeball = "mcl_mobitems:slimeball"
local goo = "mcl_sulfur_cube_goo.png"
local gravity = 32

core.register_entity ("mcl_sulfur_cube:contents", {
	initial_properties = {visual = "wielditem", wield_item = "mcl_sulfur:sulfur", visual_size = {x = 0.61, y = 0.61},
		physical = false, collide_with_objects = false, pointable = false, static_save = false},
	on_activate = function (self) self.object:set_armor_groups ({immortal = 1}) end,
	on_step = function (self)
		if not self.object:get_attach () then self.object:remove () end
	end,
})

local function play (self, sound, pitch)
	core.sound_play (sound, {object = self.object, gain = 0.6, pitch = pitch or 1, max_hear_distance = 16}, true)
end

local function show_contents (self)
	if self._display and self._display:is_valid () then self._display:remove () end
	self._display = nil
	local small = self.name == small_id
	local suffix = small and "_small" or ""
	local inner = self._contents and "blank.png" or "mcl_sulfur_cube_inner" .. suffix .. ".png"
	self:set_textures ({inner, "mcl_sulfur_cube_outer" .. suffix .. ".png"})
	if self._contents then
		self.object:set_properties ({stepheight = 0})
		local display = core.add_entity (self.object:get_pos (), "mcl_sulfur_cube:contents")
		if display then
			display:set_properties ({wield_item = self._contents})
			display:set_attach (self.object, "", vector.new (0, 5.2, 0), vector.zero ())
			self._display = display
		end
	else
		self.object:set_properties ({stepheight = self._initial_step_height})
	end
end

local function absorb (self, name)
	if self.dead or self.removed or self.name == small_id or self._contents or not archetype_for (name) then return false end
	self._contents = name
	self.persistent = true
	self._hop_delay = 0
	self:halt_in_tracks (true)
	self:set_yaw (0)
	self.object:set_yaw (self.rotate)
	mcl_burning.extinguish (self.object)
	show_contents (self)
	play (self, "green_slime_attack", 0.8)
	return true
end

local function eject (self)
	if not self._contents or self._fuse then return false end
	local pos = vector.offset (self.object:get_pos (), 0, 0.6, 0)
	local drop = core.add_item (pos, self._contents)
	if not drop then return false end
	-- Prevent the cube from immediately swallowing the block it just dropped.
	drop:set_velocity (vector.new (0, 3.5, 0))
	self._contents = nil
	self._feed_cooldown = 3
	self._fall_distance = 0
	self._last_fall_y = nil
	show_contents (self)
	play (self, "green_slime_attack", 1.2)
	return true
end

local function prime (self, seconds)
	if self._contents ~= "mcl_tnt:tnt" or self._fuse then return false end
	self._fuse = seconds
	play (self, "tnt_ignite")
	return true
end

local function can_capture (self)
	return self.name == big_id and not self._fuse and not self.object:get_attach ()
end

local function capture (self, player, stack)
	if not can_capture (self) then return end
	local item = ItemStack (filled_bucket)
	local meta = item:get_meta ()
	meta:set_string ("properties", core.serialize ({_contents = self._contents, nametag = self:get_nametag (), health = self.health}))
	local name = player:get_player_name ()
	if not core.is_creative_enabled (name) then stack:take_item () end
	if stack:is_empty () then
		player:set_wielded_item (item)
	else
		local inv = player:get_inventory ()
		if not inv:room_for_item ("main", item) then return end
		inv:add_item ("main", item)
		player:set_wielded_item (stack)
	end
	play (self, "green_slime_attack", 1.1)
	self:safe_remove ()
end

local function is_flint (name)
	return core.get_item_group (name, "flint_and_steel") > 0
end

local cube = {
	description = S ("Sulfur Cube"),
	type = "animal",
	_spawn_category = "monster",
	persist_in_peaceful = true,
	does_not_prevent_sleep = true,
	hp_min = 8,
	hp_max = 8,
	xp_min = 1,
	xp_max = 2,
	drops = {},
	visual = "mesh",
	mesh = "mcl_sulfur_cube.obj",
	visual_size = {x = 1, y = 1},
	textures = {{"mcl_sulfur_cube_inner.png", "mcl_sulfur_cube_outer.png"}},
	use_texture_alpha = true,
	collisionbox = {-0.49, 0, -0.49, 0.49, 0.98, 0.49},
	can_ride_boat = false,
	can_ride_cart = true,
	tnt_knockback = true,
	can_despawn = true,
	makes_footstep_sound = false,
	floats = 1,
	ai_functions = {},
	sounds = {damage = "green_slime_damage", death = "green_slime_death"},
}

function cube:mob_activate (staticdata, dtime)
	if mob_class.mob_activate (self, staticdata, dtime) == false then return false end
	if not self._contents or not archetype_for (self._contents) or self.name == small_id then
		self._contents, self._fuse = nil, nil
	end
	show_contents (self)
	return true
end

function cube:on_deactivate (removal)
	if self._display and self._display:is_valid () then self._display:remove () end
	mob_class.on_deactivate (self, removal)
end

function cube:actionable_on_rightclick (player)
	local name = player:get_wielded_item ():get_name ()
	if self.name == small_id then return name == slimeball end
	if name == empty_bucket then return can_capture (self) end
	if self._contents then
		return not self._fuse and (core.get_item_group (name, "shears") > 0
			or self._contents == "mcl_tnt:tnt" and is_flint (name))
	end
	return archetype_for (name) ~= nil or mob_class.actionable_on_rightclick (self, player)
end

function cube:on_rightclick (player)
	if self.dead or self.removed or not player:is_player () then return end
	local name = player:get_player_name ()
	local pos = vector.round (self.object:get_pos ())
	if core.is_protected (pos, name) then
		core.record_protection_violation (pos, name)
		return
	end
	local stack = player:get_wielded_item ()
	local item = stack:get_name ()
	if item == empty_bucket then
		capture (self, player, stack)
		return
	end
	local wear, consumed
	if self.name == small_id then
		consumed = item == slimeball and self:replace_with (big_id, false, {persistent = true})
	elseif self._contents then
		wear = (core.get_item_group (item, "shears") > 0 and eject (self)) or (is_flint (item) and prime (self, 6))
	else
		consumed = absorb (self, item)
	end
	if not core.is_creative_enabled (name) then
		if consumed then stack:take_item () end
		if wear then mcl_util.use_item_durability (stack, 1) end
		if wear or consumed then player:set_wielded_item (stack) end
	end
end

function cube:_on_dispense (stack)
	if self.dead or self.removed or self.name == small_id or self._fuse
		or core.is_protected (vector.round (self.object:get_pos ()), "") then return end
	local name = stack:get_name ()
	if (core.get_item_group (name, "shears") > 0 and eject (self)) or (is_flint (name) and prime (self, 6)) then
		mcl_util.use_item_durability (stack, 1)
		return stack
	end
	if archetype_for (name) and self._contents ~= name then
		if self._contents and not eject (self) then return end
		if absorb (self, name) then
			stack:take_item ()
			return stack
		end
	end
	return mob_class._on_dispense (self, stack)
end

function cube:receive_damage (reason, damage)
	if self.dead or self.removed then return false end
	if self._fuse and reason.type ~= "out_of_world" then return false end
	if self._contents and damage > 0 then
		if self._contents == "mcl_tnt:tnt" and reason.type == "explosion" then
			prime (self, 0.75 + math.random () * 2.25)
			return false
		elseif self._contents == "mcl_tnt:tnt" and reason.flags and reason.flags.is_fire then
			prime (self, 6)
			return false
		elseif reason.type == "fall" or reason.source and reason.source:is_player () then
			return false
		end
	end
	return mob_class.receive_damage (self, reason, damage)
end

function cube:do_punch (hitter, elapsed, caps, direction)
	if not self._contents then return end
	if not hitter or not hitter:is_player () then return end
	if self.dead or self.removed then return false end
	if core.is_protected (vector.round (self.object:get_pos ()), hitter:get_player_name ()) then return false end
	local profile = archetypes[archetype_for (self._contents)]
	local heading = direction or hitter:get_look_dir ()
	local horizontal = vector.normalize (vector.new (heading.x, 0, heading.z))
	local factor = math.max (0.2, math.min (1, elapsed / (caps and caps.full_punch_interval or 1)))
	local before = vector.multiply (self.object:get_velocity (), 0.5)
	local lift = math.max (0, heading.y) * profile.lift
	local after = vector.add (before, vector.multiply (horizontal, profile.speed * factor))
	after.y = math.max (before.y, 0) + (profile.lift + lift) * factor
	self.object:set_velocity (after)
	play (self, "green_slime_attack", 0.7 + profile.bounce * 0.5)
	return false
end

function cube:motion_step (dtime, result, pos)
	if not self._contents or not result or self.object:get_attach () then
		return mob_class.motion_step (self, dtime, result, pos)
	end
	local profile = archetypes[archetype_for (self._contents)]
	local v = self.object:get_velocity ()
	for _, collision in ipairs (result.collisions) do
		local axis = collision.axis
		local impact = collision.old_velocity[axis]
		local cutoff = axis == "y" and 1.6 or 0.3
		if math.abs (impact) > cutoff then v[axis] = -impact * profile.bounce end
	end
	local grounded = result.touching_ground or result.standing_on_object
	local rate = grounded and v.y < 1 and profile.friction or profile.drag
	if self._liquidtype and self._liquidtype ~= "none" then rate = rate + 3 end
	local drag = math.exp (-rate * dtime)
	v.x, v.z = v.x * drag, v.z * drag
	if self._immersion_depth and self._immersion_depth > 0.55 and profile.buoyant then
		v.y = math.min (2, (v.y + gravity * dtime * 0.33) * drag)
	elseif not grounded or v.y > 0 then
		v.y = math.max (-48, v.y - gravity * dtime)
	end
	self:check_collision (pos, v, dtime * profile.speed * 2)
	self.object:set_velocity (v)
end

local function closest_food (self, pos)
	local closest, best = nil, 8
	local small = self.name == small_id
	for object in core.objects_inside_radius (pos, best) do
		local valid = false
		local stack
		if object:is_player () and object:get_hp () > 0 and mcl_gamemode.get_gamemode (object) ~= "spectator" then
			stack = object:get_wielded_item ()
			valid = small and stack:get_name () == slimeball or not small and archetype_for (stack:get_name ())
		elseif not small and (self._feed_cooldown or 0) <= 0 then
			local item = object:get_luaentity ()
			if item and item.name == "__builtin:item" and item.age >= 1 then
				stack = ItemStack (item.itemstring)
				valid = archetype_for (stack:get_name ())
			end
		end
		if valid then
			local distance = vector.distance (pos, object:get_pos ())
			if distance <= 1.2 and not object:is_player () and absorb (self, stack:get_name ()) then
				stack:take_item ()
				if stack:is_empty () then object:remove () else object:get_luaentity ():set_item (stack:to_string ()) end
				return nil
			end
			if distance < best and self:target_visible (pos, object) then closest, best = object, distance end
		end
	end
	return closest
end

function cube:run_ai (dtime, result)
	if not result or self._contents or self.object:get_attach () then return end
	self._hop_delay = math.max (0, (self._hop_delay or 0) - dtime)
	self._feed_cooldown = math.max (0, (self._feed_cooldown or 0) - dtime)
	if self._hop_delay > 0 or not result.touching_ground then return end
	local pos = self.object:get_pos ()
	local target = closest_food (self, pos)
	if self._contents then return end
	if target then self:look_at (target:get_pos ()) else self:set_yaw (math.random () * math.pi * 2) end
	self._hop_delay = target and 0.45 or 0.9 + math.random () * 2
	self.movement_goal = "go_pos"
	self.movement_target = target and target:get_pos () or pos
	self.movement_velocity = self.name == small_id and 4 or 5
	self._jump = true
	play (self, "green_slime_jump", self.name == small_id and 1.3 or 0.9)
	core.add_particle ({pos = vector.offset (pos, 0, 0.08, 0), velocity = vector.new (0, 0.6, 0),
		expirationtime = 0.4, size = 2, texture = goo})
end

function cube:do_go_pos (_, result)
	local moving = self._jump or not result.touching_ground
	self.acc_speed = moving and self.movement_velocity or 0
	self.acc_dir.z = moving and self.movement_velocity / 20 or 0
end

function cube:do_custom (dtime)
	if not self._contents then return end
	local pos = self.object:get_pos ()
	if self._fuse then
		self._fuse = self._fuse - dtime
		if self._fuse <= 0 then
			self:safe_remove ()
			mcl_explosions.explode (vector.offset (pos, 0, 0.5, 0), 3, {}, self.object)
			return false
		end
		if self._display and self._display:is_valid () then
			self._display:set_texture_mod (math.floor (self._fuse * 8) % 2 == 0 and "^[brighten" or "")
		end
	end
	self._effect_delay = (self._effect_delay or 0) - dtime
	if self._effect_delay > 0 then return end
	self._effect_delay = 0.2
	if self._contents == "mcl_nether:magma" then
		for other in core.objects_inside_radius (vector.offset (pos, 0, 0.45, 0), 1.1) do
			local entity = other:get_luaentity ()
			if other ~= self.object and (other:is_player () or entity and entity.is_mob) then
				mcl_util.deal_damage (other, 1, {type = "hot_floor", direct = self.object})
			end
		end
	elseif self._contents == "mcl_tnt:tnt" and not self._fuse then
		local nodepos = vector.round (pos)
		local node = core.get_node (nodepos)
		if core.get_item_group (node.name, "fire") > 0 or self._liquidtype == "lava"
			or mcl_redstone.get_power (nodepos) > 0 then
			prime (self, 6)
		end
	end
end

function cube:on_die (pos)
	if self.name == small_id or self._fuse then return end
	if self._contents then core.add_item (vector.offset (pos, 0, 0.5, 0), self._contents) end
	local angle = math.random () * math.pi * 2
	for side = -1, 1, 2 do
		local direction = vector.new (math.cos (angle) * side, 0, math.sin (angle) * side)
		local target = vector.add (pos, vector.multiply (direction, 0.3))
		local child = core.add_entity (target, small_id, core.serialize ({persistent = self.persistent}))
		if child then child:set_velocity (vector.add (direction, vector.new (0, 1.5, 0))) end
	end
end

mcl_mobs.register_mob (big_id, cube)
mcl_mobs.register_mob (small_id, table.merge (cube, {
	hp_min = 4, hp_max = 4, xp_min = 0, xp_max = 0,
	mesh = "mcl_sulfur_cube_small.obj",
	textures = {{"mcl_sulfur_cube_inner_small.png", "mcl_sulfur_cube_outer_small.png"}},
	collisionbox = {-0.245, 0, -0.245, 0.245, 0.49, 0.245},
}))
mcl_mobs.register_egg (big_id, S ("Sulfur Cube"), "#edca42", "#ad4b24")
core.override_item (big_id, {inventory_image = "mcl_sulfur_cube_spawn_egg.png"})

local spawner = table.merge (mcl_mobs.default_spawner, {
	name = big_id, biomes = mobs_mc.overworld_biomes, spawn_category = "monster",
	weight = 100, pack_min = 2, pack_max = 4, is_canonical = true,
})

function spawner:test_spawn_position (spawn_pos, node_pos, data, cache, flag)
	if flag ~= "spawner" then
		local below = self:get_node (cache, -1, node_pos)
		if below.name ~= "mcl_sulfur:sulfur" or node_pos.y < mcl_vars.mg_overworld_min
			or node_pos.y > -24 or (core.get_natural_light (node_pos, 0.5) or 15) > 7 then
			return false
		end
	end
	return mcl_mobs.default_spawner.test_spawn_position (self, spawn_pos, node_pos, data, cache, flag)
end

mcl_mobs.register_spawner (spawner)

local function release (stack, pos, player)
	local node = core.get_node (pos)
	local def = core.registered_nodes[node.name]
	local player_name = player and player:get_player_name () or ""
	if not def or def.walkable or node.name == "ignore" or core.is_protected (pos, player_name) then return stack end
	local meta = stack:get_meta ()
	local data = core.deserialize (meta:get_string ("properties"), true)
	if type (data) ~= "table" then data = {} end
	local custom_name = meta:get_string ("name")
	local props = {
		_contents = type (data._contents) == "string" and data._contents or nil,
		nametag = custom_name ~= "" and custom_name or (type (data.nametag) == "string" and data.nametag or nil),
		health = math.max (1, math.min (8, tonumber (data.health) or 8)),
		persistent = true,
	}
	local object = core.add_entity (vector.offset (pos, 0, -0.5, 0), big_id, core.serialize (props))
	if not object or not object:is_valid () then return stack end
	play (object:get_luaentity (), "green_slime_attack", 0.9)
	return player and core.is_creative_enabled (player_name) and stack or ItemStack (empty_bucket)
end

local function place_bucket (stack, player, pointed)
	local result = mcl_util.call_on_rightclick (stack, player, pointed)
	if result then return result end
	if pointed.type ~= "node" then return stack end
	return release (stack, pointed.above, player)
end

core.register_craftitem (":" .. filled_bucket, {
	description = S ("Bucket of Sulfur Cube"),
	inventory_image = "mcl_sulfur_cube_bucket.png",
	stack_max = 1,
	groups = {bucket = 1},
	on_place = place_bucket,
	_on_dispense = function (stack, _, pos) return release (stack, pos, nil) end,
})

if mcl_levelgen.levelgen_enabled then
	mcl_levelgen.register_levelgen_script (modpath .. "/cave.lua")
elseif core.get_mapgen_setting ("mg_name") ~= "singlenode" then
	core.ipc_set ("mcl_sulfur_cube:native_min_y", mcl_vars.mg_overworld_min)
	core.register_mapgen_script (modpath .. "/cave.lua")
end
