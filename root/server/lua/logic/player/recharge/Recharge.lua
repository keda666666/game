local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ItemConfig = require "resource.ItemConfig"
local ActivityConfig = require "resource.ActivityConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local Recharge = oo.class()

function Recharge:ctor(player)
    self.player = player
end

function Recharge:onCreate()
	self:onLoad()
end

function Recharge:onLoad()
	self.cache = self.player.cache.recharger_data
end

function Recharge:onInitClient()
	local msg = self:packFirstInfo()
	server.sendReq(self.player, "sc_recharge_first_info", msg)
	self:SendDoubleCharger()
	self:SetDailyRewardId()
	self:SendRechargeCashMsg()
end

local _Charge = {}
_Charge[1] = function(player, PayItemsConfig, rechargeid)
	local yb = PayItemsConfig.amount
	player:ChangeYuanBao(yb, server.baseConfig.YuanbaoRecordType.Recharge, "Recharge Normal")
	local doubleyb = player.recharge:DoubleCharger(PayItemsConfig)
	server.bonusMgr:AddQueue(player.cache.dbid, PayItemsConfig.award)
	player.activityPlug:onRecharge(yb)
	player.auctionPlug:onRecharge(yb)
	player.activityPlug:ActivityReward(26, rechargeid)

	if PayItemsConfig.itemid and (not player.recharge.cache.choicerechare or player.recharge.cache.choicerechare == 0) then
		player.recharge.cache.choicerechare = rechargeid
	end
	
	local addyb = yb + doubleyb
	player.recharge:SendDoubleCharger()
	return PayItemsConfig.cash, addyb
end

_Charge[2] = function(player, PayItemsConfig)
	local yb = player.welfare:Activation(PayItemsConfig.type)
	return PayItemsConfig.cash, yb
end

_Charge[3] = function(player, PayItemsConfig)
	local yb = player.welfare:Activation(PayItemsConfig.type)
	return PayItemsConfig.cash, yb
end

--人民币礼包
_Charge[4] = function(player, PayItemsConfig, rechargeid)
	player.activityPlug:onBuyGift(rechargeid)
	return PayItemsConfig.cash, 0
end

_Charge[6] = function(player, PayItemsConfig)
	local yb = player.welfare:Activation(PayItemsConfig.type)
	return PayItemsConfig.cash, yb
end

function Recharge:DoubleCharger(PayItemsConfig)
	if PayItemsConfig.isFanli ~= 1 then
		local tag = true
		if self.cache.doubleChargerList[PayItemsConfig.id] == 1 then return 0 end
		self.cache.doubleChargerList[PayItemsConfig.id] = 1

		local PayItemsConfigList = server.configCenter.PayItemsConfig
		for k,v in pairs(PayItemsConfigList) do
			local isplat = (server.platformid == 3 and v.plat == 3) or (server.platformid ~= 3 and v.plat ~= 3)
			if v.type == 1 and v.isFanli ~= 1 and isplat then
				if not self.cache.doubleChargerList[k] then
					tag = false
					break
				end
			end
		end
		if tag then
			self.cache.doubleChargerList = {}
		end
	end
	
	self.player:ChangeYuanBao(PayItemsConfig.award, server.baseConfig.YuanbaoRecordType.Recharge,"Recharge Double")
	return PayItemsConfig.award
end

function Recharge:SendDoubleCharger()
	local msg = {
		reward = {},
		choicerechare = self.cache.choicerechare or 0,
		finish = {},
	}
	for k,v in pairs(self.cache.doubleChargerList) do
		table.insert(msg.reward, k)
	end
	for k,v in pairs(self.cache.finishList) do
		table.insert(msg.finish, k)
	end
	server.sendReq(self.player, "sc_recharge_double", msg)
end

function Recharge:RechargeNormal(rechargeid)
	print("Recharge:RechargeNormal--------", self.player.dbid, rechargeid)
	local PayItemsConfig = server.configCenter.PayItemsConfig[rechargeid]
	if not PayItemsConfig then return end
	if PayItemsConfig.type ~= 4 then
		self.cache.dailyrechare = self.cache.dailyrechare + PayItemsConfig.cash
		self:SendRechargeCashMsg()
		self.cache.total = self.cache.total + PayItemsConfig.amount
		if self.cache.lastday == server.serverRunDay then
			self.cache.daycount = self.cache.daycount + PayItemsConfig.amount
			self.cache.daycash = self.cache.daycash + PayItemsConfig.cash
		else
			self.cache.lastday = server.serverRunDay
			self.cache.daycount = PayItemsConfig.amount
			self.cache.daycash = PayItemsConfig.cash
		end
		self.player:Recharge(PayItemsConfig.cash)
		self.player.advanced:AddCharge(PayItemsConfig.cash)
		self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.Recharge)
		if self.cache.firsttime == 0 then
			self.cache.firsttime = lua_app.now()
		end
	end

	self.cache.finishList[rechargeid] = 1
	return _Charge[PayItemsConfig.type](self.player, PayItemsConfig, rechargeid)
