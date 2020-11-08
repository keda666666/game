--成长基金
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityConfig = require "resource.ActivityConfig"
local ItemCfg = require "resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityGrowFund = oo.class(ActivityBaseType)

function ActivityGrowFund:ctor(id)
end

function ActivityGrowFund:GetMyConfig(activityId)
	return ActivityConfig:GetActConfig("ActivityType24Config", activityId)
end

function ActivityGrowFund:PackData(player, activityId)

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
	local cfg = self:GetMyConfig(activityId)
	if record.status >= #cfg then
		data2.status = 0
	else
		data2.status = record.status
	end
	data2.reward = {}
	for k,_ in pairs(record.reward) do
		table.insert(data2.reward,k)
	end

	local data3 = {}
	data3.type24 = data2 

	return data3
end

-- function ActivityGrowFund:OpenHandler(activityId)

-- end

-- function ActivityGrowFund:AddPlayer(player)
-- --登录对玩家领取条件进行判断修改
-- end

-- function ActivityGrowFund:DayTimer()
-- 	--跨天对全服在线玩家领取状态进行修改
-- 	local players = server.playerCenter:GetOnlinePlayers()
-- 	for dbid, player in pairs(players) do
-- 		self:Reward(dbid)
-- 	end

-- end
-- function ActivityGrowFund:onDayTimer(dbid)
-- 	self:Reward(dbid)
-- end

function ActivityGrowFund:AddInvest(dbid, index)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, index)
	-- local dbid = actor:Get(config.dbid)
	-- local cache = server.cacheMgr:GetCache(dbid)
	-- local record = cache:GetActData(activityId)
	-- local activity = self.activityListByType[activityId]
	local day = server.serverRunDay
	local param = ActivityConfig:GetActTypeConfig(index).params
	if day > param then
		server.sendErr(player, "成长基金已结束")
		return
	end
	if record.status == 1 then
		server.sendErr(player, "重复购买")
		return
	end
	local baseConfig = server.configCenter.InvestmentBaseConfig

	if not player:PayRewards(table.wcopy(baseConfig.growfundcost), server.baseConfig.YuanbaoRecordType.GrowFund, "growFund") then
		server.sendErr(player, "元宝不足")
		return
	end
	record.status = 1
	player.activityPlug:SetActData(index, record)
	self:SendActivityData(player, index)
end

function ActivityGrowFund:Reward(dbid, index, id)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local cfg = self:GetMyConfig(id)
	if player.cache.level() < cfg[index].level then return end

	local record = server.activityMgr:GetActData(player, id)
	if record.status == 0 then return end
	if record.reward[index] then return end
	record.reward[index] = 1
	player:GiveRewardAsFullMailDefault(table.wcopy(cfg[index].reward), "成长基金", server.baseConfig.YuanbaoRecordType.GrowFund, "成长基金")
	player.activityPlug:SetActData(id, record)
	self:SendActivityData(player, id)
end

function ActivityGrowFund:IsOpen(player, index)
	local record = server.activityMgr:GetActData(player, index)
	if record.status == 1 then 
		local cfg = self:GetMyConfig(index)
		for k,_ in pairs(cfg) do
			if not record.reward[k] then
				return true
			end
		end
	end
	return false --(record and record.status == 1)
end

return ActivityGrowFund
