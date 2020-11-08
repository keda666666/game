local lua_app = require "lua_app"
local server = require "server"

local ServerMgr = {}

function ServerMgr:Init()
	self.svrlist = self.svrlist or {}
	self.tmpsvr = false
	self.svrdtb = {}		-- serverid = index
	self.dtblist = {}		-- index = serverids
	self.tmpdtb = {}		-- serverids = source
	self.tmpsend = {}		-- 发送给下一个的缓存
	self.svrnum = {}
	self.centerSource = 0	
	if server.name == "logic" or server.index ~= 0 and server.serverConfig.svrNameToNodeName[server.name] then
		self.heartbeattimer = lua_app.add_update_timer(6000, self, "HeartBeat")
	end

	self.gcID = lua_app.add_update_timer(50000, self, "Collect")
end

function ServerMgr:Release()
	-- 注销并且清空
	if self.centerSource ~= 0 then
		lua_app.send(self.centerSource, lua_app.MSG_LUA, "ServerDisconnect")
	end
	if self.heartbeattimer then
		lua_app.del_local_timer(self.heartbeattimer)
		self.heartbeattimer = nil
	end
	if self.gcID then
		lua_app.del_local_timer(self.gcID)
		self.gcID = nil
	end
end

function ServerMgr:Collect()
	self.gcID = lua_app.add_update_timer(math.random(600000, 900000), self, "Collect")
	-- local startMem = collectgarbage("count")
	collectgarbage("collect")
	-- local overMem = collectgarbage("count")
	-- lua_app.log_info("collect memory:", startMem, overMem)
end

function ServerMgr:HeartBeat()		
	self.heartbeattimer = lua_app.add_update_timer(30000, self, "HeartBeat")
	local ret
	local index = server.name == "logic" and server.serverid or server.index
	if self.centerSource ~= 0 then
		ret = lua_app.supercall(9000, self.centerSource, lua_app.MSG_LUA, "ServerHeartBeat", server.name, index)
	end
	if not ret then
		ret = self.centerSource ~= 0
		self.centerSource = 0
		for i = 1, 3 do
			if self.centerSource == 0 then
				self.centerSource = lua_app.check(server.GetWholeName("center", 0, server.platformid)) or 0
			end
			if self.centerSource ~= 0 then								
				lua_app.send(self.centerSource, lua_app.MSG_LUA, "ServerRegist", server.name, index)
				return
			end
		end
	end
end

function ServerMgr:CheckConnTarget()
	return true
end

function ServerMgr:SendCenter(...)
	lua_app.send(self.centerSource, lua_app.MSG_LUA, ...)
end
function ServerMgr:CallCenter(...)
	return lua_app.supercall(30000, self.centerSource, lua_app.MSG_LUA, ...)
end
function ServerMgr:SendCenterMod(...)
	lua_app.send(self.centerSource, lua_app.MSG_LUA, "SendRunModFun", ...)
end
function ServerMgr:CallCenterMod(...)
	return lua_app.supercall(30000, self.centerSource, lua_app.MSG_LUA, "CallRunModFun", ...)
end

function ServerMgr:GetServerInfo(src)
	if self.tmpsvr then return self.tmpsvr[src] end
	self.tmpsvr = {}
	for name, svrlist in pairs(self.svrlist) do
		for index, src in pairs(svrlist) do
			self.tmpsvr[src] = {
				name = name,
				index = index,
			}
		end
	end
	return self.tmpsvr[src]
end
-- name不能为logic
function ServerMgr:GetLogicServers(name, index)
	index = index or server.index
	if not self.tmpdtb[name] then
		self.tmpdtb[name] = {}
	end
	if not self.tmpdtb[name][index] then		
		if index == 0 then
			-- 本地
			if not server.serverid then
				return
			end
			self.tmpdtb[name][0] = {
				[server.serverid]		= self.svrlist.logic[0],
			}			
		else
			local tmp = {}			
			local serverids = self.dtblist[name] and self.dtblist[name][index]			
			local svrlist = self.svrlist.logic
			if serverids and svrlist then
				for serverid, _ in pairs(serverids) do
					tmp[serverid] = svrlist[serverid]
				end
			end
			
			self.tmpdtb[name][index] = tmp
		end
	end

	return self.tmpdtb[name][index]
