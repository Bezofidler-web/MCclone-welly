local S = core.get_translator(core.get_current_modname())

if core.is_singleplayer() or not core.settings:get_bool("mcl_friends_only", false) then
	return
end

if not core.settings:get_bool("disallow_empty_password", false) then
	error("Friends-only multiplayer requires disallow_empty_password = true.")
end

local allowed = {}
local function allow(name)
	if name == "" or #name > 20 or name:find("[^A-Za-z0-9_%-]") or name:lower() == "singleplayer" then
		error("Use Luanti multiplayer names of 1 to 20 letters, digits, hyphens or underscores.")
	end
	allowed[name] = true
end

local admin = core.settings:get("name") or ""
if admin == "" then
	error("Set name to the host's Luanti player name in the friends server configuration.")
end
allow(admin)

local friends = (core.settings:get("mcl_friends_allowed_names") or ""):trim()
if friends ~= "" then
	for _, entry in ipairs(friends:split(",", true)) do
		allow(entry:trim())
	end
end

local invitee = (core.settings:get("mcl_friends_invited_name") or ""):trim()
if invitee ~= "" and not allowed[invitee] then
	error("Set mcl_friends_invited_name to a name on the friends list or to the host's name.")
end

local function has_password(name, account)
	return account and account.password ~= "" and not core.check_password_entry(name, account.password, "")
end

core.register_on_prejoinplayer(function(name)
	if not allowed[name] then
		return S("This is a friends-only server. Ask the host to add your exact player name.")
	end

	local auth = core.get_auth_handler()
	local account = auth.get_auth(name)
	if account then
		if not has_password(name, account) then
			return S("This account needs a password. Ask the host to reset it.")
		end
		return
	end

	-- A nonempty default_password makes Luanti require it for first-time login.
	local password = core.settings:get("default_password") or ""
	if name ~= invitee or not password:find("%S") then
		return S("Registration for this name is closed. Ask the host for an invitation.")
	end
	if name ~= admin then
		local host = auth.get_auth(admin)
		if not has_password(admin, host) or core.check_password_entry(admin, host.password, password) then
			return S("The host must set their own password before inviting friends.")
		end
	end
end)
