local lua_app = require "lua_app"
local server = require "server"

local LocalCenter = {}

function LocalCenter:Init()
	self.svrlist = {}
end

function LocalCenter:HotFix()
	self:BroadcastLocal("HotFix")
end

function LocalCenter:Release()
	lua_app.waitmultrun(function(src)
		return lua_app.call(src, lua_app.MSG_LUA, "Stop")
	end, self:GetSvrList())
end

function LocalCenter:GetSvrList()
	local srclist = {}
	for _, svrlist in pairs(self.svrlist) do
		for _, src in pairs(svrlist) do
			srclist[src] = true
		end
	end
	return srclist
end

function LocalCenter:BroadcastLocal(...)
	for _, svrlist in pairs(self.svrlist) do
		for _, src in pairs(svrlist) do
			lua_app.send(src, lua_app.MSG_LUA, ...)
		end
	end
end

function LocalCenter:SetNewServer(name, index)
	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	if self.svrlist[name][index] then
		lua_app.log_info("server.SetNewServer:: exist server", name, index)
		return false
	end
	local src = lua_app.new_lua(name .. "/" .. name, server.platformid, index, server.name .. "/include")
	self.svrlist[name][index] = src
	lua_app.call(src, lua_app.MSG_LUA, "Start", server.cfgCenter, lua_app.self())
	if server.LocalCenterCallBack then
		server.LocalCenterCallBack(name, index, src)
	end
	return true
end

function server.SetMultServer(src, infos)
	for name, indexs in pairs(infos) do
		for index, _ in pairs(indexs) do
			server.localCenter:SetNewServer(name, index)
		end
	end
end

function server.SetNewServer(src, name, index)
	lua_app.ret(server.localCenter:SetNewServer(name, index))
end

server.SetCenter(LocalCenter, "localCenter")
return LocalCenter