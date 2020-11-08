local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local WeightData = require "WeightData"
local ItemConfig = require "resource.ItemConfig"
local ActConfig = require "resource.ActivityConfig"

local CashCow = oo.class()

function CashCow:ctor(player)
	self.player = player
end

function CashCow:onCreate()
	self:onLoad()
	self:ResetData()
end

function CashCow:onLoad()
	self.cache = self.player.cache.cashCow
end

function CashCow:onInitClient()
	self:GenDrawBin()
	self:SendClientMsg()
end

function CashCow:GenDrawBin()
	local isupdate = false
	if not self.cache.drawBin or not next(self.cache.drawBin) then
		isupdate = true
	end
	local CashCowBoxConfig = server.configCenter.CashCowBoxConfig
	local drawBin = lua_util.CreateArray(#CashCowBoxConfig, ActConfig.LevelStatus.NoReach)
	self.cache.drawBin = self.cache.drawBin or {}
	for id, v in ipairs(drawBin) do
		if self.cache.drawBin[id] == nil then
			self.cache.drawBin[id] = v
		end
	end
	if isupdate then
		self:UpdateBoxRewards()
	end
end

function CashCow:Shake()
	if not self:CheckShake() then return end

	local shake = self.cache.shake + 1
	local shakeCfg = server.configCenter.CashCowBasicConfig[shake]
	local cost = ItemConfig:GenNumericRewards(ItemConfig.NumericType.YuanBao, shakeCfg.yuanbao)
	if not self.player:PayRewards(cost, server.baseConfig.YuanbaoRecordType.CashCow, "CashCow:Shake") then
		lua_app.log_info("money not enough.")
		return
	end

	local amplitude = self:CalcAmplitude() + (self.cache.odds-1)*100
	local gold = math.ceil(shakeCfg.gold*amplitude/100)
	local rewards = ItemConfig:GenNumericRewards(ItemConfig.NumericType.Gold, gold)
	self.player:GiveRewardAsFullMailDefault(rewards, "摇钱树", server.baseConfig.YuanbaoRecordType.CashCow)
	self.cache.shake = shake

	self:AddExp()
	self:NextCrit()
	self:UpdateBoxRewards()
	self:SendClientMsg()
end

function CashCow:CheckShake()
	local vip = self.player.cache.vip
	local shakeMax = server.configCenter.CashCowLimitConfig[vip].maxTime
	if shakeMax <= self.cache.shake then
		lua_app.log_info("CheckShake reach maximum.", self.cache.shake, shakeMax)
		return false
	end

	return true
end

function CashCow:CalcAmplitude()
	local amplitudeCfg = server.configCenter.CashCowAmplitudeConfig[self.cache.level]
	local amplitude = amplitudeCfg.rate
	return amplitude
end

function CashCow:AddExp()
	local level = self.cache.level
	local CashCowAmplitudeConfig = server.configCenter.CashCowAmplitudeConfig[level + 1]
	if not CashCowAmplitudeConfig then
		lua_app.log_info("cashCow level reach maximum.", level)
		return
	end

	local exp = self.cache.exp + 1
	if CashCowAmplitudeConfig.needExp <= exp then
		exp = exp - CashCowAmplitudeConfig.needExp
		self.cache.level = self.cache.level + 1
	end

	self.cache.exp = exp
end

local _CritPool = {}
local function _GetCrit(vip)
	local luckPool = _CritPool[vip]
	if not luckPool then
		local crits = server.configCenter.CashCowLimitConfig[vip].crit
		luckPool = WeightData.new()
		for __, crit in ipairs(crits) do
			luckPool:Add(crit.rate, crit.odds)
		end
		_CritPool[vip] = luckPool
	end
	return luckPool:GetRandom()
end

function CashCow:NextCrit()
	local vip = self.player.cache.vip
	self.cache.odds = _GetCrit(vip)
end

function CashCow:UpdateBoxRewards()
	local shake = self.cache.shake
	local drawBin = self.cache.drawBin
	local CashCowBoxConfig = server.configCenter.CashCowBoxConfig
	for id, cfg in ipairs(CashCowBoxConfig) do
		if cfg.time <= shake then
			drawBin[id] = math.max(drawBin[id], ActConfig.LevelStatus.ReachNoReward)
		end
	end
end

function CashCow:GetBoxRewards(boxid)
	local drawbin = self.cache.drawBin[boxid] or ActConfig.LevelStatus.NoReach
	if drawbin ~= ActConfig.LevelStatus.ReachNoReward then
		lua_app.log_info("receive condition not reach.")
		return
	end

	local rewards = server.configCenter.CashCowBoxConfig[boxid].box
	self.player:GiveRewardAsFullMailDefault(rewards, "摇钱树宝箱", server.baseConfig.YuanbaoRecordType.CashCow)
	self.cache.drawBin[boxid] = ActConfig.LevelStatus.Reward

	self:SendClientMsg()
end

function CashCow:ResetData()
	local CashCowBoxConfig = server.configCenter.CashCowBoxConfig
	local drawBin = lua_util.CreateArray(#CashCowBoxConfig, ActConfig.LevelStatus.NoReach)

	self.cache.drawBin = drawBin
	self.cache.shake = 0
end

function CashCow:onDayTimer()
	self:ResetData()
	self:SendClientMsg()
end

function CashCow:SendClientMsg()
	local msg = {
		level = self.cache.level,
		exp = self.cache.exp,
		odds = self.cache.odds,
		shake = self.cache.shake,
		drawBin = self.cache.drawBin,
		amplitude = self:CalcAmplitude(),
	}
	server.sendReq(self.player, "sc_cashCow_info", msg)
end

server.playerCenter:SetEvent(CashCow, "cashCow")
return CashCow