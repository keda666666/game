local lua_app = require "lua_app"
local server = require "server"
local socket = require "socket"
local xml = require "xml"
local config = require "config.config"
local include = "game.include"
server.cfgCenter = xml.parse_xml(lua_app.get_env("configure"))
require "config.psproto"

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	lua_app.ret("name :test")
end)

local serverlist = {}
local function BroadcastMsg(...)
	for _, src in ipairs(serverlist) do
		lua_app.send(src, ...)
	end
end

local function MainLoop()
	local inputId = socket.start_input()
	if inputId == 0 then
		return
	end
	while true  do
		local str = socket.read_line(inputId)
		if str == "hotfix" then
			server.HotFix()
			print("receive hotfix")
		elseif str == "start" then
			server.Start()
		elseif str == "quit" then
			server.Stop()
			break
		elseif str ~= nil then
			local fun = load(str)
			if type(fun) == "function" then
				local ret,result = pcall(fun)
			else
				print(str)
			end
		end
	end
end

--脚本热更
function server.HotFix()
	config:HotFixAll()
	BroadcastMsg(lua_app.MSG_LUA, "HotFix")
end

function server.Start()
	local svrlist = {
		logic  		= server.logicSource,
		world  		= server.worldSource,
		war  		= server.warSource,
	}
	BroadcastMsg(lua_app.MSG_LUA, "InitLocalServer", server.cfgCenter.node.value % 10000, svrlist)
	lua_app.call(server.logicSource, lua_app.MSG_LUA, "Start", server.cfgCenter)
	lua_app.call(server.worldSource, lua_app.MSG_LUA, "Start", server.cfgCenter)
	lua_app.call(server.warSource, lua_app.MSG_LUA, "Start", server.cfgCenter)
	lua_app.send(server.logicSource, lua_app.MSG_LUA, "Open")
end

function server.Stop()
	lua_app.call(server.warSource, lua_app.MSG_LUA, "Stop")
	lua_app.call(server.worldSource, lua_app.MSG_LUA, "Stop")
	lua_app.call(server.logicSource, lua_app.MSG_LUA, "Stop")
	print("stop server sucess")
end

function main()
	config:InitAll(server.cfgCenter)
	local platid = server.cfgCenter.master.platid

	server.logicSource = lua_app.new_lua("logic/logic", platid)
	if server.logicSource == nil or server.logicSource == 0 then
		print("main exit error logicSource")
		lua_app.exit()
	end
	table.insert(serverlist, server.logicSource)
	server.worldSource = lua_app.new_lua("world/world", platid, 0, include)
	if server.worldSource == nil or server.worldSource == 0 then
		print("main exit error worldSource")
		lua_app.exit()
	end
	table.insert(serverlist, server.worldSource)
	server.warSource = lua_app.new_lua("war/war", platid, 0, include)
	if server.warSource == nil or server.warSource == 0 then
		print("main exit error warSource")
		lua_app.exit()
	end
	table.insert(serverlist, server.warSource)

	server.Start()
	MainLoop()
	lua_app.die()
end
