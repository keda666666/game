local oo = require "class"
local server = require "server"
local lua_util = require "lua_util"
local lua_app = require "lua_app"

local SignIn = oo.class()

local _SignConf = {
	Daily = 1,
	Vip = 2,
	Recharge = 3,
	AccSignIn = 4,
}

function SignIn:ctor(player)
	self.player = player
end

function SignIn:onCreate()
	self:onLoad()
end

function SignIn:onLoad()
	self.cache = self.player.cache.welfare_data.signin
	self:InitData(self.cache)
end

function SignIn:InitData(datas)
	datas.rewardMark = datas.rewardMark or 0
end

function SignIn:onInitClient()
	self:SetDailyRewardId()
	self:SendClientMsg()
end

local _GetRewardByType = {}
--每日奖励
_GetRewardByType[_SignConf.Daily] = function(self, SignInConfig)
	local mark = self.cache.rewardMark
	if lua_util.bit_status(mark, _SignConf.Daily) then
		lua_app.log_info(">>SignIn:GetReward the award has been received. ")
		return false
	end
	local rewards = SignInConfig.dailyreward
	self.player:GiveRewardAsFullMailDefault(rewards, "每日签到", server.baseConfig.YuanbaoRecordType.SignIn)
	self.cache.rewardMark = lua_util.bit_open(mark, _SignConf.Daily)
	self:SendClientMsg()
	return true
end

--Vip奖励
_GetRewardByType[_SignConf.Vip] = function(self, SignInConfig)
	local mark = self.cache.rewardMark
	if lua_util.bit_status(mark, _SignConf.Vip) then
		lua_app.log_info(">>SignIn:GetReward the award has been received. ")
		return false
	end
	local WelfareBaseConfig = server.configCenter.WelfareBaseConfig
	local viplv = self.player.cache.vip
	if viplv < WelfareBaseConfig.viplv then
		lua_app.log_info(">>SignIn:GetReward vip level not enough", viplv, WelfareBaseConfig.viplv)
		return false
	end
	local rewards = SignInConfig.vipreward
	self.player:GiveRewardAsFullMailDefault(rewards, "每日签到", server.baseConfig.YuanbaoRecordType.SignIn)
	self.cache.rewardMark = lua_util.bit_open(mark, _SignConf.Vip)
	self:SendClientMsg()
	return true
end

--每日充值奖励
_GetRewardByType[_SignConf.Recharge] = function(self, SignInConfig)
	local mark = self.cache.rewardMark
	if lua_util.bit_status(mark, _SignConf.Recharge) then
		lua_app.log_info(">>SignIn:GetReward the award has been received. ")
		return false
	end
	local recharge = self.player.recharge
	if not recharge:GetDailyRechargeStatus() then
		lua_app.log_info(">>SignIn:GetReward daily recharge unfinished.")
		return false
	end
	--首充判断 缺少接口
	local rewards = SignInConfig.rechargereward
	self.player:GiveRewardAsFullMailDefault(rewards, "每日签到", server.baseConfig.YuanbaoRecordType.SignIn)
	self.cache.rewardMark = lua_util.bit_open(mark, _SignConf.Recharge)
	self:SendClientMsg()
	return true
end

--累计签到奖励
_GetRewardByType[_SignConf.AccSignIn] = function(self)
	local mark = self.cache.rewardMark
	if lua_util.bit_status(mark, _SignConf.AccSignIn) then
		lua_app.log_info(">>SignIn:GetReward the award has been received. ")
		return false
	end
	local AccSignInConfig = server.configCenter.AccSignInConfig
	local rewardid = math.min(#AccSignInConfig, self.player.cache.totalloginday)

	local rewards = AccSignInConfig[rewardid].reward
	self.player:GiveRewardAsFullMailDefault(rewards, "累计签到奖励", server.baseConfig.YuanbaoRecordType.SignIn)
	self.cache.rewardMark = lua_util.bit_open(mark, _SignConf.AccSignIn)
	self:SendClientMsg()
	return true
end

function SignIn:GetReward(rewardType)
	local SignInConfig = server.configCenter.SignInConfig[self.dailyId]
	return _GetRewardByType[rewardType](self, SignInConfig)
end

--设置每日奖励id
function SignIn:SetDailyRewardId()
	local SignInConfig = server.configCenter.SignInConfig
	local maxCount = #SignInConfig
	local day = server.serverRunDay
	self.dailyId = (day - 1) % maxCount + 1
end

function SignIn:SendClientMsg()
	local msg = {
		dailyId = self.dailyId,
		rewardMark = self.cache.rewardMark,
		totalDay = self.player.cache.totalloginday,
	}
	server.sendReq(self.player, "sc_welfare_signin_info", msg)
end

function SignIn:onDayTimer()
	self:SetDailyRewardId()
	self.cache.rewardMark = 0
	self:SendClientMsg()
end

server.playerCenter:SetEvent(SignIn, "signIn")
return SignIn