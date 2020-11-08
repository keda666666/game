local lua_app = require "lua_app"
local server = require "server"

local CenterMgr = {}

function CenterMgr:Init(cfgCenter)
	self.nodeaddr = {}
	self.connlist = {}
	self.status = {}
	self.addr = cfgCenter.master.addr
	lua_app.raw_send(lua_app.self(), lua_app.get_router(), 0, lua_app.MSG_ROUTER_TEXT, "connect", self.addr)
	lua_app.log_info("CenterMgr:Init", self.addr)
	self.node = cfgCenter.node.value
	self.centerSource = 0
	self.heartbeattimer = lua_app.add_update_timer(8000, self, "HeartBeat")
	self.checkmodes = {}
end

function CenterMgr:Release()
	if self.centerSource ~= 0 then
		lua_app.send(self.centerSource, lua_app.MSG_LUA, "NodeDisconnect")
	end
	if self.heartbeattimer then
		lua_app.del_local_timer(self.heartbeattimer)
		self.heartbeattimer = nil
	end
end

function CenterMgr:HeartBeat()
	self.heartbeattimer = lua_app.add_update_timer(30000, self, "HeartBeat")
	local ret
	if self.centerSource ~= 0 then
		ret = lua_app.supercall(9000, self.centerSource, lua_app.MSG_LUA, "NodeHeartBeat", server.name, self.node, server.cfgCenter.center.value)
	end
	if not ret then
		ret = self.centerSource ~= 0
		self.centerSource = 0
		for i = 1, 3 do
			if self.centerSource == 0 then
				self.centerSource = lua_app.check(server.GetWholeName("center", 0, server.platformid)) or 0
			end
			if self.centerSource ~= 0 then
				lua_app.log_info("CenterMgr:HeartBeat:: centerSource", self.centerSource, self.addr)
				lua_app.send(self.centerSource, lua_app.MSG_LUA, "NodeRegist", server.name, self.node, server.cfgCenter.center.value)
				return
			end
		end
		if ret then
			lua_app.log_error("can not connect to center server:", self.addr)
		end
	else
		self:CheckConn(true)
	end
end

local _CheckConnFunc = {}
function CenterMgr:CheckConn(isprint)
	for _, mode in pairs(self.checkmodes) do
		_CheckConnFunc[mode](self, isprint)
	end
	for name, connlist in pairs(self.connlist) do
		local status = true
		for node, src in pairs(connlist) do
			if src == 0 then
				connlist[node] = lua_app.check(server.GetWholeName(name, node, server.platformid)) or 0
				if connlist[node] == 0 then
					if isprint then
						lua_app.log_error("CenterMgr:CheckConn:: not connect cross", name, node, self.nodeaddr[name][node])
					end
					status = false
				end
			end
		end
		self.status[name] = status
	end
end
-- 内部互连
function _CheckConnFunc:inside(isprint)
	local nodeToAddr = self.nodeaddr[server.name] or {}
	local connlist = self.connlist[server.name] or {}
	for node, addr in pairs(nodeToAddr) do
		if not connlist[node] then
			if self.node > node then
				lua_app.raw_send(lua_app.self(), lua_app.get_router(), 0, lua_app.MSG_ROUTER_TEXT, "connect", addr)
				lua_app.sleep(2000)
			end
			connlist[node] = lua_app.check(server.GetWholeName(server.name, node, server.platformid)) or 0
		end
	end
	self.connlist[server.name] = connlist
end
-- 全跨服连接
function _CheckConnFunc:other(isprint)
	for name, nodeToAddr in pairs(self.nodeaddr) do
		if name ~= server.name then
			local connlist = self.connlist[name] or {}
			for node, addr in pairs(nodeToAddr) do
				if not connlist[node] then
					lua_app.raw_send(lua_app.self(), lua_app.get_router(), 0, lua_app.MSG_ROUTER_TEXT, "connect", addr)
					lua_app.sleep(1000)
					connlist[node] = lua_app.check(server.GetWholeName(name, node, server.platformid)) or 0
				end
			end
			self.connlist[name] = connlist
		end
	end
end

function CenterMgr:SetCheckMode(modes)
	self.checkmodes = modes
end

function CenterMgr:UpdateConnList(nodeToAddr)
	lua_app.log_info("CenterMgr:UpdateList")
	table.ptable(nodeToAddr, 5, nil, lua_app.log_info)
	for name, nodeaddr in pairs(nodeToAddr) do
		self.nodeaddr[name] = nodeaddr
	end
	self:CheckConn()
end

function server.UpdateConnList(src, nodeToAddr)
	server.centerMgr:UpdateConnList(nodeToAddr)
end

function server.GetCenterConnlist()
	lua_app.ret(server.centerMgr.connlist)
end

server.SetCenter(CenterMgr, "centerMgr")
return CenterMgr