end

function ServerMgr:SendOne(name, index, ...)
	index = index or server.index
	local src = self.svrlist[name] and self.svrlist[name][index]
	--local src = self.svrlist[name] and self.svrlist[name][0]
	if not src or src == 0 then
		return
	end
	lua_app.send(src, lua_app.MSG_LUA, ...)
end
function ServerMgr:CallOne(name, index, ...)
	index = index or server.index
	local src = self.svrlist[name] and self.svrlist[name][index]
	--local src = self.svrlist[name] and self.svrlist[name][0]
	if not src or src == 0 then
		return
	end
	return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
end
function ServerMgr:BroadcastName(name, ...)
	for _, src in pairs(self.svrlist[name]) do
		if src ~= 0 then
			lua_app.send(src, lua_app.MSG_LUA, ...)
		end
	end
end
-- 随意发给下一个
function ServerMgr:GetNextSrc(name)
	if not self.svrlist[name] then return end
	local sendindex, src = self.tmpsend[name]
	sendindex, src = next(self.svrlist[name], sendindex)
	if not src or src == 0 then
		sendindex, src = next(self.svrlist[name])
		if not src or src == 0 then
			return
		end
	end
	self.tmpsend[name] = sendindex
	return sendindex, src
end
function ServerMgr:SendNext(name, ...)
	local index, src = self:GetNextSrc(name)
	if not src then
		return
	end
	lua_app.send(src, lua_app.MSG_LUA, ...)
end
function ServerMgr:CallNext(name, ...)
	local index, src = self:GetNextSrc(name)
	if not src then
		return
	end
	return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
end
-- 非逻辑发送到逻辑
function ServerMgr:SendLogics_r(index, ...)
	local tmpdtb = self:GetLogicServers(server.name, index)
	for _, src in pairs(tmpdtb) do
		if src ~= 0 then
			lua_app.send(src, lua_app.MSG_LUA, ...)
		end
	end
end
function ServerMgr:CallLogics_r(index, ...)	
	local tmpdtb = self:GetLogicServers(server.name, index)
	return lua_app.waitmultrun(function(_, src, ...)
			return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
		end, tmpdtb, ...)
end
function ServerMgr:CallLogicRet_r(index, ...)
	local tmpdtb = self:GetLogicServers(server.name, index)
	return lua_app.waitoneret(function(_, src, ...)
			return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
		end, tmpdtb, ...)
end
-- 其他发送到分配的逻辑
function ServerMgr:SendLogics(...)
	self:SendLogics_r(nil, ...)
end
function ServerMgr:CallLogics(...)	
	return self:CallLogics_r(nil, ...)
end
function ServerMgr:CallLogicRet(...)
	return self:CallLogicRet_r(nil, ...)
end
-- 逻辑发送到其他
function ServerMgr:SendDtb_r(name, serverid, ...)
	local info = self.svrdtb[name] and self.svrdtb[name][serverid or server.serverid]	
	local src = info and self.svrlist[name] and self.svrlist[name][info.index]
	--local src = info and self.svrlist[name] and self.svrlist[name][0]
	if not src or src == 0 then
		return
	end
	lua_app.send(src, lua_app.MSG_LUA, ...)
end
function ServerMgr:CallDtb_r(name, serverid, ...)
	local info = self.svrdtb[name] and self.svrdtb[name][serverid or server.serverid]
	local src = info and self.svrlist[name] and self.svrlist[name][info.index]
	--local src = info and self.svrlist[name] and self.svrlist[name][0]
	if not src or src == 0 then
		return
	end
	return lua_app.supercall(30000, src, lua_app.MSG_LUA, ...)
end
function ServerMgr:HasDtb_r(name, serverid)
	local info = self.svrdtb[name] and self.svrdtb[name][serverid or server.serverid]
	local src = info and self.svrlist[name] and self.svrlist[name][info.index]
	--local src = info and self.svrlist[name] and self.svrlist[name][0]
	if not src or src == 0 then
		return false
	end
	return true