end

-- 获取充值的商品对应的充值金额及返回元宝
function Recharge:GetRechargeInfo(rechargeid)
	local PayItemsConfig = server.configCenter.PayItemsConfig[rechargeid]
	if not PayItemsConfig then
		return 0
	end

	return PayItemsConfig.cash 		-- 仅返回充值金额
end
-- 充值进去，这里调用到各个充值模块进行充值
function Recharge:Recharge(rechargeid)
	local yuanbao = 0
	local cash = 0
	if rechargeid < 1000 then
		cash, yuanbao = self:RechargeNormal(rechargeid)
	end
	return yuanbao	-- 返回本次充值一共增加的元宝数
end

function Recharge:SetDailyRewardId()
	local DailyrechargeConfig = server.configCenter.DailyrechargeConfig
	local maxCount = #DailyrechargeConfig
	local day = server.serverRunDay
	self.cache.dailyid = (day - 1) % maxCount + 1
end

function Recharge:GetReward(id)
	local DailyrechargeConfig = server.configCenter.DailyrechargeConfig
	if lua_util.bit_status(self.cache.rewardmark, id) then
		lua_app.log_info(">>Recharge:GetReward reward id not exist: id", id)
		return
	end
	local rewardCfg = DailyrechargeConfig[self.cache.dailyid]
	local rechareTb = table.packKeyArray(rewardCfg)
	table.sort(rechareTb, function(a, b)
		return a < b
	end)
	if rechareTb[id] > self.cache.dailyrechare then
		lua_app.log_info(">>Daily recharge cash no enough.", self.cache.dailyrechare)
		return
	end
	self.cache.rewardmark = lua_util.bit_open(self.cache.rewardmark, id)
	local rewards = rewardCfg[rechareTb[id]].reward
	self.player:GiveRewardAsFullMailDefault(rewards, "每日充值", server.baseConfig.YuanbaoRecordType.DailyRecharge)
	self:SendRechargeCashMsg()
end

function Recharge:SendRechargeCashMsg()
	server.sendReq(self.player, "sc_recharge_dailyrechare", {
			dailyrechare = self.cache.dailyrechare,
			rewardmark = self.cache.rewardmark,
			dailyid = self.cache.dailyid,
		})
end

function Recharge:GetChoiceReward()
	if not self.cache.choicerechare or self.cache.choicerechare < 1 then return end
	local payItemsConfig = server.configCenter.PayItemsConfig[self.cache.choicerechare]
	if not payItemsConfig or not payItemsConfig.itemid then return end
	self.cache.choicerechare = self.cache.choicerechare * -1
	self.player:GiveRewardAsFullMailDefault(payItemsConfig.itemid, "特惠充值", server.baseConfig.YuanbaoRecordType.ChoiceRechare)
	self:SendDoubleCharger()
	server.chatCenter:ChatLink(31, nil, nil, self.player.cache.name, ItemConfig:ConverLinkText(payItemsConfig.itemid[1]))
end

function Recharge:GetDailyRechargeStatus()
	return (self.cache.dailyrechare > 0)
end

function Recharge:onDayTimer()
	self.cache.dailyrechare = 0
	self.cache.daycount = 0
	self.cache.daycash = 0
	self.cache.rewardmark = 0
	self:SetDailyRewardId()
	self:SendRechargeCashMsg()
end

function Recharge:FirstReward(id)
	local rechargeConfig = server.configCenter.FirstRechargeConfig
	if not rechargeConfig[id] then return end
	if self.cache.firstRewardList[id] == 1 then return end
	self.cache.firstRewardList[id] = 1
	self.player:GiveRewardAsFullMailDefault(rechargeConfig[id].item, "首冲奖励", server.baseConfig.YuanbaoRecordType.Recharge, "首冲奖励")
	local msg = self:packFirstInfo()
	server.sendReq(self.player, "sc_recharge_first_info", msg)
end

function Recharge:packFirstInfo()
	local msg = {
		rechargeNum = self.player.cache.recharge,
		reward = {},
		firsttime = self.cache.firsttime,
	}
	for k,v in pairs(self.cache.firstRewardList) do
		table.insert(msg.reward, k)
	end
	return msg
end

function Recharge:UpDateMsg()
	local msg = self:packFirstInfo()
	server.sendReq(self.player, "sc_recharge_first_info", msg)
end

server.playerCenter:SetEvent(Recharge, "recharge")
return Recharge