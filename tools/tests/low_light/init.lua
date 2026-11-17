-- luacheck: globals mcl_player mcl_weather vector
local setting = "mcl_weather:low_light_visibility"
local world = core.get_worldpath()
local expected = assert(os.getenv("MCL_LIGHT_TEST_WORLD")):gsub("\\", "/")
assert(world:gsub("\\", "/") == expected, "Unexpected low-light test world")
local cave = vector.new(0, 41, 0)
local pool = vector.new(32, 41, 0)

local function build_room(pos, flooded)
	local shell, inside = {}, {}
	for z = -3, 21 do
		for x = -6, 6 do
			for y = -1, 6 do
				local edge = math.abs(x) == 6 or y == -1 or y == 6 or z == -3 or z == 21
				local nodes = edge and shell or inside
				nodes[#nodes + 1] = vector.offset(pos, x, y, z)
			end
		end
	end
	core.bulk_set_node(shell, {name = "mcl_core:stone"})
	core.bulk_set_node(inside, {name = flooded and "mcl_core:water_source" or "air"})
	for z = 5, 19, 7 do
		for y = 0, 4 do
			core.set_node(vector.offset(pos, -2, y, z), {name = "mcl_core:goldblock"})
			core.set_node(vector.offset(pos, 2, y, z), {name = "mcl_core:ironblock"})
		end
	end
	core.fix_light(vector.offset(pos, -6, -1, -3), vector.offset(pos, 6, 6, 21))
end

local function view(player, pos)
	player:set_pos(pos)
	player:set_look_horizontal(0)
	player:set_look_vertical(-0.05)
	mcl_weather.skycolor.update_sky_color({player})
end

local function check(player)
	view(player, cave)
	local curve = player:get_lighting().static.light_curve
	assert(#curve == 16 and curve[1] >= 55 and curve[16] == 255)
	for i = 2, #curve do assert(curve[i - 1] < curve[i]) end
	assert(core.get_node_light(cave, 0.5) == 0)
	local saturation = player:get_lighting().saturation
	player:set_lighting({saturation = 0.5})
	mcl_player.set_player_setting(player, setting, false)
	assert(not next(player:get_lighting().static.light_curve))
	assert(player:get_lighting().saturation == 0.5)
	player:set_lighting({saturation = saturation})
	assert(core.get_node_light(cave, 0.5) == 0)
	view(player, pool)
	local original = player:get_sky(true).fog
	mcl_player.set_player_setting(player, setting, nil)
	local bright = player:get_sky(true).fog
	assert(bright.fog_distance > original.fog_distance and bright.fog_start > original.fog_start)
	assert(bright.fog_color.r > original.fog_color.r and bright.fog_color.g > original.fog_color.g)
	assert(core.get_node_light(pool, 0.5) == 0)
	assert(player:get_properties().breath_max > 0)
	player:get_meta():set_int("night_vision", 1)
	mcl_weather.skycolor.update_sky_color({player})
	assert(player:get_sky(true).fog.fog_distance > bright.fog_distance)
	player:get_meta():set_int("night_vision", 0)
	player:get_meta():set_int("darkness", 1)
	player:set_sky({fog = {fog_start = 0.03, fog_distance = 10}})
	mcl_weather.skycolor.update_sky_color({player})
	assert(player:get_sky(true).fog.fog_distance == 10)
	player:get_meta():set_int("darkness", 0)
	view(player, cave)
	assert(player:get_sky(true).fog.fog_distance == -1)
	core.log("action", "[low-light] PASS display curve, zero map light, underwater fog, Night Vision, Darkness and surfacing")
end

local function wait_for_scene(player, last)
	local file = io.open(world .. "/scene", "r")
	local scene = file and file:read("*l")
	if file then file:close() end
	if scene and scene ~= last then
		if scene == "stop" then core.request_shutdown("Visibility review complete", false, 0) return end
		view(player, scene:find("water", 1, true) and pool or cave)
		mcl_player.set_player_setting(player, setting, not scene:find("old", 1, true))
		core.log("action", "[low-light] Scene " .. scene)
	end
	core.after(0.3, wait_for_scene, player, scene)
end

core.register_on_joinplayer(function(player)
	player:hud_set_flags({minimap = false, hotbar = false, healthbar = false, crosshair = false})
	if os.getenv("MCL_LIGHT_TEST_VISUAL") == "1" then
		player:set_properties({breath_max = 600})
		player:set_breath(600)
	end
	core.emerge_area(vector.offset(cave, -8, -2, -4), vector.offset(pool, 8, 8, 22), function(_, _, remaining)
		if remaining ~= 0 then return end
		core.after(0, function()
			build_room(cave, false)
			build_room(pool, true)
			check(player)
			if os.getenv("MCL_LIGHT_TEST_VISUAL") == "1" then
				wait_for_scene(player)
			else
				core.request_shutdown("Visibility regression passed", false, 0)
			end
		end)
	end)
end)
