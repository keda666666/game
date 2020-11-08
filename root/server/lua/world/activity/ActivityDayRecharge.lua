--每日充值
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityDayRecharge = oo.class(ActivityBaseType)

function ActivityDayRecharge:ctor(id)

end

function ActivityDayRecharge:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType18Config", activityId)
end

function ActivityDayRecharge:PackData(player, activityId)
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
	data2.dayrecash = actdata.dayrecash

	local data3 = {}
	data3.type18 = data2 
	return data3
end

function ActivityDayRecharge:AddRechargeCash(player, cash)
	local openDay = server.serverRunDay
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local data = player.activityPlug:PlayerData()
			local upCfg = self:GetMyConfig(activityId)
			for id,cfg in pairs(upCfg) do
				if openDay == cfg.day then
					if data.dayrecash >= cfg.value then
						if record.drawBin[id] == ActCfg.LevelStatus.NoReach then
							record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
						end
					end
				end
			end
			player.activityPlug:SetActData(activityId, record)
			print("ActivityDayRecharge:AddRechargeCash---------", data.dayrecash)
		end
		self:SendActivityData(player,activityId)
	end
end

function ActivityDayRecharge:DayTimer()
end

function ActivityDayRecharge:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local openDay = server.serverRunDay
	local ActivityConfig = self:GetMyConfig(activityId)
	local cfg = ActivityConfig[index]
	local activity = self.activityListByType[activityId]
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player,"领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "充值活动")
	self:SendActivityData(player,activityId)
end

return ActivityDayRecharge
