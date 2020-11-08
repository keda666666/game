--折扣商品
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ItemConfig = require "resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"
local _NotLimit = 2
local _DayLimit = 3

local PackageDiscount = oo.class(ActivityBaseType)

function PackageDiscount:ctor(id)

end


function PackageDiscount:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local type2Cfg = ActCfg:GetActConfig("ActivityType2Config", activityId)
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.buyData = {}
	for index,indexCfg in pairs(type2Cfg) do
		if record.buyData[index] == nil then
			record.buyData[index] = 0
		end
		if record.buyDay[index] ~= server.serverRunDay then
			record.buyData[index] = 0
		end
		table.insert(data2.buyData, record.buyData[index])
	end

	local data3 = {}
	data3.type02 = data2 
	return data3
end

function PackageDiscount:Reward(dbid,acIndex,acId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, acId)
	local activity = self.activityListByType[acId]
	local type2Cfg = ActCfg:GetActConfig("ActivityType2Config", acId)
	local cfg = type2Cfg[acIndex]
	if not activity.openStatus then
		server.sendErr(player,"活动已关闭")
		return
	end
	if cfg == nil then
		lua_app.log_error("Discount activity cfg not exist",acId,acIndex)
		return
	end
	if record.buyData[acIndex] == nil then
		record.buyData[acIndex] = 0
	end

	if record.buyDay[acIndex] ~= server.serverRunDay then
		record.buyData[acIndex] = 0
	end
	if cfg.type.type == _DayLimit then
		if record.buyData[acIndex] >= cfg.type.value then
			server.sendErr(player, "已达到最大购买数量")
			return
		end
	end
	
	local result = player:PayRewards({table.wcopy(cfg.gold)}, server.baseConfig.YuanbaoRecordType.Activity, "PackageDiscount:"..acId)
	if not result then
		server.sendErr(player, "元宝不足")
		return
	end
	record.buyData[acIndex] = record.buyData[acIndex] + 1
	record.buyDay[acIndex] = server.serverRunDay
	local rewards = {{type = ItemConfig.AwardType.Item, id = cfg.itemid, count = cfg.count}}
	player.activityPlug:GiveReward(acId, record, rewards, "DiscountShop:" .. acId .. "," .. acIndex)
	self:SendActivityData(player,acId)

	local playername = player.cache.name()
	local titleName = cfg.title 
	if titleName == nil or titleName == "" then
		local __,reward = next(rewards)
		local itemId = reward.id
		titleName = server.configCenter.ItemConfig[itemId].name
	end

	if acId == ActCfg.ActivityID.PackageSpecial then
		local noticeId = ActCfg.NoticeID.PackageSpecial
		player.server.noticeCenter:Notice(noticeId,playername,titleName)
	else
		local noticeId = ActCfg.NoticeID.PackageDiscount
		player.server.noticeCenter:Notice(noticeId,playername,titleName)
	end
end

return PackageDiscount
