local S = core.get_translator (core.get_current_modname ())
local mob_class = mcl_mobs.mob_class
local ID = "mobs_mc:panda"
local BAMBOO = "mcl_bamboo:bamboo_small"

-- The weighted genes used by Java 26.3. Brown and weak are recessive.
local gene_pool = {
	"lazy", "worried", "playful", "weak", "aggressive", "weak", "weak", "weak",
	"weak", "brown", "brown", "normal", "normal", "normal", "normal", "normal",
}
local known_genes = {}
for _, gene in ipairs (gene_pool) do known_genes[gene] = true end

local function random_gene ()
	return gene_pool[math.random (#gene_pool)]
end

local function inherited_gene (parent)
	if math.random (32) == 1 then return random_gene () end
	if math.random (2) == 1 then return parent._panda_main_gene end
	return parent._panda_hidden_gene
end

local function select_coat (self)
	local main, hidden = self._panda_main_gene, self._panda_hidden_gene
	if (main == "brown" or main == "weak") and main ~= hidden then return "normal" end
	return main
end

local function apply_texture (self)
	local suffix = self.child and "_baby.png" or ".png"
	self.base_texture = {"mcl_pandas_panda_" .. self._panda_coat .. suffix}
	self:set_textures (self.base_texture)
end

local panda = {
	description = S ("Panda"),
	type = "animal",
	_spawn_category = "creature",
	hp_min = 20,
	hp_max = 20,
	xp_min = 1,
	xp_max = 3,
	drops = {{name = BAMBOO, chance = 1, min = 1, max = 1}},
	attack_type = "melee",
	damage = 6,
	reach = 1.5,
	view_range = 12,
	tracking_distance = 12,
	visual = "mesh",
	mesh = "mcl_pandas_panda.b3d",
	_child_mesh = "mcl_pandas_panda_baby.b3d",
	textures = {{"mcl_pandas_panda_normal.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.65, 0, -0.65, 0.65, 1.25, 0.65},
	head_eye_height = 0.94,
	movement_speed = 3.0,
	follow = {BAMBOO},
	follow_distance = 10,
	floats = 1,
	can_ride_boat = false,
	makes_footstep_sound = true,
	sounds = {eat = "mobs_mc_animal_eat_generic", distance = 12},
	animation = {
		stand_start = 0, stand_end = 20, stand_speed = 10,
		walk_start = 21, walk_end = 41, walk_speed = 20,
		run_start = 21, run_end = 41, run_speed = 28,
		eat_start = 42, eat_end = 62, eat_speed = 20,
		back_start = 63, back_end = 83, back_speed = 10,
		roll_start = 84, roll_end = 104, roll_speed = 20, roll_loop = false,
		scare_start = 105, scare_end = 125, scare_speed = 20,
	},
}

function panda:mob_activate (staticdata, dtime)
	if not mob_class.mob_activate (self, staticdata, dtime) then return false end
	if not known_genes[self._panda_main_gene] then self._panda_main_gene = random_gene () end
	if not known_genes[self._panda_hidden_gene] then self._panda_hidden_gene = random_gene () end
	self._panda_coat = select_coat (self)
	if self._panda_coat == "weak" then
		self.object:set_properties ({hp_max = 10})
		self.health = math.min (self.health, 10)
		self:update_tag ()
	elseif self._panda_coat == "lazy" then
		self:add_physics_factor ("movement_speed", "panda_lazy", 0.07 / 0.15)
	elseif self._panda_coat == "worried" then
		self.runaway_from = {"players", "monsters"}
		self.runaway_view_range = 8
		self._runaway_monster_view_range = 4
	end
	apply_texture (self)
	return true
end

function panda:on_grown ()
	apply_texture (self)
end

local function scared (self)
	return self._panda_coat == "worried" and mcl_weather.get_weather () == "thunder"
end

function panda:actionable_on_rightclick (player)
	return self._panda_pose == "back" or player:get_wielded_item ():get_name () == BAMBOO
		or mob_class.actionable_on_rightclick (self, player)
end

function panda:on_rightclick (player)
	if not player:is_player () or scared (self) then return end
	if self._panda_pose == "back" then
		self._panda_pose, self._panda_pose_time = nil, nil
		return
	end
	local stack = player:get_wielded_item ()
	if stack:get_name () ~= BAMBOO then return end
	self._panda_bitten = self._active_target
	if self:feed_tame (player, nil, true, false) then return end
	if self._panda_pose or core.get_item_group (self.standing_in, "water") > 0 then return end
	if not core.is_creative_enabled (player:get_player_name ()) then
		stack:take_item ()
		player:set_wielded_item (stack)
	end
	self:cancel_navigation ()
	self:halt_in_tracks (false, true)
	self._panda_pose, self._panda_pose_time = "eat", 2
	self:mob_sound ("eat", nil, true)
end

local function bamboo_near (pos)
	local a, b = vector.offset (pos, -7, 0, -7), vector.offset (pos, 7, 2, 7)
	for _, found in ipairs (core.find_nodes_in_area (a, b, {"group:bamboo_tree"})) do
		-- Java accepts grown bamboo, including the lower part of a stalk.
		if core.get_item_group (core.get_node (found).name, "bamboo_tree") > 1 then return true end
	end
	return false
end

local function check_breeding (self, pos, dtime)
	if not self:is_breeding () then return false end
	if not self.mate and (self._panda_bamboo_near == nil or self:check_timer ("panda_bamboo", 1)) then
		self._panda_bamboo_near = bamboo_near (vector.round (pos))
	end
	if self.mate or self._panda_bamboo_near then
		return mob_class.check_breeding (self, pos, dtime)
	end
	return false
end

function panda:on_breed (mate)
	local first, second = self, mate
	if math.random (2) == 1 then first, second = mate, self end
	local pos = self.object:get_pos ()
	local child = core.add_entity (pos, ID, core.serialize ({
		child = true,
		persistent = true,
		_panda_main_gene = inherited_gene (first),
		_panda_hidden_gene = inherited_gene (second),
	}))
	local entity = child and child:get_luaentity ()
	if entity then entity:prevent_phasing (entity.collisionbox) end
end

function panda:receive_damage (reason, damage)
	if damage > 0 and reason.source then
		self._panda_bitten = nil
		self._panda_pose, self._panda_pose_time = nil, nil
	end
	return mob_class.receive_damage (self, reason, damage)
end

function panda:get_active_target ()
	if self._active_target ~= self._panda_bitten then return self._active_target end
end

function panda:custom_attack ()
	mob_class.custom_attack (self)
	if self._panda_coat ~= "aggressive" then self._panda_bitten = self.attack end
end

local function pose_activity (self, _, dtime)
	if scared (self) and core.get_item_group (self.standing_in, "water") == 0 then
		self:cancel_navigation ()
		self:halt_in_tracks (false, true)
		self:set_animation ("scare")
		return true
	end
	local pose = self._panda_pose
	if pose then
		self._panda_pose_time = self._panda_pose_time - dtime
		if self._panda_pose_time <= 0 then
			self._panda_pose, self._panda_pose_time = nil, nil
			if pose == "roll" then self:cancel_navigation () end
			return false
		end
		self:set_animation (pose)
		if pose == "roll" then self:go_to_stupidly (self._panda_roll_target, 0.75) end
		return true
	end
	return false
end

local function temperament_idle (self, pos, _, moveresult)
	if not moveresult.touching_ground or not self:navigation_finished () or not self:check_timer ("panda_idle", 2) then
		return false
	end
	if self.child and math.random (self._panda_coat == "weak" and 14 or 150) == 1 then
		local nose = vector.offset (pos, 0, self.head_eye_height, 0)
		mcl_mobs.effect (nose, 6, "mcl_particles_smoke.png", 1, 2, 1, 0.3)
		if mcl_vars.mobs_drop_items and math.random (700) == 1 then core.add_item (pos, "mcl_mobitems:slimeball") end
	elseif self._panda_coat == "lazy" and math.random (5) == 1 then
		self._panda_pose, self._panda_pose_time = "back", 4
		self:halt_in_tracks (false, true)
		return true
	elseif self._panda_coat == "playful" and math.random (12) == 1 then
		self._panda_pose, self._panda_pose_time = "roll", 1
		self._panda_roll_target = vector.add (pos, vector.multiply (core.yaw_to_dir (self:get_yaw ()), 2))
		return true
	end
	return false
end

function panda:get_staticdata_table ()
	local data = mob_class.get_staticdata_table (self)
	if data then
		data._panda_pose, data._panda_pose_time = nil, nil
		data._panda_roll_target, data._panda_bamboo_near = nil, nil
	end
	return data
end

panda._targeting_rules = {
	mcl_mobs.build_retaliation_target_rule (
		function (self) return self.child end,
		true,
		function (_, _, _, entity)
			return entity and entity.name == ID and entity._panda_coat == "aggressive" and not entity.child
		end),
	mcl_mobs.build_alert_receiver_rule (),
}

panda.ai_functions = {
	pose_activity, mob_class.check_frightened, check_breeding, mob_class.check_attack, mob_class.check_following,
	mob_class.check_avoid, temperament_idle, mob_class.check_pace,
}

mcl_mobs.register_mob (ID, panda)
mcl_mobs.register_egg (ID, S ("Panda"), "#e7e5dc", "#222222", 0)
core.override_item (ID, {inventory_image = "mcl_pandas_spawn_egg.png"})

local spawner = table.merge (mobs_mc.animal_spawner, {
	name = ID,
	weight = 1,
	pack_min = 1,
	pack_max = 2,
	biomes = {"Jungle"},
})

function spawner:spawn (pos, index, data, pack_size)
	if index > 1 and math.random (5) == 1 then
		data = table.merge (data or {}, {child = true})
	end
	return mcl_mobs.default_spawner.spawn (self, pos, index, data, pack_size)
end

mcl_mobs.register_spawner (spawner)
mcl_mobs.register_spawner (table.merge (spawner, {weight = 80, biomes = {"BambooJungle"}}))
