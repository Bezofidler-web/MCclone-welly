local NIGHT_VISION_RATIO = 0.45
local S = core.get_translator(core.get_current_modname())
local vibrant_setting = "mcl_weather:vibrant_lighting"
local clouds_setting = "mcl_weather:enable_clouds"
local visibility_setting = "mcl_weather:low_light_visibility"
local clear_cloud_color = "#FFF0F0E5"
local weather_cloud_colors = { rain = "#5D5D5FE8", thunder = "#3D3D3FE8" }
local water_at_eye = {}
local default_sky_color = "#78A7FF"
local default_horizon_color = "#C0D8FF"
local default_water_fog = "#050533"
local water_fog_lift = "#5099B9"
local sky_sample_spacing = 8

-- Luanti 5.18 converts the existing map light into display brightness using
-- this table on each client. A visible level zero still counts as zero for
-- spawning and all other game mechanics. Full sunlight stays at 255.
local low_light_curve = {61, 71, 80, 90, 100, 112, 124, 136, 149, 163, 177, 191, 206, 222, 238, 255}

-- Overworld water fog attributes from Java Edition 26.3. The order matters
-- for the native mapgen, where warmer ocean aliases overlap.
local water_fog_biomes = {
	{ biomes = { "Swamp" }, color = "#232317", distance_factor = 0.85 },
	{ biomes = { "MangroveSwamp" }, color = "#4D7A60", distance_factor = 0.85 },
	{ biomes = { "CherryGrove" }, color = "#5DB7EF" },
	{ biomes = { "DappledForest" }, color = "#375154" },
	{ biomes = { "PaleGarden" }, color = "#556980" },
	{ biomes = { "WarmOcean" }, color = "#041F33" },
	{ biomes = { "LukewarmOcean", "DeepLukewarmOcean" }, color = "#041633" },
}

core.register_on_mods_loaded (function ()
	for _, profile in ipairs (water_fog_biomes) do
		profile.matches = mcl_biome_dispatch.make_biome_test (profile.biomes)
	end
end)

local function get_water_fog (pos)
	local biome = mcl_biome_dispatch.get_biome_name_nosample (pos)
	for _, profile in ipairs (water_fog_biomes) do
		if profile.matches (biome) then
			return profile.color, profile.distance_factor or 1
		end
	end
	return default_water_fog, 1
end

local standard_lighting = {
	shadows = { intensity = 0.30, tint = "#000000" },
	volumetric_light = { strength = 0.12 },
	bloom = { intensity = 0.025, radius = 1, strength_factor = 1 },
	exposure = {
		luminance_min = -3.5,
		luminance_max = -2.5,
		exposure_correction = 0.35,
		speed_dark_bright = 1500,
		speed_bright_dark = 700,
	},
	saturation = 1.0,
}

local vibrant_lighting = {
	overworld = {
		shadows = { intensity = 0.45, tint = "#39485D" },
		volumetric_light = { strength = 0.20 },
		bloom = { intensity = 0.045, radius = 1, strength_factor = 1.0 },
		saturation = 1.06,
	},
	nether = {
		shadows = { intensity = 0, tint = "#000000" },
		volumetric_light = { strength = 0 },
		bloom = { intensity = 0.05, radius = 1.1, strength_factor = 1.0 },
		saturation = 1.04,
	},
	["end"] = {
		shadows = { intensity = 0, tint = "#000000" },
		volumetric_light = { strength = 0 },
		bloom = { intensity = 0.035, radius = 1.05, strength_factor = 1.0 },
		saturation = 1.02,
	},
}
local vibrant_exposure = {
	luminance_min = -3.5,
	luminance_max = -2.5,
	exposure_correction = 0.12,
	speed_dark_bright = 1500,
	speed_bright_dark = 700,
}

local function vibrant_enabled (player)
	return mcl_player.get_player_setting (player, vibrant_setting, false)
end

local function visibility_enabled (player)
	return mcl_player.get_player_setting (player, visibility_setting, true)
end

local function display_lighting (player)
	return {light_curve = visibility_enabled (player) and low_light_curve or {}}
end

local function set_lighting (player)
	if not player.set_lighting then return end
	local dim = mcl_worlds.pos_to_dimension (player:get_pos ())
	local lighting = vibrant_enabled (player) and vibrant_lighting[dim]
	player:set_lighting (table.merge (lighting or standard_lighting, {
		exposure = lighting and vibrant_exposure or standard_lighting.exposure,
		static = display_lighting (player),
	}))
end

