local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local json = require "cjson"
json.encode_sparse_array(true,1)
local ActivityConfig = require "resource.ActivityConfig"

local RechargeContinue = require "activity.RechargeContinue"
local SpendWheel = require "activity.SpendWheel"
local PackageDiscount = require "activity.PackageDiscount"
local ActivityWeekLogin = require "activity.ActivityWeekLogin"
local ActivityUpgrade = require "activity.ActivityUpgrade"
-- local ActivityReach = require "activity.ActivityReach"
local ActivityRechargeTotal = require "activity.ActivityRechargeTotal"
local ActivityInvest = require "activity.ActivityInvest"
-- local ActivityLoop = require "activity.ActivityLoop"
-- local ActivityMergeWing = require "activity.ActivityMergeWing"
-- local ActivityMergeBag = require "activity.ActivityMergeBag"
-- local ActivityMergeRecharge = require "activity.ActivityMergeRecharge"
-- local CumulativeRecharge = require "activity.CumulativeRecharge"
-- local ActivityResetDouble = require "activity.ActivityResetDouble"
local ActivitySingleRecharge = require "activity.ActivitySingleRecharge"
local ActivityDayLogin = require "activity.ActivityDayLogin"
local ActivityArenaTarget = require "activity.ActivityArenaTarget"
local ActivityDayRecharge = require "activity.ActivityDayRecharge"
local ActivityGrowFund = require "activity.ActivityGrowFund"
local ActivitySpendGift = require "activity.ActivitySpendGift"
local ActivityPowerTarget = require "activity.ActivityPowerTarget"
local ActivityOadvance = require "activity.ActivityOadvance"
local ActivityCashGift = require "activity.ActivityCashGift"
local ActivityDiscountShop = require "activity.ActivityDiscountShop"
local ActivityRechargeGroupon = require "activity.ActivityRechargeGroupon"
local ActivityOrangePetTarget = require "activity.ActivityOrangePetTarget"
local ActivityRebate = require "activity.ActivityRebate"
local DailyRecharge = require "activity.DailyRecharge"
local tbname = server.GetSqlName("worlddatas")
local tbcolumn = "record_activity"

local ActivityMgr = {}

function ActivityMgr:SetServerRunDay(serverRunDay)
	server.serverRunDay = serverRunDay
end

function ActivityMgr:SetServerOpenTime(serverOpenTime)
	server.serverOpenTime = serverOpenTime
end

function ActivityMgr:ResetDay(player)
	for __,activityObj in pairs(self.activityList) do
		for activityId,activity in pairs(activityObj.activityListByType) do
			activity:AddDay(1)
		end
	end
	-- local time = server.svrMgr:GetMergeTime()
	-- server.svrMgr:SetMergeTime(time-24*60*60)
end

function ActivityMgr:ResetServer()
	if server.serverCenter:IsCross() then return end
	self:ResetActivity()
end

