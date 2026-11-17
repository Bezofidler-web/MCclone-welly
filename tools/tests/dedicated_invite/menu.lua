-- Luanti's title-menu environment supplies gamedata.
-- luacheck: read_globals gamedata
local title = assert(os.getenv("MCW_QA_TITLE"))
local text = assert(os.getenv("MCW_QA_INVITE"))
local port = assert(os.getenv("MCW_QA_PORT"))
core.log("action", "[dedicated-invite] entered menu fixture")
local codec = dofile(assert(title:match("^(.*[/\\])")) .. "../mods/MISC/mcl_friends/invite.lua")
local example = "abcdefghijklmnopqrstuvwx"
for _, dest in ipairs({"game.example.org", "127.0.0.1", "[2001:db8::1]", "[::1]", "[::ffff:192.0.2.1]"}) do
	local record = assert(codec.read(assert(codec.create(dest, 31000, "Host", "Guest", example))))
	assert(record.destination == dest .. ":31000" and record.port == 31000)
end
local spec
local update = core.update_formspec
core.update_formspec = function(value) spec = value; update(value) end
local previous = core.settings:get("main_menu_script")
core.settings:set("main_menu_script", title)
dofile(title)
core.settings:set("main_menu_script", previous)
local function has(value) return spec:find(value, 1, true) ~= nil end
local press = core.button_handler
local old_address, old_port, old_name = core.settings:get("address"), core.settings:get("remote_port"), core.settings:get("name")
local old_password = core.settings:get("password")
press({mc_server=true})
assert(has("Join with Invite"))
press({mc_invite=true})
assert(has("pwdfield[") and has("Review Invite"))
for _, bad in ipairs({"MCW1-!!!!", "junk", "MCW1-" .. core.encode_base64("https://other.invalid:30000|Host|Guest|abcdefghijklmnopqrstuvwx"),
	"MCW1-" .. core.encode_base64("127.0.0.256:30000|Host|Guest|abcdefghijklmnopqrstuvwx"),
	"MCW1-" .. core.encode_base64("[::::]:30000|Host|Guest|abcdefghijklmnopqrstuvwx"),
	"MCW1-" .. core.encode_base64("host.invalid:65536|Host|Guest|abcdefghijklmnopqrstuvwx"),
	"MCW1-" .. core.encode_base64("host.invalid:30000|Host|singleplayer|abcdefghijklmnopqrstuvwx")}) do
	press({mc_invite_review=true, mc_invite_text=bad})
	assert(has("Invalid invite") and not has("Join this world?"))
end
press({key_enter_field="mc_invite_text", mc_invite_text=text})
assert(has("Join this world?") and has("InviteGuest") and has("InviteHost") and has("127.0.0.1:" .. port) and not has(text))
press({mc_back=true})
assert(has("Join with Invite") and not has("Join this world?"))
assert(core.settings:get("address") == old_address and core.settings:get("remote_port") == old_port and core.settings:get("name") == old_name)
press({mc_invite_join=true})
assert(has("Join with Invite"))
press({mc_invite=true})
press({mc_invite_review=true, mc_invite_text=text})
assert(has("Join this world?"))
local start = core.start
core.start = function()
	assert(gamedata.allow_login_or_register == "login" and gamedata.address == "127.0.0.1" and gamedata.port == port)
	assert(gamedata.playername == "InviteGuest" and #gamedata.password == 24 and not has(gamedata.password))
	assert(core.settings:get("address") == gamedata.address and core.settings:get("remote_port") == port)
	assert(core.settings:get("name") == gamedata.playername and core.settings:get("password") == old_password)
	core.log("action", "[dedicated-invite] PASS malformed rejection, target review, cancellation, login-only confirmation")
	start()
end
press({mc_invite_join=true})
