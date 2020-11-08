--每日壕充
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local DailyRecharge = oo.class(ActivityBaseType)

function DailyRecharge:ctor(id)
end

function DailyRecharge:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType28Config", activityId)
end

function DailyRecharge:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	local actdata = player.activityPlug:PlayerData()
	data2.baseData = data1
	data2.record = record.drawBin
	data2.recharge = actdata.dayrecash
	data2.runday = activity:GetRunDay()
	
	local data3 = {}
	data3.type28 = data2 
	return data3
end

function DailyRecharge:onPlayerDayTimer(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end

	for activityId, activity in pairs(self.activityListByType) do
		local record = server.activityMgr:GetActData(player, activityId)
		local runday = activity:GetRunDay()
		local acCfg = self:GetMyConfig(activityId)
		local day = 1
		while (record.drawBin[day] and day < runday) do
			if record.drawBin[day] == ActCfg.LevelStatus.ReachNoReward then
				player:SendMail("每日壕充", "这是你在每日壕充中，达成充值的活动奖励，请注意查收", table.wcopy(acCfg[day].gift), server.baseConfig.YuanbaoRecordType.Activity)
				record.drawBin[day] = ActCfg.LevelStatus.Reward
				
			end
			day = day + 1
		end
		player.activityPlug:SetActData(activityId, record)
	end
end

function DailyRecharge:AddRechargeCash(player, cash)
	local openDay = server.serverRunDay
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local acCfg = self:GetMyConfig(activityId)
			local runday = activity:GetRunDay()
			local actdata = player.activityPlug:PlayerData()
			if acCfg[runday].recharge <= actdata.dayrecash then
				record.drawBin[runday] = math.max(record.drawBin[runday], ActCfg.LevelStatus.ReachNoReward)
			end
			player.activityPlug:SetActData(activityId, record)
		end
		self:SendActivityDataOne(player,activityId)
	end
end

function DailyRecharge:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activity = self.activityListByType[activityId]
	local runday = activity:GetRunDay()
	local record = server.activityMgr:GetActData(player, activityId)
	local drawbin = record.drawBin[runday] or ActCfg.LevelStatus.NoReach
	if drawbin ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player,"领取失败")
		return
	end
	record.drawBin[runday] = ActCfg.LevelStatus.Reward

	local acCfg = self:GetMyConfig(activityId)
	player.activityPlug:GiveReward(activityId, record, table.wcopy(acCfg[runday].gift), "每日壕充")
	self:SendActivityData(player,activityId)
end

return DailyRecharge
