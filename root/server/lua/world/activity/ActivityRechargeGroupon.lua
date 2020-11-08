local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActCfg = require "resource.ActivityConfig"

local ActivityRechargeGroupon = oo.class(ActivityBaseType)

function ActivityRechargeGroupon:ctor(id)
end

function ActivityRechargeGroupon:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType21Config", activityId)
end

function ActivityRechargeGroupon:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0
	
	self:UpdateReward(player, activityId)
	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.record = record.drawBin
	data2.rechargeNum = record.rechargeNum
	data2.people = self:GetActivityPlayerNumber(activityId)

	local data3 = {}
	data3.type21 = data2
	return data3
end

function ActivityRechargeGroupon:InitActivityData(data)
	data.rechargePlayers = data.rechargePlayers or {}
	data.rechargepeople = data.rechargepeople or 0
end

function ActivityRechargeGroupon:OpenHandler(activityId)
	local activityData = self:GetActivityData(activityId)
	self:InitActivityData(activityData)
end

function ActivityRechargeGroupon:GetActivityData(activityId)
	local activity = self.activityListByType[activityId]
	return activity.cache.activity_data
end

function ActivityRechargeGroupon:GetActivityPlayerNumber(activityId)
	local activityData = self:GetActivityData(activityId)
	return activityData.rechargepeople
end

function ActivityRechargeGroupon:GetActivityPlayers(activityId)
	local activityData = self:GetActivityData(activityId)
	return activityData.rechargePlayers
end

function ActivityRechargeGroupon:DayTimer()
	--在线玩家发送未领取的奖励
	local playerlist = server.playerCenter:GetOnlinePlayers()
	for __, player in pairs(playerlist) do
		for activityId,__ in pairs(self.activityListByType) do
			local record = server.activityMgr:GetActData(player, activityId)
			local actCfg = self:GetMyConfig(activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					local rewards = table.wcopy(actCfg[id].rewards)
					server.serverCenter:SendLocalMod("logic", "mailCenter", "SendMail", player.dbid, "充值团购奖励", "这是你在开服活动中，达成团购充值的活动奖励，请注意查收", rewards, server.baseConfig.YuanbaoRecordType.Activity)
				end
			end
			server.activityMgr:ResetActData(player, activityId)
		end
	end

	for activityId, activity in pairs(self.activityListByType) do
		activity.cache.activity_data.rechargepeople = 0
		activity.cache.activity_data.rechargePlayers = {}
	end
end

function ActivityRechargeGroupon:onLogin(player)
	for activityId, activity in pairs(self.activityListByType) do
		local ActivityConfig = self:GetMyConfig(activityId)
		local record = server.activityMgr:GetActData(player, activityId)
		if record.loginday ~= server.serverRunDay then
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					local rewards = table.wcopy(ActivityConfig[id].rewards)
					server.serverCenter:SendLocalMod("logic", "mailCenter", "SendMail", player.dbid, "充值团购奖励", "这是你在开服活动中，达成团购充值的活动奖励，请注意查收", rewards, server.baseConfig.YuanbaoRecordType.Activity)
				end
			end
			server.activityMgr:ResetActData(player, activityId)
			self:SendActivityData(player, activityId)
		end
	end
end

function ActivityRechargeGroupon:AddRechargeCash(player, value)
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local upCfg = self:GetMyConfig(activityId)
			record.rechargeNum = record.rechargeNum + value
			player.activityPlug:SetActData(activityId, record)

			local rechargePlayers = self:GetActivityPlayers(activityId)
			if not rechargePlayers[player.dbid] then
				rechargePlayers[player.dbid] = true
				self:UpdateRechargeUserCount(activityId)
			else
				self:SendActivityDataOne(player, activityId)
			end
		end
	end
end

function ActivityRechargeGroupon:GetRechargeIncrement(activityId)
	local AutoAddConfig = server.configCenter.AutoAddConfig
	local activityData = self:GetActivityData(activityId)
	local findcfg = table.matchValue(AutoAddConfig, function(matchdata)
		return matchdata.range - activityData.rechargepeople
	end)
	if findcfg then
		return math.random(findcfg.min, findcfg.max)
	else
		return 1
	end
end

function ActivityRechargeGroupon:UpdateRechargeUserCount(activityId)
	local activityData = self:GetActivityData(activityId)
	activityData.rechargepeople = activityData.rechargepeople + self:GetRechargeIncrement(activityId)
	
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		self:SendActivityDataOne(player, activityId)
	end
end

function ActivityRechargeGroupon:UpdateReward(player, activityId)
	local record = server.activityMgr:GetActData(player, activityId)
	local upCfg = self:GetMyConfig(activityId)
	for id, cfg in pairs(upCfg) do
		if record.rechargeNum >= cfg.value and self:GetActivityPlayerNumber(activityId) >= cfg.type then
			record.drawBin[id] = math.max(record.drawBin[id], ActCfg.LevelStatus.ReachNoReward)
		end
	end
	player.activityPlug:SetActData(activityId, record)
end

function ActivityRechargeGroupon:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activity = self.activityListByType[activityId]
	local record = server.activityMgr:GetActData(player, activityId)
	local data = player.activityPlug:PlayerData()
	local ActivityType21Config = self:GetMyConfig(activityId)
	local cfg = ActivityType21Config[index]
	if cfg == nil then
		lua_app.log_error("activity target config not exist")
		return
	end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "团购奖励领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "团购奖励")
	self:SendActivityDataOne(player, activityId)
end

return ActivityRechargeGroupon
