local oo = require "class"
local server = require "server"
local lua_util = require "lua_util"
local lua_app = require "lua_app"

local LoginGift = oo.class()

function LoginGift:ctor(player)
	self.player = player
end

function LoginGift:onCreate()
	self:onLoad()
end

function LoginGift:onLoad()
	self.cache = self.player.cache.welfare_data.logingift
end

function LoginGift:onInitClient()
	self:SendLoginMsg()
end

function LoginGift:CheckReceiveReward(indexDay)
	if lua_util.bit_status(self.cache.receivemark, indexDay) then
		lua_app.log_info("LoginGift:reward is received.")
		return false
	end
	if self.player.cache.totalloginday < indexDay then
		lua_app.log_info("LoginGift:totalloginday not enough.", self.player.cache.totalloginday, indexDay)
		return false
	end
	return true
end

function LoginGift:GetReward(indexDay)
	if not self:CheckReceiveReward(indexDay) then
		return
	end
	local LoginRewardConfig = assert(server.configCenter.LoginRewardConfig[indexDay], string.format("LoginRewardConfig not exist index:%d", indexDay))
	self.player:GiveRewardAsFullMailDefault(LoginRewardConfig.reward, "登入福利", server.baseConfig.YuanbaoRecordType.LoginGift)
	self.cache.receivemark = lua_util.bit_open(self.cache.receivemark, indexDay)
	self:SendLoginMsg()
end

function LoginGift:SendLoginMsg()
	server.sendReq(self.player, "sc_welfare_login_gift_info", {
			totalLoginday = self.player.cache.totalloginday,
			receivemark = self.cache.receivemark,
		})
end

function LoginGift:onDayTimer()
	self:SendLoginMsg()
end

server.playerCenter:SetEvent(LoginGift, "loginGift")
return LoginGift