function ActivityMgr:PlayerLogin(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end
	local data = {}
	data.datas = {}
	local others = {}
	for activityId,activity in pairs(self.activityList) do
		activity:AddPlayer(player)
		local datas = activity:PackDataList(player)
		for _, v in ipairs(datas) do
			self:AddConfigStr(v)
			if v.basecfg then
				table.insert(others, v)
			else
				table.insert(data.datas, v)
			end
		end
	end
	server.sendReqByDBID(player.dbid, "sc_activity_init_info", data)
	for _, v in ipairs(others) do
		server.sendReqByDBID(player.dbid, "sc_activity_init_info", { datas = { v } })
	end
end

local _configstr = {}
local function _GetConfigStr(config)
	if not config then return end
	if _configstr[config] then return _configstr[config] end
	_configstr[config] = json.encode(config)
	return _configstr[config]
end
function ActivityMgr:AddConfigStr(data)
	for k, v in pairs(data) do
		if v.baseData then
			local config = ActivityConfig:GetActTypeConfig(v.baseData.id)
			if config.config then
				data.basecfg = config
				data.btncfg = _GetConfigStr(config.btncfg)
				data.config = _GetConfigStr(config.config)
			end
		end
	end
end

--根据时间添加活动
function ActivityMgr:AddActivityByTime()
	local activityCfg = ActivityConfig:GetAllActConfig()
	for acId,acCfg in pairs(activityCfg) do
		self:AddActivity(acId)
	end
end

function ActivityMgr:onDayTimer()
	if server.serverCenter:IsCross() then return end
	for activityId,activity in pairs(self.activityList) do
		activity:DayTimer()
	end
	local players = server.playerCenter:GetOnlinePlayers()
	for _, player in pairs(players) do
		local data = {}
		data.datas = {}
		local others = {}
		for activityId,activity in pairs(self.activityList) do
			local datas = activity:PackDataList(player)
			for _, v in ipairs(datas) do
				self:AddConfigStr(v)
				if v.basecfg then
					table.insert(others, v)
				else
					table.insert(data.datas, v)
				end
			end
		end
		server.sendReqByDBID(player.dbid, "sc_activity_init_info", data)
		for _, v in ipairs(others) do
			server.sendReqByDBID(player.dbid, "sc_activity_init_info", { datas = { v } })
		end
	end
end

-- function ActivityMgr:onHalfHour()
-- 	for activityId,activity in pairs(self.activityList) do
-- 		activity:DayTimer()
-- 	end
-- end

function ActivityMgr:HotFix()
	print("ActivityMgr:HotFix-----", server.serverRunDay)
end

function ActivityMgr:InitEx()
	self.activityList[ActivityConfig.ActivityOadvance] = ActivityOadvance.new(ActivityConfig.ActivityOadvance)
	self.activityList[ActivityConfig.ActivityOadvance]:AddActivity(10)
end

function ActivityMgr:Init()
	self.saveTimerID = 0
	self.activityList = {}

	if not server.serverCenter:IsCross() then
		self.activityList[ActivityConfig.RechargeContinue] = RechargeContinue.new(ActivityConfig.RechargeContinue)
		self.activityList[ActivityConfig.PackageDiscount] = PackageDiscount.new(ActivityConfig.PackageDiscount)
		self.activityList[ActivityConfig.ActivityUpgrade] = ActivityUpgrade.new(ActivityConfig.ActivityUpgrade)
		self.activityList[ActivityConfig.ActivityWeekLogin] = ActivityWeekLogin.new(ActivityConfig.ActivityWeekLogin)
		self.activityList[ActivityConfig.ActivityDayLogin] = ActivityDayLogin.new(ActivityConfig.ActivityDayLogin)
		self.activityList[ActivityConfig.ActivitySingleRecharge] = ActivitySingleRecharge.new(ActivityConfig.ActivitySingleRecharge)
		self.activityList[ActivityConfig.ActivityArenaTarget] = ActivityArenaTarget.new(ActivityConfig.ActivityArenaTarget)
		self.activityList[ActivityConfig.ActivityDayRecharge] = ActivityDayRecharge.new(ActivityConfig.ActivityDayRecharge)
		self.activityList[ActivityConfig.ActivityInvest] = ActivityInvest.new(ActivityConfig.ActivityInvest)
		self.activityList[ActivityConfig.ActivityGrowFund] = ActivityGrowFund.new(ActivityConfig.ActivityGrowFund)
		self.activityList[ActivityConfig.ActivitySpendGift] = ActivitySpendGift.new(ActivityConfig.ActivitySpendGift)
		self.activityList[ActivityConfig.ActivityPowerTarget] = ActivityPowerTarget.new(ActivityConfig.ActivityPowerTarget)	
		self.activityList[ActivityConfig.ActivityRechargeGroupon] = ActivityRechargeGroupon.new(ActivityConfig.ActivityRechargeGroupon)
		self.activityList[ActivityConfig.ActivityOadvance] = ActivityOadvance.new(ActivityConfig.ActivityOadvance)
		self.activityList[ActivityConfig.ActivityCashGift] = ActivityCashGift.new(ActivityConfig.ActivityCashGift)
		self.activityList[ActivityConfig.ActivityDiscountShop] = ActivityDiscountShop.new(ActivityConfig.ActivityDiscountShop)
		self.activityList[ActivityConfig.ActivityOrangePetTarget] = ActivityOrangePetTarget.new(ActivityConfig.ActivityOrangePetTarget)
		self.activityList[ActivityConfig.SpendWheel] = SpendWheel.new(ActivityConfig.SpendWheel)
		self.activityList[ActivityConfig.ActivityRebate] = ActivityRebate.new(ActivityConfig.ActivityRebate)
		self.activityList[ActivityConfig.DailyRecharge] = DailyRecharge.new(ActivityConfig.DailyRecharge)
		self.activityList[ActivityConfig.ActivityRechargeTotal] = ActivityRechargeTotal.new(ActivityConfig.ActivityRechargeTotal)
	end

	self.recordCache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self:AddActivityByTime()
	self.timerID = lua_app.add_update_timer(1000, self, "TickActivity")
end

function ActivityMgr:Release()
	for __,activityTypeObj in pairs(self.activityList) do
		for activityId,activity in pairs(activityTypeObj.activityListByType) do
			activity:Save()
		end
	end
end

function ActivityMgr:AddActivity(id)
	local cfg = ActivityConfig:GetActTypeConfig(id)
	if cfg == nil then
		print("Add activity failed.cfg not exist ! activity Id is:",id)
		return
	end
	if not ActivityConfig:CheckPlat(id) then
		print("Add activity failed. ActivityMgr:AddActivity activity, platformid:", id, server.platformid)
		return
	end
	local activityType = cfg.activityType
	if self.activityList[activityType] == nil then
		print("Add activity failed.type handle not exist ! activity Id is:", id)
		return
	end

	print("ActivityMgr:AddActivity---------------", activityType, id)
	self.activityList[activityType]:AddActivity(id)
end


--计时开启关闭
function ActivityMgr:TickActivity()
	self.timerID = lua_app.add_update_timer(1000,self,"TickActivity")
	for activityId,activityTypeList in pairs(self.activityList) do
		activityTypeList:TickActivity()
	end
end

--充值元宝
function ActivityMgr:AddRecharge(dbid, value)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	-- self.activityList[ActivityConfig.RechargeContinue]:AddRecharge(player, value)
	-- self.activityList[ActivityConfig.RechargeWheel]:AddRecharge(player, value)
	-- self.activityList[ActivityConfig.ActivityRechargeTotal]:AddRecharge(player, value)
	-- self.activityList[ActivityConfig.ActivityMergeBag]:AddRecharge(player, value)
	-- self.activityList[ActivityConfig.ActivityMergeRecharge]:AddRecharge(player, value)
	-- self.activityList[ActivityConfig.CumulativeRecharge]:AddRecharge(player, value)
	
end

--充值金额
function ActivityMgr:AddRechargeCash(dbid, cash)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.activityList[ActivityConfig.ActivitySingleRecharge]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.ActivityRechargeGroupon]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.RechargeContinue]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.ActivityOadvance]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.ActivityDayRecharge]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.SpendWheel]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.DailyRecharge]:AddRechargeCash(player, cash)
	self.activityList[ActivityConfig.ActivityRechargeTotal]:AddRechargeCash(player, cash)