local function sky_fog (player, start, distance, color)
	local fog = { fog_color = color or "#00000000" }
	-- Darkness owns the fog range and pulsating fog start while it is active.
	if player:get_meta ():get_int ("darkness") ~= 1 then
		fog.fog_start = start
		fog.fog_distance = distance or -1
	end
	return fog
end

local function get_water_at_eye (player, pos)
	local offset = player:get_eye_offset ()
	-- The eye offset uses tenths of a node.
	local height = player:get_properties ().eye_height + offset.y / 10
	local name = core.get_node (vector.offset (pos, 0, height, 0)).name
	if core.get_item_group (name, "water") ~= 0 then
		return name:find ("river_water", 1, true) and "river" or "water"
	end
	return false
end

local function storm_light_ratio ()
	if mcl_weather.skycolor.current_layer_name () == "lightning" then
		return 1
	end
	local factor = mcl_weather.get_current_light_factor ()
	if factor then
		local daylight = 1 - math.abs (0.5 - core.get_timeofday ())
		return math.max (0.2, daylight * factor - 0.15)
	end
end

mcl_player.register_player_setting (vibrant_setting, {
	type = "boolean",
	section = "Graphics",
	short_desc = S ("Vibrant lighting"),
	long_desc = S ("Tinted shadows and more atmospheric fog. Use the Vibrant client profile for shadows, bloom and light shafts."),
	ui_default = "false",
	on_change = function (player)
		set_lighting (player)
		mcl_weather.skycolor.update_sky_color ({player})
	end,
})

mcl_player.register_player_setting (visibility_setting, {
	type = "boolean",
	section = "Graphics",
	short_desc = S ("Brighter caves and water"),
	long_desc = S ("Make caves easier to see and extend underwater visibility. This changes only what you see."),
	ui_default = "true",
	on_change = function (player)
		if player.set_lighting then
			player:set_lighting ({static = display_lighting (player)})
		end
		mcl_weather.skycolor.update_sky_color ({player})
	end,
})

mcl_player.register_player_setting(clouds_setting, {
	type = "boolean",
	section = "Graphics",
	short_desc = S("Clouds"),
	ui_default = "true",
	on_change = function (player)
		mcl_weather.skycolor.update_sky_color ({player})
	end,
})

function mcl_weather.set_sky_box_clear(player, sky, fog)
	if mcl_serverplayer.is_csm_at_least (player, 2) then
		return
	end

	local sc = {
			day_sky = default_sky_color,
			day_horizon = default_horizon_color,
			dawn_sky = default_sky_color,
			dawn_horizon = default_horizon_color,
			night_sky = "#000000",
			night_horizon = "#4A6790",
			indoors = default_horizon_color,
			fog_sun_tint = "#ff5f33",
			fog_moon_tint = nil,
			fog_tint_type = "custom"
		}
	if sky then
		sc.day_sky = sky
		sc.dawn_sky = sky
	end
	if fog then
		sc.day_horizon = fog
		sc.dawn_horizon = fog
	end
	player:set_sky({
		type = "regular",
		sky_color = sc,
		fog = sky_fog (player, vibrant_enabled (player) and 0.89 or -1),
		clouds = mcl_player.get_player_setting (player, clouds_setting, true),
		auto_dim_skybox = false,
	})
end

function mcl_weather.set_sky_color(player, def)
	if mcl_serverplayer.is_csm_at_least (player, 2) then
		return
	end

	player:set_sky({
		type = def.type,
		sky_color = def.sky_color,
		fog = sky_fog (player, def.fog_start or -1, def.fog_distance),
		clouds = def.clouds,
		auto_dim_skybox = false,
	})
end

local function get_sky_color (pos)
	local nodepos = mcl_util.get_nodepos (pos)
	return mcl_biome_dispatch.get_sky_color (nodepos)
end

local function get_fog_color (pos)
	local nodepos = mcl_util.get_nodepos (pos)
	return mcl_biome_dispatch.get_fog_color (nodepos)
end

local function add_weighted_color (sum, color, weight)
	local r, g, b = core.colorspec_to_bytes (color):byte (1, 3)
	sum.r = sum.r + r * weight
	sum.g = sum.g + g * weight
	sum.b = sum.b + b * weight
end

local function rgb_hex (color)
	return ("#%02X%02X%02X"):format (
		math.floor (color.r + 0.5), math.floor (color.g + 0.5), math.floor (color.b + 0.5))
end

