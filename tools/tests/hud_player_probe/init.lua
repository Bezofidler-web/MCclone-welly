local oak, birch = "mcl_trees:wood_oak", "mcl_trees:wood_birch"
local function run()
	local inv = core.create_detached_inventory("hud_player_probe", {})
	local player = {
		get_inventory = function() return inv end, is_player = function() return true end,
		get_pos = function() return vector.zero() end, get_player_name = function() return "AuditProbe" end,
		get_look_dir = function() return vector.new(0, 0, 1) end,
	}
	local function reset()
		inv:set_size("main", 36)
		inv:set_size("craft", 9)
		inv:set_width("craft", 3)
		inv:set_list("craft", {})
		inv:set_list("main", {})
	end
	local failures = 0
	local function check(name, fn)
		reset()
		local ok, message = pcall(fn)
		if not ok then failures = failures + 1 end
		core.log("action", "[hud_player_probe] " .. (ok and "PASS " or "FAIL ") .. name .. (message and " " .. message or ""))
	end
	local function transfer(inputs, items, width)
		inv:set_list("main", inputs)
		mcl_inventory.to_craft_grid(player, {type="normal", width=width or 1, items=items})
	end
	check("mixed planks produce real stick recipe", function()
		transfer({oak, birch}, {"group:wood", "group:wood"})
		local result = core.get_craft_result({method = "normal", width = 3, items = inv:get_list("craft")})
		assert(result.item:get_name() == "mcl_core:stick" and result.item:get_count() == 4)
		assert(inv:is_empty("main"))
	end)
	check("compound groups and overlapping exact ingredients", function()
		transfer({oak, birch}, {"group:wood,wood", oak}, 2)
		assert(inv:get_stack("craft", 1):get_name() == birch and inv:get_stack("craft", 2):get_name() == oak)
	end)
	check("incomplete recipe preserves existing grid", function()
		inv:set_stack("craft", 1, "mcl_core:stone")
		transfer({oak}, {"group:wood", "group:wood"})
		assert(inv:get_stack("craft", 1):get_name() == "mcl_core:stone" and inv:get_stack("main", 1):get_name() == oak)
	end)
	check("single existing grid item can be reused", function()
		inv:set_stack("craft", 2, birch)
		transfer({oak}, {"group:wood","group:wood"})
		assert(inv:get_stack("craft", 1):get_count() == 1 and inv:get_stack("craft", 4):get_count() == 1)
	end)
	check("full backpack can exchange existing craft ingredients", function()
		inv:set_size("main", 1)
		inv:set_stack("craft", 2, birch)
		transfer({oak}, {oak})
		assert(inv:get_stack("craft", 1):get_name() == oak and inv:get_stack("main", 1):get_name() == birch)
	end)
	check("no return space leaves backpack and grid untouched", function()
		inv:set_size("main", 1)
		inv:set_list("craft", {birch})
		transfer({oak .. " 2"}, {oak})
		assert(inv:get_stack("main", 1):get_count() == 2 and inv:get_stack("craft", 1):get_name() == birch)
	end)
	check("personal crafting rejects three rows and preserves the grid stride", function()
		inv:set_list("main", {oak .. " 3"})
		local recipe = {type="normal", width=1, items={oak, oak, oak}}
		assert(not mcl_inventory.to_craft_grid(player, recipe, 2, 2))
		assert(inv:get_stack("main", 1):get_count() == 3 and inv:is_empty("craft"))
		recipe.items[3] = nil
		assert(mcl_inventory.to_craft_grid(player, recipe, 2, 2))
		assert(inv:get_stack("craft", 4):get_name() == oak and inv:get_stack("craft", 3):is_empty())
	end)
	check("bulk fill conserves named stacks", function()
		local named = ItemStack(oak .. " 4")
		named:get_meta():set_string("description", "Timber")
		inv:set_list("main", {named})
		inv:set_list("craft", {oak})
		mcl_inventory.fill_grid(player)
		assert(inv:get_stack("craft", 1):get_count() == 1 and inv:get_stack("main", 1):equals(named))
		inv:set_stack("craft", 1, named:peek_item())
		mcl_inventory.fill_grid(player)
		assert(inv:get_stack("craft", 1):get_count() == 5 and inv:is_empty("main"))
	end)
	local original = core.registered_on_item_eats
	check("eating callback sees the last food and retains replacement", function()
		local eaten
		core.registered_on_item_eats = {function(_, _, stack) eaten = stack:get_name() end}
		local result = core.do_item_eat(nil, "mcl_core:bowl", ItemStack("mcl_farming:bread"), player, {type="nothing"})
		assert(eaten == "mcl_farming:bread" and result:get_name() == "mcl_core:bowl")
	end)
	check("cancelling consumption preserves original stack", function()
		core.registered_on_item_eats = {function(_, _, stack) return stack end}
		local result = core.do_item_eat(4, nil, ItemStack("mcl_farming:bread"), player, {type="nothing"})
		assert(result:get_name() == "mcl_farming:bread" and result:get_count() == 1)
	end)
	core.registered_on_item_eats = original
	core.log("action", "[hud_player_probe] TOTAL FAILURES " .. failures)
	core.request_shutdown("audit complete", false, 0)
end
core.after(0, run)
