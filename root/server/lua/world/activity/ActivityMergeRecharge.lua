--合服累计充值
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local config = require "logic.dbbase.config"
local ActivityBaseType = require "activity.ActivityBaseType"
local AcCfg = require "common.resource.ActivityConfig"

local ActivityMergeRecharge = oo.class(ActivityBaseType)

function ActivityMergeRecharge:ctor(id)

end

function ActivityMergeRecharge:PackData(actor,activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local dbid = actor:Get(config.dbid)
	local cache = server.cacheMgr:GetCache(dbid)
	local record = cache:GetActData(activityId)
	data2.baseData = data1
	data2.recharge = record.recharge
	data2.drawBin = record.drawBin
	

	local data3 = {}
	data3.type12 = data2 
	
	return data3
end

function ActivityMergeRecharge:AddRecharge(actor,value)
	local cache = server.cacheMgr:GetCache(actor:Get(config.dbid))
	for activityId,activity in pairs(self.activityListByType) do
		local record = cache:GetActData(activityId)
		if activity.openStatus then
			record.recharge = record.recharge + value
			self:SendActivityData(actor,activityId)
		end
	end
end

function ActivityMergeRecharge:DayTimer()

end

function ActivityMergeRecharge:AddActor(actor)

end

function ActivityMergeRecharge:Reward(actor,index,activityId)
	local activity = self.activityListByType[activityId]
	local dbid = actor:Get(config.dbid)
	local cache = server.cacheMgr:GetCache(dbid)
	local record = cache:GetActData(activityId)
	local cfg = server.configCenter.ActivityType12Config[activityId][index]
	if record.recharge < cfg.play then
		server.sendDebug(actor,"不满足充值条件")
		return
	end
	if record.drawBin&(1<<index) ~= 0 then
		server.sendDebug(actor,"重复领取奖励")
		return
	end
	record.drawBin = record.drawBin|(1<<index)
	server.mailCenter:GiveRewardAsFullMailIndex(dbid,cfg.rewards,56, server.baseConfig.YuanbaoRecordType.ActivityMergeRecharge)
	self:SendActivityData(actor,activityId)
end

return ActivityMergeRecharge
