local lua_app = require "lua_app"

local processes = {}
local uniqueprocesses = {}
local watched = {}

local command = {}


function command.new_process(source,session,process_name,...)
	local args = table.concat({...}," ")
	local index = process_name.." "..args
	local handler = uniqueprocesses[index]
	if handler then
		lua_app.ret(handler)
	end
	handler = lua_app.new_process(process_name,args)
	if handler then
		processes[handler] = index
		watched[handler] = {session = session,watcher = source}
		lua_app.ret(handler)
	else
		lua_app.ret(0)
	end
end

function command.unique_process(source,session,process_name,...)
	local args = table.concat({...}," ")
	local index = process_name.." "..args
	local handler = uniqueprocesses[index]
	if handler then
		lua_app.ret(handler)
		return
	end
	handler = lua_app.new_process(process_name,args)
	if handler then
		processes[handler] = index
		watched[handler] = {session = session,watcher = source}
		uniqueprocesses[index] = handler
		lua_app.ret(handler)
	else
		lua_app.ret(0)
	end
end

function command.launch_ok(source)
	local watcher = watched[source]
	if watcher and processes[watcher.watcher] then
		lua_app.raw_send(0,watcher.watcher,watcher.session,"response",source)
		watched[source] = nil
	end
end

function command.launch_err(source)
	local watcher = watched[source]

	if watcher then
		lua_app.raw_send(0,watcher.watcher,watcher.session,"response",0)
		watched[source] = nil
	end
end

function command.remove(source,session,handler)
	processes[handler] = nil
end

function command.test(source,session)
	lua_app.ret(1,2,3)
end

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	local f = command[cmd]

	if f then
		f(source,session,...)
	else
		print("launcher unknown command")
		lua_app.ret({"launcher Unknown command" .. cmd})
	end
end)

function main() end