end

function ActivityMgr:DoTarget(dbid, targetdata)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.activityList[ActivityConfig.ActivityArenaTarget]:DoTarget(player, targetdata)
end

function ActivityMgr:ActivityAction(dbid, id, ...)
	local cfg = ActivityConfig:GetAllActConfig()
	local acType = cfg[id].activityType
	local mgr = self.activityList[acType]
	mgr:Action(dbid, id, ...)
end

function ActivityMgr:onFightResult(dbid, id)
	local cfg = ActivityConfig:GetAllActConfig()
	local acType = cfg[id].activityType
	local mgr = self.activityList[acType]
	mgr:onFightResult(dbid, id)
end

function ActivityMgr:ActivityReward(dbid, id, index)
	local cfg = ActivityConfig:GetAllActConfig()
	local acType = cfg[id].activityType
	local mgr = self.activityList[acType]
	lua_app.log_info("----------------------------8888:",acType)
	mgr:Reward(dbid, index, id)
end

function ActivityMgr:ActivityOpen(dbid, id)
	local cfg = ActivityConfig:GetAllActConfig()
	local acType = cfg[id].activityType
	self.activityList[acType]:AddInvest(dbid, id)
end

function ActivityMgr:ChangeYuanBao(dbid, count)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.activityList[ActivityConfig.ActivitySpendGift]:ChangeYuanBao(player, count)
	self.activityList[ActivityConfig.SpendWheel]:SpendYuanBao(player, count)
end

function ActivityMgr:onPlayerDayTimer(dbid)
	self.activityList[ActivityConfig.ActivityInvest]:onPlayerDayTimer(dbid)
	self.activityList[ActivityConfig.ActivityRebate]:onPlayerDayTimer(dbid)
	self.activityList[ActivityConfig.DailyRecharge]:onPlayerDayTimer(dbid)
	self.activityList[ActivityConfig.ActivityCashGift]:onPlayerDayTimer(dbid)
	self:ResetActDataByType(dbid, ActivityConfig.ActivityOadvance)
end

function ActivityMgr:WheelInfo(player,activityId)
	self.activityList[ActivityConfig.RechargeWheel]:SendWheelInfo(player,activityId)
end

function ActivityMgr:StartTurn(player,activityId)
	self.activityList[ActivityConfig.RechargeWheel]:StartTurn(player,activityId)
end

function ActivityMgr:FinishTurn(player,activityId)
	self.activityList[ActivityConfig.RechargeWheel]:FinishTurn(player,activityId)
end

