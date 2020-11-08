--连续充值
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActCfg = require "resource.ActivityConfig"

local RechargeContinue = oo.class(ActivityBaseType)

function RechargeContinue:ctor(id)
end

function RechargeContinue:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType3Config", activityId)
end

function RechargeContinue:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	local activitydata = player.activityPlug:PlayerData()
	data2.baseData = data1
	data2.record = record.drawBin
	data2.day = record.reachDay
	data2.rechargeCount = activitydata.dayrecharge

	local data3 = {}
	data3.type03 = data2 
	return data3
end

function RechargeContinue:CloseHandler(activityId)
	local playerlist = server.playerCenter:GetOnlinePlayers()
	for __, player in pairs(playerlist) do
		for activityId,__ in pairs(self.activityListByType) do
			local record = server.activityMgr:GetActData(player, activityId)
			local actCfg = self:GetMyConfig(activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					player:SendMail("开服连续充值活动", "这是你在开服活动中，达成连续充值的活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
				end
			end
			record.closeaward = true
			player.activityPlug:SetActData(activityId, record)
		end
	end
end

function RechargeContinue:onLogin(player)
	for activityId, activity in pairs(self.activityListByType) do
		if not activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			if not record.closeaward then
				local actCfg = self:GetMyConfig(activityId)
				for id, drawbin in ipairs(record.drawBin) do
					if drawbin == ActCfg.LevelStatus.ReachNoReward then
						player:SendMail("开服连续充值活动", "这是你在开服活动中，达成连续充值的活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
					end
				end
				record.closeaward = true
				player.activityPlug:SetActData(activityId, record)
			end
		end
	end
end

function RechargeContinue:AddRechargeCash(player, value)
	local openDay = server.serverRunDay
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local upCfg = self:GetMyConfig(activityId)
			local data = player.activityPlug:PlayerData()
			if record.lastday ~= openDay then
				if (openDay - record.lastday) ~= 1 then
					record.reachDay = 0
				end
				record.lastday = openDay
				record.reachDay = record.reachDay + 1
				for id, cfg in pairs(upCfg) do
					if record.reachDay >= cfg.rechargeday then
						record.drawBin[id] = math.max(record.drawBin[id], ActCfg.LevelStatus.ReachNoReward)
					end
				end
			end
			player.activityPlug:SetActData(activityId, record)
			self:SendActivityDataOne(player, activityId)
		end
	end
end

function RechargeContinue:DayTimer()
end

function RechargeContinue:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local openDay = server.serverRunDay
	local ActivityConfig = self:GetMyConfig(activityId)
	local cfg = ActivityConfig[index]
	if not cfg then
		server.sendErr(player,"领取失败")
		return
	end
	if record.reachDay < cfg.rechargeday then
		server.sendErr(player,"连续充值天数不足，未达到领取条件")
		return
	end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "连续充值活动")
	self:SendActivityDataOne(player,activityId)
end

return RechargeContinue
