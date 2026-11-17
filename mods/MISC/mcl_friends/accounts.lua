local S = core.get_translator(core.get_current_modname())
local storage = core.get_mod_storage()
local access_prefix = "access:"

local function valid_name(name)
	return #name >= 1 and #name <= 20
		and not name:find("[^A-Za-z0-9_%-]") and name:lower() ~= "singleplayer"
end

local function has_password(name, account)
	return account and account.password ~= "" and not core.check_password_entry(name, account.password, "")
end

local function temporary_password(name)
	-- Luanti's Lua API uses the legacy hash for provisioning. Use a
	-- high-entropy generated password. The native Change Password dialog
	-- replaces the legacy entry with an SRP verifier.
	local password = core.encode_base64(SecureRandom():next_bytes(18))
	local hash = core.get_password_hash(name, password)
	if not core.set_player_password(name, hash) then return end
	local account = core.get_auth_handler().get_auth(name)
	if account and account.password == hash then return password end
end

return function(host)
	local configured = {}
	local name_error = S("Use 1 to 20 letters, numbers, hyphens or underscores. Choose a name other than singleplayer.")
	local function add_configured(name)
		if not valid_name(name) then error(name_error) end
		local lower = name:lower()
		if configured[lower] and configured[lower] ~= name then
			error("Use one exact spelling per name in the friends server configuration.")
		end
		configured[lower] = name
	end

	add_configured(host)
	local friends = (core.settings:get("mcl_friends_allowed_names") or ""):trim()
	for _, entry in ipairs(friends:split(",")) do
		if entry:trim() ~= "" then add_configured(entry:trim()) end
	end
	local legacy_invitee = (core.settings:get("mcl_friends_invited_name") or ""):trim()
	local legacy_password = core.settings:get("default_password") or ""
	if legacy_invitee ~= "" and configured[legacy_invitee:lower()] ~= legacy_invitee then
		error("Set mcl_friends_invited_name to an exact name on the friends list or to the host's name.")
	end

	local function is_allowed(name)
		if name == host then return true end
		local access = storage:get_string(access_prefix .. name)
		return access == "allowed" or (access == "" and configured[name:lower()] == name)
	end

	local function spelling_conflict(name)
		local lower = name:lower()
		local reserved = configured[lower]
		if reserved and reserved ~= name then return reserved end
		for existing in core.get_auth_handler().iterate() do
			if existing ~= name and existing:lower() == lower then return existing end
		end
	end

	-- The auth database is available after script initialisation.
	core.after(0, function()
		if os.getenv("MCL_FRIENDS_CONSOLE") ~= "1" then return end
		local account = core.get_auth_handler().get_auth(host)
		local reset = os.getenv("MCL_FRIENDS_RESET_HOST") == "1"
		if reset or (not account and legacy_invitee == "") then
			if not account and spelling_conflict(host) then
				error("Use the existing host account's exact capitalisation in the server configuration.")
			end
			local password = assert(temporary_password(host), "Failed to prepare the host account.")
			print("Host account: " .. host)
			print("Temporary password: " .. password)
			print("Join with Login, then use Esc -> Change Password.")
		elseif account and not has_password(host, account) then
			error("The host account needs a password. Start the launcher with -ResetHostPassword.")
		end
	end)

	core.register_on_prejoinplayer(function(name)
		if not is_allowed(name) then
			return S("This is a friends-only server. Ask the host to invite your exact player name.")
		end

		local auth = core.get_auth_handler()
		local account = auth.get_auth(name)
		if account then
			if not has_password(name, account) then
				return S("This account needs a password. Ask the host to reset it.")
			end
			return
		end

		-- Retain the original invitation workflow for existing configurations.
		if name ~= legacy_invitee or not legacy_password:find("%S") then
			return S("Registration for this name is closed. Ask the host for an invitation.")
		end
		if name ~= host then
			local host_account = auth.get_auth(host)
			if not has_password(host, host_account)
				or core.check_password_entry(host, host_account.password, legacy_password) then
				return S("The host must set their own password before inviting friends.")
			end
		end
	end)

	-- A removal can happen while a client is still downloading media.
	core.register_on_joinplayer(function(player)
		if not is_allowed(player:get_player_name()) then
			core.kick_player(player:get_player_name(), S("Your access to this server was removed."))
		end
	end)

	local function manage(actor, action, name)
		if actor ~= host then return false, S("Only the host can manage accounts.") end
		name = name:trim()
		if not valid_name(name) then return false, name_error end
		if name:lower() == host:lower() then
			return false, S("Use Change Password or the server launcher to manage the host account.")
		end

		local account = core.get_auth_handler().get_auth(name)
		local key = access_prefix .. name
		local allowed = is_allowed(name)
		if action == "remove" then
			if not allowed then return false, S("@1 already has no access.", name) end
			storage:set_string(key, "denied")
			if core.get_player_by_name(name) then
				core.kick_player(name, S("Your access to this server was removed."))
			end
			return true, S("Removed access for @1.", name)
		elseif action == "allow" then
			if not has_password(name, account) then
				return false, S("@1 needs an account with a password. Use Invite or Reset Password.", name)
			end
			storage:set_string(key, "allowed")
			return true, S("@1 can join with their existing password.", name)
		elseif action == "invite" then
			if account then return false, S("@1 already has an account. Use Allow or Reset Password.", name) end
			local conflict = spelling_conflict(name)
			if conflict then return false, S("The name @1 is already in use. Match its capitalisation or pick another.", conflict) end
		elseif action == "reset" then
			if not account then return false, S("@1 has no account. Use Invite first.", name) end
		else
			return false, S("Choose Invite, Allow, Reset Password or Remove Access.")
		end

		local password = temporary_password(name)
		if not password then return false, S("Could not set a password for @1.", name) end
		if action == "invite" then storage:set_string(key, "allowed") end
		if core.get_player_by_name(name) then
			core.kick_player(name, S("Your password was reset. Ask the host for the new one."))
		end
		if action == "reset" and not allowed then
			return true, S("Password reset for @1. Use Allow to restore access.", name), password
		end
		return true, S("@1 can log in with this temporary password.", name), password
	end

	local function list()
		local entries = {}
		for _, name in pairs(configured) do
			entries[name] = true
		end
		for key in pairs(storage:to_table().fields) do
			if key:sub(1, #access_prefix) == access_prefix then
				entries[key:sub(#access_prefix + 1)] = true
			end
		end
		entries[host] = nil
		local names = {}
		for name in pairs(entries) do names[#names + 1] = name end
		table.sort(names)
		return names, is_allowed
	end

	return {manage = manage, list = list}
end
