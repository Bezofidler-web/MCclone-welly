local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape

local name = "mcl_crafter:crafter"
local slots = 9
local craft_delay = 2 -- Four Java game ticks at the default two game ticks per redstone tick.
local flash_duration = 3
local variants = {
	[""] = {},
	_triggered = { top = "_triggered", east = "_triggered", west = "_triggered", south = "_triggered" },
	_crafting = { top = "_crafting", east = "_crafting", west = "_crafting", north = "_crafting" },
	_crafting_triggered = {
		top = "_crafting", east = "_crafting", west = "_crafting", north = "_crafting", south = "_triggered",
	},
}

local function is_disabled(mask, index)
	return bit.band(mask, bit.lshift(1, index - 1)) ~= 0
end

local function get_insert_slot(pos, item)
	local meta = core.get_meta(pos)
	local mask = meta:get_int("disabled_slots")
	local inv = meta:get_inventory()
	local best, best_count
	for i = 1, slots do
		if not is_disabled(mask, i) then
			local stack = inv:get_stack("main", i)
			if stack:is_empty() then return i end
			local count = stack:get_count()
			if (not best_count or count < best_count) and stack:item_fits(item) then
				best, best_count = i, count
			end
		end
	end
	return best
end

-- Some registered recipes need interactive callbacks to compute an item or retain
-- its data. Their ordinary recipe previews alone aren't enough to craft them.
local function requires_manual_crafting(result, inputs)
	local output = result:get_name()
	if output == "mcl_books:written_book" or output == "mcl_sus_stew:stew" then
		return true
	end

	for _, stack in ipairs(inputs) do
		local item = stack:get_name()
		if core.get_item_group(item, "filled_map") > 0
			or core.get_item_group(output, "armor_leather") > 0 and core.get_item_group(item, "armor_leather") > 0
			or core.get_item_group(output, "shield") > 0 and core.get_item_group(item, "shield") > 0
			or output == "mcl_candles:candle_1" and core.get_item_group(item, "candles") > 0
			or output == "mcl_pottery_sherds:pot" and stack:get_definition()._mcl_pottery_sherd_name then
			return true
		end
		if core.get_item_group(output, "banner") > 0 and core.get_item_group(item, "banner") > 0 then
			return true
		end
		if core.get_item_group(output, "tipped_arrow") > 0 and core.get_item_group(item, "ling_potion") > 0
			and (stack:get_meta():get_int("mcl_potions:potion_potent") ~= 0
				or stack:get_meta():get_int("mcl_potions:potion_plus") ~= 0) then
			return true
		end
	end
	return false
end

local function get_recipe(inv)
	local contents = inv:get_list("main")
	if not contents then return end
	local inputs = {}
	for i = 1, slots do
		inputs[i] = contents[i]:peek_item(1)
	end
	local result, rest = core.get_craft_result({ method = "normal", width = 3, items = inputs })
	if result.item:is_empty() or requires_manual_crafting(result.item, inputs) then return end
	-- Recolouring a shulker box must retain its contents and name.
	if core.get_item_group(result.item:get_name(), "shulker_box") > 0 then
		for _, stack in ipairs(inputs) do
			if core.get_item_group(stack:get_name(), "shulker_box") > 0 then
				result.item:get_meta():from_table(stack:get_meta():to_table())
				break
			end
		end
	end
	return result, rest, contents
end

local function itemslot(x, y, width, height)
	return mcl_formspec.get_itemslot_bg_v4(x, y, width, height, 1 / 16, nil, 1 / 8)
end