local function water_view (player, pos, dim)
	local color, distance_factor = "#1D476D", 1
	if dim == "overworld" then
		color, distance_factor = get_water_fog (mcl_util.get_nodepos (pos))
	end
	local clear = visibility_enabled (player)
	local night_vision = player:get_meta ():get_int ("night_vision") == 1
	local distance = clear and (night_vision and 112 or 72) or (night_vision and 88 or 48)
	local start = clear and (night_vision and 0.40 or 0.23) or (night_vision and 0.35 or 0.10)
	if clear then
		local blend = {r = 0, g = 0, b = 0}
		add_weighted_color (blend, color, 0.58)
		add_weighted_color (blend, water_fog_lift, 0.42)
		color = rgb_hex (blend)
	end
	return color, start, math.floor (distance * distance_factor + 0.5)
end

local function get_blended_sky_colors (pos)
	local x0 = math.floor (pos.x / sky_sample_spacing) * sky_sample_spacing
	local z0 = math.floor (pos.z / sky_sample_spacing) * sky_sample_spacing
	local y = math.floor (pos.y + 0.5)
	local dx = (pos.x - x0) / sky_sample_spacing
	local dz = (pos.z - z0) / sky_sample_spacing
	-- Fall back to the camera's own biome when a neighbouring chunk hasn't loaded.
	local local_sky, local_fog = mcl_biome_dispatch.get_sky_and_fog_colors (mcl_util.get_nodepos (pos))
	local sky_total = {r = 0, g = 0, b = 0}
	local fog_total = {r = 0, g = 0, b = 0}
	for i = 0, 1 do
		for j = 0, 1 do
			local sky, fog = mcl_biome_dispatch.get_sky_and_fog_colors (
				vector.new (x0 + i * sky_sample_spacing, y, z0 + j * sky_sample_spacing))
			local weight = (i == 0 and 1 - dx or dx) * (j == 0 and 1 - dz or dz)
			add_weighted_color (sky_total, sky or local_sky or default_sky_color, weight)
			add_weighted_color (fog_total, fog or local_fog or default_horizon_color, weight)
		end
	end
	return rgb_hex (sky_total), rgb_hex (fog_total)
end