end
-- 逻辑发送到分配的其他
function ServerMgr:SendDtb(name, ...)
	self:SendDtb_r(name, nil, ...)
end
function ServerMgr:BroadcastDtb(...)
	for name, _ in pairs(self.dtblist) do
		self:SendDtb_r(name, nil, ...)
	end
end
function ServerMgr:CallDtb(name, ...)
	return self:CallDtb_r(name, nil, ...)
end
-- 本地服调用，发送到本地其他
function ServerMgr:SendLocal(name, ...)
	lua_app.send(self.svrlist[name][0], lua_app.MSG_LUA, ...)
end
function ServerMgr:BroadcastLocal(...)
	for name, v in pairs(self.svrlist) do
		if name ~= server.name and v[0] then		-- 不广播给自己
			lua_app.send(v[0], lua_app.MSG_LUA, ...)
		end
	end
end
function ServerMgr:CallLocal(name, ...)
	return lua_app.supercall(30000, self.svrlist[name][0], lua_app.MSG_LUA, ...)
end
-- 逻辑发送到本地和其他
function ServerMgr:SendDtbAndLocal(name, ...)
	self:SendDtb_r(name, nil, ...)
	local src = self.svrlist[name] and self.svrlist[name][0]
	if src then
		lua_app.send(self.svrlist[name][0], lua_app.MSG_LUA, ...)
	end
end
-- 逻辑广播到非自己
function ServerMgr:BroadcastDtbAndLocal(...)
	self:BroadcastDtb(...)
	self:BroadcastLocal(...)
end
--是否分配远程服务器
function ServerMgr:HasDtb(name)
	return self:HasDtb_r(name, nil)
end
-- 已配置的固定服务数量，不适用不固定的服务数量获取
function ServerMgr:GetOneServerNum(name)
	if not self.svrnum[name] and self.centerSource ~= 0 then
		self.svrnum[name] = lua_app.supercall(30000, self.centerSource, lua_app.MSG_LUA, "GetOneServerNum", name)
	end
	return self.svrnum[name]
