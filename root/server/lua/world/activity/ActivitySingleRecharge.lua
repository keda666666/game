--单笔充值奖励
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local AcCfg = require "resource.ActivityConfig"

local ActivitySingleRecharge = oo.class(ActivityBaseType)

function ActivitySingleRecharge:ctor(id)

end

function ActivitySingleRecharge:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType15Config", activityId)
end

function ActivitySingleRecharge:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	local cfg = self:GetMyConfig(activityId)
	data2.baseData = data1
	data2.datas = {}
	for __,v in ipairs(cfg or {}) do
		local oneRecord = record.recharge[v.cash]
		if not oneRecord then
			oneRecord = { times = 0, rewardTimes = 0}
		end
		record.recharge[v.cash] = oneRecord
		local times = (oneRecord.times > v.count and v.count or oneRecord.times) - oneRecord.rewardTimes
		local onedata={times = times, rewardTimes = oneRecord.rewardTimes}
		table.insert(data2.datas, onedata)
	end
	local data3 = {}
	data3.type15 = data2 
	
	return data3
end

function ActivitySingleRecharge:CloseHandler(activityId)
	local players = server.playerCenter:GetOnlinePlayers()
	local activity = self.activityListByType[activityId]
	local cfg = self:GetMyConfig(activityId)
	for dbid, player in pairs(players) do
		local record = server.activityMgr:GetActData(player, activityId)
		for __,v in ipairs(cfg or {}) do
			local oneRecord = record.recharge[v.cash]
			if not oneRecord then break end
			local times = (oneRecord.times > v.count and v.count or oneRecord.times) - oneRecord.rewardTimes
			for i = 1, times do
				server.mailCenter:SendMail(dbid, "单笔充值奖励补发", "您有未领取的单笔充值奖励，现已补发，请在附件中领取。", v.rewards, nil, server.baseConfig.YuanbaoRecordType.ActivitySingleRecharge)
			end
		end
	end
end

function ActivitySingleRecharge:AddRechargeCash(player, value)
	for activityId,activity in pairs(self.activityListByType) do
		local cfg = self:GetMyConfig(activityId)
		local record = server.activityMgr:GetActData(player, activityId)
		if activity.openStatus then
			for __,v in ipairs(cfg or {}) do
				if v.cash == value then
					local oneRecord = record.recharge[v.cash]
					if not oneRecord then
						oneRecord = { times = 0, rewardTimes = 0}
					end
					oneRecord.times = oneRecord.times + 1
					record.recharge[math.tointeger(v.cash)] = oneRecord
					break
				end
			end
			player.activityPlug:SetActData(activityId, record)
			self:SendActivityData(player,activityId)
		end
	end
end

function ActivitySingleRecharge:DayTimer()

end

function ActivitySingleRecharge:AddPlayer(player)

end

function ActivitySingleRecharge:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local activity = self.activityListByType[activityId]
	local ActivityType15Config = self:GetMyConfig(activityId)
	local cfg = ActivityType15Config[index]
	local oneRecord = record.recharge[cfg.cash]
	if not oneRecord then
		oneRecord = { times = 0, rewardTimes = 0}
	end
	record.recharge[cfg.cash] = oneRecord
	record.recharge[cfg.cash] = record.recharge[cfg.cash] or 0
	if oneRecord.rewardTimes >=  cfg.count then
		server.sendDebug(player, "已达领取上限")
		return
	end
	if oneRecord.times <= oneRecord.rewardTimes then
		server.sendDebug(player, "未充值，不能领取奖励")
		return
	end
	oneRecord.rewardTimes = oneRecord.rewardTimes + 1
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "充值活动")
	self:SendActivityData(player, activityId)
end

return ActivitySingleRecharge
