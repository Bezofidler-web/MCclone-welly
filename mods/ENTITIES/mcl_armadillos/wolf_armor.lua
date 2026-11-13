return function (shared)
	local S = shared.translate
	local scute = shared.scute
	local armor_name = "mcl_armadillos:wolf_armor"
	local base_texture = "mcl_armadillos_wolf_armor.png"
	local overlay_texture = "mcl_armadillos_wolf_armor_overlay.png"
	local armor = {}

	local bypass = {
		cramming = true, drown = true, drowning = true, dry_out = true, freeze = true, in_wall = true,
		indirect_magic = true, magic = true, outside_border = true, starve = true, thorns = true, wither = true,
	}

	function armor.textures (wolf)
		if wolf.child or not wolf._wolf_armor_item then return "blank.png", "blank.png" end
		local stack = ItemStack (wolf._wolf_armor_item)
		local overlay = overlay_texture
		local wear = stack:get_wear ()
		local cracks = wear >= 49152 and "high" or wear >= 32768 and "medium" or wear >= 16384 and "low"
		if cracks then overlay = "(" .. overlay .. ")^mcl_armadillos_wolf_armor_crackiness_" .. cracks .. ".png" end
		return base_texture, overlay
	end

	local function set_armor (wolf, stack)
		wolf._wolf_armor_item = not stack:is_empty () and stack:to_string () or nil
		wolf.base_texture = wolf:compute_textures ()
		wolf:set_textures (wolf.base_texture)
	end

	local function consume (player, stack)
		if not core.is_creative_enabled (player:get_player_name ()) then
			stack:take_item ()
			player:set_wielded_item (stack)
		end
	end

	function armor.interact (wolf, player, stack)
		local name = stack:get_name ()
		local worn = ItemStack (wolf._wolf_armor_item or "")
		local shears = core.get_item_group (name, "shears") > 0
		if name ~= armor_name and (worn:is_empty () or (name ~= scute and not shears)) then return false end
		if wolf.child or wolf.owner ~= player:get_player_name () then return true end
		if name == armor_name then
			if not worn:is_empty () then return true end
			local equipped = ItemStack (stack)
			equipped:set_count (1)
			set_armor (wolf, equipped)
			consume (player, stack)
		elseif name == scute and worn:get_wear () > 0 then
			worn:set_wear (math.max (0, worn:get_wear () - 8192))
			set_armor (wolf, worn)
			consume (player, stack)
		elseif shears then
			local item = core.add_item (wolf.object:get_pos (), worn)
			if not item then return true end
			set_armor (wolf, ItemStack ())
			if not core.is_creative_enabled (player:get_player_name ()) then
				mcl_util.use_item_durability (stack, 1)
				player:set_wielded_item (stack)
			end
		end
		return true
	end

	function armor.absorb (wolf, reason, damage)
		if not wolf._wolf_armor_item or damage <= 0 or bypass[reason.type]
			or reason.flags and reason.flags.bypasses_invulnerability then
			return false
		end
		local stack = ItemStack (wolf._wolf_armor_item)
		local wear = math.min (65536, math.ceil (damage) * 1024)
		stack:add_wear (wear)
		if stack:is_empty () then core.sound_play ("default_tool_breaks", {object = wolf.object}, true) end
		set_armor (wolf, stack)
		return true
	end

	function armor.drop (wolf, pos)
		if wolf._wolf_armor_item then
			core.add_item (pos, wolf._wolf_armor_item)
			wolf._wolf_armor_item = nil
		end
	end

	core.register_tool (armor_name, {
		description = S ("Wolf Armor"),
		_doc_items_longdesc = S ("An adult tamed wolf's owner can equip this armor, repair it with scutes, and remove it with shears."),
		inventory_image = "mcl_armadillos_wolf_armor_item.png",
		_repair_material = scute,
		_mcl_uses = 64,
	})

	core.register_craft ({
		output = armor_name,
		recipe = {{scute, "", ""}, {scute, scute, scute}, {scute, "", scute}},
	})

	mobs_mc.wolf_armor = armor
end
