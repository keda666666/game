--7天登录
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActivityConfig = require "resource.ActivityConfig"

local ActivityWeekLogin = oo.class(ActivityBaseType)

function ActivityWeekLogin:ctor(id)

end

function ActivityWeekLogin:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType5Config", activityId)
end

function ActivityWeekLogin:PackData(player, activityId)
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
	data2.logTime = record.loginDayNum

	local data3 = {}
	data3.type05 = data2 
	
	return data3
end

function ActivityWeekLogin:DayTimer()
	local players = server.playerCenter:GetOnlinePlayers()
	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus then
			for dbid, player in pairs(players) do
				local cfg = ActivityConfig:GetActTypeConfig(activityId)
				local record = server.activityMgr:GetActData(player, activityId)
				if cfg.timeType == 0 then
					if record.loginDay < server.serverRunDay then
						record.loginDayNum = record.loginDayNum + 1
					end
					record.loginDay = server.serverRunDay
				-- elseif cfg.timeType == 2 then
				-- 	local mergeDay = server.svrMgr:GetMergeDay()
				-- 	if record.loginDay ~= mergeDay then
				-- 		record.loginDayNum = record.loginDayNum + 1
				-- 	end
				-- 	record.loginDay = mergeDay
				end
				player.activityPlug:SetActData(activityId, record)
				self:SendActivityData(player,activityId)
			end
		end
	end
end


function ActivityWeekLogin:AddPlayer(player)
	for activityId,activity in pairs(self.activityListByType) do
		local record = server.activityMgr:GetActData(player, activityId)
		local cfg = ActivityConfig:GetActTypeConfig(activityId)
		if cfg.timeType == 0 then
			if record.loginDay ~= server.serverRunDay then
				record.loginDayNum = record.loginDayNum + 1
			end
			record.loginDay = server.serverRunDay
		-- elseif cfg.timeType == 2 then
		-- 	local mergeDay = server.svrMgr:GetMergeDay()
		-- 	if record.loginDay ~= mergeDay then
		-- 		record.loginDayNum = record.loginDayNum + 1
		-- 	end
		-- 	record.loginDay = mergeDay
		end
		player.activityPlug:SetActData(activityId, record)
	end
end

function ActivityWeekLogin:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local activity = self.activityListByType[activityId]
	if record.loginDayNum < index then
		return
	end
	if record.loginBinData & (1<<(index)) ~= 0 then
		return
	end
	record.loginBinData = record.loginBinData | (1<<(index))
	local ActivityType5Config = self:GetMyConfig(activityId)
	local cfg = ActivityType5Config[index]
	if cfg ==  nil then
		lua_app.log_error("weekLogin config failed")
		return
	end
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "冲级活动")
	self:SendActivityData(player,activityId)
end

return ActivityWeekLogin
