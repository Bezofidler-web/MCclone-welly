local H, G = "InviteHost", "InviteGuest"
local main = "mcl_friends:server_controls"
local accounts = main .. ":accounts"
local shown, form
local display = core.show_formspec
core.show_formspec = function(name, which, fs)
	if name == H then shown, form = fs, which end
	return display(name, which, fs)
end
local function submit(player, which, fields)
	for _, handler in ipairs(core.registered_on_player_receive_fields) do
		if handler(player, which, fields) then break end
	end
end
core.after(0, function()
	local p = assert(os.getenv("MCW_QA_HOST_KEY"))
	assert(core.set_player_password(H, core.get_password_hash(H, p)))
end)
core.register_on_joinplayer(function(player)
	core.after(0.5, function()
		local name = player:get_player_name()
		if name == H then
			assert(core.registered_chatcommands.servercontrols.func(H))
			submit(player, main, {accounts = true})
			assert(form == accounts)
			submit(player, accounts, {invite = true, account_name = G})
			assert(form == accounts .. ":invite")
			local code = assert(shown:match("copy_invite;;([^%]]+)%]"))
			local secret = assert(shown:match("copy_password;;([^%]]+)%]"))
			local codec = dofile(core.get_modpath("mcl_friends") .. "/invite.lua")
			local parsed = assert(codec.read(code))
			assert(parsed.host == H and parsed.name == G and parsed.password == secret and parsed.port == tonumber(os.getenv("MCW_QA_PORT")))
			assert(core.check_password_entry(G, core.get_auth_handler().get_auth(G).password, parsed.password))
			assert(core.safe_file_write(core.get_worldpath() .. "/invite.tmp", code))
			core.log("action", "[dedicated-invite] host account control issued a valid private invite")
		elseif name == G then
			assert(#core.get_connected_players() == 2)
			assert(not mcl_friends.is_host(player) and not core.check_player_privs(name, {server=true}))
			assert(not core.registered_chatcommands.servercontrols.func(G))
			core.log("action", "[dedicated-invite] PASS invited guest joined existing private account beside host")
			core.request_shutdown("Invitation check complete", false, 1)
		end
	end)
end)