function ActivityMgr:RequestReachInfo(player,activityId)
	self.activityList[ActivityConfig.ActivityReach]:ActivityInfo(player,activityId)
end

function ActivityMgr:SendLevelRecord(player,activityId)
	self.activityList[ActivityConfig.ActivityUpgrade]:SendActivityData(player,activityId)
end

function ActivityMgr:LevelUp(dbid, oldlevel, newlevel)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.activityList[ActivityConfig.ActivityUpgrade]:UpdatePlayerLv(player, newlevel)
end

--战力提升
function ActivityMgr:PowerUp(dbid, newpower)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end
	self.activityList[ActivityConfig.ActivityPowerTarget]:UpdatePlayerTotalPower(player, newpower)
end

--购买礼包
function ActivityMgr:BuyGift(dbid, giftid)
	lua_app.log_info("----------------------------2222")
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.activityList[ActivityConfig.ActivityCashGift]:BuyGift(player, giftid)
end

function ActivityMgr:ResetActivity()
	lua_app.del_local_timer(self.timerID)
	for __,activityType in pairs(self.activityList) do
		activityType:ResetActivity()
	end
	self.timerID = lua_app.add_update_timer(1000, self, "TickActivity")
end

function ActivityMgr:RecalActivity()
	for __,activityType in pairs(self.activityList) do
		activityType:RecalActivity()
	end
end

function ActivityMgr:AddInvest(player, acid, index)
	local typeMgr = self.activityList[ActivityConfig.ActivityInvest] 
	typeMgr:AddInvest(player,acid,index)
end

function ActivityMgr:SendReachHistory(player)
	local infos = server.svrMgr:GetReachWiner()
	local datas = {}
	for acId,winer in pairs(infos) do
		local tmp = {}
		local cache = server.cacheMgr:GetCache(winer.dbid)
		tmp.id =acId
		tmp.name = cache.actorname
		tmp.value = winer.value
		tmp.vip = cache.vip_level
		tmp.monthCard = cache.monthcard
		tmp.monthcard_super = cache.monthcard_super
		tmp.headId = cache.job*10+cache.sex
		table.insert(datas,tmp)
	end

	server.sendReq(player,"sc_activity_race_history",{data = datas})
end

function ActivityMgr:onLogin(player)
	if server.serverCenter:IsCross() then return end
	
	self.activityList[ActivityConfig.RechargeContinue]:onLogin(player)
	self.activityList[ActivityConfig.ActivityPowerTarget]:onLogin(player)
	self.activityList[ActivityConfig.ActivityUpgrade]:onLogin(player)
	self.activityList[ActivityConfig.ActivityRechargeGroupon]:onLogin(player)
	self.activityList[ActivityConfig.ActivityRechargeTotal]:onLogin(player)
end

function ActivityMgr:GetActData(player, id)
	local cfg = ActivityConfig:GetActTypeConfig(id)
	local record = player.activityPlug:GetActData(id)
	if not next(record) or record.startTime ~= cfg.startTime or record.endTime ~= cfg.endTime then
		record = server.activityCtl:Gen(id)
	end
	return record
end

function ActivityMgr:ResetActData(player, id)
	local record = server.activityCtl:Gen(id)
	player.activityPlug:SetActData(id, record)
end

function ActivityMgr:ResetActDataByType(dbid, activityType)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		local allCfg = ActivityConfig:GetAllActConfig()
		for id, cfg in ipairs(allCfg) do
			if cfg.activityType == activityType then
				self:ResetActData(player, id)
			end
		end
	end
end

function ActivityMgr:AddActivityRecord(config)
	if ActivityConfig:GetActTypeConfig(config.id) then
		lua_app.log_error("ActivityMgr:AddActivityRecord:: repead activity:", config.id)
		return
	end
	if config.btncfg and not next(config.btncfg) then
		config.btncfg = nil
	end
	self.recordCache.list[config.id] = config
	ActivityConfig:ResetActConfig()
	self:AddActivity(config.id)
end

function ActivityMgr:DelActivityRecord(id)
	if not self.recordCache.list[id] then
		lua_app.log_error("ActivityMgr:DelActivityRecord:: no activity:", id)
		return
	end
	self:DelActivity(id)
	ActivityConfig:ResetActConfig()
end

function ActivityMgr:DelActivity(id)
	local cfg = ActivityConfig:GetActTypeConfig(id)
	if self.activityList[cfg.activityType] then
		self.activityList[cfg.activityType]:DelActivity(id)
	end
	self.recordCache.list[id] = nil
end

server.SetCenter(ActivityMgr, "activityMgr")
return ActivityMgr
