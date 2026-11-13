local S = core.get_translator(core.get_current_modname())
local mob_class = mcl_mobs.mob_class
local BEE = "mobs_mc:bee"
local RANGE = 12

local bee = {
	description = S("Bee"),
	type = "animal",
	_spawn_category = "creature",
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	drops = {},
	collisionbox = {-0.35, 0, -0.35, 0.35, 0.60, 0.35},
	head_eye_height = 0.30,
	visual = "mesh",
	mesh = "mobs_mc_bee.obj",
	_child_mesh = "mobs_mc_bee_baby.obj",
	textures = {{"mobs_mc_bee.png", "mobs_mc_bee_stinger.png"}},
	use_texture_alpha = true,
	visual_size = {x = 1, y = 1},
	movement_speed = 4.0,
	_no_fall_damage = true,
	can_ride_cart = false,
	can_ride_boat = false,
	attack_type = "null",
	pushable = false,
	makes_footstep_sound = false,
}

local function is_flower(name)
	return core.get_item_group(name, "flower") > 0
end

function bee:update_textures()
	local texture = "mobs_mc_bee"
	if self._bee_anger_time and self._bee_anger_time > 0 then texture = texture .. "_angry" end
	if self._bee_nectar then texture = texture .. "_nectar" end
	if self.child then texture = texture .. "_baby" end
	self.base_texture = {texture .. ".png", self._bee_stung and "blank.png" or "mobs_mc_bee_stinger.png"}
	self.base_mesh = self.initial_properties.mesh
	self.base_size = self.initial_properties.visual_size
	self.base_colbox = self.initial_properties.collisionbox
	self:set_textures(self.base_texture)
end

function bee:on_grown()
	self:update_textures()
end

function bee:anger_at(attacker)
	if not self._bee_stung and attacker and attacker:is_valid() and attacker ~= self.object then
		if attacker:is_player() and core.is_creative_enabled(attacker:get_player_name()) then
			return
		end
		self._bee_attacker = attacker
		self._bee_anger_time = 25
		self:update_textures()
	end
end

function mcl_beehives.alert_bees(pos, attacker)
	if not attacker then return end
	for object in core.objects_inside_radius(pos, 8) do
		local entity = object:get_luaentity()
		if entity and entity.name == BEE then entity:anger_at(attacker) end
	end
end

function bee:receive_damage(reason, damage)
	local pos = self.object:get_pos()
	local success = mob_class.receive_damage(self, reason, damage)
	if success and damage > 0 and pos and reason.source then
		mcl_beehives.alert_bees(pos, reason.source)
	end
	return success
end

function bee:actionable_on_rightclick(clicker)
	return is_flower(clicker:get_wielded_item():get_name()) or mob_class.actionable_on_rightclick(self, clicker)
end

function bee:on_rightclick(clicker)
	if is_flower(clicker:get_wielded_item():get_name()) then
		self:feed_tame(clicker, nil, true, false)
	end
end

function bee:on_breed()
	core.add_entity(self.object:get_pos(), BEE, core.serialize({child = true, persistent = true}))
end

function bee:beget_child(pos)
	local mate = self.mate and self.mate:get_luaentity()
	if not mate then return end
	self.mate, mate.mate = nil, nil
	self._mate_time, mate._mate_time = nil, nil
	self._mob_breeding, mate._mob_breeding = 0, 0
	self._mob_age, mate._mob_age = 6000, 6000
	mcl_experience.throw_xp(pos, math.random(1, 7))
	self:on_breed()
end

local function open_air(pos)
	local name = core.get_node(pos).name
	local def = core.registered_nodes[name]
	return def and name ~= "ignore" and not def.walkable and def.liquidtype == "none"
end

local function nearest(pos, candidates, predicate)
	local selected, best
	for _, candidate in ipairs(candidates) do
		local distance = vector.distance(pos, candidate)
		if distance <= RANGE and (not best or distance < best) and predicate(candidate) then
			selected, best = candidate, distance
		end
	end
	return selected
end

local function find_home(pos)
	local a, b = vector.offset(pos, -RANGE, -RANGE, -RANGE), vector.offset(pos, RANGE, RANGE, RANGE)
	return nearest(pos, core.find_nodes_in_area(a, b, {"group:beehive", "group:bee_nest"}), function(candidate)
		local node = core.get_node(candidate)
		return mcl_beehives.entrance(candidate, node) and mcl_beehives.has_room(candidate, node)
	end)
end

local function flower_target(pos)
	return vector.offset(pos, 0, 0.58, 0)
end

