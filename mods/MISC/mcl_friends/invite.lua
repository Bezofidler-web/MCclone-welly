-- SPDX-License-Identifier: GPL-3.0-or-later
-- Shared by the dedicated server and the title menu. A code contains a
-- temporary credential and is only for the invited player.
local invite = {}
local function valid_name(s)
	return #s >= 1 and #s <= 20 and s:match("^[A-Za-z0-9_%-]+$") and s:lower() ~= "singleplayer"
end

local function ipv4(s)
	local a, b, c, d = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then return false end
	for _, part in ipairs({a, b, c, d}) do
		if #part > 3 or tostring(tonumber(part)) ~= part or tonumber(part) > 255 then return false end
	end
	return true
end

local function ipv6(s)
	local compressed = s:find("::", 1, true)
	if s:find(":::", 1, true) or (compressed and s:find("::", compressed + 2, true)) then return false end
	if (s:sub(1, 1) == ":" and s:sub(1, 2) ~= "::") or
			(s:sub(-1) == ":" and s:sub(-2) ~= "::") then return false end
	local count = 0
	for part in s:gmatch("[^:]+") do
		if #part <= 4 and part:match("^%x+$") then
			count = count + 1
		elseif ipv4(part) and s:sub(-#part) == part then
			count = count + 2
		else
			return false
		end
	end
	return compressed and count < 8 or not compressed and count == 8
end

local function hostname(s)
	if #s == 0 or #s > 253 or s:sub(1, 1) == "." or s:sub(-1) == "." or s:find("..", 1, true) then return false end
	if s:match("^[%d.]+$") then return ipv4(s) end
	for label in s:gmatch("[^.]+") do
		if #label > 63 or not label:match("^[A-Za-z0-9%-]+$") or
				label:sub(1, 1) == "-" or label:sub(-1) == "-" then return false end
	end
	return true
end

local function endpoint(text, default_port)
	if type(text) ~= "string" or #text > 270 then return end
	local address, port
	if text:sub(1, 1) == "[" then
		address, port = text:match("^%[([^%]]+)%]:(%d+)$")
		address = address or text:match("^%[([^%]]+)%]$")
		if not address or not ipv6(address) then return end
	else
		address, port = text:match("^([^:]+):(%d+)$")
		address = address or text
		if not hostname(address) then return end
	end
	port = tonumber(port or default_port)
	if not port or port < 1 or port > 65535 or port ~= math.floor(port) then return end
	return address, port
end

function invite.create(destination, default_port, host, name, password)
	local address, port = endpoint(destination, default_port)
	if not address or not valid_name(host) or not valid_name(name) or
			#password ~= 24 or not password:match("^[A-Za-z0-9+/]+$") then return end
	if address:find(":", 1, true) then address = "[" .. address .. "]" end
	return "MCW1-" .. core.encode_base64(table.concat({address .. ":" .. port, host, name, password}, "|"))
end

function invite.read(input)
	if type(input) ~= "string" or #input > 600 then return end
	local body = input:match("^%s*MCW1%-([A-Za-z0-9+/=]+)%s*$")
	if not body then return end
	local decoded = core.decode_base64(body)
	if not decoded or core.encode_base64(decoded) ~= body then return end
	local destination, host, name, password = decoded:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
	if not destination or invite.create(destination, nil, host, name, password) ~= "MCW1-" .. body then return end
	local address, port = endpoint(destination)
	return {destination = destination, address = address, port = port, host = host, name = name, password = password}
end

return invite
