--每日登陆，如果后面登陆过，前面的都给算上
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActivityConfig = require "resource.ActivityConfig"

local ActivityDayLogin = oo.class(ActivityBaseType)

function ActivityDayLogin:ctor(id)

end

function ActivityDayLogin:GetMyConfig(activityId)
	return ActivityConfig:GetActConfig("ActivityType16Config", activityId)
end

function ActivityDayLogin:PackData(player, activityId)
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
	data2.record = record.loginBinData
	data2.logrecord = record.loginBinDay

	local data3 = {}
	data3.type16 = data2 
	
	return data3
end

function ActivityDayLogin:DayTimer()
	local players = server.playerCenter:GetOnlinePlayers()
	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus and server.serverRunDay <= 10 then
			for dbid, player in pairs(players) do
				local cfg = ActivityConfig:GetActTypeConfig(activityId)
				local record = server.activityMgr:GetActData(player, activityId)
				if cfg.timeType == 0 then
					record.loginBinDay = 0
					for i = 1, server.serverRunDay do
						record.loginBinDay = record.loginBinDay | (1<<(i))
					end
				end
				player.activityPlug:SetActData(activityId, record)
				self:SendActivityData(player,activityId)
			end
		end
	end
end


function ActivityDayLogin:AddPlayer(player)
	for activityId,activity in pairs(self.activityListByType) do
		local record = server.activityMgr:GetActData(player, activityId)
		local cfg = ActivityConfig:GetActTypeConfig(activityId)
		if cfg.timeType == 0 and server.serverRunDay <= 10 then
			record.loginBinDay = 0
			for i=1,server.serverRunDay do
				record.loginBinDay = record.loginBinDay | (1<<(i))
			end
		end
		player.activityPlug:SetActData(activityId, record)
		print("ActivityDayLogin:AddPlayer-----------", record.loginBinDay)
	end
end

function ActivityDayLogin:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local activity = self.activityListByType[activityId]
	if record.loginBinDay & (1<<(index)) == 0 then
		print("can not reward", record.loginBinDay)
		return
	end
	if record.loginBinData & (1<<(index)) ~= 0 then
		print("has been reward")
		return
	end
	record.loginBinData = record.loginBinData | (1<<(index))
	local ActTypeConfig = self:GetMyConfig(activityId)
	local cfg = ActTypeConfig[index]
	if cfg ==  nil then
		lua_app.log_error("weekLogin config failed")
		return
	end
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "冲级活动")
	self:SendActivityData(player,activityId)
end

return ActivityDayLogin
