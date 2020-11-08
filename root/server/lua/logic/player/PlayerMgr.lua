local server = require "server"
local lua_app = require "lua_app"
local Player = require "player.Player"
local tbname = "players"

local PlayerMgr = {}
local hearttime = 60 * 1000

function PlayerMgr:Init()
	self.playerlist = {}
	self.dbidlist = {}
	self.cachecount = 0
	self.heart_timer = 0--lua_app.add_update_timer(hearttime, self, "CheckHeatbeat")
	self:RegLocalFunc()
	self:SetEvent()
	self.playercount = 0
end

function PlayerMgr:CheckHeatbeat()
	self.heart_timer = lua_app.add_update_timer(hearttime, self, "CheckHeatbeat")
	local lostTime = lua_app.now() - 900
	local remove = {}
	for socket, player in pairs(self.playerlist) do
		if player.heatbeatTime < lostTime then
			remove[socket] = player
		end
	end
	for socket, player in pairs(remove) do
		print("===>>> heatbeat timeout", player.cache.name)
		self:KickOff(player)
	end
end

function PlayerMgr:AddPlayer(player)
	local dbid = player.dbid
	if self.dbidlist[dbid] then
		lua_app.log_error("PlayerMgr:AddPlayer the same player", dbid)
		self:ReleasePlayer(dbid)
	end
	self.dbidlist[dbid] = player
	self.cachecount = self.cachecount + 1
	print("now player cache count", self.cachecount)
end

function PlayerMgr:ReleasePlayer(dbid)
	if not self.dbidlist[dbid] then
		lua_app.log_error("PlayerMgr:ReleasePlayer no player", dbid)
	else
		local player = self.dbidlist[dbid]
		self.dbidlist[dbid] = nil
		self.cachecount = self.cachecount - 1
		player:Release()
	end
end

function PlayerMgr:CreatePlayer(datas, logininfo)
	local player = Player.new()
	player:SetLoginInfo(logininfo)
	player:Create(datas)
	self:AddPlayer(player)
	return player
end

function PlayerMgr:GetPlayerBySocket(socket)
	return self.playerlist[socket]
end

function PlayerMgr:GetPlayerDBIDs()
	return self.dbidlist
end

function PlayerMgr:GetPlayerByDBID(dbid)
	return self.dbidlist[dbid]
end

function PlayerMgr:GetOnlinePlayers()
	return self.playerlist
end

function PlayerMgr:IsOnline(dbid)
	local player = self:GetPlayerByDBID(dbid)
	return (player and player.isLogin or false)
end

function PlayerMgr:DoGetPlayerByDBID(dbid)
	local player = self.dbidlist[dbid]
	if player == nil then
		lua_app.waitlockrun(dbid, function()
				if not self.dbidlist[dbid] then
					player = Player.new()
					if player:Load({ dbid = dbid }) then
						if self.dbidlist[dbid] then
							lua_app.log_error("PlayerMgr:DoGetPlayerByDBID reload dbid:", dbid)
							player:Release()
						else
							self:AddPlayer(player)
						end
					end
				end
			end, 3)
		return self.dbidlist[dbid]
	end
	return player
end

function PlayerMgr:PlayerLogin(socket, protocol, dbid, logininfo)
	local player = self:DoGetPlayerByDBID(dbid)
	if not player then
		return 7
	end
	local sealed = player.cache.sealed
	if sealed == -1 or sealed > lua_app.now() then
		return 4
	end
	if player.loginLock and player.loginLock + 20 < lua_app.now() then
		lua_app.log_error("PlayerMgr:PlayerLogin ERROR loginLock", player.loginLock, player.cache.account, player.dbid, player.cache.name)
		return 8
	end
	if player.isLogin then
		lua_app.log_error("PlayerMgr:PlayerLogin ERROR isLogin", player.isLogin, player.cache.account, player.dbid, player.cache.name)
		return 9
	end
	player:SetLoginInfo(logininfo)
	player:BeforeLogin()
	player.socket = socket
	player.protocol = protocol
	self.playerlist[socket] = player
	self.playercount = self.playercount + 1
	lua_app.run_after(0, player.Login, player)
	-- print("online player num:", table.length(self.playerlist))
	print("cache player num:", table.length(self.dbidlist))
	return 0