local function find_flower(pos)
	local a, b = vector.offset(pos, -RANGE, -6, -RANGE), vector.offset(pos, RANGE, 6, RANGE)
	return nearest(pos, core.find_nodes_in_area(a, b, {"group:flower"}), function(candidate)
		return open_air(vector.offset(candidate, 0, 1, 0))
			and core.line_of_sight(vector.offset(pos, 0, 0.2, 0), vector.offset(candidate, 0, 0.75, 0))
	end)
end

local crops = {}
local pollinatable = {plant_beetroot = true, plant_carrot = true, plant_melon_stem = true,
	plant_potato = true, plant_pumpkin_stem = true, plant_wheat = true}
core.register_on_mods_loaded(function()
	for id, def in pairs(mcl_farming.plant_lists) do
		if pollinatable[id] then
			for _, name in ipairs(def.names) do crops[name] = id end
		end
	end
end)

local function fertilize_below(self, pos)
	for depth = 1, 2 do
		local target = vector.round(vector.offset(pos, 0, -depth, 0))
		local node = core.get_node(target)
		if crops[node.name] then
			if mcl_farming:grow_plant(crops[node.name], target, node, 1, true) then
				self._bee_crops = (self._bee_crops or 0) + 1
			end
			return
		end
	end
end

local function defend(self, pos, dtime)
	local attacker = self._bee_attacker
	if not self._bee_anger_time or self._bee_anger_time <= 0 then return false end
	self._bee_anger_time = self._bee_anger_time - dtime
	if self._bee_anger_time <= 0 or not attacker or not attacker:is_valid() then
		self._bee_anger_time, self._bee_attacker = 0, nil
		self:update_textures()
		return false
	end
	local target = attacker:get_pos()
	if not target or vector.distance(pos, target) > 24 or attacker:get_hp() <= 0 then
		self._bee_anger_time, self._bee_attacker = 0, nil
		self:update_textures()
		return false
	end
	target = vector.offset(target, 0, 0.75, 0)
	if vector.distance(pos, target) <= 1.05 and core.line_of_sight(pos, target) then
		local difficulty = mcl_vars.difficulty
		if difficulty > 0 then
			mcl_util.deal_damage(attacker, difficulty == 3 and 3 or 2, {type = "mob", source = self.object})
			if difficulty >= 2 then
				mcl_potions.give_effect_by_level("poison", attacker, 1, difficulty == 3 and 18 or 10)
			end
		end
		self._bee_stung = true
		self._bee_stung_time = 60
		self._bee_anger_time, self._bee_attacker = 0, nil
		self:update_textures()
	else
		self._bee_target = target
	end
	return true
end

local function wander(self, pos)
	if self._bee_wander and self._bee_wander_time > 0 and vector.distance(pos, self._bee_wander) > 0.4 then
		self._bee_target = self._bee_wander
		return
	end
	self._bee_wander, self._bee_wander_time = nil, 2
	for _ = 1, 4 do
		local candidate = vector.offset(pos, math.random(-4, 4), math.random(-2, 2), math.random(-4, 4))
		local ground = vector.offset(candidate, 0, -2, 0)
		if open_air(candidate) and not open_air(ground) and core.line_of_sight(pos, candidate) then
			self._bee_wander = candidate
			self._bee_target = candidate
			return
		end
	end
end

local function get_home_entrance(self, pos)
	local home = self._bee_home
	if home then
		local node = core.get_node(home)
		local entrance = mcl_beehives.is_home(node.name) and mcl_beehives.entrance(home, node)
		if entrance and vector.distance(pos, home) <= RANGE and mcl_beehives.has_room(home, node) then
			return entrance, node
		end
	end
	if self._bee_home_search > 0 then return nil end
	self._bee_home_search = 3
	self._bee_home = find_home(pos)
	if self._bee_home then
		local node = core.get_node(self._bee_home)
		return mcl_beehives.entrance(self._bee_home, node), node
	end
end

local function seek_mate(self, pos, dtime)
	if not self:is_breeding() then return false end
	local mate = self.mate
	if mate and mate:is_valid() then
		local entity = mate:get_luaentity()
		local target = mate:get_pos()
		if entity and entity.mate == self.object and entity:is_breeding() and target then
			if vector.distance(pos, target) < 1.4 and core.line_of_sight(pos, target) then
				self._mate_time = (self._mate_time or 0) + dtime
				if self._mate_time > 1.5 then self:beget_child(pos) end
			else
				self._bee_target = target
				self._mate_time = 0
			end
			return true
		end
	end
	self.mate, self._mate_time = nil, nil
	self._bee_mate_search = (self._bee_mate_search or 0) - dtime
	if self._bee_mate_search > 0 then return false end
	self._bee_mate_search = 1
	for candidate in core.objects_inside_radius(pos, 8) do
		if self:can_mate_with(candidate) then
			local entity = candidate:get_luaentity()
			self.mate, entity.mate = candidate, self.object
			self._mate_time, entity._mate_time = 0, 0
			return true
		end
	end
	return false
