local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
-- local config = require "logic.dbbase.config"
-- 单人推送天降好礼
local RechargeHolyShit = oo.class()

function RechargeHolyShit:ctor(heavenGifts, payType)
	self.heavenGifts = heavenGifts
	self.payType = payType
end

function RechargeHolyShit:Init()
end

function RechargeHolyShit:GetRecharge(player, gindex)
	return self.heavenGifts:GetRecharge(player, gindex, self)
end

function RechargeHolyShit:Recharge(player, gindex)
	return self.heavenGifts:Recharge(player, gindex, self)
end

function RechargeHolyShit:GetBlob(player)
	return player.cache.recharge_holyshit
end

function RechargeHolyShit:AddConfig(cfg, player)
	self.heavenGifts:AddOne(cfg, player, self)
end

function RechargeHolyShit:CloseConfig(gid, player)
	self.heavenGifts:CloseOne(gid, player, self)
end

return RechargeHolyShit