end

function PlayerMgr:PlayerLogout(socket)
	local player = self.playerlist[socket]
	if not player then return end
	if player.loginLock and player.loginLock + 20 < lua_app.now() then
		lua_app.log_error("PlayerMgr:PlayerLogout ERROR loginLock", player.loginLock, player.cache.account, player.dbid, player.cache.name)
		return
	end
	if not player.isLogin then
		lua_app.log_error("PlayerMgr:PlayerLogout ERROR isLogin", player.cache.account, player.dbid, player.cache.name)
		return
	end
	player:BeforeLogout()
	self.playerlist[socket] = nil
	self.playercount = self.playercount - 1
	player.socket = nil
	player.protocol = nil
	player:Logout()
	-- print("online player num:", table.length(self.playerlist))
	print("cache player num:", table.length(self.dbidlist))
end

function PlayerMgr:PlayerUpdate(player, socket, protocol, logininfo)
	self.playerlist[player.socket] = nil
	player.socket = socket
	player.protocol = protocol
	player:SetLoginInfo(logininfo)
	self.playerlist[socket] = player
	server.dataPack:UpdateSocket(player)
	lua_app.run_after(0, player.InitClient, player)
end

function PlayerMgr:GetOnlinePlayerCount()
	return self.playercount
end

function PlayerMgr:KickOff(player)
	if player.socket and player.socket ~= 0 and self.playerlist[player.socket] then
		server.CloseSocket(player.socket)
		self:PlayerLogout(player.socket)
	end
end

function PlayerMgr:KickOffAll()
	local remove = {}
	for socket, player in pairs(self.playerlist) do
		remove[socket] = player
	end
	for socket, player in pairs(remove) do
		self:KickOff(player)
	end
end

function PlayerMgr:Release()
	if self.heart_timer then
		lua_app.del_local_timer(self.heart_timer)
		self.heart_timer = nil
	end
	
end

function PlayerMgr:oncreateplug(player)
	for _, modname in ipairs(self.plugmods.order) do
		local modinfo = self.plugmods.list[modname]
		local nowmod = player
		local tree = modinfo.tree
		local max = #modinfo.tree
		for i = 1, max - 1 do
			nowmod = nowmod[tree[i]]
		end
		if nowmod[tree[max]] ~= nil then
			lua_app.log_error("PlayerMgr:oncreateplug: exist mod", modname, player.dbid, player.cache.name)
		else
			nowmod[tree[max]] = modinfo.mod.new(nowmod)
		end
	end
end
local function _RunEvent(player, eventid, event, ...)
	-- print(player.cache.name, eventid, event.modname, event.func)
	local nowmod = player
	for _, name in ipairs(event.tree) do
		nowmod = nowmod[name]
	end
	nowmod[event.func](nowmod, ...)
end
function PlayerMgr:onevent(eventid, player, ...)
	-- print("-------- PlayerMgr:onevent", player.dbid, player.cache.name, eventid, ...)
	local events = self.eventfuncs.disorder[eventid]
	if events then
		for _, v in ipairs(events) do
			_RunEvent(player, eventid, v, ...)
		end
	end
	events = self.eventfuncs.disrorder[eventid]
	if events then
		for i = #events, 1, -1 do
			local v = events[i]
			_RunEvent(player, eventid, events[i], ...)
		end
	end
end
function PlayerMgr:RegLocalFunc(eventid, modname, funcname, isreverse)
	self.eventfuncs = self.eventfuncs or {
		dispatcher = {},
		disorder = {},
		disrorder = {},
	}
	if not eventid then return end
	local dispatcher = self.eventfuncs.dispatcher
	local order = isreverse and self.eventfuncs.disrorder or self.eventfuncs.disorder
	dispatcher[eventid] = dispatcher[eventid] or {}
	order[eventid] = order[eventid] or {}
	dispatcher[eventid][modname] = dispatcher[eventid][modname] or {}
	assert(dispatcher[eventid][modname][funcname] == nil, "reregist function: eventid = " .. eventid)
	dispatcher[eventid][modname][funcname] = true
	table.insert(order[eventid], { modname = modname, func = funcname, tree = string.split(modname, ".") })
