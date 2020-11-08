local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local ItemConfig = require "resource.ItemConfig"
local _LastLayer = 9

-- 九重天的一层主控文件
local ClimbLayer = oo.class()

-- self.playerlist 玩家列表

function ClimbLayer:ctor(index, map)
	self.index = index
	self.map = map
end

function ClimbLayer:Release()

end

function ClimbLayer:Init()
	self.monsters = {}
	self.playerlist = {}
	self.minute = 0
	self.config = server.configCenter.ClimbTowerConfig[self.index]
	self.rewards = server.dropCenter:DropGroup(self.config.permingift)
	local config = server.configCenter.ClimbTowerBaseConfig
	self.rewardstr = string.format(config.chatnormalreward, ItemConfig:ItemString(self.rewards))
	self.moncfig = server.configCenter.MonstersConfig[self.config.monster]
	self:RefreshMon()
end

-- 每分钟处理
function ClimbLayer:MinuteDeal()
	self.minute = self.minute + 1
	for dbid, climbplayer in pairs(self.playerlist) do
		local player = server.playerCenter:GetPlayerByDBID(climbplayer.dbid)
		if player then
			player:GiveRewardAsFullMailDefault(self.rewards, "九重天", server.baseConfig.YuanbaoRecordType.Climb)
			player.server.chatCenter:ChatSysInfo(dbid, self.rewardstr)
		end
	end
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	for _,v in pairs(ClimbTowerBaseConfig.refresh) do
		if self.minute == v then
			self:RefreshMon()
		end
	end
end

function ClimbLayer:Sec5Deal()
	local now = lua_app.now()
	for dbid, climbplayer in pairs(self.playerlist) do
		if now >= climbplayer.pointtime + 30 then
			climbplayer.pointtime = now
			self.map:AddScore(dbid, server.configCenter.ClimbTowerBaseConfig.maxLayerScore)
		end
	end
end

function ClimbLayer:RefreshMon()
	local msg = {}
	msg.monsters = {}
	msg.flag = 0
	if self.config.refresh then
		for k,v in pairs(self.config.refresh) do
			if not self.monsters[k] then
				self.monsters[k] = {pos = v, fighting = false, pkplayer = 0}
				table.insert(msg.monsters, {id = k, x = v[1], y = v[2], monsterid = self.config.monster})
			end
		end
		self:BroadcastMonsters(msg)
	end
end

