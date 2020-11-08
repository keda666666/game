--7天登录
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local config = require "logic.dbbase.config"
local ActivityBaseType = require "activity.ActivityBaseType"
local AcCfg = require "common.resource.ActivityConfig"

local ActivityMergeWing = oo.class(ActivityBaseType)

function ActivityMergeWing:ctor(id)

end

function ActivityMergeWing:PackData(actor,activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	data2.baseData = data1

	local data3 = {}
	data3.type10 = data2 
	
	return data3
end

function ActivityMergeWing:OpenHandler(activityId)
	local rate = server.configCenter.ActivityType10Config[activityId].crit
	server.wing_critrate = rate
end

function ActivityMergeWing:CloseHandler(activityId)
	local rate = server.configCenter.ActivityType10Config[activityId].crit
	server.wing_critrate = 1
end

function ActivityMergeWing:DayTimer()

end

function ActivityMergeWing:AddActor(actor)

end

function ActivityMergeWing:Reward(actor,index,activityId)

end

return ActivityMergeWing
