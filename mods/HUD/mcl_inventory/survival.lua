local S = core.get_translator("mcl_inventory")
local F = core.formspec_escape

mcl_inventory.registered_survival_inventory_tabs = {}

function mcl_inventory.register_survival_inventory_tab(def)
	if #mcl_inventory.registered_survival_inventory_tabs == 7 then
		error("Too many tabs registered!")
	end

	assert(def.id)
	assert(def.description)
	assert(def.item_icon)
	assert(def.build)
	assert(def.handle)

	for _, d in ipairs(mcl_inventory.registered_survival_inventory_tabs) do
		assert(d.id ~= def.id, "Another tab exists with the same name!")
	end

	if not def.access then
		function def.access(_)
			return true
		end
	end

	if def.show_inventory == nil then
		def.show_inventory = true
	end

	table.insert(mcl_inventory.registered_survival_inventory_tabs, def)
end

local player_current_tab = {}

core.register_on_joinplayer(function(player)
	player_current_tab[player] = "main"
end)

core.register_on_leaveplayer(function(player)
	player_current_tab[player] = nil
end)

local function compact_slot_bg(x, y, columns, rows)
	-- The Java layout leaves one pixel of bevel on each side of a 16px item.
	return mcl_formspec.get_itemslot_bg_v4(x, y, columns, rows, 1 / 16, nil, 1 / 8)
end

local function build_page(player, content, inventory, tabname)
	local compact = tabname == "main"
	local tab_buttons = "style_type[image;noclip=true]"
	local has_tabs = #mcl_inventory.registered_survival_inventory_tabs > 1

	if has_tabs then
		for i, d in ipairs(mcl_inventory.registered_survival_inventory_tabs) do
			local btn_name = "tab_" .. d.id
			local tab_x = 0.2 + (i - 1) * (compact and 1.52 or 1.6)

			tab_buttons = tab_buttons .. table.concat({
				"style[" .. btn_name .. ";border=false;bgimg=;bgimg_pressed=;noclip=true]",
				"image[" ..
					tab_x ..
					",-1.34;1.5,1.44;" .. (tabname == d.id and "crafting_creative_active.png" or "crafting_creative_inactive.png") ..
					"]",
				"item_image_button[" .. (tab_x + 0.24) .. ",-1.1;1,1;" .. d.item_icon .. ";" .. btn_name .. ";]",
				"tooltip[" .. btn_name .. ";" .. F(d.description) .. "]"
			})
		end
	end

	local lists = ""
	if inventory and compact then
		lists = table.concat({
			"style_type[list;spacing=0.125,0.125]",
			compact_slot_bg(0.5, 5.25, 9, 3),
			"list[current_player;main;0.5,5.25;9,3;9]",
			compact_slot_bg(0.5, 8.875, 9, 1),
			"list[current_player;main;0.5,8.875;9,1;]",
		})
	elseif inventory then
		-- Custom tabs still use their original canvas and coordinates.
		lists = table.concat({
			mcl_formspec.get_itemslot_bg_v4(0.375, 5.575, 9, 3),
			"list[current_player;main;0.375,5.575;9,3;9]",
			mcl_formspec.get_itemslot_bg_v4(0.375, 9.525, 9, 1),
			"list[current_player;main;0.375,9.525;9,1;]",
		})
	end

	if compact then
		local top = has_tabs and 1.34 or 0
		local navigation, navigation_height = mcl_inventory.navigation_bar(player, 11, top + 11.3, true)
		return table.concat({
			"formspec_version[8]",
			("size[11,%g]"):format(top + 11.3 + navigation_height),
			"no_prepend[]", mcl_vars.gui_nonbg, "bgcolor[;true;#000000A0]",
			("background9[0,%g;11,11.3;mcl_base_textures_background9.png;;7]"):format(top),
			("box[0,%g;11,0.85;#202620]"):format(top),
			"style_type[label;textcolor=#F2F5EF;font=bold;font_size=*1.15]",
			("label[0.5,%g;%s]"):format(top + 0.43, F(S("Inventory"))),
			"style_type[label;textcolor=#323232;font=normal;font_size=*1]",
			("container[0,%g]"):format(top + 0.88),
			lists,
			content,
			"container_end[]",
			("container[0,%g]"):format(top),
			tab_buttons,
			"container_end[]",
			navigation,
		})
	end

	return table.concat({
		"formspec_version[7]",
		"size[11.75,10.9]",
		"bgcolor[;true;#00000099]",
		lists,
		content,
		tab_buttons,
	})
