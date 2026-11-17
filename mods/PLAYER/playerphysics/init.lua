playerphysics = {}

local function calculate_attribute_product(a, attribute)
	local product = 1
	if a == nil or a[attribute] == nil then
		return product
	end
	local factors = a[attribute]
	if type(factors) == "table" then
		for _, factor in pairs(factors) do
			product = product * factor
		end
	end
	return product
end

function playerphysics.set_absolute_fov(player, fov)
	local meta = player:get_meta()
	local a = core.deserialize(meta:get_string("playerphysics:physics")) or {}
	local is_multiplier = fov == 0

	if is_multiplier then
		if not a.fov_absolute then return end
		a.fov_absolute = nil
		fov = calculate_attribute_product(a, "fov")
	else
		if a.fov_absolute == fov then return end
		a.fov_absolute = fov
	end

	meta:set_string("playerphysics:physics", core.serialize(a))

	player:set_fov(fov, is_multiplier, 0.1)
end

function playerphysics.add_physics_factor(player, attribute, id, value)
	local meta = player:get_meta()
	local a = core.deserialize(meta:get_string("playerphysics:physics"))
	if a == nil then
		a = { [attribute] = { [id] = value } }
	elseif a[attribute] == nil then
		a[attribute] = { [id] = value }
	else
		a[attribute][id] = value
	end
	meta:set_string("playerphysics:physics", core.serialize(a))
	local raw_value = calculate_attribute_product(a, attribute)
	if attribute == "fov" then
		if player:is_player() and not a.fov_absolute then
			player:set_fov(raw_value, true, 0.1)
		end
	elseif not mcl_serverplayer.is_csm_capable (player) then
		player:set_physics_override({[attribute] = raw_value})
	end
end

function playerphysics.remove_physics_factor(player, attribute, id)
	local meta = player:get_meta()
	local a = core.deserialize(meta:get_string("playerphysics:physics"))
	if a == nil or a[attribute] == nil then
		-- Nothing to remove
		return
	else
		a[attribute][id] = nil
	end
	meta:set_string("playerphysics:physics", core.serialize(a))
	local raw_value = calculate_attribute_product(a, attribute)
	if attribute == "fov" then
		if player:is_player() and not a.fov_absolute then
			player:set_fov(raw_value, true, 0.1)
		end
	elseif not mcl_serverplayer.is_csm_capable (player) then
		player:set_physics_override({[attribute] = raw_value})
	end
end

function playerphysics.get_physics_factor(player, attribute, id)
	local meta = player:get_meta()
	local a = core.deserialize(meta:get_string("playerphysics:physics"))
	if a == nil then
		return nil
	elseif a[attribute] == nil then
		return nil
	else
		return a[attribute][id]
	end
end

-- A stock Luanti player's gravity is twice movement_gravity. Increase it
-- alongside the launch speed to match Java's jump height and airtime.
local player_gravity_factor = 1.52
core.register_on_joinplayer(function(player)
	playerphysics.add_physics_factor(player, "gravity", "playerphysics:base_gravity", player_gravity_factor)

	-- The engine calculates fall damage from impact speed. For the same
	-- fall distance, impact speed scales with the square root of gravity.
	local groups = player:get_armor_groups()
	local fall_damage_percent = 100 + (groups.fall_damage_add_percent or 0)
	groups.fall_damage_add_percent = math.round(fall_damage_percent / math.sqrt(player_gravity_factor)) - 100
	player:set_armor_groups(groups)
end)

dofile(core.get_modpath(core.get_current_modname()).."/elytra.lua")