mcl_weather.skycolor = {
	-- Should be activated before do any effect.
	active = true,

	-- To skip update interval
	force_update = true,

	-- Update interval.
	update_interval = 3,

	-- Main sky colors: starts from midnight to midnight.
	-- Please do not set directly. Use add_layer instead.
	colors = {},

	-- min value which will be used in color gradient, usualy its first user given color in 'pure' color.
	min_val = 0,

	-- number of colors while constructing gradient of user given colors
	max_val = 1000,

	-- Table for tracking layer order
	layer_names = {},

	-- To layer to colors table
	add_layer = function(layer_name, layer_color, _)
		mcl_weather.skycolor.colors[layer_name] = layer_color
		table.insert(mcl_weather.skycolor.layer_names, layer_name)
		mcl_weather.skycolor.force_update = true
	end,

	current_layer_name = function()
		return mcl_weather.skycolor.layer_names[#mcl_weather.skycolor.layer_names]
	end,

	-- Retrieve layer from colors table
	retrieve_layer = function()
		local last_layer = mcl_weather.skycolor.current_layer_name()
		return mcl_weather.skycolor.colors[last_layer]
	end,

	-- Remove layer from colors table
	remove_layer = function(layer_name)
		for k, name in pairs(mcl_weather.skycolor.layer_names) do
			if name == layer_name then
				table.remove(mcl_weather.skycolor.layer_names, k)
				mcl_weather.skycolor.force_update = true
				return
			end
		end
	end,

	-- Wrapper for updating day/night ratio that respects night vision
	override_day_night_ratio = function(player, ratio)
		if not mcl_serverplayer.is_csm_at_least (player, 2) then
			local meta = player:get_meta()
			local has_night_vision = meta:get_int("night_vision") == 1
			local has_darkness = meta:get_int("darkness") == 1
			local is_visited_shepherd = meta:get_int("mcl_shepherd:special") == 1
			local arg
			if has_darkness and not is_visited_shepherd then
				if has_night_vision then arg = 0.1
				else arg = 0 end
			else
				-- Apply night vision only for dark sky
				local is_dark = core.get_timeofday() > 0.8 or core.get_timeofday() < 0.2 or mcl_weather.state ~= "none"
				local pos = player:get_pos()
				local dim = mcl_worlds.pos_to_dimension(pos)
				if (has_night_vision or is_visited_shepherd) and is_dark and dim ~= "nether" and dim ~= "end" then
					if ratio == nil then
						arg = NIGHT_VISION_RATIO
					else
						arg = math.max(ratio, NIGHT_VISION_RATIO)
					end
				else
					arg = ratio
				end
			end
			player:override_day_night_ratio(arg)
		end
	end,

	-- Update sky color. If players not specified update sky for all players.
	update_sky_color = function(players)
		-- Override day/night ratio as well
		players = mcl_weather.skycolor.utils.get_players(players)
		for _, player in ipairs(players) do
			local pos = player:get_pos()
			local dim = mcl_worlds.pos_to_dimension(pos)
			local vibrant = vibrant_enabled (player)
			local water = get_water_at_eye (player, pos)
			water_at_eye[player] = water
			if water then
				local water_color, fog_start, distance = water_view (player, pos, dim)
				player:set_sky({
					type = "plain",
					base_color = water_color,
					fog = sky_fog (player, fog_start, distance, water_color),
					clouds = false,
					auto_dim_skybox = false,
				})
				player:set_sun ({visible = false, sunrise_visible = false})
				player:set_moon ({visible = false})
				player:set_stars ({visible = false})
				local light = dim == "end" and 0.5 or dim == "overworld" and storm_light_ratio () or nil
				mcl_weather.skycolor.override_day_night_ratio (player, light)
			elseif dim == "overworld" then
				local overcast = weather_cloud_colors[mcl_weather.state]
				local has_snow = overcast and mcl_weather.has_snow (pos)
				local has_weather = overcast and (has_snow or mcl_weather.has_rain (pos))
				local cloud_color = clear_cloud_color
				if has_weather then
					cloud_color = has_snow and "#ADADADE8" or overcast
				end
				player:set_clouds ({color = cloud_color})
				if (mcl_weather.state == "none") then
					-- Clear weather
					local biomesky, biomefog = get_blended_sky_colors (pos)
					mcl_weather.set_sky_box_clear(player,biomesky,biomefog)
					player:set_sun({visible = true, sunrise_visible = true})
					player:set_moon({visible = true})
					player:set_stars({visible = true})
					mcl_weather.skycolor.override_day_night_ratio(player, nil)
				elseif not has_weather then
					local day_color = mcl_weather.skycolor.get_sky_layer_color(0.15)
					local dawn_color = mcl_weather.skycolor.get_sky_layer_color(0.27)
					local night_color = mcl_weather.skycolor.get_sky_layer_color(0.1)
					mcl_weather.set_sky_color(player, {
						type = "regular",
						sky_color = {
							day_sky = day_color,
							day_horizon = day_color,
							dawn_sky = dawn_color,
							dawn_horizon = dawn_color,
							night_sky = night_color,
							night_horizon = night_color,
						},
						fog_start = vibrant and 0.78 or -1,
						clouds = mcl_player.get_player_setting (player, clouds_setting, true),
					})
					player:set_sun({visible = false, sunrise_visible = false})
					player:set_moon({visible = false})
					player:set_stars({visible = false})
					mcl_weather.skycolor.override_day_night_ratio (player, storm_light_ratio ())
				else
					-- Weather skies
					local day_color = mcl_weather.skycolor.get_sky_layer_color(0.5)
					local dawn_color = mcl_weather.skycolor.get_sky_layer_color(0.75)
					local night_color = mcl_weather.skycolor.get_sky_layer_color(0)
					mcl_weather.set_sky_color(player, {
						type = "regular",
						sky_color = {
							day_sky = day_color,
							day_horizon = day_color,
							dawn_sky = dawn_color,
							dawn_horizon = dawn_color,
							night_sky = night_color,
							night_horizon = night_color,
						},
						fog_start = vibrant and 0.58 or 0.72,
						clouds = mcl_player.get_player_setting (player, clouds_setting, true),
					})
					player:set_sun({visible = false, sunrise_visible = false})
					player:set_moon({visible = false})
					player:set_stars({visible = false})

					mcl_weather.skycolor.override_day_night_ratio (player, storm_light_ratio ())
				end
			elseif dim == "end" then
				local biomesky = get_sky_color (pos) or "#000000"
				local t = "mcl_playerplus_end_sky.png"
				player:set_sky({ type = "skybox",
					base_color = biomesky,
					textures = {t,t,t,t,t,t},
					fog = sky_fog (player, vibrant and 0.67 or 0.78),
					clouds = false,
				})
				player:set_sun({visible = false , sunrise_visible = false})
				player:set_moon({visible = false})
				player:set_stars({visible = false})
				mcl_weather.skycolor.override_day_night_ratio(player, 0.5)
			elseif dim == "nether" then
				local biomefog = get_fog_color (pos) or "#330808"
				mcl_weather.set_sky_color(player, {
					type = "regular",
					sky_color = {
						day_sky = biomefog,
						day_horizon = biomefog,
						dawn_sky = biomefog,
						dawn_horizon = biomefog,
						night_sky = biomefog,
						night_horizon = biomefog,
						indoors = biomefog,
						fog_sun_tint = biomefog,
						fog_moon_tint = biomefog,
						fog_tint_type = "custom"
					},
					fog_start = vibrant and 0.32 or 0.48,
					fog_distance = 96,
					clouds = false,
				})
				player:set_sun({visible = false , sunrise_visible = false})
				player:set_moon({visible = false})
				player:set_stars({visible = false})
				mcl_weather.skycolor.override_day_night_ratio(player, nil)
			elseif dim == "void" then
				player:set_sky({ type = "plain",
					base_color = "#000000",
					clouds = false,
					fog = sky_fog (player, -1),
				})
				player:set_sun({visible = false, sunrise_visible = false})
				player:set_moon({visible = false})
				player:set_stars({visible = false})
			end
		end
	end,

	-- Returns current layer color in {r, g, b} format
	get_sky_layer_color = function(timeofday)
		if #mcl_weather.skycolor.layer_names == 0 then
			return nil
		end

		-- min timeofday value 0; max timeofday value 1. So sky color gradient range will be between 0 and 1 * mcl_weather.skycolor.max_val.
		local rounded_time = math.floor(timeofday * mcl_weather.skycolor.max_val)
		local color = mcl_weather.skycolor.utils.convert_to_rgb(mcl_weather.skycolor.min_val, mcl_weather.skycolor.max_val, rounded_time, mcl_weather.skycolor.retrieve_layer())
		return color
	end,

	utils = {
		convert_to_rgb = function(minval, maxval, current_val, colors)
			local max_index = #colors - 1
			local val = (current_val-minval) / (maxval-minval) * max_index + 1.0
			local index1 = math.floor(val)
			local index2 = math.min(math.floor(val)+1, max_index + 1)
			local f = val - index1
			local c1 = colors[index1]
			local c2 = colors[index2]
			return {r=math.floor(c1.r + f*(c2.r - c1.r)), g=math.floor(c1.g + f*(c2.g-c1.g)), b=math.floor(c1.b + f*(c2.b - c1.b))}
		end,

		-- Simply getter. Ether returns user given players list or get all connected players if none provided
		get_players = function(players_in)
			local players = {}
			if players_in == nil then
				for player in mcl_util.connected_players () do
					if not mcl_serverplayer.is_csm_at_least (player, 2) then
						table.insert (players, player)
					end
				end
			else
				for _, player in ipairs (players_in) do
					if not mcl_serverplayer.is_csm_at_least (player, 2) then
						table.insert (players, player)
					end
				end
			end
			return players
		end,

		-- Returns first player sky color. I assume that all players are in same color layout.
		get_current_bg_color = function()
			local players = mcl_weather.skycolor.utils.get_players(nil)
			if players[1] then
				return players[1]:get_sky(true).sky_color
			end
			return nil
		end
	},

}

local timer = 0
local water_timer = 0
core.register_globalstep(function(dtime)
	if mcl_weather.skycolor.active ~= true or #core.get_connected_players() == 0 then
		return
	end

	if mcl_weather.skycolor.force_update then
		mcl_weather.skycolor.update_sky_color()
		mcl_weather.skycolor.force_update = false
		return
	end

	-- regular updates based on iterval
	timer = timer + dtime;
	if timer >= mcl_weather.skycolor.update_interval then
		mcl_weather.skycolor.update_sky_color()
		timer = 0
		water_timer = 0
		return
	end

	-- Refresh immediately after the camera crosses water instead of waiting
	-- for the next periodic weather and biome update.
	water_timer = water_timer + dtime
	if water_timer >= 0.2 then
		water_timer = 0
		local changed = {}
		for _, player in ipairs (mcl_weather.skycolor.utils.get_players ()) do
			if get_water_at_eye (player, player:get_pos ()) ~= water_at_eye[player] then
				changed[#changed + 1] = player
			end
		end
		if #changed > 0 then
			mcl_weather.skycolor.update_sky_color (changed)
		end
	end
end)

local function initsky(player)
	set_lighting (player)

	if (mcl_weather.skycolor.active) then
		mcl_weather.skycolor.force_update = true
	end

	local clouds = mcl_worlds.get_cloud_parameters ()
	clouds.color = clear_cloud_color
	player:set_clouds (clouds)
end

core.register_on_joinplayer(initsky)
core.register_on_respawnplayer(initsky)
core.register_on_leaveplayer (function (player)
	water_at_eye[player] = nil
end)

mcl_worlds.register_on_dimension_change(function(player)
	set_lighting (player)
	mcl_weather.skycolor.update_sky_color({player})
end)
