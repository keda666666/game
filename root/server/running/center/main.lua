local lua_app = require "lua_app"
local server = require "server"
local socket = require "socket"
local xml = require "xml"
server.cfgCenter = xml.parse_xml(lua_app.get_env("configure"))

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
	BroadcastMsg(lua_app.MSG_LUA, "HotFix")
end

function server.Start()
	lua_app.call(server.centerSource, lua_app.MSG_LUA, "Start", server.cfgCenter)
end

function server.Stop()
	lua_app.call(server.centerSource, lua_app.MSG_LUA, "Stop")
	print("stop server sucess")
end

function main()
	local platid = server.cfgCenter.master.platid

	server.centerSource = lua_app.new_lua("center/center", platid)
	if server.centerSource == nil or server.centerSource == 0 then
		print("main exit error centerSource")
		lua_app.exit()
	end
	table.insert(serverlist, server.centerSource)

	server.Start()
	MainLoop()
	lua_app.die()
end
