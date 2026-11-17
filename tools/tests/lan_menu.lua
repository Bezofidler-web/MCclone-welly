-- Runs inside Luanti's real title menu during Test-LanMultiplayer.ps1.
local role = assert(os.getenv("MCL_TEST_ROLE"))
local output = assert(os.getenv("MCL_TEST_DIR"))
local title = assert(os.getenv("MCL_TEST_MENU"))
local function mark(name, value)
	assert(core.safe_file_write(output .. "/" .. role .. "-" .. name, value or "ok"))
end
if (gamedata.errormessage or "") ~= "" then
	mark("ended", gamedata.errormessage)
	core.close()
	return
end
local spec, update = "", core.update_formspec
core.update_formspec = function(value)
	spec = value
	return update(value)
end
local wrapper = core.settings:get("main_menu_script")
core.settings:set("main_menu_script", title)
dofile(title)
core.settings:set("main_menu_script", wrapper)
mark("session", assert(os.getenv("MCL_LAN_SESSION_DIR")))
local original = core.start
core.start = function()
	assert(gamedata.mode == (role == "host" and "host" or "join"))
	assert(gamedata.password and #gamedata.password > 15)
	mark("start")
	original()
end
core.button_handler({mc_server = true})
assert(spec:find("Host World", 1, true) and not spec:find("mc_address", 1, true))
if role == "host" then
	core.button_handler({mc_host = true})
	if spec:find("mc_save_name", 1, true) then core.button_handler({mc_save_name = true, mc_name = "TestOwner"}) end
	local n = 0
	for _, world in ipairs(core.get_worlds()) do
		if world.gameid == os.getenv("MCL_GAME_ID") or world.gameid == "mineclonia" then
			n = n + 1
			if world.name == os.getenv("MCL_TEST_WORLD") then
				core.button_handler({mc_worlds = "CHG:" .. n})
				core.button_handler({mc_open_lan = true})
				return
			end
		end
	end
	error("Missing disposable world")
else
	-- Observe actual automatic refresh. The guest starts before the host.
	-- Leave the first name in the editable field until a world appears.
	local join_on_render = core.update_formspec
	local joined = false
	core.update_formspec = function(value)
		join_on_render(value)
		if not joined and value:find(os.getenv("MCL_TEST_WORLD"), 1, true) then
			joined = true
			mark("found")
			core.button_handler({mc_join_lan = true})
			if spec:find("mc_save_name", 1, true) then core.button_handler({mc_save_name = true, mc_name = "TestFriend"}) end
		end
	end
	if role == "returning" then
		-- Second launch may already have received an announcement.
		core.button_handler({mc_refresh = true})
	end
end
