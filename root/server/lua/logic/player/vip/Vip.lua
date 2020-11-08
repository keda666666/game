local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ItemConfig = require "resource.ItemConfig"

local Vip = oo.class()

function Vip:ctor(player)
	self.player = player
end

function Vip:onInitClient()
	self:SendVipInfo()
end

function Vip:SetVip(vip)
	self.player.cache.vip = vip
	self:SendVipInfo()
end

function Vip:Update()
	local recharge = self.player.cache.recharge
	local vip = self.player.cache.vip
	local cfg = server.configCenter.VipConfig
	for i = #cfg, 1, -1 do
		if recharge >= cfg[i].needYb then
			local oldlevel = self.player.cache.vip
			if oldlevel ~= i then
				server.playerCenter:onevent(server.event.viplevelup, self.player, oldlevel, i)
			end
			self.player.cache.vip = i
			break
		end
	end
	self:SendVipInfo()
end

function Vip:SendVipInfo()
	local vip = self.player.cache.vip
	local recharge = self.player.cache.recharge
	local vipstate = self.player.cache.vipstate
	local need = 0
	if vip ~= 0 then
		need = server.configCenter.VipConfig[vip].needYb
	end
	local data = {}
	data.lv = vip
	data.exp = recharge
	data.state = vipstate
	data.otherreward = self.player.cache.vipaddedreward
	self.player:sendReq("sc_vip_update_data", data)
end

function Vip:GiveReward(index)
	local viplv = self.player.cache.vip
	local vipstate = self.player.cache.vipstate
	if index > viplv then
		return
	end
	if vipstate&(1<<(index)) ~= 0 then
		return
	end
	vipstate = vipstate | (1<<(index))
	self.player.cache.vipstate = vipstate

	local cfg = server.configCenter.VipConfig[index]
	local dbid = self.player.dbid
	self.player:GiveRewardAsFullMailDefault(table.wcopy(cfg.rewards), "VIP奖励", server.baseConfig.YuanbaoRecordType.Vip)
	self:SendVipInfo()
end

function Vip:GiveOtherReward(lv)
	local vipConfig = server.configCenter.VipConfig
	local openlv = vipConfig[lv].openid
	if openlv then
		local openConfig = server.configCenter.FuncOpenConfig
		if self.player.cache.level < openConfig[openlv].conditionnum then return end
	end
	local rewards = vipConfig[lv].treward
	if not rewards then return end
	if self.player.cache.vip < lv then return end
	if self.player.cache.vipaddedreward & (1<<lv) ~= 0 then return end
	self.player.cache.vipaddedreward = self.player.cache.vipaddedreward | (1<<lv)
	self.player:GiveRewardAsFullMailDefault(table.wcopy(rewards), "VIP额外奖励", server.baseConfig.YuanbaoRecordType.Vip)
	self:SendVipInfo()
end

server.playerCenter:SetEvent(Vip, "vip")
return Vip
