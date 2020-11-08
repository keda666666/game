--逻辑服务
local server = require "server"
server.name = "logic"
local platformid, include = ...
server.index = 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
package.path = "../lua/" .. server.name .. "/?.lua;../lua/" .. server.name .. "/modules/?.lua;" .. package.path
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local lua_app = require "lua_app"

-- require(include)
require "logic.include"

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	if not server[cmd] then
		lua_app.log_error(cmd,...)
		return
	end
	server[cmd](source,...)
end)

function server.Start(source, cfgCenter)
	cfgCenter.cache.num = cfgCenter.cache.num * 2
	server.cfgCenter = cfgCenter
	server.environment = server.cfgCenter.environment.value
	server.onevent(server.event.init, cfgCenter)
	lua_app.run_after(1000,function()

	end)
	lua_app.log_info(server.wholename, "Start")
	lua_app.ret(true)
end

function server.Open(source)
	server.onevent(server.event.open)
	server.OpenClient(server.cfgCenter.login.addr)
	lua_app.log_info(server.wholename, "Open")
end

function server.HotFix()
	-- package.loaded[include] = nil
	-- require(include)
	package.loaded["logic.include"] = nil
	require "logic.include"
	server.onevent(server.event.hotfix)
	lua_app.log_info(server.wholename, "HotFix")
end

function server.Stop()
	server.CloseClient()
	server.onevent(server.event.release)
	lua_app.log_info(server.wholename, "Stop")
	lua_app.ret(true)
end

function main()
	lua_app.regist_name(server.wholename, lua_app.self())
	server.onevent(server.event.main)
	setmetatable(_G, {
		__newindex = function(_, n)
			print("attempt to write to undeclared variable "..n, 2)
			print(debug.traceback())
		end,
		__index = function(_, n)
			print("attempt to read undeclared variable "..n, 2)		
			print(debug.traceback())
		end
	})
end
