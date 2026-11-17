-- SPDX-License-Identifier: GPL-3.0-or-later
-- Main-menu side of a launcher-managed LAN session. Network discovery runs
-- outside Lua; only the integrated game server decides who can play.
local S = core.gettext
local dir = os.getenv("MCL_LAN_SESSION_DIR")
local token = os.getenv("MCL_LAN_SESSION_ID")
local key = os.getenv("MCL_LAN_PROFILE_KEY")
local port = tonumber(os.getenv("MCL_LAN_PORT"))
local lan = {}

local function hex(value, size)
	return type(value) == "string" and #value == size and not value:find("[^a-fA-F0-9]")
end

lan.available = dir and hex(token, 32) and type(key) == "string" and #key >= 32 and port
	and port == math.floor(port) and port >= 1 and port <= 65535

function lan.valid_name(name)
	return #name > 0 and #name <= 20 and name:match("^[a-zA-Z0-9_%-]+$") and name:lower() ~= "singleplayer"
end

local function read(path)
	local f = io.open(path, "rb")
	if not f then return end
	local contents = f:read(65537)
	f:close()
	if contents and #contents <= 65536 then return core.parse_json(contents) end
end

local function ipv4(address)
	if type(address) ~= "string" then return false end
	local a,b,c,d = address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	return a and tonumber(a) > 0 and tonumber(a) < 224 and tonumber(b) < 256 and tonumber(c) < 256 and tonumber(d) < 256
end

function lan.worlds()
	local worlds = {}
	if not lan.available then
		return worlds, os.getenv("MCL_LAN_ERROR") or S("Open Play Mineclonia to find and share nearby worlds.")
	end
	local status = read(dir .. "/status.json")
	local records = read(dir .. "/worlds.json")
	for _, entry in ipairs(type(records) == "table" and records or {}) do
		if type(entry) == "table" and hex(entry.id, 32) and type(entry.world) == "string" and #entry.world <= 256
				and type(entry.host) == "string" and lan.valid_name(entry.host) and ipv4(entry.address)
				and type(entry.port) == "number" and entry.port == math.floor(entry.port)
				and entry.port > 0 and entry.port <= 65535 then
			worlds[#worlds + 1] = entry
		end
	end
	return worlds, type(status) == "table" and type(status.error) == "string" and status.error or nil
end

-- The verifier accepted by one world is never a reusable account password
-- for another. Do not advertise the profile key or save it in world files.
function lan.password(id, host, name)
	return core.sha256("mcwelly-lan-login-v1\0" .. id .. "\0" .. host .. "\0" .. name .. "\0" .. key)
end

function lan.host(world, name)
	if not lan.available then return nil, S("Open Play Mineclonia to share worlds.") end
	local mt = Settings(world.path .. DIR_DELIM .. "world.mt")
	if core.settings:get_bool("mcl_friends_only") or mt:get_bool("mcl_friends_only")
			or (core.settings:get("default_password") or "") ~= "" then
		return nil, S("This world or profile uses private server accounts. Open it with its original host settings.")
	end
	local saved = read(world.path .. "/mcl_lan_world.json")
	if saved ~= nil and (type(saved) ~= "table" or not hex(saved.id, 32) or
			type(saved.owner) ~= "string" or not lan.valid_name(saved.owner) or type(saved.solo) ~= "boolean") then
		return nil, S("This world's sharing information could not be read.")
	end
	if saved and saved.owner ~= name then
		return nil, S("Reopen this world with its original host name: ") .. saved.owner
	end
	local solo = core.mcl_lan_solo_identity == true and (not saved or saved.solo)
	if saved and saved.solo and not solo then
		return nil, S("Open this world with the native mcWelly client to keep its original host player.")
	end
	-- A session nonce is random. Mix in the path so two worlds created from
	-- the same running launcher still have independent public identifiers.
	local id = saved and saved.id or core.sha256("world\0" .. token .. "\0" .. world.path):sub(1, 32)
	local info = {session = token, id = id, world_path = world.path, world_name = world.name, host = name, port = port}
	if not core.safe_file_write(dir .. "/host.json", core.write_json(info)) then
		return nil, S("The multiplayer launcher could not be reached. Reopen Play Mineclonia.")
	end
	-- The game mod writes permanent ownership only after verifying this is
	-- an eligible world and its local owner has successfully logged in.
	core.settings:set("mcl_lan_session", token)
	core.settings:set("mcl_lan_world_path", world.path)
	core.settings:set("mcl_lan_id", id)
	core.settings:set("mcl_lan_display_host", name)
	core.settings:set_bool("mcl_lan_solo_owner", solo == true)
	return {name = solo and "singleplayer" or name, password = solo and "" or lan.password(id, name, name), port = port}
end

function lan.host_description(world)
	local previous = world and read(world.path .. "/mcl_lan_world.json")
	if type(previous) == "table" and type(previous.owner) == "string" then
		if previous.solo then return S("Anyone on this network can join. Original host: ") .. previous.owner end
		return S("This world uses its separate multiplayer host player: ") .. previous.owner
	end
	if core.mcl_lan_solo_identity then return S("Anyone on this network can join while you play.") end
	return S("Anyone on this network can join. Standard Luanti keeps a separate host character and inventory for LAN sessions.")
end

function lan.consume_open_request(world)
	if not lan.available then return end
	local path = world.path .. "/mcl_open_lan.json"
	local request = read(path)
	if type(request) == "table" and request.session == token then
		return core.safe_file_write(path, "{}")
	end
end

return lan
