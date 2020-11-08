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
	self.heartbeattimer = lua_app.add_update_timer(10000, self, "HeartBeat")
end

function CenterMgr:Release()
	if self.heartbeattimer then
		lua_app.del_local_timer(self.heartbeattimer)
		self.heartbeattimer = nil
	end
end

function CenterMgr:HeartBeat()
	self.heartbeattimer = lua_app.add_update_timer(30000, self, "HeartBeat")
	self:CheckConn(true)
end

function CenterMgr:CheckConn(isprint)
	for name, nodeToAddr in pairs(self.nodeaddr) do
		local connlist = self.connlist[name] or {}
		for node, addr in pairs(nodeToAddr) do
			if not connlist[node] then
				lua_app.raw_send(lua_app.self(), lua_app.get_router(), 0, lua_app.MSG_ROUTER_TEXT, "connect", addr)
				lua_app.sleep(2000)
				connlist[node] = lua_app.check(server.GetWholeName(name, node, server.platformid)) or 0
			end
		end
		self.connlist[name] = connlist
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

server.SetCenter(CenterMgr, "centerMgr")
return CenterMgr