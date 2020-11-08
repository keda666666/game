--投资计划
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityConfig = require "resource.ActivityConfig"
local ItemCfg = require "resource.ItemConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityInvest = oo.class(ActivityBaseType)

function ActivityInvest:ctor(id)
end

function ActivityInvest:GetMyConfig(activityId)
	return ActivityConfig:GetActConfig("ActivityType8Config", activityId)
end


function ActivityInvest:PackData(player, activityId)
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
	data2.status = record.status
	data2.day = record.day

	local data3 = {}
	data3.type08 = data2

	return data3
end

-- function ActivityInvest:OpenHandler(activityId)

-- end

-- function ActivityInvest:AddPlayer(player)
-- --登录对玩家领取条件进行判断修改
-- end

-- function ActivityInvest:DayTimer()
-- 	--跨天对全服在线玩家领取状态进行修改
-- 	local players = server.playerCenter:GetOnlinePlayers()
-- 	for dbid, player in pairs(players) do
-- 		self:Reward(dbid)
-- 	end

-- end
function ActivityInvest:onPlayerDayTimer(dbid)
	for activityId, activity in pairs(self.activityListByType) do
		self:Reward(dbid, activityId)
	end
end

function ActivityInvest:AddInvest(dbid, index)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, index)
	-- local dbid = actor:Get(config.dbid)
	-- local cache = server.cacheMgr:GetCache(dbid)
	-- local record = cache:GetActData(activityId)
	-- local activity = self.activityListByType[activityId]
	local day = server.serverRunDay
	local param = ActivityConfig:GetActTypeConfig(index).params
	if day > param then
		server.sendErr(player, "投资计划已结束")
		return
	end
	if record.status == 1 then
		server.sendErr(player, "重复购买")
		return
	end
	local baseConfig = server.configCenter.InvestmentBaseConfig

	if not player:PayRewards(table.wcopy(baseConfig.investmentcost), server.baseConfig.YuanbaoRecordType.Invest, "invest") then
		server.sendErr(player, "元宝不足")
		return
	end
	record.status = 1
	record.day = 1

	local baseConfig = server.configCenter.InvestmentBaseConfig
	local title = baseConfig.mailtitleinvest
	local msg = baseConfig.maildesinvest

	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local cfg = self:GetMyConfig(activityId)
			if cfg then
				player.server.mailCenter:SendMail(dbid, title, msg, table.wcopy(cfg[record.day].item), server.baseConfig.YuanbaoRecordType.Invest, "投资计划")
				break
			end
		end
	end
	player.activityPlug:SetActData(index, record)
	self:SendActivityData(player, index)
end

function ActivityInvest:Reward(dbid, index)
	local cfg = self:GetMyConfig(index)
	if not cfg then return end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end
	local record = server.activityMgr:GetActData(player, index)
	local param = ActivityConfig:GetActTypeConfig(index).params
	if record.status == 0 then return end
	if record.day >= param then return end
	record.day = record.day + 1

	local baseConfig = server.configCenter.InvestmentBaseConfig
	local title = baseConfig.mailtitleinvest
	local msg = baseConfig.maildesinvest
	player.server.mailCenter:SendMail(dbid, title, msg, table.wcopy(cfg[record.day].item), server.baseConfig.YuanbaoRecordType.Invest, "投资计划")
	player.activityPlug:SetActData(index, record)
	self:SendActivityData(player, index)
end

function ActivityInvest:IsOpen(player, index)
	local record = server.activityMgr:GetActData(player, index)
	local param = server.configCenter.ActivityConfig[index].params
	if record.day >= param then return false end
	return (record and record.status == 1)
end

return ActivityInvest
