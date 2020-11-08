--消费有礼
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityConfig = require "resource.ActivityConfig"
local ItemCfg = require "common.resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivitySpendGift = oo.class(ActivityBaseType)

function ActivitySpendGift:ctor(id)
end

function ActivitySpendGift:GetMyConfig(activityId)
	return ActivityConfig:GetActConfig("ActivityType25Config", activityId)
end

function ActivitySpendGift:DayTimer()
	local players = server.playerCenter:GetOnlinePlayers()
	local param = ActivityConfig:GetActTypeConfig(13).params
	if server.serverRunDay ~= (param + 1) then return end
	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus then
			for dbid, player in pairs(players) do
				local record = server.activityMgr:GetActData(player, activityId)
				local baseConfig = server.configCenter.InvestmentBaseConfig
				local title = baseConfig.mailtitlecost
				local msg = baseConfig.maildescost
				for k,v in ipairs(self:GetMyConfig(activityId)) do
					if record.RechargeNum < v.cost then break end
					if record.reward & (1<<k) ~= 0 then
						record.reward = record.reward | (1<<k)
						server.mailCenter:SendMail(player.dbid, title, msg, v.item, self.YuanbaoRecordType, "消费有礼")
					end
				end
			end
		end
	end
end

function ActivitySpendGift:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)

	local actdata = player.activityPlug:PlayerData()
	data2.baseData = data1
	data2.RechargeNum = record.RechargeNum
	data2.reward = record.reward

	local data3 = {}
	data3.type25 = data2 
	return data3
end

function ActivitySpendGift:ChangeYuanBao(player, cash)
	for activityId,activity in pairs(self.activityListByType) do
		local cfg = self:GetMyConfig(activityId)
		local record = server.activityMgr:GetActData(player, activityId)
		if activity.openStatus and next(cfg) then
			record.RechargeNum = record.RechargeNum + cash
			player.activityPlug:SetActData(activityId, record)
			self:SendActivityData(player,activityId)
			break
		end
	end
end

function ActivitySpendGift:Reward(dbid, index, id)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local cfg = self:GetMyConfig(id)
	local record = server.activityMgr:GetActData(player, id)
	if record.RechargeNum < cfg[index].cost then return end
	if record.reward & (1<<index) ~= 0 then return end

	record.reward = record.reward | (1<<index)
	player:GiveRewardAsFullMailDefault(table.wcopy(cfg[index].item), "消费有礼", server.baseConfig.YuanbaoRecordType.SpendGift, "消费有礼")
	player.activityPlug:SetActData(id, record)
	self:SendActivityData(player, id)
end

return ActivitySpendGift
