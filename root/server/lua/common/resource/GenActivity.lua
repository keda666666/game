local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ActivityConfig = require "resource.ActivityConfig"


local RecordGen = {}

local RecordReset = {}

-- 1 名额已满 2 名额未满未达成 3 已达成可领取未领取 4 已领取
RecordGen[ActivityConfig.ActivityUpgrade] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType1Config", activityId)
	data.type = ActivityConfig.ActivityUpgrade
	data.index = 0
	data.closeaward = false
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityUpgrade] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityUpgrade](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--限购特惠
RecordGen[ActivityConfig.PackageDiscount] = function(activityId)
	local data = {}
	data.type = ActivityConfig.PackageDiscount
	data.buyData = {}
	data.buyDay = {}
	local cfg = ActivityConfig:GetActConfig("ActivityType2Config", activityId)
	for index,indexCfg in pairs(cfg) do
		data.buyData[index] = 0
	end

	return data
end

RecordReset[ActivityConfig.PackageDiscount] = function(activityId,record)
	local data = RecordGen[ActivityConfig.PackageDiscount](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.buyData) do
		if record.buyData[k] == nil then
			record.buyData[k] = v
		end
	end
end

--连续充值
RecordGen[ActivityConfig.RechargeContinue] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType3Config", activityId)
	data.type = ActivityConfig.RechargeContinue
	data.reachDay = 0
	data.lastday = 0
	data.closeaward = false
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.RechargeContinue] = function(activityId,record)
	local data = RecordGen[ActivityConfig.RechargeContinue](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--达标活动
RecordGen[ActivityConfig.ActivityReach] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityReach
	data.drawBin = 0
	data.stepNum = 0
	return data
end

RecordReset[ActivityConfig.ActivityReach] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityReach](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

--开服登录
RecordGen[ActivityConfig.ActivityWeekLogin] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityWeekLogin
	data.loginDay = 0
	data.loginDayNum = 0
	data.loginBinData = 0
	return data
end

RecordReset[ActivityConfig.ActivityWeekLogin] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityReach](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

--充值转盘
RecordGen[ActivityConfig.SpendWheel] = function(activityId)
	local data = {}
	local wheelCfg = ActivityConfig:GetActConfig("ActivityType6Config", activityId)
	data.type = ActivityConfig.SpendWheel
	data.index = 0
	data.drawrecord = 0
	data.drawtime = 0
	data.value = 0
	data.curremain = {}
	for id, cfg in pairs(wheelCfg) do
		data.curremain[id] = cfg.count
	end
	return data
end

RecordReset[ActivityConfig.SpendWheel] = function(activityId,record)
	local data = RecordGen[ActivityConfig.SpendWheel](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.curremain) do
		if record.curremain[k] == nil then
			record.curremain[k] = v
		end
	end
end

RecordGen[ActivityConfig.RechargeDaily] = function(activityId)
	local data = {}
	data.dailyOpenBin = 0
	data.dailyDrawBin = 0
	data.isFirst = true
	data.firstStatus = true
	data.buyTypeBin = 0
	data.dailyDay = 0
	return data
end

RecordReset[ActivityConfig.RechargeDaily] = function(activityId,record)
	local data = RecordGen[ActivityConfig.RechargeDaily](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

RecordGen[ActivityConfig.RechargeTotal] = function(activityId)
	local data = {}
	data.dailyOpenBin = 0
	data.dailyDrawBin = 0
	data.dailyDay = server.serverRunDay
	return data
end

RecordReset[ActivityConfig.RechargeTotal] = function(activityId,record)
	local data = RecordGen[ActivityConfig.RechargeTotal](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

RecordGen[ActivityConfig.RechargeMonth] = function(activityId)
	local data = {}
	data.status = ActivityConfig.MonthCard.NoReach
	return data
end

RecordReset[ActivityConfig.RechargeMonth] = function(activityId,record)
	local data = RecordGen[ActivityConfig.RechargeMonth](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

RecordGen[ActivityConfig.RechargeGift] = function(activityId)
	local data = {}
	data.dayNum = 0
	data.drawBinList = {}
	local cfg = server.configCenter.RechargeGiftConfig
	local cnt = math.ceil(table.length(cfg)/30)
	for i = 1,cnt do
		table.insert(data.drawBinList,0)
	end
	return data
end

RecordReset[ActivityConfig.RechargeGift] = function(activityId,record)
	local data = RecordGen[ActivityConfig.RechargeGift](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBinList) do
		if record.drawBinList[k] == nil then
			record.drawBinList[k] = v
		end
	end
end

--累充回馈
RecordGen[ActivityConfig.ActivityRechargeTotal] = function(activityId)
	local acCfg = ActivityConfig:GetActConfig("ActivityType7Config", activityId)
	local data = {}
	data.recharge = 0
	data.drawBin = {}
	for id,_ in pairs(acCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityRechargeTotal] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityRechargeTotal](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end

	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

-- RecordGen[ActivityConfig.ActivityInvest] = function(activityId)
-- 	local data = {}
-- 	local cfg = server.configCenter.ActivityType8Config
-- 	data.investList = {}
-- 	for i = 1,#cfg[activityId] do
-- 		local index = cfg[activityId][i].index
-- 		data.investList[index] = {}
-- 		data.investList[index].status = false
-- 		data.investList[index].reward = 0
-- 		data.investList[index].day = 0
-- 	end
-- 	return data
-- end

-- RecordReset[ActivityConfig.ActivityInvest] = function(activityId,record)
-- 	local data = RecordGen[ActivityConfig.ActivityInvest](activityId)
-- 	for k,v in pairs(data) do
-- 		if record[k] == nil then
-- 			record[k] = v
-- 		end
-- 	end
-- 	for k,v in pairs(data.investList) do
-- 		if record.investList[k] == nil then
-- 			record.investList[k] = v
-- 		end
-- 		for k1,v1 in pairs(data.investList[k]) do
-- 			if record.investList[k][k1] == nil then
-- 				record.investList[k][k1] = v1
-- 			end
-- 		end
-- 	end
-- end

RecordGen[ActivityConfig.ActivityLoop] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityLoop
	data.buyData = {}
	local type9Cfg = ActivityConfig:GetActConfig("ActivityType9Config", activityId)
	for i = 1,#type9Cfg do
		data.buyData[i] = {}
		for index,indexCfg in pairs(type9Cfg[i]) do
			data.buyData[i][index] = 0
		end
	end

	return data
	
end

RecordReset[ActivityConfig.ActivityLoop] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityLoop](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k1,v1 in pairs(data.buyData) do
		if record.buyData[k1] == nil then
			record.buyData[k1] = v1
		end
		for k2,v2 in pairs(v1) do
			if record.buyData[k1][k2] == nil then
				record.buyData[k1][k2] = v2
			end
		end
	end
end

RecordGen[ActivityConfig.ActivityMergeBag] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityMergeBag
	data.reachBin = 0
	data.drawBin = 0
	return data
end

RecordReset[ActivityConfig.ActivityMergeBag] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityMergeBag](activityId)
	data.type = ActivityConfig.ActivityMergeBag
	data.reachBin = 0
	data.drawBin = 0
end
--合服累计充值活动
RecordGen[ActivityConfig.ActivityMergeRecharge] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityMergeRecharge
	data.recharge = 0
	data.drawBin = 0
	return data
end

RecordReset[ActivityConfig.ActivityMergeRecharge] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityMergeRecharge](activityId)
	data.type = ActivityConfig.ActivityMergeRecharge
	data.recharge = 0
	data.drawBin = 0
end
--累计充值活动
RecordGen[ActivityConfig.CumulativeRecharge] = function(activityId)
	local data = {}
	data.type = ActivityConfig.CumulativeRecharge
	data.recharge = 0
	data.drawBin = 0
	return data
end

RecordReset[ActivityConfig.CumulativeRecharge] = function(activityId,record)
	local data = RecordGen[ActivityConfig.CumulativeRecharge](activityId)
	data.type = ActivityConfig.CumulativeRecharge
	data.recharge = 0
	data.drawBin = 0
end
--单笔充值活动
RecordGen[ActivityConfig.ActivitySingleRecharge] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivitySingleRecharge
	data.recharge = {}
	return data
end

RecordReset[ActivityConfig.ActivitySingleRecharge] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivitySingleRecharge](activityId)
	data.type = ActivityConfig.ActivitySingleRecharge
	data.recharge = {}
end

--每日登录
RecordGen[ActivityConfig.ActivityDayLogin] = function(activityId)
	local data = {}
	data.type = ActivityConfig.ActivityDayLogin
	data.loginDay = 0
	data.loginBinData = 0
	data.loginBinDay = 0
	return data
end

RecordReset[ActivityConfig.ActivityDayLogin] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityReach](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

--每日目标
RecordGen[ActivityConfig.ActivityArenaTarget] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType17Config", activityId)
	data.type = ActivityConfig.ActivityArenaTarget
	data.index = 0
	data.drawBin = {}
	data.targetBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
		data.targetBin[id] = 0
	end
	return data
end

RecordReset[ActivityConfig.ActivityArenaTarget] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityArenaTarget](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
	for k,v in pairs(data.targetBin) do
		if record.targetBin[k] == nil then
			record.targetBin[k] = v
		end
	end
end

--每日充值
RecordGen[ActivityConfig.ActivityDayRecharge] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType18Config", activityId)
	data.type = ActivityConfig.ActivityDayRecharge
	data.index = 0
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityDayRecharge] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityDayRecharge](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end
--投资计划
RecordGen[ActivityConfig.ActivityInvest] = function(activityId)
	local data = {}
	-- local upCfg = ActivityConfig:GetActConfig("ActivityType8Config", activityId)
	data.type = ActivityConfig.ActivityInvest
	data.status = 0
	data.day = 0
	return data
end

RecordReset[ActivityConfig.ActivityInvest] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityInvest](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end
--成长基金
RecordGen[ActivityConfig.ActivityGrowFund] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType24Config", activityId)
	data.type = ActivityConfig.ActivityGrowFund
	data.status = 0
	data.reward = {}
	return data
end

RecordReset[ActivityConfig.ActivityGrowFund] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityGrowFund](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end
--消费有礼
RecordGen[ActivityConfig.ActivitySpendGift] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType25Config", activityId)
	data.type = ActivityConfig.ActivitySpendGift
	data.RechargeNum = 0
	data.reward = 0
	return data
end

RecordReset[ActivityConfig.ActivitySpendGift] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivitySpendGift](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end
--战力目标
RecordGen[ActivityConfig.ActivityPowerTarget] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType20Config", activityId)
	data.type = ActivityConfig.ActivityPowerTarget
	data.index = 0
	data.closeaward = false
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityPowerTarget] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityPowerTarget](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--开服团购
RecordGen[ActivityConfig.ActivityRechargeGroupon] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType21Config", activityId)
	data.type = ActivityConfig.ActivityRechargeGroupon
	data.rechargePlayerNum = 0
	data.rechargeNum = 0
	data.loginday = server.serverRunDay
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityRechargeGroupon] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityRechargeGroupon](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--人民币礼包
RecordGen[ActivityConfig.ActivityCashGift] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType19Config", activityId)
	data.type = ActivityConfig.ActivityCashGift
	data.reachday = 0
	data.drawBin = {}
	for id,cfg in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityCashGift] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityCashGift](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end

	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--直升一阶
RecordGen[ActivityConfig.ActivityOadvance] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType23Config", activityId)
	data.type = ActivityConfig.ActivityOadvance
	data.runday = 0
	data.rechargeNumber = 0
	data.drawBin = ActivityConfig.LevelStatus.NoReach
	return data
end

RecordReset[ActivityConfig.ActivityOadvance] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityOadvance](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

--橙宠目标
RecordGen[ActivityConfig.ActivityOrangePetTarget] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType22Config", activityId)
	data.type = ActivityConfig.ActivityOrangePetTarget
	data.gid = 0
	data.drawBin = {}
	for id,_ in pairs(upCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.ActivityOrangePetTarget] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityOrangePetTarget](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end

--折扣商店
RecordGen[ActivityConfig.ActivityDiscountShop] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType26Config", activityId)
	data.type = ActivityConfig.ActivityDiscountShop
	data.buyData = {}
	for id,_ in pairs(upCfg) do
		data.buyData[id] = 0
	end
	return data
end

RecordReset[ActivityConfig.ActivityDiscountShop] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityDiscountShop](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
	for k,v in pairs(data.buyData) do
		if record.buyData[k] == nil then
			record.buyData[k] = v
		end
	end
end

--充值返利
RecordGen[ActivityConfig.ActivityRebate] = function(activityId)
	local data = {}
	local upCfg = ActivityConfig:GetActConfig("ActivityType25Config", activityId)
	data.type = ActivityConfig.ActivityRebate
	data.data = {}
	return data
end

RecordReset[ActivityConfig.ActivityRebate] = function(activityId,record)
	local data = RecordGen[ActivityConfig.ActivityRebate](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end
end

--每日壕充
RecordGen[ActivityConfig.DailyRecharge] = function(activityId)
	local acCfg = ActivityConfig:GetActConfig("ActivityType28Config", activityId)
	local data = {}
	data.drawBin = {}
	for id,_ in pairs(acCfg) do
		data.drawBin[id] = ActivityConfig.LevelStatus.NoReach
	end
	return data
end

RecordReset[ActivityConfig.DailyRecharge] = function(activityId, record)
	local data = RecordGen[ActivityConfig.DailyRecharge](activityId)
	for k,v in pairs(data) do
		if record[k] == nil then
			record[k] = v
		end
	end

	for k,v in pairs(data.drawBin) do
		if record.drawBin[k] == nil then
			record.drawBin[k] = v
		end
	end
end


local ActivityCtl = {}


function ActivityCtl:Gen(id)
	local cfg = ActivityConfig:GetActTypeConfig(id)
	local actType = cfg.activityType
	if RecordGen[actType] == nil then
		return {}
	else
		
		local data = RecordGen[actType](id)
		data.startTime = cfg.startTime
		data.endTime = cfg.endTime
		return data
	end
end

server.SetCenter(ActivityCtl, "activityCtl")
return ActivityCtl
