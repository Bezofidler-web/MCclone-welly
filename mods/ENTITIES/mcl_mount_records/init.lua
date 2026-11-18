-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator (core.get_current_modname ())
local storage = core.get_mod_storage ()
local loaded = {}
local max_records = 24
local mount_names = {
	"horse", "donkey", "mule", "skeleton_horse", "zombie_horse",
	"llama", "trader_llama", "pig", "strider", "camel", "camel_husk",
	"nautilus", "zombie_nautilus", "happy_ghast",
}
local mounts = {}
for _, name in ipairs (mount_names) do mounts["mobs_mc:" .. name] = true end

local function get_records (owner)
	return core.deserialize (storage:get_string ("player:" .. owner), true) or {}
end

local function save_records (owner, records)
	storage:set_string ("player:" .. owner, next (records) and core.serialize (records) or "")
end

local function has_owner (mount)
	return mount.owner and mount.owner ~= ""
end

local function describe_gear (mount)
	local items = {}
	for _, stack in pairs ({
		mount._saddle, mount._horse_armor_stack, mount._nautilus_armor, mount._harness,
	}) do
		local name = ItemStack (stack):get_name ()
		if name ~= "" then items[#items + 1] = name end
	end
	if mount._camel_saddle or mount._nautilus_saddle or mount.saddle == "yes" then
		items[#items + 1] = "mcl_mobitems:saddle"
	end
	if mount._chest then items[#items + 1] = "mcl_chests:chest" end
	table.sort (items)
	return table.concat (items, ",")
end

local function snapshot (mount, pos, removed)
	return {
		name = mount.nametag or "",
		entity = mount.name,
		position = core.pos_to_string (vector.round (pos)),
		dimension = mcl_worlds.pos_to_dimension (pos),
		gear = describe_gear (mount),
		removed = removed or nil,
	}
end

local function update (mount, records, removed)
	local id = mount._mount_record_id
	if not records[id] then
		loaded[id] = nil
		mount._mount_record_id, mount._mount_record_owner = nil, nil
		return false
	end
	if has_owner (mount) and mount.owner ~= mount._mount_record_owner then
		records[id] = nil
		loaded[id] = nil
		mount._mount_record_id, mount._mount_record_owner = nil, nil
		return true
	end
	local pos = mount.object:get_pos ()
	if not pos then return false end
	local record = snapshot (mount, pos, removed)
	local old = records[id]
	if record.name ~= old.name or record.position ~= old.position or record.dimension ~= old.dimension
		or record.gear ~= old.gear or record.removed ~= old.removed then
		records[id] = record
		return true
	end
	return false
end

core.register_on_mods_loaded (function ()
	for entity in pairs (mounts) do
		local def = core.registered_entities[entity]
		local activate, deactivate = def.on_activate, def.on_deactivate
		def.on_activate = function (self, ...)
			activate (self, ...)
			if self._mount_record_id and self._mount_record_owner and self.object:get_pos () then
				loaded[self._mount_record_id] = self
			end
		end
		def.on_deactivate = function (self, removal)
			local id, owner = self._mount_record_id, self._mount_record_owner
			if id and owner and loaded[id] == self then
				local records = get_records (owner)
				if update (self, records, removal) then save_records (owner, records) end
				loaded[id] = nil
			end
			deactivate (self, removal)
		end
	end
end)

local function update_loaded_records ()
	local per_owner, dirty = {}, {}
	for id, mount in pairs (loaded) do
		if not mount.object:is_valid () then
			loaded[id] = nil
		else
			local owner = mount._mount_record_owner
			local records = per_owner[owner] or get_records (owner)
			per_owner[owner] = records
			if update (mount, records) then dirty[owner] = true end
		end
	end
	for owner in pairs (dirty) do save_records (owner, per_owner[owner]) end
end

local elapsed = 0
core.register_globalstep (function (dtime)
	elapsed = elapsed + dtime
	if elapsed < 5 then return end
	elapsed = 0
	update_loaded_records ()
end)
core.register_on_shutdown (update_loaded_records)

local function current_mount (player)
	local vehicle = player:get_attach ()
	if vehicle then
		local entity = vehicle:get_luaentity ()
		if entity and mounts[entity.name] and entity.driver == player then return entity end
	end
	local pointed = mcl_util.get_pointed_thing (player, true, false)
	local entity = pointed and pointed.type == "object" and pointed.ref:get_luaentity ()
	if entity and mounts[entity.name] and entity.owner == player:get_player_name () then return entity end
end

local function add_record (player, records)
	local mount = current_mount (player)
	local pos = mount and mount.object:get_pos ()
	if not pos then return false, S ("Ride a named mount or look at one you own.") end
	if not mount.nametag or mount.nametag == "" then return false, S ("Name the mount with a name tag first.") end
	local owner = player:get_player_name ()
	if has_owner (mount) and mount.owner ~= owner then
		return false, S ("Only this mount's owner can record it.")
	end
	local previous_owner = mount._mount_record_owner
	local id = mount._mount_record_id
	if previous_owner == owner and records[id] then
		records[id] = snapshot (mount, pos)
		save_records (owner, records)
		return true, S ("Updated Mount Record @1.", id)
	end
	local n = 0
	for _ in pairs (records) do n = n + 1 end
	if n >= max_records then return false, S ("Your mount record is full. Use /mounts remove <ID>.") end
	if previous_owner and previous_owner ~= owner then
		local previous_records = get_records (previous_owner)
		if previous_records[id] then
			if mount.owner ~= owner then return false, S ("This mount already has a keeper.") end
			previous_records[id] = nil
			save_records (previous_owner, previous_records)
		end
		loaded[id] = nil
	end
	local serial = storage:get_int ("next_id") + 1
	storage:set_int ("next_id", serial)
	id = tostring (serial)
	mount._mount_record_id, mount._mount_record_owner = id, owner
	records[id] = snapshot (mount, pos)
	loaded[id] = mount
	save_records (owner, records)
	return true, S ("Saved Mount Record @1 for @2.", id, mount.nametag)
end

local function show_records (owner, records)
	local ids = {}
	for id in pairs (records) do ids[#ids + 1] = id end
	table.sort (ids, function (a, b) return tonumber (a) < tonumber (b) end)
	local cells = {S ("ID"), S ("Mount"), S ("Last known location"), S ("Gear")}
	for _, id in ipairs (ids) do
		local record = records[id]
		local equipment = {}
		for item in record.gear:gmatch ("[^,]+") do
			equipment[#equipment + 1] = ItemStack (item):get_short_description ()
		end
		cells[#cells + 1] = id
		local def = core.registered_entities[record.entity]
		cells[#cells + 1] = S ("@1 (@2)", record.name, def and def.description or record.entity)
		local location = record.position .. "  " .. record.dimension
		cells[#cells + 1] = record.removed and S ("Removed near @1", location) or location
		cells[#cells + 1] = #equipment > 0 and table.concat (equipment, ", ") or S ("None")
	end
	for i, cell in ipairs (cells) do cells[i] = core.formspec_escape (cell) end
	core.show_formspec (owner, "mcl_mount_records:records", table.concat ({
		"formspec_version[4]size[16,9]",
		"label[0.45,0.45;", core.formspec_escape (S ("Mount Records")), "]",
		"label[0.45,0.95;", core.formspec_escape (S ("Use /mounts add while riding a named mount or looking at one you own.")), "]",
		"tablecolumns[text;text;text;text]",
		"table[0.45,1.45;15.1,6.6;records;", table.concat (cells, ","), ";0]",
		"label[0.45,8.5;", core.formspec_escape (S ("Use /mounts remove <ID> to forget an entry.")), "]",
		"button_exit[13.3,8.15;2.2,0.65;close;", core.formspec_escape (S ("Close")), "]",
	}))
end

core.register_chatcommand ("mounts", {
	params = S ("[add | remove <ID>]"),
	description = S ("Show your private records for named mounts."),
	privs = {interact = true},
	func = function (owner, param)
		local player = core.get_player_by_name (owner)
		if not player then return false end
		local records = get_records (owner)
		if param == "" then show_records (owner, records); return true end
		if param == "add" then return add_record (player, records) end
		local id = param:match ("^remove%s+(%d+)$")
		if not id then return false, S ("Usage /mounts, /mounts add, or /mounts remove <ID>.") end
		if not records[id] then return false, S ("That Mount Record does not exist.") end
		local mount = loaded[id]
		if mount then
			mount._mount_record_id, mount._mount_record_owner = nil, nil
			loaded[id] = nil
		end
		records[id] = nil
		save_records (owner, records)
		return true, S ("Forgot Mount Record @1.", id)
	end,
})