end

local function get_inventory_formspec(player)
	local inv = player:get_inventory()

	local armor_slots = { "helmet", "chestplate", "leggings", "boots" }
	local armor_slot_imgs = ""
	for a = 1, 4 do
		if inv:get_stack("armor", a + 1):is_empty() then
			armor_slot_imgs = armor_slot_imgs ..
				"image[0.5," .. (0.5 + (a - 1) * 1.125) .. ";1,1;mcl_inventory_empty_armor_slot_" .. armor_slots[a] .. ".png]"
		end
	end

	local offhand_slot_img = ""
	if inv:get_stack("offhand", 1):is_empty() then
		offhand_slot_img = "image[4.8125,3.875;1,1;mcl_inventory_empty_armor_slot_shield.png]"
	end

	local craft_width = inv:get_width("craft")
	if craft_width == 0 then
		core.log("warning", "[mcl_inventory] craft width for player " .. player:get_player_name() .. " is 0")
		craft_width = 3
	end

	return table.concat({
		--Armor slots
		compact_slot_bg(0.5, 0.5, 1, 4),
		armor_slot_imgs,
		"list[current_player;armor;0.5,0.5;1,1;1]",
		"list[current_player;armor;0.5,1.625;1,1;2]",
		"list[current_player;armor;0.5,2.75;1,1;3]",
		"list[current_player;armor;0.5,3.875;1,1;4]",

		--Player model background
		"image[1.5625,0.4375;3.125,4.5;mcl_inventory_background9.png;2]",

		--Offhand
		compact_slot_bg(4.8125, 3.875, 1, 1),
		offhand_slot_img,
		"list[current_player;offhand;4.8125,3.875;1,1]",

		--Craft grid
		"label[6.0625,0.65;" .. F(core.colorize(mcl_formspec.label_color, S("Crafting"))) .. "]",

		compact_slot_bg(6.125, 1.125, 2, 2),
		"list[current_player;craft;6.125,1.125;2,1]",
		"list[current_player;craft;6.125,2.25;2,1;", craft_width, "]",

		"image[8.4375,1.6875;1,1;crafting_formspec_arrow.png]",

		compact_slot_bg(9.5, 1.6875, 1, 1),
		"list[current_player;craftpreview;9.5,1.6875;1,1;]",

		"style_type[image_button:hovered,image_button:focused;bgimg=mcl_inventory_button9.png^[multiply:#AAC7DF]",
		"image_button[9.55,2.875;0.9,0.9;mcl_crafting_table_inv_fill.png;__mcl_crafting_fillgrid;]",
		"tooltip[__mcl_crafting_fillgrid;" .. F(S("Fill Craft Grid")) .. "]",

		--Help button
		"image_button[7.267,3.925;0.9,0.9;doc_button_icon_lores.png;__mcl_doc;]",
		"tooltip[__mcl_doc;" .. F(S("Help")) .. "]",

		--Achievements button
		"image_button[8.408,3.925;0.9,0.9;mcl_achievements_button.png;__mcl_achievements;]",
		"tooltip[__mcl_achievements;" .. F(S("Advancements")) .. "]",

		"label[0.5,5.04;" .. F(S("Backpack")) .. "]",
		"label[0.5,8.66;" .. F(S("Hotbar")) .. "]",

		--Listring
		"listring[current_player;main]",
		"listring[current_player;sorter]",
		"listring[current_player;main]",
		"listring[current_player;craft]",
		"listring[current_player;main]",
		"listring[current_player;armor]",
		"listring[current_player;main]",
		"listring[current_player;offhand]",
		"listring[current_player;main]",

		-- Player model
		mcl_player.get_player_formspec_model(player, 1.5625, 0.4375, 3.125, 4.5, ""),
	})
