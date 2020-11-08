--每日壕充
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityRechargeTotal = oo.class(ActivityBaseType)

function ActivityRechargeTotal:ctor(id)
end

function ActivityRechargeTotal:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType7Config", activityId)
end

function ActivityRechargeTotal:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.record = record.drawBin
	data2.recharge = record.recharge
	
	local data3 = {}
	data3.type07 = data2 
	return data3
end

function ActivityRechargeTotal:CloseHandler(activityId)
	local playerlist = server.playerCenter:GetOnlinePlayers()
	
	for activityId,__ in pairs(self.activityListByType) do
		local actCfg = self:GetMyConfig(activityId)

		for __, player in pairs(playerlist) do
			local record = server.activityMgr:GetActData(player, activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					player:SendMail("累充回馈", "这是你在累充回馈活动中，达成充值目标活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
					record.drawBin[id] = ActCfg.LevelStatus.Reward
				end
			end
			player.activityPlug:SetActData(activityId, record)
		end

	end
end

function ActivityRechargeTotal:onLogin(player)
	for activityId, activity in pairs(self.activityListByType) do
		if not activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local actCfg = self:GetMyConfig(activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					player:SendMail("累充回馈", "这是你在累充回馈活动中，达成充值目标活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
					record.drawBin[id] = ActCfg.LevelStatus.Reward
				end
			end
			player.activityPlug:SetActData(activityId, record)
		end
	end
end

function ActivityRechargeTotal:AddRechargeCash(player, cash)
	local openDay = server.serverRunDay
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			record.recharge = record.recharge + cash

			local acCfg = self:GetMyConfig(activityId)
			for id, cfg in ipairs(acCfg) do
				if cfg.value <= record.recharge then
					record.drawBin[id] = math.max(record.drawBin[id], ActCfg.LevelStatus.ReachNoReward)
				end
			end
			player.activityPlug:SetActData(activityId, record)
		end
		self:SendActivityDataOne(player,activityId)
	end
end

function ActivityRechargeTotal:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activity = self.activityListByType[activityId]
	local record = server.activityMgr:GetActData(player, activityId)
	local drawbin = record.drawBin[index] or ActCfg.LevelStatus.NoReach
	if drawbin ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player,"领取失败")
		return
	end

	record.drawBin[index] = ActCfg.LevelStatus.Reward
	local acCfg = self:GetMyConfig(activityId)
	player.activityPlug:GiveReward(activityId, record, table.wcopy(acCfg[index].rewards), "累充回馈")
	self:SendActivityData(player,activityId)
end

return ActivityRechargeTotal
