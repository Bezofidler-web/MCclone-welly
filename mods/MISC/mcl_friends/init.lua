mcl_friends = { is_host = function() return false end }

if os.getenv("MCL_LAN_SESSION_ID") and not core.settings:get_bool("mcl_friends_only", false) then
	dofile(core.get_modpath(core.get_current_modname()) .. "/lan.lua")
end

if core.is_singleplayer() or not core.settings:get_bool("mcl_friends_only", false) then
	return
end

if not core.settings:get_bool("disallow_empty_password", false) then
	error("Friends-only multiplayer requires disallow_empty_password = true.")
end

local admin = core.settings:get("name") or ""
if admin == "" then
	error("Set name to the host's Luanti player name in the friends server configuration.")
end

local modpath = core.get_modpath(core.get_current_modname())
-- Keep the dedicated server's account policy with the save when it is
-- subsequently selected from a different local client configuration.
core.get_mod_storage():set_int("private_world", 1)
local accounts = dofile(modpath .. "/accounts.lua")(admin)
dofile(modpath .. "/controls.lua")(admin, accounts)
