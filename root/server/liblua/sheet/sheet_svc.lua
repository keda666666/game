local lua_app = require "lua_app"
local dump = require "sheet.dump"
local core = require "DataSheet"

local datasheet = {}
local handles = {}	-- handle:{ ref:count , name:name , collect:resp }
local dataset = {}	-- name:{ handle:handle, monitor:{monitors queue} }

local function releasehandle(handle)
	local h = handles[handle]
	h.ref = h.ref - 1
	if h.ref == 0 and h.collect then
		h.collect(true)
		h.collect = nil
		handles[handle] = nil
	end
end

-- from builder, create or update handle
function datasheet.update(name, handle)
	local t = dataset[name]
	if not t then
		-- new datasheet
		t = { handle = handle, monitor = {} }
		dataset[name] = t
		handles[handle] = { ref = 1, name = name }
	else
		t.handle = handle
		-- report update to customers
		handles[handle] = { ref = 1 + #t.monitor, name = name }

		for k,v in ipairs(t.monitor) do
			v(true, handle)
			t.monitor[k] = nil
		end
	end
	lua_app.ret()
end

-- from customers
function datasheet.query(name)
	local t = assert(dataset[name], "create data first")
	local handle = t.handle
	local h = handles[handle]
	h.ref = h.ref + 1
	lua_app.ret(handle)
end

-- from customers, monitor handle change
function datasheet.monitor(handle)
	local h = assert(handles[handle], "Invalid data handle")
	local t = dataset[h.name]
	if t.handle ~= handle then	-- already changes
		lua_app.ret(t.handle)
	else
		h.ref = h.ref + 1
		table.insert(t.monitor, lua_app.response())
	end
end

-- from customers, release handle , ref count - 1
function datasheet.release(handle)
	-- send message, don't ret
	releasehandle(handle)
end

-- from builder, monitor handle release
function datasheet.collect(handle)
	local h = assert(handles[handle], "Invalid data handle")
	if h.ref == 0 then
		handles[handle] = nil
		lua_app.ret()
	else
		assert(h.collect == nil, "Only one collect allows")
		h.collect = lua_app.response()
	end
end

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	local f = assert(datasheet[cmd])
	f(...)
end)

function main()

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
