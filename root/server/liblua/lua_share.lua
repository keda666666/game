local lua_app = require "lua_app"
local sd = require "share.share_core"

local handler = 0



local sharedata = {}
local cache = setmetatable({}, { __mode = "kv" })


local function service()
	if handler == 0 then
		handler = lua_app.unique_lua("share/share_svc")
	end
	return handler
end

local function monitor(name, obj, cobj,call)
	local newobj = cobj
	while true do
		newobj = lua_app.call(service(), "lua", "monitor", name, newobj)
		if newobj == nil then
			break
		end
		sd.update(obj, newobj)
		if call then
			call()
		end
	end
	if cache[name] == obj then
		cache[name] = nil
	end
end

function sharedata.query(name,call)
	if cache[name] then
		return cache[name]
	end
	local obj = lua_app.call(service(), "lua", "query", name)
	local r = sd.box(obj)
	lua_app.send(service(), "lua", "confirm" , obj)
	lua_app.fork(monitor,name, r, obj,call)
	cache[name] = r
	return r
end

function sharedata.init(namePath,configPath)
	lua_app.send(service(), "lua", "init", namePath,configPath)
end

function sharedata.refresh(name)
	lua_app.send(service(), "lua", "refresh", name)
end

function sharedata.refreshall()
	lua_app.send(service(), "lua", "refreshall")
end

function sharedata.new(name, v, ...)
	lua_app.send(service(), "lua", "new", name, v, ...)
end

function sharedata.update(name, v, ...)
	lua_app.send(service(), "lua", "update", name, v, ...)
end

function sharedata.delete(name)
	lua_app.send(service(), "lua", "delete", name)
end

function sharedata.flush()
	for name, obj in pairs(cache) do
		sd.flush(obj)
	end
	collectgarbage()
end

function sharedata.deepcopy(name, ...)
	if cache[name] then
		local cobj = cache[name].__obj
		return sd.copy(cobj, ...)
	end

	local cobj = lua_app.call(service(), "lua", "query", name)
	local ret = sd.copy(cobj, ...)
	lua_app.send(service(), "lua", "confirm" , cobj)
	return ret
end

return sharedata
