local server = require "server"
local lua_app = require "lua_app"
require "modules.BaseCenter"

local PlayerMgr = {}

function PlayerMgr:Init()
	self.playerlist = {}
	self.dbidlist = {}
end

function PlayerMgr:GetPlayerBySocket(socket)
	return self.playerlist[socket]
end

function PlayerMgr:GetPlayerByDBID(dbid)
	return self.dbidlist[dbid]
end

function PlayerMgr:GetOnlinePlayers()
	return self.playerlist
end

function PlayerMgr:GetPlayerDBIDs()
	return self.dbidlist
end

function PlayerMgr:ClearPlayerDBIDS()
	self.dbidlist = {}
end

function PlayerMgr:IsOnline(dbid)
	local player = self:GetPlayerByDBID(dbid)
	return (player and rawget(player, "isLogin") or false)
end

local _datamt = {
	__index = function(ar, k)
		rawset(ar, #ar+1, k)
		return ar
	end,
	__newindex = function(ar, k, v)
		setmetatable(ar, nil)
		rawset(ar, #ar+1, k)
		local player = ar.player
		ar.player = nil
		server.SendPlayerLogic("SetPlayerData", player.dbid, ar, v)
	end,
	__call = function(cond, ccond, ...)
		setmetatable(cond, nil)
		local player = cond.player
		cond.player = nil
		if not ccond then
			return server.CallPlayerLogic("GetPlayerData", player.dbid, cond)
		else
			return server.CallPlayerLogic("RunPlayerFuncAndRet", player.dbid, cond, ...)
		end
	end,
}
local _syncmt = {}
_syncmt.__index = function(player, k)
	local v = rawget(_syncmt, k)
	if v then return v end
	local condarray = {k}
	condarray.player = player
	setmetatable(condarray, _datamt)
	return condarray
end
_syncmt.__newindex = function(player, k, v)
	assert(false)
end
function _syncmt:Get(cond)
	setmetatable(cond, nil)
	cond.player = nil
	return server.CallPlayerLogic("GetPlayerData", self.dbid, cond)
end
function _syncmt:Set(cond, value)
	setmetatable(cond, nil)
	cond.player = nil
	server.SendPlayerLogic("SetPlayerData", self.dbid, cond, value)
end
function PlayerMgr:ClearLoginSocket(player)
	local socket = rawget(player, "socket")
	if socket then
		rawset(player, "isLogin", nil)
		rawset(player, "protocol", nil)
		rawset(player, "socket", nil)
		self.playerlist[socket] = nil
	end
end
function PlayerMgr:GetAndNewPlayer(datas)
	local player = self.dbidlist[datas.dbid]
	if server.index == 0 then
		datas.nowserverid = 0
	end
	if not player then
		player = {}
		for k, v in pairs(datas) do
			player[k] = v
		end
		setmetatable(player, _syncmt)
		self.dbidlist[player.dbid] = player
	else
		self:ClearLoginSocket(player)
		for k, v in pairs(datas) do
			rawset(player, k, v)
		end
	end
	local socket = datas.socket
	if socket and socket ~= 0 then
		rawset(player, "isLogin", true)
		self.playerlist[socket] = player
	end
	return player
end
function PlayerMgr:recvLogin(datas)
	-- print("======== PlayerMgr:recvLogin", server.wholename, datas.dbid, datas.protocol, datas.socket, datas.name, datas.nowserverid)
	return self:GetAndNewPlayer(datas)
end
function PlayerMgr:recvLogins(dataslist)
	for _, datas in pairs(dataslist) do
		self:recvLogin(datas)
	end
	return true
end

function PlayerMgr:onLogout(player)
	-- print("======== PlayerMgr:onLogout", server.wholename, player.dbid, rawget(player, "protocol"), rawget(player, "socket"), player.name, player.nowserverid)
	self:ClearLoginSocket(player)
end
-- 强制获取玩家信息
function PlayerMgr:DoGetPlayerByDBID(dbid, serverid)
	if self.dbidlist[dbid] then return self.dbidlist[dbid] end
	local datas
	if server.index == 0 then
		-- 本地服只能获取自己服务器的玩家
		serverid = 0
		datas = server.serverCenter:CallOne("logic", serverid, "GetPlayerBaseinfoByServer", server.name, dbid)
	else
		if serverid then
			datas = server.serverCenter:CallOne("logic", serverid, "GetPlayerBaseinfoByServer", server.name, dbid)
			local realserverid = server.serverCenter:CallNextMod("httpr", "recordDatas", "GetRealServerid", serverid)
			if realserverid ~= serverid then
				datas = server.serverCenter:CallOne("logic", realserverid, "GetPlayerBaseinfoByServer", server.name, dbid)
			end
		end
		if not datas then
			serverid, datas = server.serverCenter:CallLogicRet("GetPlayerBaseinfoByServer", server.name, dbid)
		end
	end
	if not datas then
		lua_app.log_error("PlayerMgr:DoGetPlayerByDBID:: no player", dbid, serverid)
		return
	end
	local player = self:GetAndNewPlayer(datas)
	return player
end

function server.onRecvPlayerLogin(src, datas)
	local player = server.playerCenter:recvLogin(datas)
	server.onevent(server.event.login, player)
end

function server.onrecvplayerevent(src, eventid, playerid, ...)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	server.onevent(eventid, player, ...)
end

function server.RegistCallBack()
	lua_app.rununtiltrue(server.RegistCallBack, 5000, function()
			local rets = server.serverCenter:CallLogicsMod("dataPack", "GetUsedPacks", server.name)
			-- table.ptable(rets, 5, nil, lua_app.log_info)
			local serverlist = server.serverCenter:GetLogicServers(server.name)
			for serverid, _ in pairs(serverlist) do
				if not rets[serverid] then return end
			end
			for _, ret in pairs(rets) do
				server.playerCenter:recvLogins(ret)
			end
			return true
		end)
end

function server.BeforeUpdateDtb(datas, isreset)
	if datas[server.name] then
		if isreset then
			for _, player in pairs(table.weakCopy(server.playerCenter:GetOnlinePlayers())) do
				server.onevent(server.event.logout, player)
			end
			server.playerCenter:ClearPlayerDBIDS()
		end
	end
end

function server.UpdateDtbCallBack(datas, isreset)
	local datainfos = datas[server.name]
	if datainfos then
		if isreset then
			server.RegistCallBack()
			return
		end
		for serverid, info in pairs(datainfos) do
			if info.index == server.index then
				local ret = server.serverCenter:CallOneMod("logic", serverid, "dataPack", "GetUsedPacks", server.name)
				if not ret then
					server.RegistCallBack()
					return
				end
				server.playerCenter:recvLogins(ret)
			end
		end
	end
end

if server.index == 0 then
function server.GetPlayerServerid(playerid)
	return 0
end
else
function server.GetPlayerServerid(playerid)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	return player.nowserverid
end
end

function server.SendPlayerLogic(name, playerid, ...)
	server.serverCenter:SendOne("logic", server.GetPlayerServerid(playerid), name, playerid, ...)
end
function server.CallPlayerLogic(name, playerid, ...)
	return server.serverCenter:CallOne("logic", server.GetPlayerServerid(playerid), name, playerid, ...)
end

function server.sendReq(player, name, param)
	if not player or not rawget(player, "isLogin") then return end
	server.sendToPlayer(player, name, param)
end

function server.sendReqByDBID(playerid, name, param)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	server.sendReq(player, name, param)
end

function server.broadcastReq(name, param)
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		server.sendReq(player, name, param)
	end
end

function server.broadcastList(name, param, list, escapdbid)
	if server.index == 0 then
		for playerid, _ in pairs(list) do
			if playerid ~= escapdbid then
				server.sendReqByDBID(playerid, name, param)
			end
		end
		return
	end
	local serverToplayer = {}
	for playerid, _ in pairs(list) do
		if playerid ~= escapdbid then
			local nowserverid = server.GetPlayerServerid(playerid)
			if not serverToplayer[nowserverid] then
				serverToplayer[nowserverid] = {}
			end
			serverToplayer[nowserverid][playerid] = true
		end
	end
	for serverid, playerlist in pairs(serverToplayer) do
		server.serverCenter:SendOne("logic", serverid, "rbc_list", name, param, playerlist)
	end
end

function server.sendErr(player, msg, code)
	local data = {}
	data.msg = msg
	data.code = code or 0
	server.sendReq(player, "sc_error_code", data)
end

function server.sendErrByDBID(playerid, msg, code)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	server.sendErr(player, msg, code)
end

server.SetCenter(PlayerMgr, "playerCenter")
return PlayerMgr