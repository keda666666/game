local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local KingConfig = require "resource.KingConfig"
local _PointType = {
	City = 1,
	Common = 2,
}

-- 跨服争霸阵营
local KingCamp = oo.class()

function KingCamp:ctor(camp, map)
	self.camp = camp
	self.map = map
	self.citypoint = 0 		--整个阵营的王城积分
	self.addpointtime = lua_app.now()
	self.playerlist = {}
	self.totalpower = 0
end

function KingCamp:Release()
	self.camp = nil
	self.map = nil
	self.citypoint = nil 		--整个阵营的王城积分
	self.addpointtime = nil
	self.totalpower = nil
end

function KingCamp:End()
	self.citypoint = 0
	self.playerlist = {}
	self.totalpower = 0
end

function KingCamp:SetServerid(serverid)
	self.serverid = serverid
	lua_app.log_info("KingMap:SetServerid--- serverid and camp", serverid, self.camp)
end

function KingCamp:SetWarReport(warReport)
	self.warReport = warReport
end

function KingCamp:InitKingPlayer(playerinfo)
	local status = KingConfig.status.Act
	if not self.map.center.begin then
		status = KingConfig.status.Ready
	end
	local player = {
		playerinfo = playerinfo,
		citypoint = 0,		--王城积分
		commonpoint = 0,	--普通积分
		pointtocity = 0,	--立马转换成王城积分的普通积分
		cityreward = {},	--已经领取的王城积分奖励
		commonreward = {},	--已经领取的个人积分奖励
		deadtime = 0,		--死亡时间
		fighting = false,	--正在战斗
		transform = false, 	--是否变身
		status = status,
		guardcity = 99,		--正在守的城
	}
	return player
end

function KingCamp:Join(playerinfo)
	self.playerlist[playerinfo.dbid] = self:InitKingPlayer(playerinfo)
	self.totalpower = self.totalpower + playerinfo.power
	self.warReport:AddPersonData(playerinfo.dbid, {
			camp = self.camp
		})
	return true
end

function KingCamp:EnterMap(dbid, pos)
	-- 拉到地图
	local status = self.playerlist[dbid].status
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local x, y = self:GetBornPos()
	if status == KingConfig.status.Guard and pos then
		x = pos.x
		y = pos.y
	end
	if x and y then
		server.mapCenter:Enter(dbid, KingBaseConfig.mapid, x, y)
	end
end

-- 准备倒计时结束
function KingCamp:Begin()
	for dbid, kingplayer in pairs(self.playerlist) do
		if kingplayer.status == KingConfig.status.Ready then
			kingplayer.status = KingConfig.status.Act
			self.map:BroadcastStatusChange(dbid, kingplayer.status)
		end
	end
end

-- 每秒处理
function KingCamp:DoSecond(now)
	local KingBaseConfig = server.configCenter.KingBaseConfig
	for dbid, kingplayer in pairs(self.playerlist) do
		if kingplayer.status == KingConfig.status.Dead and
			kingplayer.deadtime ~= 0 and
			now >= kingplayer.deadtime + KingBaseConfig.revivetime then
			self:DoRevive(kingplayer)
		end
	end
end

-- 王城积分
function KingCamp:AddCityPoint(dbid, point)
	if point == 0 then return end
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.citypoint = kingplayer.citypoint + point
	end
	self.citypoint = self.citypoint + point
	self.addpointtime = lua_app.now()
	self.map:BroadcastPointInfo()
	self.map:SendPonitData(dbid)
	print("KingCamp:AddCityPoint------------------",dbid,point,self.citypoint)
end

-- 普通积分
function KingCamp:AddCommonPoint(dbid, point)
	if point == 0 then return end
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.commonpoint = kingplayer.commonpoint + point
		kingplayer.pointtocity = kingplayer.pointtocity + point
		local KingBaseConfig = server.configCenter.KingBaseConfig
		if kingplayer.pointtocity >= KingBaseConfig.exchange then
			local addpoint  = math.floor(kingplayer.pointtocity / KingBaseConfig.exchange);
			local newpoint = kingplayer.pointtocity - addpoint * KingBaseConfig.exchange
			self:AddCityPoint(dbid, addpoint)
			kingplayer.pointtocity = newpoint
		end
	end
	self.map:SendPonitData(dbid)
	-- print("KingCamp:AddCommonPoint------------------",dbid,point)
end

-- 全体加普通积分
function KingCamp:AddAllCommonPoint(point, exclude)
	for dbid, kingplayer in pairs(self.playerlist) do
		if not exclude[dbid] then
			self:AddCommonPoint(dbid, point)
		end
	end
	print("KingCamp:AddAllCommonPoint------------------",point)