end

function bee:ai_step(dtime)
	mob_class.ai_step(self, dtime)
	local pos = self.object:get_pos()
	if not pos then return end
	self._bee_target = nil
	self._bee_home_search = (self._bee_home_search or 0) - dtime
	self._bee_flower_search = (self._bee_flower_search or 0) - dtime
	self._bee_wander_time = (self._bee_wander_time or 0) - dtime
	if self._bee_stung then
		self._bee_stung_time = (self._bee_stung_time or 60) - dtime
		if self._bee_stung_time <= 0 then
			self:damage_mob("starve", 20)
			return
		end
		wander(self, pos)
		return
	end
	if defend(self, pos, dtime) then return end
	if seek_mate(self, pos, dtime) then return end
	local forage = mcl_beehives.can_forage(pos)
	local entrance, home_node = get_home_entrance(self, pos)
	if self._bee_nectar or not forage then
		if entrance then
			if self._bee_nectar then
				self._bee_pollen_timer = (self._bee_pollen_timer or 1) - dtime
				if self._bee_pollen_timer <= 0 and (self._bee_crops or 0) < 10 then
					self._bee_pollen_timer = 1
					fertilize_below(self, pos)
				end
			end
			if vector.distance(pos, entrance) < 0.52 then
				mcl_beehives.admit(self._bee_home, home_node, self)
				return
			end
			self._bee_target = entrance
			return
		end
	elseif not self._bee_nectar then
		local flower = self._bee_flower
		if flower and (not is_flower(core.get_node(flower).name) or vector.distance(pos, flower) > RANGE) then
			flower = nil
			self._bee_pollination = 0
		end
		if not flower and self._bee_flower_search <= 0 then
			flower = find_flower(pos)
			self._bee_flower_search = 3
		end
		self._bee_flower = flower
		if flower then
			self._bee_target = flower_target(flower)
			if vector.distance(pos, self._bee_target) < 0.65 then
				self._bee_pollination = (self._bee_pollination or 0) + dtime
				if self._bee_pollination >= 20 then
					self._bee_flower, self._bee_pollination = nil, 0
					self._bee_nectar, self._bee_crops = true, 0
					self:update_textures()
				end
			else
				self._bee_pollination = 0
			end
			return
		end
	end
	wander(self, pos)
end

function bee:motion_step(dtime, _, pos)
	local target = self._bee_target
	local desired = vector.zero()
	if target then
		local delta = vector.subtract(target, pos)
		local distance = vector.length(delta)
		if distance > 0.08 then
			local speed = self.movement_speed * (self._bee_anger_time and self._bee_anger_time > 0 and 1.6 or 1)
			desired = vector.multiply(delta, math.min(speed / distance, 3.0))
		end
	end
	local velocity = self.object:get_velocity()
	local new_velocity = vector.add(velocity, vector.multiply(vector.subtract(desired, velocity), math.min(1, dtime * 8)))
	self.object:set_velocity(new_velocity)
	if math.abs(new_velocity.x) + math.abs(new_velocity.z) > 0.12 then
		self:set_yaw(math.atan2(new_velocity.z, new_velocity.x) - math.pi / 2)
	end
end

function bee:get_staticdata_table()
	local data = mob_class.get_staticdata_table(self)
	if data then
		data._bee_target = nil
		data._bee_wander = nil
		data._bee_attacker = nil
	end
	return data
end

mcl_mobs.register_mob(BEE, bee)
core.register_craftitem(":" .. BEE, {
	description = S("Bee Spawn Egg"),
	inventory_image = "mobs_mc_spawn_icon_bee.png",
	groups = {spawn_egg = 1},
	on_place = function(itemstack, placer, pointed)
		local result = mcl_util.call_on_rightclick(itemstack, placer, pointed)
		if result then return result end
		if not placer or pointed.type ~= "node" then return itemstack end
		local name = placer:get_player_name()
		if core.is_protected(pointed.above, name) then
			core.record_protection_violation(pointed.above, name)
			return itemstack
		end
		local pos = vector.offset(pointed.above, 0, -0.5, 0)
		local object = core.add_entity(pos, BEE, core.serialize({persistent = true}))
		if object and object:is_valid() then
			object:get_luaentity():set_nametag(itemstack:get_meta():get_string("name"))
			if not core.is_creative_enabled(name) then itemstack:take_item() end
		end
		return itemstack
	end,
})