function ClimbLayer:InitPlayer(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local now = lua_app.now()
	local climbplayer = {
		dbid = dbid,
		fighting = false,
		playerinfo = player:BaseInfo(),
		time = now,
		pointtime = now,
	}
	return climbplayer
end

function ClimbLayer:SetFighting(dbid, fighting)
	local climbplayer = self.playerlist[dbid]
	if climbplayer and climbplayer.fighting ~= fighting then
		climbplayer.fighting = fighting
	end
	local msg = {dbid = dbid, isfighting = fighting}
	self:Broadcast("sc_climb_fighting_change", msg)
end

function ClimbLayer:SetMonFighting(id, fighting, dbid)
	local monster = self.monsters[id]
	if monster then
		monster.fighting = fighting
		monster.pkplayer = dbid
	end
	local msg = {dbid = id, isfighting = fighting}
	self:Broadcast("sc_climb_fighting_change", msg)
end

function ClimbLayer:GetCount()
	local count = 0
	for _, _ in pairs(self.playerlist) do
		count = count + 1
	end
	return count
end

--进入
function ClimbLayer:Enter(dbid)
	self.playerlist[dbid] = self:InitPlayer(dbid)

	local posindex = math.random(#self.config.point)
	local pos = self.config.point[posindex]
	server.mapCenter:Enter(dbid, self.config.sceneid, pos[1], pos[2])

	self.map:GetClimbInfo(dbid)
	print("ClimbLayer:Enter player enter", dbid)
end

function ClimbLayer:Leave(dbid)
	self.playerlist[dbid] = nil
	for monid, monster in pairs(self.monsters) do
		if monster.pkplayer == dbid then
			self:SetMonFighting(monid, false, 0)
		end
	end
	local baseinfo = self.map.center.playerbaseinfo[dbid]
	if baseinfo then
		self.map.center:SendOne(baseinfo.serverid, "SetLeaveTime", dbid)
	end
	print("ClimbLayer:Leave player leave", dbid)
end

function ClimbLayer:End()
	for dbid, _ in pairs(self.playerlist) do
		server.mapCenter:Leave(dbid)
	end
	self.playerlist = {}
end

-- 自由pk
function ClimbLayer:PK(dbid, datas, targetid)
	local ids = {dbid}
	if targetid and self:IsPlayer(targetid) then
		--大于10是人
		local targetinfo = self.playerlist[targetid]

		if not targetinfo then
			print("ClimbLayer:PK no target info", targetid)
			return
		end

		if targetinfo.fighting then
			print("ClimbLayer:PK target is fighting", targetid)
			return
		end

		local target = server.playerCenter:GetPlayerByDBID(targetid)
		if not target then
			print("ClimbLayer:PK no target", targetid)
			return
		end

		local targetdatas = target.server.dataPack:FightInfoByDBID(targetid)
		datas.exinfo.target = targetdatas
		table.insert(ids, targetid)
	end
	datas.exinfo.targetid = targetid
	
	datas.exinfo.layer = self
	server.raidMgr:Enter(server.raidConfig.type.ClimbPK, dbid, datas, ids)
end

function ClimbLayer:GetTargetName(targetid)
	if self:IsPlayer(targetid) then
		local baseinfo = self.map.center.playerbaseinfo[targetid]
		if baseinfo then
			return baseinfo.name
		end
	else
		return self.moncfig.name
	end
	return ""
end

function ClimbLayer:PKUpDown(iswin, dbid, targetid)
	local notice
	local config = server.configCenter.ClimbTowerBaseConfig
	if iswin then
		self.map:Next(dbid)
		notice = string.format(config.chatpkwin, self:GetTargetName(targetid), self.config.killscore)
	else
		self.map:Back(dbid)
		notice = string.format(config.chatpklost, self:GetTargetName(targetid), self.config.failscore)
	end
	self.map:GetScoreInfo(dbid)

	if targetid and not self:IsPlayer(targetid) then
		if iswin then
			self.monsters[targetid] = nil
			self:BroadcastMonsters()
		else
			self:SetMonFighting(targetid, false, 0)
		end
	end

	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		player.server.chatCenter:ChatSysInfo(dbid, notice)
	end
end

function ClimbLayer:PkResult(iswin, dbid, targetid)
	print("ClimbLayer:PkResult--------", iswin, dbid, targetid)
	if iswin then
		local killscore = self.config.killscore
		if dbid == self.map.king then
			killscore = killscore + server.configCenter.ClimbTowerBaseConfig.kingAdd
		end
		self.map:AddScore(dbid, self.config.killscore)

		if self:IsPlayer(targetid) then
			self.map:AddScore(targetid, self.config.failscore)
			if self.map.king == targetid then
				server.mapCenter:SetTitle(targetid, 0)
				server.mapCenter:SetTitle(dbid, server.configCenter.ClimbTowerBaseConfig.titleid)
				self.map.king = dbid
				self:BroadcastKing()
			end
		end
	else
		if self:IsPlayer(targetid) then
			if targetid == self.map.king then
				self.map:AddScore(targetid, self.config.killscore + server.configCenter.ClimbTowerBaseConfig.kingAdd)
			else
				self.map:AddScore(targetid, self.config.killscore)
			end
			if self.map.king == dbid then
				server.mapCenter:SetTitle(dbid, 0)
				server.mapCenter:SetTitle(targetid, server.configCenter.ClimbTowerBaseConfig.titleid)
				self.map.king = targetid
				self:BroadcastKing()
			end
		end

		self.map:AddScore(dbid, self.config.failscore)
	end
end

function ClimbLayer:GetFighting()
	local list = {}
	for dbid, climblayer in pairs(self.playerlist) do
		if climblayer.fighting then
			table.insert(list, dbid)
		end
	end
	for id, mon in pairs(self.monsters) do
		if mon.fighting then
			table.insert(list, id)
		end
	end
	return list
end

function ClimbLayer:GetMonsterMsg()
	local list = {}
	for k,v in pairs(self.monsters) do
		table.insert(list, {id = k, x = v.pos[1], y = v.pos[2], monsterid = self.config.monster})
	end
	return list
end

function ClimbLayer:BroadcastMonsters(msg)
	self:Broadcast("sc_climb_refresh_mon", msg or {flag = 1, monsters = self:GetMonsterMsg()})
end

function ClimbLayer:GetPlayerCount()
	local count = 1
	for _, _ in pairs(self.playerlist) do
		count = count + 1
	end
	return count
end

function ClimbLayer:BroadcastKing()
	self:Broadcast("sc_climb_king", {dbid = self.map.king})
	local baseinfo = self.map.center.playerbaseinfo[self.map.king]
	if baseinfo then
		-- server.serverCenter:SendLogicsMod("noticeCenter", "Notice", server.configCenter.ClimbTowerBaseConfig.notice, baseinfo.name)
		self.map:BroadcastServerMod("noticeCenter", "Notice", server.configCenter.ClimbTowerBaseConfig.notice, baseinfo.name)
	end
end

function ClimbLayer:BroadcastKingFirst()
	local baseinfo = self.map.center.playerbaseinfo[self.map.king]
	if baseinfo then
		self.map:BroadcastServerMod("noticeCenter", "Notice", server.configCenter.ClimbTowerBaseConfig.notice1, baseinfo.name)
	end
end

function ClimbLayer:Broadcast(name, msg)
	for dbid, _ in pairs(self.playerlist) do
		server.sendReqByDBID(dbid, name, msg)
	end
end

function ClimbLayer:IsPlayer(targetid)
	return (targetid > 100)
end

return ClimbLayer