end

-- 打输了踢回出生点
function KingCamp:DeadKick(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.status = KingConfig.status.Dead
		kingplayer.deadtime = lua_app.now()
		local x, y = self:GetBornPos()
		server.mapCenter:Fly(server.configCenter.KingBaseConfig.mapid, dbid, x, y, true)
		self.map:BroadcastStatusChange(dbid, kingplayer.status)
		self:SendRebornCount(dbid)

		if kingplayer.transform then
			self:SetTransform(dbid, false)
		end
	end

	print("KingCamp:DeadKick-----------------------",dbid)
end


function KingCamp:SendRebornCount(dbid)
	server.sendReqByDBID(dbid, "sc_king_reborn_countdown", {reborncout = self:GetRebonCount(dbid)})
end

-- 玩家守城
function KingCamp:Guard(dbid, city)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.status = KingConfig.status.Guard
		kingplayer.guardcity = city
		self.map:BroadcastStatusChange(dbid, kingplayer.status)
	end

	print("KingCamp:Guard-----------------------",dbid)
end

-- 玩家守城
function KingCamp:LeaveGuard(dbid, city)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.status = KingConfig.status.Act
		kingplayer.guardcity = 99
		self.map:BroadcastStatusChange(dbid, kingplayer.status)
	end
end

function KingCamp:GetMyGuardCamp(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		if kingplayer.status == KingConfig.status.Guard then
			return kingplayer.guardcity
		end
	end
	return 99
end

function KingCamp:GetMyGuard(dbid)
	server.sendReqByDBID(dbid, "sc_king_my_guard_city", {city = self:GetMyGuardCamp(dbid)})
end

-- 复活
function KingCamp:DoRevive(kingplayer)
	kingplayer.status = KingConfig.status.Act
	kingplayer.deadtime = 0
	self.map:BroadcastStatusChange(kingplayer.playerinfo.dbid, kingplayer.status)
end

-- 花钱复活
function KingCamp:PayRevive(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer and kingplayer.status == KingConfig.status.Dead then
		local revivecost = server.configCenter.KingBaseConfig.revivecost
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player and player:PayReward(revivecost.type, revivecost.id, revivecost.count, server.baseConfig.YuanbaoRecordType.King, "King:Revive") then
			self:DoRevive(kingplayer)
		else
			print("KingCamp:PayRevive no user or no money",dbid)
		end
	end
end

-- 领取积分奖励
function KingCamp:GetPointReward(dbid, ptype, index)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		if ptype == _PointType.City then
			local config = server.configCenter.KingWPointsRewardConfig[index]
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			if player and config and kingplayer.citypoint >= config.citypoints and not kingplayer.cityreward[index] then
				kingplayer.cityreward[index] = true
				local rewards = server.dropCenter:DropGroup(config.reward) or {}
				player:GiveRewardAsFullMailDefault(rewards, "跨服争霸", server.baseConfig.YuanbaoRecordType.King)
			end
		elseif ptype == _PointType.Common then
			local config = server.configCenter.KingPointsRewardConfig[index]
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			if player and config and kingplayer.commonpoint >= config.partnerpoints and not kingplayer.commonreward[index] then
				kingplayer.commonreward[index] = true
				local rewards = server.dropCenter:DropGroup(config.reward) or {}
				player:GiveRewardAsFullMailDefault(rewards, "跨服争霸", server.baseConfig.YuanbaoRecordType.King)
			end
		end
	end
	self.map:SendPonitData(dbid)
end

-- 是否能战斗
function KingCamp:CanFight(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		if kingplayer.status ~= KingConfig.status.Act then
			print("KingCamp:CanFight----------", kingplayer.status, kingplayer.fighting)
			return false
		else
			return true
		end
	end
	print("KingCamp:CanFight no this player", dbid, self.camp)
	return false
end

-- 是否可以变身
function KingCamp:CanTransfrom(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		if kingplayer.status ~= KingConfig.status.Act or 
			kingplayer.transform or
			kingplayer.fighting then
			print("KingCamp:CanTransfrom ", kingplayer.status, kingplayer.transform, kingplayer.fighting)
			return false
		else
			local team, info = server.teamCenter:GetPlayerTeam(dbid)
			if team then
				print("KingCamp:CanTransfrom in team")
				return false
			else
				return true
			end
		end
	end
	print("KingCamp:CanTransfrom no this player", dbid, self.camp)
	return false
end

-- 设置战斗状态
function KingCamp:SetFighting(dbid, fighting)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.fighting = fighting
	end
end

-- 设置变身状态
function KingCamp:SetTransform(dbid, istransform)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		kingplayer.transform = istransform
		self.map:BroadcastTransformChange(dbid, istransform)
	end
end

-- 是否
function KingCamp:IsTransform(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		return kingplayer.transform
	end
end

function KingCamp:IsFighting(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		return kingplayer.fighting
	end
end

function KingCamp:CanTeam(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		if (kingplayer.status == KingConfig.status.Ready or kingplayer.status == KingConfig.status.Act) and
			(not kingplayer.fighting and not kingplayer.transform) then
			return true
		end
	end
end

-- 获得玩家状态
function KingCamp:GetStatus(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer then
		return kingplayer.status
	end
end

-- 获得复活倒计时
function KingCamp:GetRebonCount(dbid)
	local kingplayer = self.playerlist[dbid]
	if kingplayer and kingplayer.status == KingConfig.status.Dead then
		local KingBaseConfig = server.configCenter.KingBaseConfig
		local countdown = kingplayer.deadtime + KingBaseConfig.revivetime - lua_app.now()
		countdown = math.max(countdown, 0)
		return countdown
	end
	return 0
end

-- 活动出生点的随机位置
function KingCamp:GetBornPos()
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local bornpos
	if self.camp == KingConfig.camp.Human then
		bornpos = KingBaseConfig.rbronpos
	elseif self.camp == KingConfig.camp.God then
		bornpos = KingBaseConfig.xbronpos
	elseif self.camp == KingConfig.camp.Devil then
		bornpos = KingBaseConfig.mbronpos
	end
	if bornpos then
		local leftx = bornpos[1][1]
		local rightx = bornpos[2][1]
		local lefty = bornpos[1][2]
		local righty = bornpos[2][2]
		local x
		local y
		if leftx < rightx then
			x = math.random(leftx, rightx)
		else
			x = math.random(rightx, leftx)
		end
		if lefty < righty then
			y = math.random(lefty, righty)
		else
			y = math.random(righty, lefty)
		end
		return x, y
	else
		return 0, 0
	end
end

function KingCamp:GetCityPoint(dbid)
	local data
	local playerdata = self.playerlist[dbid]
	if playerdata then
		data = {
			dbid = dbid,
			citypoint = playerdata.citypoint,
			serverid = self.serverid,
		}
	end
	return data
end

function KingCamp:BroadcastOnline(name, msg)
	local onlinelist = self.map.onlinelist
	for dbid, __ in pairs(self.playerlist) do
		if onlinelist[dbid] then
			print("--------------------", dbid, name)
			server.sendReqByDBID(dbid, name, msg)
		end
	end
end

--发送胜利奖励
function KingCamp:SendWinReward()
	if self.serverid then
		local KingBaseConfig = server.configCenter.KingBaseConfig
		local WinConfig = server.configCenter.KingRewardConfig[1]
		self:SenParticipantReward(self.playerlist, WinConfig, KingBaseConfig.mailtitle, KingBaseConfig.maildes)
	end
end

--发送参与奖励
function KingCamp:SendLostReward()
	if self.serverid then
		local KingBaseConfig = server.configCenter.KingBaseConfig
		local LostConfig = server.configCenter.KingRewardConfig[2]
		self:SenParticipantReward(self.playerlist, LostConfig, KingBaseConfig.mailtitle2, KingBaseConfig.maildes2)
	end
end

function KingCamp:SenParticipantReward(playerlist, rewardconfig, mailtitle, maildes)
	for __, kingplayer in pairs(playerlist) do
		local level = kingplayer.playerinfo.level
		local receiveCfg = table.matchValue(rewardconfig, function(cfg)
			return level - cfg.level
		end, 1)

		local dbid = kingplayer.playerinfo.dbid
		local rewards = server.dropCenter:DropGroup(receiveCfg.reward)
		self:SendMail(dbid, mailtitle, maildes, rewards, server.baseConfig.YuanbaoRecordType.King)
		self.warReport:AddRewards(dbid, rewards)
	end
end

function KingCamp:SendMail(dbid, mailtitle, mailcontexts, rewards, ttype)
	server.serverCenter:SendOneMod("logic", self.serverid, "mailCenter", "SendMail", dbid, mailtitle, mailcontexts, rewards, ttype)
end

function KingCamp:GetPlayerName(dbid)
	return self.playerlist[dbid].playerinfo.name
end

return KingCamp