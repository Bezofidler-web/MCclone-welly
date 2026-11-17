-- SPDX-License-Identifier: GPL-3.0-or-later
-- The integrated server connects its own player over loopback. Limit other
-- players to the IPv4 subnets selected by the launcher for this session.
local function ipv4(value)
	if type(value) ~= "string" then return end
	local a, b, c, d = value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then return end
	a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
	if a > 255 or b > 255 or c > 255 or d > 255 then return end
	return ((a * 256 + b) * 256 + c) * 256 + d
end

return function(config)
	local subnets = {}
	for entry in (config or ""):gmatch("[^,]+") do
		local address, mask = entry:match("^([^/]+)/([^/]+)$")
		address, mask = ipv4(address), ipv4(mask)
		if address and mask then
			for bits = 1, 32 do
				local size = 2 ^ (32 - bits)
				if mask == 2 ^ 32 - size then
					local first = address - address % size
					subnets[#subnets + 1] = {first, first + size}
					break
				end
			end
		end
	end
	return function(ip)
		if ip == "::1" then return true end
		local address = ipv4(ip)
		if not address then return false end
		if math.floor(address / 2 ^ 24) == 127 then return true end
		for _, subnet in ipairs(subnets) do
			if address >= subnet[1] and address < subnet[2] then return true end
		end
		return false
	end
end
