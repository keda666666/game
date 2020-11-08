local lua_app = require "lua_app"
local dump = require "sheet.dump"
local core = require "DataSheet"

local builder = {}

local cache = {}
local dataset = {}
local address = 0

local function getaddr()
	if address == 0 then
		address=lua_app.unique_lua("sheet/sheet_svc")
	end
	return address
end

local unique_id = 0
local function unique_string(str)
	unique_id = unique_id + 1
	return str .. tostring(unique_id)
end

local function monitor(pointer)
	lua_app.fork(function()
		lua_app.call(getaddr(), "lua", "collect", pointer)
		for k,v in pairs(cache) do
			if v == pointer then
				cache[k] = nil
				return
			end
		end
	end)
end

local function dumpsheet(v)
	if type(v) == "string" then
		return v
	else
		return dump.dump(v)
	end
end

function builder.new(name, v)
	assert(dataset[name] == nil)
	local datastring = unique_string(dumpsheet(v))
	local pointer = core.stringpointer(datastring)
	lua_app.call(getaddr(), "lua", "update", name, pointer)
	cache[datastring] = pointer
	dataset[name] = datastring
	monitor(pointer)
end

function builder.update(name, v)
	local lastversion = assert(dataset[name])
	local newversion = dumpsheet(v)
	local diff = unique_string(dump.diff(lastversion, newversion))
	local pointer = core.stringpointer(diff)
	lua_app.call(getaddr(), "lua", "update", name, pointer)
	cache[diff] = pointer
	local lp = assert(cache[lastversion])
	lua_app.send(getaddr(), "lua", "release", lp)
	dataset[name] = diff
	monitor(pointer)
end

function builder.compile(v)
	return dump.dump(v)
end

--[[
skynet.info_func(function()
	local info = {}
	local tmp = {}
	for k,v in pairs(handles) do
		tmp[k] = v
	end
	for k,v in pairs(dataset) do
		local h = handles[v.handle]
		tmp[v.handle] = nil
		info[k] = {
			handle = v.handle,
			monitors = #v.monitor,
		}
	end
	for k,v in pairs(tmp) do
		info[k] = v.ref
	end

	return info
end)
]]

return builder
