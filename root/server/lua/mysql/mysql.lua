local server = require "server"
server.name = "mysql"
local platformid, include = ...
server.index = 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
-- package.path = "../lua/" .. server.name .. "/?.lua;" .. package.path
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local lua_app = require "lua_app"

-- require(include)
require "mysql.include"

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	if not server[cmd] then
		lua_app.log_error(cmd,...)
		return
	end
	server[cmd](source,...)
end)

local count = 0
function server.Start(source, cfgCenter)
	count = count + 1
	if count <= 1 then
		server.cfgCenter = cfgCenter
		server.onevent(server.event.init, cfgCenter)
		lua_app.log_info(server.wholename, "Start")
	end
	lua_app.ret(true)
end

local hotfixcount = 0
function server.HotFix()
	hotfixcount = hotfixcount + 1
	if hotfixcount % count ~= 0 then return end
	-- package.loaded[include] = nil
	-- require(include)
	package.loaded["mysql.include"] = nil
	require "mysql.include"
	server.onevent(server.event.hotfix)
	lua_app.log_info(server.wholename, "HotFix")
end

function server.Stop()
	count = count - 1
	if count <= 0 then
		server.onevent(server.event.release)
		lua_app.log_info(server.wholename, "Stop")
	end
	lua_app.ret(true)
end

local function collect()
	local collect_tick = 0
	while true do
		lua_app.sleep(1000)	-- sleep 1s
		if collect_tick <= 0 then
			collect_tick = 888	-- reset tick count to 600 sec
			-- local startMem = collectgarbage("count")
			if server.mysqlPool then
				server.mysqlPool:CheckClearCache(9999)
			end
			collectgarbage()
			-- local overMem = collectgarbage("count")
			-- lua_app.log_info("collect memory:", startMem, overMem)
		else
			collect_tick = collect_tick - 1
		end
	end
end

function main()
	lua_app.regist_name(server.wholename, lua_app.self())
	lua_app.fork(collect)
	server.onevent(server.event.main)
end