end
-- 根据tag获取服务器索引，tag为number或string
function ServerMgr:GetServerIndex(tag, name)
	local hash
	if type(tag) == "number" then
		hash = tag
	else
		hash = 0
		for i = 1, math.min(#tag, 5) do
			hash = hash + tag:byte(i)
		end
	end
	local svrnum = self:GetOneServerNum(name or server.name)
	if svrnum then
		return hash % svrnum + 1
	end
end
----------------------- 更新服务器信息 -----------------------
function ServerMgr:InitLocalServer(serverid, datas)
	server.serverid = serverid
	self.svrlist = self.svrlist or {}
	self.tmpdtb = {}
	self.tmpsend = {}
	for name, src in pairs(datas) do
		self.tmpsend[name] = nil
		if not self.svrlist[name] then
			self.svrlist[name] = {}
		end
		self.svrlist[name][0] = src
		self.tmpdtb[name] = {}
	end
	self.tmpsvr = false
end

function ServerMgr:UpdateServerSource(datas)
	for name, srcs in pairs(datas) do
		self.tmpdtb[name] = {}
		self.tmpsend[name] = nil
		local svrlist = self.svrlist[name] or {}
		for index, src in pairs(srcs) do
			svrlist[index] = src
		end		
		self.svrlist[name] = svrlist
	end
	self.tmpsvr = false
	if server.RegistCallBack then
		server.RegistCallBack(datas)
	end
end

function ServerMgr:SetServerSource(src, name, index, reason)
	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	if not self.tmpdtb[name] then
		self.tmpdtb[name] = {}
	end
	self.svrlist[name][index] = src
	self.tmpdtb[name][index] = nil
	self.tmpsend[name] = nil
	self.tmpsvr = false
	if server.OtherServerChangeCallBack then
		server.OtherServerChangeCallBack(name, index, src, reason)
	end
end

function ServerMgr:UpdateServerDtb(datas, isreset)
	if server.BeforeUpdateDtb then
		server.BeforeUpdateDtb(datas, isreset)
	end
	for name, v in pairs(datas) do
		self.tmpdtb[name] = {}
		if not self.svrdtb[name] or isreset then
			self.svrdtb[name] = {}
		end
		if not self.dtblist[name] or isreset then
			self.dtblist[name] = {}
		end
		for serverid, info in pairs(v) do
			self.svrdtb[name][serverid] = info
			if not self.dtblist[name][info.index] then				
				self.dtblist[name][info.index] = {}
			end			
			self.dtblist[name][info.index][serverid] = true
		end
	end
	if server.UpdateDtbCallBack then
		server.UpdateDtbCallBack(datas, isreset)
	end
end

function ServerMgr:IsCross()
	if server.index ~= 0 then
		return true
	else
		return false
	end
end

function server.UpdateServerSource(src, datas)
	server.serverCenter:UpdateServerSource(datas)
end

function server.SetServerSource(src, dsrc, name, index, reason)
	server.serverCenter:SetServerSource(dsrc, name, index, reason)
end

function server.UpdateServerDtb(src, datas, isreset)
	server.serverCenter:UpdateServerDtb(datas, isreset)
end

function server.InitLocalServer(src, serverid, datas)
	server.serverCenter:InitLocalServer(serverid, datas)
end
---------------- 其他调用逻辑服模块的函数 ---------------------
function ServerMgr:SendLogicsMod(...)
	self:SendLogics("SendRunModFun", ...)
end
function ServerMgr:CallLogicsMod(...)
	return self:CallLogics("CallRunModFun", ...)
end
function ServerMgr:CallLogicModRet(...)
	return self:CallLogicRet("CallRunModFun", ...)
end
-------------- 逻辑调用本地其他服模块的函数 -------------------
function ServerMgr:SendLocalMod(name, ...)
	self:SendLocal(name, "SendRunModFun", ...)
end
function ServerMgr:CallLocalMod(name, ...)
	return self:CallLocal(name, "CallRunModFun", ...)
end
-------------- 逻辑调用分配其他服模块的函数 -------------------
function ServerMgr:SendDtbMod(name, ...)
	self:SendDtb(name, "SendRunModFun", ...)
end
function ServerMgr:CallDtbMod(name, ...)
	return self:CallDtb(name, "CallRunModFun", ...)
end
-------------- 广播给某个类型的所有服的模块 -------------------
function ServerMgr:BroadcastNameMod(name, ...)
	self:BroadcastName(name, "SendRunModFun", ...)
end
-------------- 任意调用其中一个服模块的函数 -------------------
function ServerMgr:SendNextMod(name, ...)
	self:SendNext(name, "SendRunModFun", ...)
end
function ServerMgr:CallNextMod(name, ...)
	return self:CallNext(name, "CallRunModFun", ...)
end
---------------- 跨服调用其他服模块的函数 ---------------------
function ServerMgr:SendOneMod(name, index, ...)
	self:SendOne(name, index, "SendRunModFun", ...)
end
function ServerMgr:CallOneMod(name, index, ...)
	return self:CallOne(name, index, "CallRunModFun", ...)
end
------------------ 调用标志指定服的函数 -----------------------
function ServerMgr:SendTag(tag, name, ...)
	local index = self:GetServerIndex(tag, name)
	if not index then
		return
	end
	self:SendOne(name, index, ...)
end
function ServerMgr:CallTag(tag, name, ...)
	local index = self:GetServerIndex(tag, name)
	if not index then
		return
	end
	return self:CallOne(name, index, ...)
end
---------------- 调用标志指定服的模块函数 ---------------------
function ServerMgr:SendTagMod(tag, name, ...)
	local index = self:GetServerIndex(tag, name)
	if not index then
		return
	end
	self:SendOne(name, index, "SendRunModFun", ...)
end
function ServerMgr:CallTagMod(tag, name, ...)
	local index = self:GetServerIndex(tag, name)
	if not index then
		return
	end
	return self:CallOne(name, index, "CallRunModFun", ...)
end

server.SetCenter(ServerMgr, "serverCenter")
return ServerMgr
