local lua_app = require "lua_app"
local server = require "server"

local ServerCenter = {}

function ServerCenter:Init()
	self.svrlist = {}
	self.srcToInfo = {}
	self.checktimer = lua_app.add_update_timer(30000, self, "CheckHeartBeat")
	self.gcID = lua_app.add_update_timer(50000, self, "Collect")
end

function ServerCenter:Release()
	if self.checktimer then
		lua_app.del_local_timer(self.checktimer)
		self.checktimer = nil
	end
	if self.gcID then
		lua_app.del_local_timer(self.gcID)
		self.gcID = nil
	end
end

function ServerCenter:Collect()
	self.gcID = lua_app.add_update_timer(math.random(600000, 900000), self, "Collect")
	local startMem = collectgarbage("count")
	collectgarbage("collect")
	local overMem = collectgarbage("count")
	lua_app.log_info("collect memory:", startMem, overMem)
end

function ServerCenter:Send(src, ...)
	lua_app.send(src, lua_app.MSG_LUA, ...)
end

function ServerCenter:SendIndex(name, index, ...)
	local svrlist = self.svrlist[name]
	if svrlist and svrlist[index] then
		self:Send(svrlist[index], ...)
	else
		lua_app.log_error("ServerCenter:SendIndex:: no index", name, index, ...)
	end
end

function ServerCenter:Call(src, ...)
	return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
end

function ServerCenter:CallIndex(name, index, ...)
	local svrlist = self.svrlist[name]
	if svrlist and svrlist[index] then
		return self:Call(svrlist[index], ...)
	else
		lua_app.log_error("ServerCenter:SendIndex:: no index", name, index, ...)
	end
end

function ServerCenter:BroadcastName(name, ...)
	for _, src in pairs(self.svrlist[name] or {}) do
		self:Send(src, ...)
	end
end

function ServerCenter:Broadcast(...)
	for src, _ in pairs(self.srcToInfo) do
		self:Send(src, ...)
	end
end

function ServerCenter:ServerRegist(src, name, index)
	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	local isreconnect, info, dsrc = false
	if self.svrlist[name][index] then
		dsrc = self.svrlist[name][index]
		info = self.srcToInfo[dsrc]		
		if info.name ~= name or info.index ~= index then
			lua_app.log_error("ServerCenter:ServerRegist:: exist error name, index", name, index, src, info.name, info.index, dsrc)
			return
		end
		self.srcToInfo[dsrc] = nil
		self.svrlist[name][index] = nil
		isreconnect = true
	end
	if self.srcToInfo[src] then
		info = self.srcToInfo[src]
		dsrc = self.svrlist[info.name][info.index]
		if dsrc ~= src then
			lua_app.log_error("ServerCenter:ServerRegist:: exist error src", name, index, src, info.name, info.index, dsrc)
			return
		end
		self.svrlist[info.name][info.index] = nil
		self.srcToInfo[src] = nil
		isreconnect = true
	end
	server.dispatchCenter:SendDtbinfo(src)
	self:Broadcast("SetServerSource", src, name, index)
	server.nodeCenter:Broadcast("SetServerSource", src, name, index)
	self.svrlist[name][index] = src
	self.srcToInfo[src] = {
		name = name,
		index = index,
		time = lua_app.now(),
	}
	if name == "logic" then		
		self:Send(src, "UpdateConnList", server.nodeCenter:GetNodeToAddr())
		server.dispatchCenter:ToAddMatch(nil, nil)
	end
	self:Send(src, "UpdateServerSource", self.svrlist)
	if isreconnect then
		lua_app.log_info("ServerRegist:: reconnect", name, index, src, info.name, info.index, dsrc)
	else
		lua_app.log_info("ServerRegist:: connect", name, index, src)
	end
end

function ServerCenter:ServerDisconnect(src, reason)
	local info = self.srcToInfo[src]
	if not info then return end
	self.svrlist[info.name][info.index] = nil
	self.srcToInfo[src] = nil
	self:Broadcast("SetServerSource", nil, info.name, info.index, reason)
	server.nodeCenter:Broadcast("SetServerSource", nil, info.name, info.index, reason)
	lua_app.log_info("ServerDisconnect::", reason, info.name, info.index, src)
end

function ServerCenter:HeartBeat(src, name, index)
	local info = self.srcToInfo[src]
	if not info or info.name ~= name or info.index ~= index then return false end
	info.time = lua_app.now()
	return true
end

function ServerCenter:CheckHeartBeat()
	self.checktimer = lua_app.add_update_timer(30000, self, "CheckHeartBeat")
	local outtime = lua_app.now() - 60
	local removes = {}
	for src, info in pairs(self.srcToInfo) do
		if info.time < outtime then
			removes[src] = info
		end
	end
	for src, _ in pairs(removes) do
		self:ServerDisconnect(src, "timeout")
	end
end
---------------------- 调用模块函数 ---------------------------
function server.SendRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	mod[funcname](mod, ...)
end
function server.CallRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	lua_app.ret(mod[funcname](mod, ...))
end

function server.ServerRegist(src, name, index)
	server.serverCenter:ServerRegist(src, name, index)
end

function server.ServerDisconnect(src)
	server.serverCenter:ServerDisconnect(src, "normal")
end

function server.ServerHeartBeat(src, name, index)
	lua_app.ret(server.serverCenter:HeartBeat(src, name, index))
end

local _nodeNumber = false
function server.GetNodeNum()
	if not _nodeNumber then
		_nodeNumber = {
			plat = server.cfgCenter.master.platnum,
			record = server.cfgCenter.master.recordnum,
		}
	end
	return _nodeNumber
end

function server.GetOneServerNum(src, name)
	lua_app.ret(server.GetServerNum()[name])
end

local _serverNumber = false
function server.GetServerNum()
	if not _serverNumber then
		_serverNumber = {}
		_serverNumber.httpp = server.GetNodeNum().plat * 13
		_serverNumber.mainplat = 1
		_serverNumber.httpr = server.GetNodeNum().record * 5
		_serverNumber.mainrecord = 1
	end
	return _serverNumber
end

function server.GM(src, funcname, ...)
	lua_app.log_info("== GM >>>CMD::", funcname, ...)
	if server[funcname] then
		server[funcname](...)
	elseif server.dispatchCenter[funcname] then
		server.dispatchCenter[funcname](server.dispatchCenter, ...)
	elseif server.nodeDispatch[funcname] then
		server.nodeDispatch[funcname](server.nodeDispatch, ...)
	else
		lua_app.log_error("GM:: no cmd", funcname, ...)
	end
end

server.SetCenter(ServerCenter, "serverCenter")
return ServerCenter