local event_module = {}
local event_api = {}
local event_meta = {__index = event_api}

function event_module.new()
	local ret = {}
	setmetatable(ret,event_meta)
	return ret
end

function event_api:add(func)
	self.func = func
end

function event_api:trige(...)
	self.func(...)
end


local api = {check_conflict = false}
local datas = {}
local handlers = {}
local disables = {}

function api.regist(key,func)
	if api.check_conflict then
		assert(handlers[key] == nil)
	end
	handlers[key] = func
end

function api.replace(key,func)
	handlers[key] = func
	disables[key] = nil
end

function api.disable(key)
	local func = handlers[key]
	if func == nil then
		return
	end
	handlers[key] = nil
	disables[key] = func
end

function api.enable(key)
	local func = disables[key]
	if func == nil then
		return
	end
	handlers[key] = func
	disables[key] = nil
end

function api.dispatch(key,...)
	local func = handlers[key]
	if func == nil then
		return
	end
	func(...)
end

function api.get_dispatch(key)
	return handlers[key]
end

function api._regist_event(key,func)
	local event = rawget(api,key)
	if event == nil then
		event = event_module.new()
		rawset(api,key,event)
	end
	event:add(func)
end

function api.trige_event(key,...)
	local event = rawget(api,key)
	assert(event)
	event:trige(...)
end

function api.disable_globals()
	local globals = assert(_G)
	setmetatable(globals,{
		__newindex = function(_,name,val)
			local msg = string.format("you can't define new global value:%s",name)
			error(msg,0)
		end
	})
end

function api.GetWholeName(name, index, platformid)
	if name == "center" then
		return name .. platformid
	else
		return (index == 0 and "." or "") .. name .. (index == 0 and "" or platformid .. "_" .. index)
	end
end

function api.GetSqlName(name)
	local index = rawget(datas, "index")
	return index == 0 and name or rawget(datas, "name") .. index .. "_" .. name
end

local mt = 
	{
		__index = function(_,key)
			local val = rawget(datas,key)
			if val == nil then
				val = rawget(handlers,key)
			end
			return val
		end,
		__newindex = function(_,key,val)
			if api.check_conflict then
				assert(rawget(handlers,key) == nil)
			end
			if type(val) == "function" then
				rawset(handlers,key,val)
			else
				rawset(datas,key,val)
			end
		end,
	}

setmetatable(api,mt)

return api
