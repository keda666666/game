local server = require "server"
server.name = "world"
local platformid, index, include = ...
server.index = tonumber(index) or 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
package.path = "../lua/" .. server.name .. "/?.lua;" .. package.path
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local lua_app = require "lua_app"
-- local ServerMgr = require "ServerMgr"

-- server.serverMgr = ServerMgr.new()

if include and include ~= "" then
	require(include)
end
require "include"

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	-- if cmd ~= "LogicHeatbeat" and cmd ~= "PlatformHeatbeat" then
	-- 	print(cmd,...)
	-- end
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
	if include and include ~= "" then
		package.loaded[include] = nil
		require(include)
	end
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
	-- server.httpCenter:startServer(baseCfg.httpd.ip, tonumber(baseCfg.httpd.port))
	server.onevent(server.event.main)
	setmetatable(_G, {
		__newindex = function(_, n)
			error("attempt to write to undeclared variable "..n, 2)
		end,
		__index = function(_, n)
			error("attempt to read undeclared variable "..n, 2)		
		end
	})
end