end
local _EventFunc = {
	onCreate		= { server.event.createplayer },
	onLoad			= { server.event.loadplayer },
	onRelease		= { server.event.releaseplayer, true },
	onBeforeLogin	= { server.event.beforelogin },
	onLogin			= { server.event.login },
	onInitClient	= { server.event.clientinit },
	onBeforeLogout	= { server.event.beforelogout, true },
	onLogout		= { server.event.logout, true },
	onLevelUp		= { server.event.levelup },
	onVipLevelUp	= { server.event.viplevelup },
	onDayTimer		= { server.event.daytimer },
	onDayByDay		= { server.event.daybyday },
	onHalfHour		= { server.event.halfhourtimer },
}
function PlayerMgr:SetEvent(mod, modname)
	self.plugmods = self.plugmods or {
		list = {},
		order = {},
		modnames = {},
	}
	if not mod then return end
	if self.plugmods.list[modname] ~= nil then
		-- lua_app.log_info("PlayerMgr:SetEvent exist", modname)
		return
	end
	self.plugmods.list[modname] = { mod = mod, tree = string.split(modname, ".") }
	table.insert(self.plugmods.order, modname)
	for funcname, v in pairs(_EventFunc) do
		if mod[funcname] then
			-- print("PlayerMgr:SetEvent", v[1], v[2], modname, funcname)
			self:RegLocalFunc(v[1], modname, funcname, v[2])
		end
	end
end

function PlayerMgr:onDayTimer(day)
	for _, player in pairs(self.playerlist) do
		player:DayTimer(day)
	end
end

function PlayerMgr:onHalfHour(hour, minute)
	for _, player in pairs(self.playerlist) do
		player:HalfHour(hour, minute)
	end
end

function server.RegistCallBack()
	lua_app.rununtiltrue(server.RegistCallBack, 5000, function()
		local rets = {}
		local players = server.playerCenter:GetPlayerDBIDs()
		for _, player in pairs(players) do
			local ret = server.dataPack:GetPlayerPacks(player)
			for name, datas in pairs(ret) do
				if not rets[name] then rets[name] = {} end
				rets[name][player.dbid] = datas
			end
		end
		-- table.ptable(rets, 5, nil, lua_app.log_info)
		local result = true
		lua_app.waitmultrun(function(name, v)
				local ret = server.serverCenter:CallDtbMod(name, "playerCenter", "recvLogins", v)
				if not ret then
					result = nil
				end
			end, rets)
		return result
	end)
end

-- 其他服务器调用
local function _GetDatas(_cond, datas)
	local retdatas = {}
	for k, v in pairs(_cond) do
		if type(v) == "table" then
			assert(type(datas[k]) == "table", dbid .. "::error cond:" .. k)
			retdatas[k] = _GetDatas(v, datas[k])
		else
			retdatas[k] = datas[k]
		end
	end
	return retdatas
end
function server.GetPlayerCache(src, dbid, cond)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		lua_app.ret(false)
		return
	end
	lua_app.ret(_GetDatas(cond, player.cache))
end

