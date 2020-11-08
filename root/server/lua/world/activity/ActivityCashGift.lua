--冲级
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ItemConfig = require "resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityCashGift = oo.class(ActivityBaseType)

function ActivityCashGift:ctor(activityId)
end

function ActivityCashGift:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType19Config", activityId)
end

function ActivityCashGift:PackData(player, activityId)
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
	data2.reachday = record.reachday
	data2.runday = activity:GetRunDay()
	data2.record = record.drawBin or {}

	local data3 = {}
	data3.type19 = data2 
	return data3
end

function ActivityCashGift:onPlayerDayTimer(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end

	for activityId, activity in pairs(self.activityListByType) do
		local record = server.activityMgr:GetActData(player, activityId)
		local runday = activity:GetRunDay()
		local acCfg = self:GetMyConfig(activityId)
		local day = record.reachday + 1
		record.drawBin = record.drawBin or {}
		repeat
			local drawbin = record.drawBin[day] or ActCfg.LevelStatus.NoReach
			if drawbin == ActCfg.LevelStatus.ReachNoReward then
				player:SendMail("人民币礼包", "这是你购买的人民币礼包奖励，请注意查收", table.wcopy(acCfg[day].gift), server.baseConfig.YuanbaoRecordType.Activity)
				record.drawBin[day] = ActCfg.LevelStatus.Reward
				record.reachday = record.reachday + 1
			end
			day = day + 1
		until (drawbin ~= ActCfg.LevelStatus.ReachNoReward)
		player.activityPlug:SetActData(activityId, record)
	end
end

function ActivityCashGift:BuyGift(player, giftid)
	lua_app.log_info("----------------------------3333")
	for activityId,activity in pairs(self.activityListByType) do
		lua_app.log_info("----------------------------4444")
		if activity.openStatus then
			lua_app.log_info("----------------------------555")
			local record = server.activityMgr:GetActData(player, activityId)
			local acCfg = self:GetMyConfig(activityId)
			local rewardCfg = table.matchValue(acCfg, function(cfg)
				return giftid == cfg.rechargeid and 0 or -1
			end)

			record.drawBin = record.drawBin or {}
			if rewardCfg then
				record.drawBin[rewardCfg.index] = math.max(record.drawBin[rewardCfg.index] or 0, ActCfg.LevelStatus.ReachNoReward)
			else
				lua_app.log_error("giftid error:", giftid)
			end
			lua_app.log_info("----------------------------666")
			player.activityPlug:SetActData(activityId, record)
		end
		self:SendActivityDataOne(player,activityId)
	end
end

function ActivityCashGift:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activity = self.activityListByType[activityId]
	local record = server.activityMgr:GetActData(player, activityId)
	local drawbin = record.drawBin[index] or ActCfg.LevelStatus.NoReach
	if drawbin ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player,"领取失败")
		return
	end

	local acCfg = self:GetMyConfig(activityId)
	local rewardCfg = acCfg[index]
	record.reachday = record.reachday + 1
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(rewardCfg.gift), "人民币礼包")
	self:SendActivityDataOne(player, activityId)

	server.serverCenter:SendLocalMod("logic", "chatCenter", "ChatLink", 32, nil, nil, player.cache.name(), rewardCfg.name, ItemConfig:ConverLinkText(rewardCfg.gift[1]))
end

return ActivityCashGift
