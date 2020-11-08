local server = require "server"
local lua_app = require "lua_app"

server.event = {
	main 			= 1,
	init			= 2,
	open			= 3,
	release			= 4,
	hotfix 			= 5,
	newplayer		= 6,
	createplayer	= 7,
	loadplayer		= 8,
	releaseplayer	= 9,
	beforelogin 	= 10,
	login			= 11,
	clientinit		= 12,
	beforelogout	= 13,
	logout			= 14,
	levelup			= 15,
	daytimer		= 16,
	daybyday		= 17,
	halfhourtimer	= 18,
	viplevelup		= 19,
	leavemap		= 20,
	entermap		= 21,
	resetserver		= 22,
}

server.eventfuncs = server.eventfuncs or {
	dispatcher = {},
	disorder = {},
	disrorder = {},
}

-- 注册函数类型无法热更
function server.regfunc(eventid, func, isreverse)
	local dispatcher = server.eventfuncs.dispatcher
	local order = isreverse and server.eventfuncs.disrorder or server.eventfuncs.disorder
	dispatcher[eventid] = dispatcher[eventid] or {}
	order[eventid] = order[eventid] or {}
	assert(dispatcher[eventid][func] == nil, "reregist function: eventid = " .. eventid)
	dispatcher[eventid][func] = true
	table.insert(order[eventid], func)
end

-- function server.regfuncname(eventid, funcname, isreverse)
--	local dispatcher = server.eventfuncs.dispatcher
--	local order = isreverse and server.eventfuncs.disrorder or server.eventfuncs.disorder
-- 	dispatcher[eventid] = dispatcher[eventid] or {}
-- 	order[eventid] = order[eventid] or {}
-- 	assert(dispatcher[eventid][funcname] == nil, "reregist function: eventid = " .. eventid)
-- 	dispatcher[eventid][funcname] = true
-- 	table.insert(order[eventid], funcname)
-- end

function server.reglocalfunc(eventid, modname, funcname, isreverse)
	local dispatcher = server.eventfuncs.dispatcher
	local order = isreverse and server.eventfuncs.disrorder or server.eventfuncs.disorder
	dispatcher[eventid] = dispatcher[eventid] or {}
	order[eventid] = order[eventid] or {}
	dispatcher[eventid][modname] = dispatcher[eventid][modname] or {}
	assert(dispatcher[eventid][modname][funcname] == nil, "reregist function: eventid = " .. eventid)
	dispatcher[eventid][modname][funcname] = true
	table.insert(order[eventid], { mod = modname, func = funcname })
end

function server.isreglocalfunc(eventid, modname, funcname)
	local dispatcher_event = server.eventfuncs.dispatcher[eventid]
	return dispatcher_event and dispatcher_event[modname] and dispatcher_event[modname][funcname]
end

local disevent = {}
disevent["function"] = function(func, ...)
	-- print(server.wholename, "function", func)
	func(...)
end
disevent["string"] = function(funcname, ...)
	-- print(server.wholename, "string", funcname)
	server[funcname](...)
end
disevent["table"] = function(localfunc, ...)
	-- print(server.wholename, "table", localfunc.mod, localfunc.func)
	server[localfunc.mod][localfunc.func](server[localfunc.mod], ...)
end
function server.onevent(eventid, ...)
	-- print("-------- server.onevent", server.wholename, eventid, ...)
	local events = server.eventfuncs.disorder[eventid]
	if events then
		for _, v in ipairs(events) do
			disevent[type(v)](v, ...)
		end
	end
	events = server.eventfuncs.disrorder[eventid]
	if events then
		for i = #events, 1, -1 do
			local v = events[i]
			disevent[type(v)](v, ...)
		end
	end
end

function server.onrecvevent(src, eventid, ...)
	server.onevent(eventid, ...)
end