function server.GetAllPlayerCacheStr(src, cond)
	if not cond.dbid then
		lua_app.log_error("server.GetAllPlayerCacheStr:: error cond, no dbid")
		return
	end
	local condlist = {}
	for str, _ in pairs(cond) do
		local sp, modname, ttbname = RankConfig:ParseRankData(str)
		if not condlist[modname] then
			condlist[modname] = {
				spcond = {},
				fields = {},
				tbname = ttbname,
			}
		end
		condlist[modname].spcond[str] = sp
		condlist[modname].fields[sp[1]] = true
	end
	local rets = {}
	for modname, list in pairs(condlist) do
		local idindex = modname == "player" and "dbid" or "playerid"
		local values = server.mysqlCenter:query(list.tbname, {}, list.fields)
		for _, value in ipairs(values) do
			local ret = rets[value[idindex]]
			if not ret then
				ret = {}
				rets[value[idindex]] = ret
			end
			local player = server.playerCenter:GetPlayerByDBID(value[idindex])
			if player then		-- 在线的话就用内存数据
				value = modname == "player" and player.cache or player[modname].cache
				assert(value)
			end
			for str, spc in pairs(list.spcond) do
				local v = value
				for _, vv in ipairs(spc) do
					v = v[vv]
				end
				assert(v ~= value)
				ret[str] = v
			end
		end
	end
	lua_app.ret(rets)
end

function server.GetPlayerData(src, dbid, cond)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		lua_app.ret(false)
		return
	end
	local datas = player
	for _, k in ipairs(cond) do
		datas = datas[k]
	end
	lua_app.ret(datas or false)
end

function server.SetPlayerData(src, dbid, cond, value)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		return false
	end
	local datas = player
	local length = #cond
	for i = 1, length - 1 do
		datas = datas[cond[i]]
	end
	datas[cond[length]] = value
	return true
end

function server.SetPlayerDataRet(src, dbid, cond, value)
	lua_app.ret(server.SetPlayerData(src, dbid, cond, value))
end

function server.RunPlayerFunc(src, dbid, cond, ...)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		return
	end
	local mod = player
	local condlength = #cond
	for i = 1, condlength - 1 do
		mod = mod[cond[i]]
	end
	if mod == server then
		return mod[cond[condlength]](...)
	else
		return mod[cond[condlength]](mod, ...)
	end
end
function server.RunPlayerFuncAndRet(src, dbid, cond, ...)
	lua_app.ret(server.RunPlayerFunc(src, dbid, cond, ...))
end

function server.GetPlayerRecordInfo(src, playerid)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	lua_app.ret({
		serverid	= player.cache.serverid,
		playerid	= player.dbid,
		account		= player.cache.account,
		name		= player.cache.name,
		uid			= player.uid,
		cid			= player.channelId,
	})
end
---------------------- 客户端通信 --------------------------
function server.sendReq(player, name, param)
	if not player or not player.isLogin then return end
	player:sendReq(name, param)
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

function server.rbc_online(src, name, param, list)
	server.broadcastReq(name, param)
end

function server.broadcastList(name, param, list, escapdbid)
	for playerid, _ in pairs(list) do
		if playerid ~= escapdbid then
			server.sendReqByDBID(playerid, name, param)
		end
	end
end

function server.rbc_list(src, name, param, list)
	server.broadcastList(name, param, list)
end

function server.broadcastGuildReq(guildid, name, param)
	local guild = server.guildCenter:GetGuild(guildid)
	if guild then
		guild:Broadcast(name, param)
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

-- function PlayerMgr:DayTimer()
-- 	for dbid,actor in pairs(self.actordbidList) do
-- 		actor:CalLoginDay()
-- 		actor:SendServerDay()
-- 		actor:SendServerTime()
-- 	end
-- end

-- function PlayerMgr:GetDBIDByAccount(name, serverid)
-- 	local actor = self:DoGetPlayerByAccount(name, serverid)
-- 	if actor and actor.dbid ~= 0 then return actor.dbid end
-- end

-- function PlayerMgr:GetActorDBInfo(name, serverid)
-- 	local actor = self:DoGetPlayerByAccount(name, serverid)
-- 	if actor and actor.dbid ~= 0 then
-- 		local roleCtrl = actor.module[actor.RoleCtrlKey]
-- 		local roledbs = {}
-- 		for i = 0, #roleCtrl.roleList do
-- 			table.insert(roledbs, roleCtrl.roleList[i].db)
-- 		end
-- 		return actor.db, roledbs, actor
-- 	end
-- 	-- local value = server.query("actors", { accountname = name })[1]
-- 	-- if value then
-- 	-- 	local roleValues = server.query("roles", { actorid = value.dbid })
-- 	-- 	local roledbs = {}
-- 	-- 	for _, v in ipairs(roleValues) do
-- 	-- 		roledbs[v.roleid] = v
-- 	-- 	end
-- 	-- 	return value, roledbs
-- 	-- end
-- end