end

mcl_inventory.register_survival_inventory_tab({
	id = "main",
	description = "Main Inventory",
	item_icon = "mcl_crafting_table:crafting_table",
	show_inventory = true,
	build = get_inventory_formspec,
	handle = function() end,
})

--[[
mcl_inventory.register_survival_inventory_tab({
	id = "test",
	description = "Test",
	item_icon = "mcl_core:stone",
	show_inventory = true,
	build = function(player)
		return "label[1,1;Hello hello]button[2,2;2,2;Hello;hey]"
	end,
	handle = function(player, fields)
		print(dump(fields))
	end,
})]]

function mcl_inventory.build_survival_formspec(player)
	local tab = player_current_tab[player]

	local tab_def = nil

	for _, d in ipairs(mcl_inventory.registered_survival_inventory_tabs) do
		if tab == d.id then
			tab_def = d
			break
		end
	end
	local form

	if tab_def then
		form = build_page(player, tab_def.build(player), tab_def.show_inventory, tab)
	end

	return form
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "" and #mcl_inventory.registered_survival_inventory_tabs ~= 1 and
		player:get_meta():get_string("gamemode") ~= "creative" then
		for _, d in ipairs(mcl_inventory.registered_survival_inventory_tabs) do
			if fields["tab_" .. d.id] and d.access(player) then
				player_current_tab[player] = d.id
				mcl_inventory.update_inventory(player)
				break
			end
		end

		for _, d in ipairs(mcl_inventory.registered_survival_inventory_tabs) do
			if player_current_tab[player] == d.id and d.access(player) then
				d.handle(player, fields)
				return
			end
		end
	end
end)

local function find_empty_inv_slots(inv)
	local main, hotbar
	for i, stack in pairs(inv:get_list("main")) do
		if i > 9 and not main and stack:is_empty() then
			main = i
		elseif i <= 9 and not hotbar and stack:is_empty() then
			hotbar = i
		end
		if hotbar and main then break end
	end
	return main, hotbar
end

core.register_on_player_inventory_action(function(player, action, inv, info)
	if action == "move" and info.to_list == "sorter" then
		local stack = inv:get_stack(info.to_list, info.to_index)
		local empty_main, empty_hotbar = find_empty_inv_slots(inv)
		if core.get_item_group(stack:get_name(), "armor") > 0 then
			local newstack = mcl_armor.equip(stack, player, true)
			if newstack and not newstack:is_empty() then
				if inv:get_stack(info.from_list, info.from_index):is_empty() then
					inv:set_stack(info.from_list, info.from_index, newstack)
				elseif inv:room_for_item(info.from_list, newstack) then
					inv:add_item(info.from_list, newstack)
				end
			end
		elseif info.from_list == "main" and info.from_index <= 9 and empty_main then --hotbar to inv
			inv:set_stack("main", empty_main, stack)
		elseif info.from_list == "main" and info.from_index > 9 and empty_hotbar then
			inv:set_stack("main", empty_hotbar, stack)
		else
			inv:set_stack(info.from_list, info.from_index, stack)
		end
		inv:set_stack("sorter", 1, ItemStack(""))
	end
end)

core.register_allow_player_inventory_action(function(_, action, inv, info)
	if info.to_list == "sorter" or info.from_list == "sorter" or info.listname == "sorter" then
		if action == "put" or action == "take" then return 0 end
		local stack = inv:get_stack(info.from_list, info.from_index)
		local empty_main, empty_hotbar = find_empty_inv_slots(inv)
		if core.get_item_group(stack:get_name(), "armor") > 0 then
			return 1
		elseif ( info.from_list == "main" and info.from_index <= 9 and empty_main ) or
			( info.from_list == "main" and info.from_index > 9 and empty_hotbar ) then
			return stack:get_count()
		end
		return 0
	end
end)
