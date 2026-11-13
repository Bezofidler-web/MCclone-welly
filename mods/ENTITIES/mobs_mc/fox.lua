local S = core.get_translator ("mobs_mc")
local mob_class = mcl_mobs.mob_class
local FOX = "mobs_mc:fox"

local berries = {
	["mcl_farming:sweet_berry"] = true,
	["mcl_lush_caves:glow_berry"] = true,
}
local prey = {
	"mobs_mc:chicken", "mobs_mc:rabbit", "mobs_mc:cod", "mobs_mc:salmon", "mobs_mc:tropical_fish",
}
local snow_fox_biome
core.register_on_mods_loaded (function ()
	snow_fox_biome = mcl_biome_dispatch.make_biome_test ({
		"SnowyPlains", "IceSpikes", "FrozenOcean", "SnowyTaiga", "FrozenRiver", "SnowyBeach",
		"FrozenPeaks", "JaggedPeaks", "SnowySlopes", "Grove",
	})
end)

local fox = {
	description = S ("Fox"),
	type = "animal",
	_spawn_category = "creature",
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	view_range = 12,
	attack_type = "melee",
	damage = 2,
	reach = 1,
	visual = "mesh",
	mesh = "mobs_mc_fox.b3d",
	textures = {"mobs_mc_fox.png"},
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.30, 0, -0.30, 0.30, 0.70, 0.30},
	head_eye_height = 0.40,
	movement_speed = 4.0,
	pursuit_bonus = 1.35,
	runaway_from = {"mobs_mc:wolf", "mobs_mc:polar_bear"},
	runaway_bonus_near = 1.35,
	runaway_bonus_far = 1.15,
	runaway_view_range = 8,
	makes_footstep_sound = false,
	-- Animation ranges from the Animalia model.
	animation = {
		stand_start = 1, stand_end = 39, stand_speed = 10,
		walk_start = 41, walk_end = 59, walk_speed = 30,
		run_start = 41, run_end = 59, run_speed = 45,
	},
}

local function texture (snow)
	return snow and "mobs_mc_fox.png^[colorize:#e6eced:172" or "mobs_mc_fox.png"
end

function fox:on_spawn ()
	if self._fox_snow == nil then
		local biome = mcl_biome_dispatch.get_biome_name (self.object:get_pos ())
		self._fox_snow = snow_fox_biome (biome) == true
	end
	self.base_texture = {texture (self._fox_snow)}
	self:set_textures (self.base_texture)
	return true
end

function fox:actionable_on_rightclick (clicker)
	return berries[clicker:get_wielded_item ():get_name ()] or mob_class.actionable_on_rightclick (self, clicker)
end

function fox:on_rightclick (clicker)
	if berries[clicker:get_wielded_item ():get_name ()] and self:feed_tame (clicker, nil, true, false)
		and not self.child then
		self._fox_breeder = clicker:get_player_name ()
	end
end

function fox:on_breed (mate)
	local trusts = {}
	if self._fox_breeder then trusts[self._fox_breeder] = true end
	if mate._fox_breeder then trusts[mate._fox_breeder] = true end
	self._fox_breeder, mate._fox_breeder = nil, nil
	local variant = math.random (2) == 1 and self or mate
	core.add_entity (self.object:get_pos (), FOX, core.serialize ({
		child = true,
		persistent = true,
		_fox_snow = variant._fox_snow,
		_fox_trusts = trusts,
	}))
end

local function skittish_of (self, player)
	local name = player:get_player_name ()
	return not (self._fox_trusts and self._fox_trusts[name])
		and not core.is_creative_enabled (name) and not player:get_player_control ().sneak
end

function fox:should_runaway_from_mob (entity)
	return not entity.tamed
end

function fox:receive_damage (reason, damage)
	if reason.type == "sweet_berry" then return false end
	return mob_class.receive_damage (self, reason, damage)
end

local function avoid_player (self, pos)
	if self._fox_flee and self._fox_flee:is_valid () and skittish_of (self, self._fox_flee)
		and not self:navigation_finished () then
		return "avoid_player"
	end
	self._fox_flee = nil
	if not self:check_timer ("fox_avoid", 0.5) then return false end
	local closest, best
	for player in core.objects_inside_radius (pos, 8) do
		if player:is_player () and skittish_of (self, player) and self:target_visible (pos, player) then
			local distance = vector.distance (pos, player:get_pos ())
			if not best or distance < best then closest, best = player, distance end
		end
	end
	if not closest then return false end
	local destination = self:target_away_from (pos, closest:get_pos ())
	if destination and self:gopath (destination, self.runaway_bonus_near) then
		self._fox_flee = closest
		return "avoid_player"
	end
	return false
end

local function rest_by_day (self, pos)
	local time = core.get_timeofday ()
	if time <= 0.23 or time >= 0.77 or self:is_breeding () or self._recent_attacker
		or (core.get_natural_light (vector.round (pos), 0.5) or 15) >= 12 then
		return false
	end
	self:cancel_navigation ()
	self:halt_in_tracks ()
	self:set_animation ("stand")
	return "rest"
end

fox.ai_functions = {
	mob_class.check_avoid,
	avoid_player,
	mob_class.check_breeding,
	rest_by_day,
	mob_class.check_attack,
	mob_class.check_pace,
}
fox._targeting_rules = {
	mcl_mobs.build_nearest_target_rule ("mobs_mc:chicken", prey, nil, nil, false),
}

mcl_mobs.register_mob (FOX, fox)
mcl_mobs.register_egg (FOX, S ("Fox"), "#d0602d", "#c9c9c9", 0)
core.override_item (FOX, {inventory_image = "mobs_mc_spawn_icon_fox.png"})

local spawner = table.merge (mobs_mc.animal_spawner, {
	name = FOX,
	weight = 4,
	pack_min = 2,
	pack_max = 4,
	biomes = {"DappledForest", "Taiga", "SnowyTaiga", "OldGrowthPineTaiga", "OldGrowthSpruceTaiga", "Grove"},
})

function spawner:test_supporting_node (node)
	return core.get_item_group (node.name, "grass_block") > 0
		or node.name == "mcl_core:snowblock" or node.name == "mcl_core:coarse_dirt" or node.name == "mcl_core:podzol"
end

function spawner:describe_supporting_nodes ()
	return S ("on grass, snow blocks, coarse dirt, or podzol")
end

mcl_mobs.register_spawner (spawner)
