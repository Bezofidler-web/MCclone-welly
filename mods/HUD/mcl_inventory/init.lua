mcl_inventory = {}

local modname = core.get_current_modname()
local path = core.get_modpath(modname)
local S = core.get_translator(modname)
local F = core.formspec_escape

function mcl_inventory.navigation_bar(player, width, y, include_recipes)
	local common = {}
	if core.get_modpath("mcl_minimap") then
		common[#common + 1] = { field = "__mcl_full_map", label = S("Map") }
	end
	if core.get_modpath("mcl_player_roster") then
		common[#common + 1] = { field = "__mcl_online_players", label = S("Players") }
	end
	common[#common + 1] = { field = "__mcl_inventory_commands", label = S("Commands") }
	common[#common + 1] = { field = "__mcl_player_settings", label = S("Options") }

	local extra = {}
	if include_recipes then
		extra[#extra + 1] = { field = "__mcl_craftguide", label = S("Recipe Book") }
	end
	if mcl_friends and mcl_friends.is_host(player) then
		extra[#extra + 1] = { field = "__mcl_friends_controls", label = S("Server Controls") }
	end

	local height = #extra > 0 and 2.16 or 1.2
	local fs = {
		("box[0,%g;%g,%g;#202620]"):format(y, width, height),
		("box[0,%g;%g,0.035;#687360]"):format(y, width),
	}
	local function row(controls, row_y)
		if #controls == 0 then return end
		local button_width = (width - 0.9 - (#controls - 1) * 0.18) / #controls
		for i, control in ipairs(controls) do
			local field = control.field
			local tint = field == "__mcl_friends_controls" and "^[multiply:#98C58C" or ""
			fs[#fs + 1] = "style[" .. field .. ";border=false;bgimg=mcl_options_button.png" .. tint
				.. ";bgimg_middle=3;textcolor=#FFFFFF]"
			fs[#fs + 1] = "style[" .. field .. ":hovered," .. field
				.. ":focused;bgimg=mcl_options_button_highlighted.png" .. tint .. "]"
			fs[#fs + 1] = ("button[%g,%g;%g,0.78;%s;%s]"):format(0.45 + (i - 1) * (button_width + 0.18),
				row_y, button_width, field, F(control.label))
		end
	end
	row(common, y + 0.2)
	row(extra, y + 1.16)
	return table.concat(fs), height
end

dofile(path .. "/creative.lua")
dofile(path .. "/survival.lua")

---Returns a single itemstack in the given inventory to the main inventory, or drop it when there's no space left.
local function return_item(itemstack, dropper, pos, inv)
	if dropper:is_player() then
		-- Return to main inventory
		if inv:room_for_item("main", itemstack) then
			inv:add_item("main", itemstack)
		else
			-- Drop item on the ground
			local v = dropper:get_look_dir()
			local p = vector.offset(pos, 0, 1.2, 0)
			p.x = p.x + (math.random(1, 3) * 0.2)
			p.z = p.z + (math.random(1, 3) * 0.2)
			local obj = core.add_item(p, itemstack)
			if obj then
				v.x = v.x * 4
				v.y = v.y * 4 + 2
				v.z = v.z * 4
				obj:set_velocity(v)
				obj:get_luaentity()._insta_collect = false
			end
		end
	else
		-- Fallback for unexpected cases
		core.add_item(pos, itemstack)
	end
	return itemstack
end

---Return items in the given inventory list (name) to the main inventory, or drop them if there is no space left.
local function return_fields(player, name)
	if not player or not player:get_pos() then return end -- make sure player is still there
	local inv = player:get_inventory()

	local list = inv:get_list(name)
	if not list then return end
	for i, stack in ipairs(list) do
		return_item(stack, player, player:get_pos(), inv)
		stack:clear()
		inv:set_stack(name, i, stack)
	end
end

local function return_fields_from_temp_player_inventories(player)
	return_fields(player, "craft")
	return_fields(player, "enchanting_lapis")
	return_fields(player, "enchanting_item")
end

local function set_inventory(player)
	if core.is_creative_enabled(player:get_player_name()) then
		mcl_inventory.set_creative_formspec(player)
		return
	end

	local formspec = mcl_inventory.build_survival_formspec (player)
	mcl_player.set_inventory_formspec (player, formspec, 0)
end

local function plan_recipe(inv, craft, grid_width, grid_height, stride)
	stride = stride or inv:get_width("craft")
	if stride == 0 then stride = 3 end
	grid_width = grid_width or stride
	grid_height = grid_height or math.ceil(inv:get_size("craft") / stride)
	local size = table.max_index(craft.items)
	local width = craft.width ~= 0 and craft.width or (size <= 4 and 2 or 3)
	if size == 0 or width > grid_width or math.ceil(size / width) > grid_height then return end

	local assigned, complete, stacks = mcl_craftguide.match_recipe(inv, craft.items)
	if not complete then return end
	local grid = {}
	for slot, source in pairs(assigned) do
		local row = math.floor((slot - 1) / width)
		grid[row * stride + (slot - 1) % width + 1] = stacks[source]:take_item()
	end
	return grid, stacks
end

function mcl_inventory.get_recipe_groups(player, craft, optional_width, optional_height)
	local grid = plan_recipe(player:get_inventory(), craft, optional_width, optional_height, optional_width)
	if not grid then return false end
	local names = {}
	for slot = 1, table.max_index(grid) do
		names[slot] = grid[slot] and grid[slot]:get_name() or ""
	end
	return names
end

function mcl_inventory.to_craft_grid(player, craft, grid_width, grid_height)
	if craft.type ~= "normal" then return false end
	local inv = player:get_inventory()
	local grid, stacks = plan_recipe(inv, craft, grid_width, grid_height)
	if not grid then return false end
	local main_size = inv:get_size("main")
	local main = {}
	for i = 1, main_size do main[i] = stacks[i] end
	-- Rehome unused crafting items only after we know everything fits.
	for i = main_size + 1, #stacks do
		local leftover = stacks[i]
		if not leftover:is_empty() then
			local empty_slot
			for slot, stack in ipairs(main) do
				if stack:is_empty() then
					empty_slot = empty_slot or slot
				elseif stack:get_wear() == leftover:get_wear() then
					leftover = stack:add_item(leftover)
				end
				if leftover:is_empty() then break end
			end
			if not leftover:is_empty() then
				if not empty_slot then return false end
				main[empty_slot] = leftover
			end
		end
	end
	inv:set_list("main", main)
	inv:set_list("craft", grid)
	return true
end

function mcl_inventory.fill_grid(player)
	local inv = player:get_inventory()
	local main = inv:get_list("main")
	local grid = inv:get_list("craft")
	local slots, sources, totals = {}, {}, {}
	for i, stack in ipairs(main) do
		if not stack:is_empty() then
			local key = stack:peek_item():to_string()
			sources[key] = sources[key] or {}
			table.insert(sources[key], i)
			totals[key] = (totals[key] or 0) + stack:get_count()
		end
	end
	for _, stack in ipairs(grid) do
		local key = stack:peek_item():to_string()
		slots[key] = (slots[key] or 0) + 1
	end
	for _, stack in ipairs(grid) do
		local key = stack:peek_item():to_string()
		if sources[key] then
			local needed = math.min(stack:get_stack_max() - stack:get_count(), math.floor(totals[key] / slots[key]))
			for _, i in ipairs(sources[key]) do
				if needed <= 0 then break end
				local taken = main[i]:take_item(math.min(needed, main[i]:get_count()))
				needed = needed - taken:get_count()
				stack:add_item(taken)
			end
		end
	end
	inv:set_list("main", main)
	inv:set_list("craft", grid)
end

function mcl_inventory.show_inventory(player)
	if core.is_creative_enabled(player:get_player_name()) then
		mcl_inventory.set_creative_formspec(player)
	end
	core.show_formspec(player:get_player_name(), "", player:get_inventory_formspec())
end

dofile(path .. "/commands.lua")

mcl_player.register_player_settings_button({
	field = "__mcl_inventory",
	icon = "crafting_creative_prev.png",
	description = S("Return to player inventory"),
	priority = math.huge, -- first
})

core.register_on_player_receive_fields(function(player, _, fields)
	if fields.__mcl_crafting_fillgrid then
		mcl_inventory.fill_grid(player)
	elseif fields.__mcl_inventory then
		mcl_inventory.show_inventory(player)
		return false
	elseif fields.quit then
		-- Drop items from special player inventories on formspec closing
		return_fields_from_temp_player_inventories(player)
	end
end)

function mcl_inventory.get_required_craft_grid_size (grid_contents, grid_width)
	if grid_width == 0 then
		grid_width = 3
	end
	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = 0, 0
	local size = #grid_contents
	local i = 0
	local row = 1
	while i < size do
		for j = 1, grid_width do
			if grid_contents[i+j] and not grid_contents[i+j]:is_empty() then
				min_x, min_y = math.min(min_x, j), math.min(min_y, row)
				max_x, max_y = math.max(max_x, j), math.max(max_y, row)
			end
		end
		i = i + grid_width
		row = row + 1
	end
	if max_x == 0 then
		return 0
	else
		return math.max(max_x - min_x, max_y - min_y) + 1
	end
end

core.register_craft_predict(function(itemstack, player, old_craft_grid, inv) ---@diagnostic disable-line: unused-local
	if not player or not player:get_pos() then return end -- can apparently be called when player has already left !?
	if inv and mcl_inventory.get_required_craft_grid_size(old_craft_grid, inv:get_width("craft")) > 2
		and not mcl_crafting_table.has_crafting_table(player) then
		return_fields(player, "craft")
		core.chat_send_player(player:get_player_name(), S("Crafting table out of range!"))
	end
end)

function mcl_inventory.update_inventory_formspec(player)
	set_inventory(player)
end

-- Drop crafting grid items on leaving
core.register_on_leaveplayer(function(player)
	return_fields_from_temp_player_inventories(player)
end)

core.register_on_joinplayer(function(player)
	-- Make sure the player's temporary inv lists are empty. Why? Because
	-- the player might have items remaining from the previous join; this is
	-- likely when the server has been shutdown and the server didn't clean
	-- up the player inventories.
	return_fields_from_temp_player_inventories(player)

	--init inventory
	local inv = player:get_inventory()

	inv:set_width("main", 9)
	inv:set_size("main", 36)
	inv:set_width("craft", 3)
	inv:set_size("craft", 9)
	inv:set_size("offhand", 1)
	inv:set_size("sorter", 1)
	inv:set_stack("sorter", 1, ItemStack(""))

	--set hotbar size
	player:hud_set_hotbar_itemcount(9)
	--add hotbar images
	player:hud_set_hotbar_image("mcl_inventory_hotbar.png")
	player:hud_set_hotbar_selected_image("mcl_inventory_hotbar_selected.png")

	--build survival inventory formspec (this is handled in creative.lua for creative mode)
	if not core.is_creative_enabled(player:get_player_name()) then
		set_inventory(player)
	end

end)

function mcl_inventory.update_inventory(player)
	local player_gamemode = player:get_meta():get_string("gamemode")
	if player_gamemode == "" then player_gamemode = "survival" end

	if player_gamemode == "creative" then
		mcl_inventory.set_creative_formspec(player)
	elseif player_gamemode == "survival" then
		local formspec = mcl_inventory.build_survival_formspec (player)
		mcl_player.set_inventory_formspec (player, formspec, 0)
	end
	mcl_meshhand.update_player(player)
end

mcl_player.register_on_visual_change(mcl_inventory.update_inventory_formspec)

mcl_gamemode.register_on_gamemode_change(function(p, old_gm, gm) ---@diagnostic disable-line: unused-local
	set_inventory(p)
end)

-- Handles replacing the item wielded in an interaction with another item
--
-- Replaces the wielded stack with the reward stack if the wielded stack is
-- empty after the interaction, and otherwise tries to add the reward stack into
-- the player's inventory and drops it at the player's position if there is no
-- room.
--
-- Creative behavior specifies how to handle creative mode for this interaction:
-- "nothing": neither give nor take any items
-- "give": don't take item from wielded stack, but give reward
-- "give_new": like "give", but only give reward, if it isn't already in player's inventory (default)
-- "both": give and take item like in non creative mode

function mcl_inventory.give_and_take(player, wield_stack, reward_stack, creative_behavior)
	if not player then return nil end
	local creative = core.is_creative_enabled(player:get_player_name())
	creative_behavior = creative_behavior or "give_new"
	if creative and creative_behavior == "nothing" then
		return wield_stack
	end
	if not creative or creative_behavior == "both" then
		wield_stack:take_item()
	end
	local inv = player:get_inventory()
	local contains = inv:contains_item("main", reward_stack, true)
	if not creative or creative_behavior ~= "give_new" or not contains then
		if wield_stack:is_empty() then
			return reward_stack
		elseif inv:room_for_item("main", reward_stack) then
			inv:add_item("main", reward_stack)
			return wield_stack
		else
			core.add_item(player:get_pos(), reward_stack)
			return wield_stack
		end
	end
end