local function build_formspec(meta)
	local inv = meta:get_inventory()
	local mask = meta:get_int("disabled_slots")
	local arrow = meta:get_int("powered") == 1 and "powered" or "unpowered"
	local fs = {
		"formspec_version[7]size[11,10.75]",
		mcl_vars.gui_bg_color, mcl_vars.gui_bg_img,
		"bgcolor[;true;#00000099]",
		"style_type[list;spacing=0.125,0.125]",
		"label[0.5,0.32;" .. F(S("Crafter")) .. "]",
	}
	for row = 0, 2 do
		local y = 0.7 + row * 1.53
		fs[#fs + 1] = itemslot(2, y, 3, 1)
		fs[#fs + 1] = ("list[context;main;2,%g;3,1;%d]"):format(y, row * 3)
		for column = 0, 2 do
			local index = row * 3 + column + 1
			local x = 2 + column * 1.125
			local disabled = is_disabled(mask, index)
			if disabled then
				fs[#fs + 1] = ("image[%g,%g;1.125,1.125;mcl_crafter_disabled_slot.png]"):format(
					x - 0.0625, y - 0.0625)
			end
			if inv:get_stack("main", index):is_empty() then
				local field = "toggle_" .. index
				local title = disabled and S("Enable slot @1", index) or S("Disable slot @1", index)
				fs[#fs + 1] = ("button[%g,%g;0.97,0.35;%s;%s]"):format(x + 0.015, y + 1.065,
					field, disabled and "+" or "×")
				fs[#fs + 1] = "tooltip[" .. field .. ";" .. F(title) .. "]"
			end
		end
	end
	fs[#fs + 1] = "image[5.9,2.23;1,1;mcl_crafter_" .. arrow .. "_redstone.png]"
	fs[#fs + 1] = itemslot(7.3, 2.23, 1, 1)
	local recipe = get_recipe(inv)
	if recipe then
		fs[#fs + 1] = "item_image[7.3,2.23;1,1;" .. F(recipe.item:get_name()) .. "]"
		local count = recipe.item:get_count()
		if count > 1 then
			fs[#fs + 1] = "label[7.95,3.046;" .. core.colorize("#FFFFFF", tostring(count)) .. "]"
		end
		local desc = recipe.item:get_description()
		fs[#fs + 1] = "tooltip[7.3,2.23;1,1;" .. F(desc) .. "]"
	end
	fs[#fs + 1] = "label[0.5,5.48;" .. F(S("Inventory")) .. "]"
	fs[#fs + 1] = itemslot(0.5, 5.84, 9, 3)
	fs[#fs + 1] = "list[current_player;main;0.5,5.84;9,3;9]"
	fs[#fs + 1] = itemslot(0.5, 9.44, 9, 1)
	fs[#fs + 1] = "list[current_player;main;0.5,9.44;9,1;]"
	fs[#fs + 1] = "listring[context;main]listring[current_player;main]"
	return table.concat(fs)
end

local function refresh_formspec(pos)
	local meta = core.get_meta(pos)
	meta:set_string("formspec", build_formspec(meta))
end

local function initialize_grid(pos)
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("main") == 0 then
		inv:set_size("main", slots)
		refresh_formspec(pos)
	end
end

local function player_inventory_changed(pos)
	refresh_formspec(pos)
	mcl_redstone.update_comparators(pos)
end

local function inventory_changed(pos, listname)
	if listname == "main" then refresh_formspec(pos) end
end

local function player_can_edit(pos, player)
	if not player or not player:is_player() then return false end
	local player_name = player:get_player_name()
	if core.is_protected(pos, player_name) then
		core.record_protection_violation(pos, player_name)
		return false
	end
	return true
end

local function slot_is_open(pos, index)
	return index >= 1 and index <= slots and not is_disabled(core.get_meta(pos):get_int("disabled_slots"), index)
end

local function receive_fields(pos, _, fields, player)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	for i = 1, slots do
		if fields["toggle_" .. i] then
			if not player_can_edit(pos, player) or not inv:get_stack("main", i):is_empty() then return end
			meta:set_int("disabled_slots", bit.bxor(meta:get_int("disabled_slots"), bit.lshift(1, i - 1)))
			player_inventory_changed(pos)
			return
		end
	end
end

local function comparator_power(pos)
	local meta = core.get_meta(pos)
	local mask = meta:get_int("disabled_slots")
	local inv = meta:get_inventory()
	local power = 0
	for i = 1, slots do
		if is_disabled(mask, i) or not inv:get_stack("main", i):is_empty() then
			power = power + 1
		end
	end
	return power
end

local outbox = "outbox"

local function move_output(pos, destination, dir, inv, index, container)
	local stack = inv:get_stack(outbox, index)
	if stack:is_empty() then return end
	local list
	if container == 4 then
		if dir.y < 0 then
			list = "src"
		else
			-- The side and underside expose fuel. The smelted result slot
			-- on the underside is extraction-only.
			local target_inv = core.get_meta(destination):get_inventory()
			if stack:get_name() == "mcl_buckets:bucket_empty" then
				if target_inv:is_empty("fuel") then
					mcl_util.move_item_container(pos, destination, outbox, index, "fuel")
				end
				return
			end
			if not mcl_furnaces.is_transferrable_fuel(stack:peek_item(1), nil, nil, target_inv, "fuel") then
				return
			end
			list = "fuel"
		end
	end

	-- A second successful transfer can reach the other half of a double chest.
	local available = stack:get_count()
	while available > 0 and mcl_util.move_item_container(pos, destination, outbox, index, list, available) do
		available = inv:get_stack(outbox, index):get_count()
	end
end

local function flush_output(pos, node, inv)
	local dir = -core.facedir_to_dir(node.param2)
	local destination = pos + dir
	local target = core.get_node_or_nil(destination)
	if not target or target.name == "ignore" then return false end
	local container = core.get_item_group(target.name, "container")
	for i = 1, inv:get_size(outbox) do
		if container > 0 then
			move_output(pos, destination, dir, inv, i, container)
		end
		local stack = inv:get_stack(outbox, i)
		if not stack:is_empty() then
			local obj = core.add_item(pos + dir * 0.7, stack)
			if obj then
				obj:set_velocity(dir * 2.5 + vector.new(0, 1.5, 0))
				inv:set_stack(outbox, i, ItemStack())
			end
		end
	end
	if inv:is_empty(outbox) then
		inv:set_size(outbox, 0)
		return true
	end
	return false
end

local function craft(pos, node, meta)
	local inv = meta:get_inventory()
	if not inv:is_empty(outbox) then return false end
	local recipe, rest, contents = get_recipe(inv)
	if not recipe then return false end
	local outputs = { recipe.item }
	for _, stack in ipairs(rest.items) do
		if not stack:is_empty() then outputs[#outputs + 1] = stack end
	end
	for _, stack in ipairs(recipe.replacements or {}) do
		outputs[#outputs + 1] = stack
	end
	for _, stack in ipairs(contents) do
		stack:take_item(1)
	end
	-- Persist the result until it has a destination, including when a block
	-- border is unloaded or creation of a dropped item fails.
	inv:set_size(outbox, #outputs)
	inv:set_list(outbox, outputs)
	inv:set_list("main", contents)
	if not flush_output(pos, node, inv) then core.get_node_timer(pos):start(0.5) end
	mcl_redstone.update_comparators(pos)
	return true
end

local function show_state(pos, node, meta)
	local flashing = meta:get_float("flash_until") > 0
	local powered = meta:get_int("powered") == 1
	local suffix = (flashing and "_crafting" or "") .. (powered and "_triggered" or "")
	local newname = name .. suffix
	if node.name ~= newname then
		mcl_redstone.swap_node(pos, { name = newname, param2 = node.param2 })
	end
	refresh_formspec(pos)
end

local function schedule(pos, at)
	mcl_redstone.after(math.max(0, at - mcl_redstone.get_current_tick()), function()
		local node = core.get_node_or_nil(pos)
		if not node or core.get_item_group(node.name, "crafter") == 0 then return end
		local meta = core.get_meta(pos)
		local now = mcl_redstone.get_current_tick()
		local due = meta:get_float("craft_at")
		local flash = meta:get_float("flash_until")
		if flash > 0 and flash <= now then meta:set_float("flash_until", 0) end
		if due > 0 and due <= now then
			meta:set_float("craft_at", 0)
			if craft(pos, node, meta) then
				local until_tick = now + flash_duration
				meta:set_float("flash_until", until_tick)
				schedule(pos, until_tick)
			end
		end
		show_state(pos, node, meta)
	end)
end

local function update_power(pos, node)
	local meta = core.get_meta(pos)
	local was_powered = meta:get_int("powered") == 1
	local powered = mcl_redstone.get_power(pos) > 0
	if powered == was_powered then return end
	meta:set_int("powered", powered and 1 or 0)
	if powered and meta:get_float("craft_at") == 0 then
		local at = mcl_redstone.get_current_tick() + craft_delay
		meta:set_float("craft_at", at)
		schedule(pos, at)
	elseif not powered then
		meta:set_float("flash_until", 0)
	end
	show_state(pos, node, meta)
end

local function restore_pending(pos, node)
	initialize_grid(pos)
	local meta = core.get_meta(pos)
	for _, key in ipairs({ "craft_at", "flash_until" }) do
		local at = meta:get_float(key)
		if at > 0 then schedule(pos, at) end
	end
	update_power(pos, node)
end

local function place(itemstack, placer, pointed_thing)
	local result = mcl_util.call_on_rightclick(itemstack, placer, pointed_thing)
	if result ~= nil then return result end
	local facedir = placer and placer:is_player() and core.dir_to_facedir(placer:get_look_dir(), true) or 0
	return core.item_place_node(itemstack, placer, pointed_thing, facedir)
end

for suffix, faces in pairs(variants) do
	local nodename = name .. suffix
	local function tile(face) return "mcl_crafter_" .. face .. (faces[face] or "") .. ".png" end
	core.register_node(nodename, {
		description = S("Crafter"),
		_doc_items_longdesc = S("Crafts the recipe in its grid when it receives a redstone pulse."),
		_doc_items_usagehelp = S("Put ingredients in the grid. Use the small buttons to disable empty slots. The result exits the front face."),
		_doc_items_create_entry = suffix == "",
		tiles = { tile("top"), tile("bottom"), tile("east"), tile("west"), tile("south"), tile("north") },
		paramtype2 = "facedir",
		is_ground_content = false,
		drop = name,
		groups = { pickaxey = 1, container = 2, crafter = 1, material_stone = 1, unmovable_by_piston = 1,
			not_in_creative_inventory = suffix ~= "" and 1 or nil },
		sounds = mcl_sounds.node_sound_stone_defaults(),
		_mcl_hardness = 1.5,
		_mcl_blast_resistance = 3.5,
		_mcl_redstone = {
			connects_to = function() return true end,
			init = restore_pending,
			update = update_power,
		},
		_mcl_container_insert_slot = get_insert_slot,
		_mcl_container_inventory_changed = inventory_changed,
		on_construct = initialize_grid,
		on_timer = function(pos)
			return not flush_output(pos, core.get_node(pos), core.get_meta(pos):get_inventory())
		end,
		on_place = place,
		on_receive_fields = receive_fields,
		on_rotate = screwdriver.rotate_simple,
		-- While ejection is blocked, keep the already crafted items recoverable.
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty(outbox)
		end,
		after_dig_node = mcl_util.drop_items_from_meta_container({ "main", outbox }),
		allow_metadata_inventory_move = function(pos, from_list, _, to_list, index, count, player)
			return from_list == "main" and to_list == "main" and slot_is_open(pos, index)
				and player_can_edit(pos, player) and count or 0
		end,
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			return listname == "main" and slot_is_open(pos, index) and player_can_edit(pos, player)
				and stack:get_count() or 0
		end,
		allow_metadata_inventory_take = function(pos, listname, _, stack, player)
			return listname == "main" and player_can_edit(pos, player) and stack:get_count() or 0
		end,
		on_metadata_inventory_move = player_inventory_changed,
		on_metadata_inventory_put = player_inventory_changed,
		on_metadata_inventory_take = player_inventory_changed,
	})
	mcl_redstone.register_comparator_measure_func(nodename, comparator_power)
end

local iron = "mcl_core:iron_ingot"
local dust = "mcl_redstone:redstone"
core.register_craft({
	output = name,
	recipe = {
		{ iron, iron, iron },
		{ iron, "mcl_crafting_table:crafting_table", iron },
		{ dust, "mcl_dispensers:dropper", dust },
	},
})
