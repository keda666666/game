local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActCfg = require "resource.ActivityConfig"

local ActivityPowerTarget = oo.class(ActivityBaseType)

function ActivityPowerTarget:ctor(id)

end

function ActivityPowerTarget:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType20Config", activityId)
end

function ActivityPowerTarget:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0
	
	self:UpPowerRecord(player, activityId)
	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.record = record.drawBin

	local data3 = {}
	data3.type20 = data2 
	return data3
end

function ActivityPowerTarget:DayTimer()
	
end

function ActivityPowerTarget:UpdatePlayerTotalPower(player, totalPower)
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local upCfg = self:GetMyConfig(activityId)
			local isChange = false
			for id,cfg in pairs(upCfg) do
				if totalPower >= cfg.value and record.index < id then
					record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
					record.index = id
					isChange = true
				end
			end
			player.activityPlug:SetActData(activityId, record)
			if isChange then
				self:SendActivityDataOne(player, activityId)
			end
		end
	end
end

function ActivityPowerTarget:CloseHandler(activityId)
	local playerlist = server.playerCenter:GetOnlinePlayers()
	for __, player in pairs(playerlist) do
		for activityId,__ in pairs(self.activityListByType) do
			local record = server.activityMgr:GetActData(player, activityId)
			local actCfg = self:GetMyConfig(activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					player:SendMail("开服战力活动", "这是你在开服活动中，达成战力目标的活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
					record.drawBin[id] = ActCfg.LevelStatus.Reward
				end
			end
			record.closeaward = true
			player.activityPlug:SetActData(activityId, record)
		end
	end
end

function ActivityPowerTarget:onLogin(player)
	for activityId, activity in pairs(self.activityListByType) do
		if not activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			if not record.closeaward then
				local actCfg = self:GetMyConfig(activityId)
				for id, drawbin in ipairs(record.drawBin) do
					if drawbin == ActCfg.LevelStatus.ReachNoReward then
						player:SendMail("开服战力活动", "这是你在开服活动中，达成战力目标的活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
						record.drawBin[id] = ActCfg.LevelStatus.Reward
					end
				end
				record.closeaward = true
				player.activityPlug:SetActData(activityId, record)
			end
		end
	end
end

function ActivityPowerTarget:UpPowerRecord(player, activityId)
	local record = server.activityMgr:GetActData(player, activityId)
	local upCfg = self:GetMyConfig(activityId)
	local power = player.cache.totalpower()
	for id, cfg in pairs(upCfg) do
		if power >= cfg.value and record.index < id then
			record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
			record.index = id
		end
	end
	player.activityPlug:SetActData(activityId, record)
end

function ActivityPowerTarget:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local ActivityType20Config = self:GetMyConfig(activityId)
	local cfg = ActivityType20Config[index]
	if cfg == nil then
		lua_app.log_error("activity target config not exist")
		return
	end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "战力目标")
	self:SendActivityDataOne(player, activityId)
end

return ActivityPowerTarget
