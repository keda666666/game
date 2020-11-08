local server = require "server"
server.name = "cross"
local platformid, index = ...
server.index = tonumber(index)
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
package.path = "../running/cross/" .. server.name .. "/?.lua;" .. package.path
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local lua_app = require "lua_app"

require "include"

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	if not server[cmd] then
		lua_app.log_error(server.wholename, "no cmd:", cmd, ...)
		return
	end
	server[cmd](source,...)
end)

function server.Start(source, cfgCenter)
	server.cfgCenter = cfgCenter
	server.onevent(server.event.init, cfgCenter)
	lua_app.log_info(server.wholename, "Start")
	lua_app.ret(true)
end

function server.HotFix()
	package.loaded["include"] = nil
	require "include"
	server.onevent(server.event.hotfix)
	lua_app.log_info(server.wholename, "HotFix")
end

function server.Stop()
	server.onevent(server.event.release)
	lua_app.log_info(server.wholename, "Stop")
	lua_app.ret(true)
end

function main()
	lua_app.regist_name(server.wholename, lua_app.self())
	server.onevent(server.event.main)
end
