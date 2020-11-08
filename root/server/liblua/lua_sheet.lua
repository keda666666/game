local lua_app = require "lua_app"
local core = require "DataSheet"

local address = 0

local function getaddr()
	if address == 0 then
		address=lua_app.unique_lua("sheet/sheet_svc")
	end
	return address
end

local datasheet = {}
local sheets = setmetatable({}, {
	__gc = function(t)
		for _,v in pairs(t) do
			lua_app.send(getaddr(), "lua", "release", v.handle)
		end
	end,
})

local function querysheet(name)
	return lua_app.call(getaddr(), "lua", "query", name)
end

local function updateobject(name)
	local t = sheets[name]
	if not t.object then
		t.object = core.new(t.handle)
	end
	local function monitor()
		local handle = t.handle
		local newhandle = lua_app.call(getaddr(), "lua", "monitor", handle)
		core.update(t.object, newhandle)
		t.handle = newhandle
		lua_app.send(getaddr(), "lua", "release", handle)
		lua_app.fork(monitor)
	end
	lua_app.fork(monitor)
end

function datasheet.query(name)
	local t = sheets[name]
	if not t then
		t = {}
		sheets[name] = t
	end
	if t.error then
		error(t.error)
	end
	if t.object then
		return t.object
	end
	if t.queue then
		local co = coroutine.running()
		table.insert(t.queue, co)
		lua_app.wait(co)
	else
		t.queue = {}	-- create wait queue for other query
		local ok, handle = pcall(querysheet, name)
		if ok then
			t.handle = handle
			updateobject(name)
		else
			t.error = handle
		end
		local q = t.queue
		t.queue = nil
		for _, co in ipairs(q) do
			lua_app.wake(co)
		end
	end
	if t.error then
		error(t.error)
	end
	return t.object
end

return datasheet
