local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local AcCfg = require "common.resource.ActivityConfig"
local ItemCfg = require "common.resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityDiscountShop = oo.class(ActivityBaseType)

function ActivityDiscountShop:ctor(id)
end

function ActivityDiscountShop:GetMyConfig(activityId)
	return AcCfg:GetActConfig("ActivityType26Config", activityId)
end

function ActivityDiscountShop:PackData(player,activityId)
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
	data2.buynums = record.buyData

	local data3 = {}
	data3.type26 = data2
	return data3
end

function ActivityDiscountShop:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data = player.activityPlug:PlayerData()
	local ActivityConfig = self:GetMyConfig(activityId)
	local cfg = ActivityConfig[index]
	if not activity.openStatus then
		server.sendErr(player,"活动已关闭")
		return
	end

	if cfg == nil then
		lua_app.log_error("Discount activity cfg not exist", activityId, index)
		return
	end

	local buyCfg = cfg.type
	local cost = {
		table.wcopy(cfg.gold)
	}
	if buyCfg.type == 3 and record.buyData[index] + 1 > buyCfg.value then
		lua_app.log_info("Discount activity already empty", index)
		return
	end
	if not player:PayRewards(cost, server.baseConfig.YuanbaoRecordType.Activity, "ActivityDiscountShop:discount") then
		lua_app.log_info("Discount activity pay failed", index)
		return
	end
	
	local rewards = {}
	table.insert(rewards, {
			type = ItemCfg.AwardType.Item,
			id = cfg.itemid,
			count = cfg.count,
		})
	record.buyData[index] = record.buyData[index] + 1
	player.activityPlug:GiveReward(activityId, record, rewards, "外观折扣商店")
	self:SendActivityDataOne(player, activityId)
end

return ActivityDiscountShop