-- function PlayerMgr:SetActorDBValue(dbid, key, value)
-- 	local actor = self:DoGetPlayerByDBID(dbid)
-- 	actor:Set(key, value)
-- end

-- local function _SavePoint()
-- 	local save_tmp = server.actorCenter.save_tmp
-- 	if not save_tmp.issaving then return end
-- 	local everyCount = 100
-- 	for i = save_tmp.onlinecount + 1, #save_tmp.onlinelist do
-- 		save_tmp.onlinelist[i]:Save()
-- 		everyCount = everyCount - 1
-- 		if everyCount <= 0 then
-- 			save_tmp.onlinecount = i
-- 			lua_app.add_timer(1000, _SavePoint)
-- 			return
-- 		end
-- 	end
-- 	save_tmp.onlinecount = #save_tmp.onlinelist
-- 	if everyCount > 0 then
-- 		for i = save_tmp.offlinecount + 1, #save_tmp.offlinelist do
-- 			local actor = save_tmp.offlinelist[i]
-- 			local serverid = actor:Get(config.serverindex)
-- 			if i > 500 and not server.actorCenter:GetPlayerByAccount(actor:Get(config.accountname), serverid) then
-- 				server.actorCenter.offlineListByDBID[actor.dbid] = nil
-- 				if server.actorCenter.offlineListByAccount[serverid] then
-- 					server.actorCenter.offlineListByAccount[serverid][actor:Get(config.accountname)] = nil
-- 				end
-- 			end
-- 			actor:Save()
-- 			everyCount = everyCount - 1
-- 			if everyCount <= 0 then
-- 				save_tmp.offlinecount = i
-- 				lua_app.add_timer(1000, _SavePoint)
-- 				return
-- 			end
-- 		end
-- 	end
-- 	save_tmp.issaving = false
-- 	save_tmp.onlinelist = {}
-- 	save_tmp.onlinecount = 0
-- 	save_tmp.offlinelist = {}
-- 	save_tmp.offlinecount = 0
-- end

-- function PlayerMgr:Save()
-- 	-- self.save_tmp.issaving = false
-- 	-- self.save_tmp.onlinelist = {}
-- 	-- self.save_tmp.onlinecount = 0
-- 	-- self.save_tmp.offlinelist = {}
-- 	-- self.save_tmp.offlinecount = 0
-- 	-- for __,actor in pairs(self.actordbidList) do
-- 	-- 	actor:Save()
-- 	-- end
-- 	-- local count = 0
-- 	-- local remove = {}
-- 	-- for dbid,actor in pairs(self.offlineListByDBID) do
-- 	-- 	actor:Save()
-- 	-- 	count = count + 1
-- 	-- 	if count > 3000 then
-- 	-- 		remove[dbid] = actor
-- 	-- 	end
-- 	-- end
-- 	-- for dbid, actor in pairs(remove) do
-- 	-- 	self.offlineListByDBID[dbid] = nil
-- 	-- 	self.offlineListByAccount[actor:Get(config.accountname)] = nil
-- 	-- end
-- 	-- return

-- 	if self.save_tmp.issaving then
-- 		return
-- 	end
-- 	self.save_tmp.issaving = true
-- 	self.save_tmp.onlinecount = 0
-- 	self.save_tmp.offlinecount = 0
-- 	local onlinelist = {}
-- 	for _, actor in pairs(self.actordbidList) do
-- 		table.insert(onlinelist, actor)
-- 	end
-- 	self.save_tmp.onlinelist = onlinelist
-- 	local offlinelist = {}
-- 	for _, actor in pairs(self.offlineListByDBID) do
-- 		table.insert(offlinelist, actor)
-- 	end
-- 	self.save_tmp.offlinelist = offlinelist
-- 	lua_app.add_timer(1000, _SavePoint)
-- end
