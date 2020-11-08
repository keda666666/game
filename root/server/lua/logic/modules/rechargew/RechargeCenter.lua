local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local RechargeCenter = oo.class()

function RechargeCenter:ctor()
end

function RechargeCenter:Init()
	self.rechargeList = {}
end

function RechargeCenter:AddRechargeMod(payType, mod)
	self.rechargeList[payType] = mod
end

function RechargeCenter:GetRecharge(actor, goodsid)
	local payType, gidx = math.floor(goodsid/10000), goodsid%10000
	return self.rechargeList[payType]:GetRecharge(actor, gidx)
end

function RechargeCenter:Recharge(actor, goodsid)
	local payType, gidx = math.floor(goodsid/10000), goodsid%10000
	return self.rechargeList[payType]:Recharge(actor, gidx)
end

server.SetCenter(RechargeCenter, "rechargeCenter")
return RechargeCenter