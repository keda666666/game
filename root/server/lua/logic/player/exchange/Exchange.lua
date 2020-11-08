local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"
local ItemConfig = require "resource.ItemConfig"

local Exchange = oo.class()

function Exchange:ctor(player)
	self.player = player
end

function Exchange:onCreate()
	self:onLoad()
end

function Exchange:onLoad()
	self.cache = self.player.cache.exchange_data
	if not self.cache.exchangeGoleCount then
		self.cache.exchangeGoleCount = 0
	end
end

function Exchange:onInitClient()
end

function Exchange:ExchangeGold()
	local ChaptersCommonConfig = server.configCenter.ChaptersCommonConfig
	local cost = {
		type = ItemConfig.AwardType.Item,
		id = ChaptersCommonConfig.itemid,
		count = 1,
	}
	if not self:CheckExchange() then
		lua_app.log_info("ExchangeGold reach the upper limit.")
		return
	end
	local costyuanbao = {
		type = ItemConfig.AwardType.Numeric,
		id = ItemConfig.NumericType.YuanBao,
		count = ChaptersCommonConfig.gold,
	}
	local yuanbaoPay = false
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.Exchange) then
		yuanbaoPay = true
	end

	if yuanbaoPay and not self.player:PayRewards({costyuanbao}, server.baseConfig.YuanbaoRecordType.Exchange, "Exchange:exchange") then
		lua_app.log_info("ExchangeGold pay failed. cost detail:", cost.type, cost.id, cost.count)
		return false
	end
	
	local goldnum = self:GetExchangeGoldnum()
	self.cache.exchangeGoleCount = self.cache.exchangeGoleCount + 1
	self.player:GiveReward(ItemConfig.AwardType.Numeric, ItemConfig.NumericType.Gold, goldnum, nil, server.baseConfig.YuanbaoRecordType.Exchange)
	return true
end

function Exchange:CheckExchange()
	local VipPrivilegeConfig = server.configCenter.VipPrivilegeConfig
	local vipLv = self.player.cache.vip
	local silvertime = VipPrivilegeConfig[vipLv].silvertime
	local exchangeCount = self.cache.exchangeGoleCount
	if exchangeCount < silvertime then
		return true
	end
	return false
end

function Exchange:GetExchangeGoldCount()
	return self.cache.exchangeGoleCount
end

function Exchange:GetExchangeGoldnum()
	local ChaptersConfig = server.configCenter.ChaptersConfig
	local ChaptersCommonConfig = server.configCenter.ChaptersCommonConfig
	local chapterLevel = self.player.cache.chapter.chapterlevel
	local goldEff = ChaptersConfig[chapterLevel + 1] and ChaptersConfig[chapterLevel + 1].goldEff or ChaptersConfig[chapterLevel].goldEff
	local rewardGold = goldEff * ChaptersCommonConfig.rat * ChaptersCommonConfig.time
	return rewardGold
end

function Exchange:onLogout()
end

function Exchange:Release()
end

function Exchange:onDayTimer()
	self.cache.exchangeGoleCount = 0
end
server.playerCenter:SetEvent(Exchange, "exchange")
return Exchange