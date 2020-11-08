local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "common.resource.ItemConfig"
local _OWN = 1 -- 自用
local _AUC = 2 -- 拍卖

local AuctionPlug = oo.class()

function AuctionPlug:ctor(player)
	self.player = player
end

function AuctionPlug:onCreate()
	self:onLoad()
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	self.cache.aucratioAct = AuctionBaseConfig.everydayvalue
end

function AuctionPlug:onLoad()
	self.cache = self.player.cache.auction
end

function AuctionPlug:onInitClient()
end

function AuctionPlug:onLogout(player)
end

function AuctionPlug:onLogin(player)
end

function AuctionPlug:SendList(auctype, flag)
	if auctype > 0 then
		local guildid = self.player.cache.guildid or 0
		if guildid == 0 then
			server.sendErr(player, "您没有帮会")
		else
			server.serverCenter:SendLocalMod("world", "auctionCenter", "SendList", 
				self.player.dbid, self.cache.aucratio, self.cache.aucratioAct, self.cache.lockratio, guildid, flag)
		end
	else
		server.serverCenter:SendDtbMod("world", "auctionCenter", "SendList", 
			self.player.dbid, self.cache.aucratio, self.cache.aucratioAct, self.cache.lockratio, 0, flag)
	end
end

function AuctionPlug:onDayTimer()
end

function AuctionPlug:onRecharge(yuanbao)
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	self:AddRatio(yuanbao * AuctionBaseConfig.goldratio)
end

function AuctionPlug:onAddActive(active)
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	self:AddRatioAc(active * AuctionBaseConfig.activeratio)
end

function AuctionPlug:AddRatio(count)
	self.cache.aucratio = self.cache.aucratio + count
	self:SendRatio()
end

function AuctionPlug:AddRatioAc(count)
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	self.cache.aucratioAct = math.min(self.cache.aucratioAct + count, AuctionBaseConfig.maxvalue)
	self:SendRatio()
end

function AuctionPlug:AllRatio()
	return (self.cache.aucratio + self.cache.aucratioAct - self.cache.lockratio)
end

function AuctionPlug:GetRatioData()
	return {
		aucratio = self.cache.aucratio,
		aucratioAct = self.cache.aucratioAct,
		lockratio = self.cache.lockratio,
	}
end

function AuctionPlug:DelRatio(count)
	if self.cache.aucratioAct >= count then
		self.cache.aucratioAct = self.cache.aucratioAct - count
	else
		self.cache.aucratioAct = 0
		local newcount = count - self.cache.aucratioAct
		if self.cache.aucratio >= newcount then
			self.cache.aucratio = self.cache.aucratio - newcount
		else
			self.cache.aucratio = 0
		end
	end
	self:SendRatio()
end

function AuctionPlug:LockRatio(count)
	self.cache.lockratio = self.cache.lockratio + count
	self:SendRatio()
end

function AuctionPlug:FreeRatio(count)
	self.cache.lockratio = math.max(self.cache.lockratio - count, 0)
	self:SendRatio()
end

function AuctionPlug:OpenItem(rewards)
	self.rewards = rewards
	self.player:sendReq("sc_auction_select", {rewards = rewards})
end

function AuctionPlug:Select(choose)
	if not self.rewards then
		return
	end
	if choose == _OWN then
		self.player:GiveRewardAsFullMailDefault(table.wcopy(self.rewards), "拍卖盒子", server.baseConfig.YuanbaoRecordType.Auction)
		self.rewards = nil
	elseif choose == _AUC then
		local _, reward = next(self.rewards)
		if not reward then return end
		local guildid = self.player.cache.guildid or 0
		local ret = false
		if guildid > 0 then
			ret = server.auctionMgr:ShelfLocal(self.player.dbid, reward.id, reward.count, guildid)
		else
			ret = server.auctionMgr:ShelfGlobal(self.player.dbid, reward.id, reward.count, guildid)
		end
		if ret then
			self.rewards = nil
		end
	end
end


function AuctionPlug:QueryShelf(id)
	local auctionCfg = server.configCenter.AuctionListConfig[id]
	local msg = {}
	if auctionCfg then
		msg = {
			numerictype = auctionCfg.price.id,
			dealprice = auctionCfg.price.count,
			addprice = auctionCfg.addprice.count,
			price = auctionCfg.startprice.count,
		}
	end
	return msg 
end

-- 出价竞拍
function AuctionPlug:Offer(id, guildid)
	if guildid > 0 then
		server.serverCenter:SendLocalMod("world", "auctionCenter", "Offer", self.player.dbid, id, guildid)
	else
		server.serverCenter:SendDtbMod("world", "auctionCenter", "Offer", self.player.dbid, id, guildid)
	end
end

-- 一口价买走
function AuctionPlug:Buy(id, guildid)
	if guildid > 0 then
		server.serverCenter:SendLocalMod("world", "auctionCenter", "Buy", self.player.dbid, id, guildid)
	else
		server.serverCenter:SendDtbMod("world", "auctionCenter", "Buy", self.player.dbid, id, guildid)
	end
end

function AuctionPlug:UpdateOne(id, guildid)
	if guildid > 0 then
		server.serverCenter:SendLocalMod("world", "auctionCenter", "SendUpdateByID", self.player.dbid, guildid, id)
	else
		server.serverCenter:SendDtbMod("world", "auctionCenter", "SendUpdateByID", self.player.dbid, guildid, id)
	end
end

function AuctionPlug:SendRatio()
	self.player:sendReq("sc_ratio_change", {
			ratio = self.cache.aucratio,
			ratioAct = self.cache.aucratioAct,
			lockratio = self.cache.lockratio,
		})
end

server.playerCenter:SetEvent(AuctionPlug, "auctionPlug")
return AuctionPlug