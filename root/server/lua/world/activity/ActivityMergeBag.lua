--合服礼包
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local config = require "logic.dbbase.config"
local ActivityBaseType = require "activity.ActivityBaseType"
local AcCfg = require "common.resource.ActivityConfig"

local ActivityMergeBag = oo.class(ActivityBaseType)

function ActivityMergeBag:ctor(id)

end

function ActivityMergeBag:PackData(actor,activityId)
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
	data2.reachBin = record.reachBin
	data2.drawBin = record.drawBin
	

	local data3 = {}
	data3.type11 = data2 

	return data3
end

function ActivityMergeBag:AddRecharge(actor,value)
	local cache = server.cacheMgr:GetCache(actor:Get(config.dbid))
	for activityId,activity in pairs(self.activityListByType) do
		local record = cache:GetActData(activityId)
		if activity.openStatus then
			local activitycfg = server.configCenter.ActivityType11Config[activityId]
			local old = record.reachBin
			for index,indexcfg in pairs(activitycfg) do
				if value >= indexcfg.recharge then
					record.reachBin = record.reachBin|(1<<index)
				end
			end
			if old ~= record.reachBin then
				self:SendActivityData(actor,activityId)
			end
		end
	end
end

function ActivityMergeBag:DayTimer()

end

function ActivityMergeBag:AddActor(actor)

end

function ActivityMergeBag:Reward(actor,index,activityId)
	local activity = self.activityListByType[activityId]
	local dbid = actor:Get(config.dbid)
	local cache = server.cacheMgr:GetCache(dbid)
	local record = cache:GetActData(activityId)
	local cfg = server.configCenter.ActivityType11Config[activityId][index]
	if record.reachBin&(1<<index) == 0 then
		server.sendDebug(actor,"未达到单次充值条件")
		return
	end
	if record.drawBin&(1<<index) ~= 0 then
		server.sendDebug(actor,"重复领取奖励")
		return
	end
	record.drawBin = record.drawBin|(1<<index)
	server.mailCenter:GiveRewardAsFullMailIndex(dbid,cfg.rewards,55, server.baseConfig.YuanbaoRecordType.ActivityMergeBag)
	self:SendActivityData(actor,activityId)
end

return ActivityMergeBag
