--充值返利
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "common.resource.ActivityConfig"
local ItemCfg = require "common.resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityRebate = oo.class(ActivityBaseType)

function ActivityRebate:ctor(id)
end

function ActivityRebate:onPlayerDayTimer(dbid)
	lua_app.add_update_timer(3 * 1000, self, "_onPlayerDayTimer", dbid)
end

function ActivityRebate:_onPlayerDayTimer(_, dbid)

	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local activity = self.activityListByType[activityId]
			if not activity.openStatus then return end
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			local record = server.activityMgr:GetActData(player, activityId)
			record.data = {}
			player.activityPlug:SetActData(activityId, record)
			self:SendActivityData(player, activityId)
		end
	end
end

function ActivityRebate:PackData(player, activityId)
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
	data2.data = {}

	for k,v in pairs(record.data) do
		table.insert(data2.data, {no = k, num = v})
	end
	local data3 = {}
	data3.type27 = data2

	return data3
end

function ActivityRebate:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType27Config", activityId)
end

function ActivityRebate:Reward(dbid, index, activityId)
	local activity = self.activityListByType[activityId]
	if not activity.openStatus then return end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local ActivityType27Config = self:GetMyConfig(activityId)
	local cfg = ActivityType27Config[index]
	if cfg == nil then return end
	if (record.data[index] or 0) > cfg.frequency then return end
	record.data[index] = (record.data[index] or 0) + 1
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.money2), "充值返利")
	player.activityPlug:SetActData(activityId, record)
	self:SendActivityData(player, activityId)
end

return ActivityRebate
