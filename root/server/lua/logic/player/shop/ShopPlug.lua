local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_timer = require "lua_timer"
local WeightData = require "WeightData"
local ItemConfig = require "resource.ItemConfig"
local BaseConfig = require "resource.BaseConfig"
local ShopConfig = require "resource.ShopConfig"
local _UnlockType = ShopConfig.UnlockType


local MysticalShopPool = false
local function _GetMysticalShop(num)
	if not MysticalShopPool then
		MysticalShopPool = WeightData.new()
		local MysticalShop = server.configCenter.MysticalShop
		for __, goodscfg in ipairs(MysticalShop) do
			MysticalShopPool:Add(goodscfg.weight, goodscfg)
		end
	end
	return MysticalShopPool:GetRandomCounts(num)
end

local function _GenerateGoods(goodsid)
	local goodscfg = server.configCenter.MysticalShop[goodsid]
	local goodsdata = {
		id = goodsid,
		buycount = 0,
	}
	return goodsdata
end

local ShopPlug = oo.class()

function ShopPlug:ctor(player)
	self.player = player
end

function ShopPlug:onCreate()
	self:onLoad()
end

function ShopPlug:onLoad()
	self.cache = self.player.cache.shop
	self:Init(self.cache)
end

function ShopPlug:Init(datas)
	local DuiYingStore = server.configCenter.DuiYingStore
	for shopType,_ in pairs(DuiYingStore) do
		datas[shopType] = self:GenShopData(datas[shopType], shopType)
	end
end

local function _GetLimitTime(unlockcfg)
	if unlockcfg[1] == _UnlockType.LimitTime then
		return (lua_app.now() + unlockcfg[2])
	end
	return 0
end

function ShopPlug:GenShopData(datas, shopType)
	local shopCfg = ShopConfig:GetShopConfig(shopType)
	local gendata = datas or {}
	gendata.datas = gendata.datas or {}
	gendata.limittime = gendata.limittime or {}
	for id, cfg in ipairs(shopCfg) do
		gendata.datas[id] = gendata.datas[id] or 0
		gendata.limittime[id] = gendata.limittime[id] or _GetLimitTime(cfg.unlocktype)
	end
	
	gendata.refreshtime = gendata.refreshtime or lua_app.now()
	return gendata
end

function ShopPlug:onInitClient()
	---- 兼容老玩家
	if server.funcOpen:Check(self.player, server.configCenter.MysticalShopBaseConfig.open)
		and #self.cache.mystical.datas <= 0 then
		self:OpenMysticalShop()
	end
	---- 兼容老玩家
	self:SendClient()
	self:SendUnlockData()
	self:SendMysticalClient()
	self:RegisterMysticalRefresh()
end

function ShopPlug:GetStoreDatas()
	local DuiYingStore = server.configCenter.DuiYingStore
	local shopdatas = {}
	for shopType, __ in pairs(DuiYingStore) do
		table.insert(shopdatas, {
				type = shopType,
				datas = self.cache[shopType].datas,
				limittime = self.cache[shopType].limittime,
			})
	end
	return shopdatas
end

function ShopPlug:OpenMysticalShop()
	local mystical = self.cache.mystical
	if mystical.refreshtime < 0 then
		local firstCfg = server.configCenter.MysticalShopBaseConfig.firstrefresh
		for __, goodsid in ipairs(firstCfg) do
			table.insert(mystical.datas, _GenerateGoods(goodsid))
		end
		mystical.refreshtime = lua_app.now() + server.configCenter.MysticalShopBaseConfig.refresh
		self:SendMysticalClient()
		self:RegisterMysticalRefresh()
	end
end

function ShopPlug:SendClient()
	server.sendReq(self.player,"sc_shop_buy_update", { shopdatas = self:GetStoreDatas() })
end

function ShopPlug:SendMysticalClient()
	server.sendReq(self.player,"sc_shop_mystical_update", self.cache.mystical)
end

function ShopPlug:GetBuyShopData(shopType)
	return self.cache[shopType].datas
end

function ShopPlug:RefreshShopByDay()
	local DuiYingStore = server.configCenter.DuiYingStore
	for shopType,__ in pairs(DuiYingStore) do
		self:RefreshBuyCountList(shopType)
	end
	self:SendClient()
end

--刷新类型
local _RefreshType = setmetatable({}, {__index = function() return function() end end})

_RefreshType[ShopConfig.BuyType.DayLimit] = function(datas, index)
	datas[index] = 0
end

_RefreshType[ShopConfig.BuyType.Weekly] = function(datas, index)
	local StoreBaseConfig = server.configCenter.StoreBaseConfig
	local week = lua_app.week()
	if week == StoreBaseConfig.reset[ShopConfig.BuyType.Weekly] then
		datas[index] = 0
	end
end

function ShopPlug:RefreshBuyCountList(shopType)
	local StoreConfig = ShopConfig:GetShopConfig(shopType)
	local shopdatas = self.cache[shopType]
	local buydata = shopdatas.datas
	for id, cfg in pairs(StoreConfig) do
		_RefreshType[cfg.type](buydata, id)
	end
	shopdatas.refreshtime = lua_app.now()
end

local _GetCondtionValue = {}

_GetCondtionValue[_UnlockType.Level] = function(player)
	return player.cache.level
end

_GetCondtionValue[_UnlockType.WildgeeseFb] = function(player)
	return player.cache.wildgeeseFb.layer
end

_GetCondtionValue[_UnlockType.GuildLevel] = function(player)
	local guild = player.guild:GetGuild()
	if not guild then
		return 0
	end
	return guild:GetLevel()
end

_GetCondtionValue[_UnlockType.ArenaRank] = function(player)
	return player.arena.cache.maxrank
end

_GetCondtionValue[_UnlockType.EscortCount] = function(player)
	return player.escort:GetEscortTotalCount()
end

_GetCondtionValue[_UnlockType.AnswerCount] = function(player)
	return player.answer:GetNum()
end

_GetCondtionValue[_UnlockType.MyBossCount] = function(player)
	return player.material:GetMyBossNum()
end

_GetCondtionValue[_UnlockType.PublicBossCount] = function(player)
	return player.publicboss:GetTotalCount()
end

_GetCondtionValue[_UnlockType.EightyOneHard] = function(player)
	return player.eightyOneHard:GetNum()
end

_GetCondtionValue[_UnlockType.Material] = function(player)
	return player.material:GetMaterialNum()
end

_GetCondtionValue[_UnlockType.TianShen] = function(player)
	return player.luckPlug:GetLuckTianshenNum()
end

local _DefaultCheak = function(player, unlocktype, unlockvalue, limittime)
	if 0 < limittime and limittime < lua_app.now() then 
		return false 
	end
	if _GetCondtionValue[unlocktype] then
		return unlockvalue <= _GetCondtionValue[unlocktype](player)
	end
	return true
end

local _UnlockCondition = setmetatable({}, {__index = function() return _DefaultCheak end})
_UnlockCondition[_UnlockType.ArenaRank] = function(player, unlocktype, unlockvalue, limittime)
	if 0 < limittime and limittime < lua_app.now() then 
		return false 
	end
	return _GetCondtionValue[unlocktype](player) <= unlockvalue
end

--更新解锁商品
function ShopPlug:onUpdateUnlock()
	self:SendUnlockData()
end

function ShopPlug:SendUnlockData()
	local datas = {}
	for unlocktype, getter in pairs(_GetCondtionValue) do
		table.insert(datas, {
				type = unlocktype,
				value = getter(self.player)
			})
	end
	server.sendReq(self.player, "sc_shop_buy_unlockdata", {
			records = datas,
		})
end

function ShopPlug:BuyItem(shopType, goodsIndex, buyNum)
	local StoreConfig = ShopConfig:GetShopConfig(shopType)
	local goodsCfg = StoreConfig[goodsIndex]
	if not goodsCfg then
		server.sendErr(self.player, "物品索引错误")
		lua_app.log_info("ShopPlug:BuyItem: actor(", self.player.cache.name ,") error: shop:",ShopConfig:GetItemName(shopType), "index:", goodsIndex)
		return
	end

	local unlocktype, unlockvalue = goodsCfg.unlocktype[1], goodsCfg.unlocktype[2]
	if not _UnlockCondition[unlocktype](self.player, unlocktype, unlockvalue, self:GetLimitTime(shopType, goodsIndex)) then
		lua_app.log_info(">> ShopPlug unlocktype condition not reach.", shopType, goodsIndex, unlocktype, unlockvalue)
		return
	end

	local goodsdata = self:GetBuyShopData(shopType)
	local totoalBuyCount = goodsdata[goodsIndex] + buyNum
	local buyCountMax = goodsCfg.daycount > 0 and goodsCfg.daycount or math.huge
	if  buyCountMax < totoalBuyCount then
		server.sendErr(self.player, "超出购买限制")
		return
	end

	local payreward = lua_util.GetArrayPlus("count")
	for i = 1, buyNum do
		payreward = payreward + goodsCfg.currency
	end
	--支付
	if not self.player:PayRewards(payreward, BaseConfig.YuanbaoRecordType.Shop, string.format("Shop:Shoptype:%d,Itemid:%d", shopType, goodsCfg.id)) then
		lua_app.log_info("ShopPlug:BuyItem pay currency not enough.", shopType, goodsIndex, buyNum)
		return
	end
	goodsdata[goodsIndex] = totoalBuyCount

	local rewards = {
		type = ItemConfig.AwardType.Item,
		id = goodsCfg.id,
		count = goodsCfg.count * buyNum,
	}
	self.player:GiveRewards({rewards}, nil, BaseConfig.YuanbaoRecordType.Shop)
	server.sendReq(self.player,"sc_shop_buy", {
			index = goodsIndex,
			shopType = shopType,
			count = totoalBuyCount,
		})
end

function ShopPlug:GetLimitTime(shoptype, index)
	local shopdata = self.cache[shoptype]
	local limittime = shopdata.limittime[index] > 0 and shopdata.limittime[index] or math.huge
	return limittime
end

function ShopPlug:PayRefreshMysticalShop()
	local MysticalShopBaseConfig = server.configCenter.MysticalShopBaseConfig
	local mystical = self.cache.mystical
	local refreshPass = mystical.refreshcount < MysticalShopBaseConfig.refreshmax
	if not refreshPass then
		lua_app.log_info("refreshcount reach maximum.", mystical.refreshcount)
		return false 
	end 

	local cost = server.configCenter.RefreshPrice[mystical.refreshcount + 1].refreshprice
	if not self.player:PayRewards(cost, server.baseConfig.YuanbaoRecordType.Shop, "ShopPlug:RefreshMysticalShop") then
		lua_app.log_info("wealth not enough.")
		return false
	end

	local MysticalShopBaseConfig = server.configCenter.MysticalShopBaseConfig
	local refreshCfg = _GetMysticalShop(MysticalShopBaseConfig.maxnum)
	local mysticaldatas = {}
	for __, cfg in ipairs(refreshCfg) do
		table.insert(mysticaldatas, _GenerateGoods(cfg.index))
	end
	mystical.datas = mysticaldatas
	mystical.refreshcount = mystical.refreshcount + 1
	self:SendMysticalClient()
end

function ShopPlug:RefreshMysticalShop()
	local mystical = self.cache.mystical
	if mystical.refreshtime < 0 then return end

	local MysticalShopBaseConfig = server.configCenter.MysticalShopBaseConfig
	local refreshCfg = _GetMysticalShop(MysticalShopBaseConfig.maxnum)
	local mysticaldatas = {}
	for __, cfg in ipairs(refreshCfg) do
		table.insert(mysticaldatas, _GenerateGoods(cfg.index))
	end

	mystical.datas = mysticaldatas
	mystical.refreshtime = lua_app.now() + MysticalShopBaseConfig.refresh

	self:SendMysticalClient()
	self:RegisterMysticalRefresh()
end

function ShopPlug:RegisterMysticalRefresh()
	local refreshdata = {
		controlfunc = "RefreshMysticalShop",
		dispatchfunc = "RefreshMysticalShop",
		refreshtime = self.cache.mystical.refreshtime,
	}
	server.shopCenter:RegisterDispatch(self.player.dbid, refreshdata)
end

function ShopPlug:BuyMysticalGoods(index, count)
	local goodsdata = self:GetMysticalGoods(index)
	if not goodsdata then
		lua_app.log_info("goods index not exist.")
		return false
	end

	local goodsCfg = server.configCenter.MysticalShop[goodsdata.id]
	local buyCountTotal = goodsdata.buycount + count
	local buyCountMax = goodsCfg.daycount == 0 and math.huge or goodsCfg.daycount
	if buyCountMax < buyCountTotal then
		lua_app.log_info("mystical buy count reach maximum.", buyCountMax, buyCountTotal)
		return false
	end

	local currency = table.wcopy(goodsCfg.currency)
	currency.count = currency.count * count
	local cost = {currency}
	if not self.player:PayRewards(cost, server.baseConfig.YuanbaoRecordType.Shop, "ShopPlug:BuyMysticalGoods")then
		lua_app.log_info("wealth not enough.")
		return false
	end

	local rewards = table.GetTbPlus("count")
	local itemreward = {type = ItemConfig.AwardType.Item, id = goodsCfg.id, count = goodsCfg.count}
	for i = 1, count do
		rewards = rewards + itemreward + goodsCfg.score
	end

	self.player:GiveRewardAsFullMailDefault(rewards, "神秘商店", server.baseConfig.YuanbaoRecordType.Shop)

	goodsdata.buycount = buyCountTotal
	self:SendMysticalClient()
	lua_app.log_info("BuyMysticalGoods-----------------", index, count)
end

function ShopPlug:GetMysticalGoods(index)
	local mystical = self.cache.mystical
	local goodsdata = table.matchValue(mystical.datas, function(data)
		return data.id == index and 0 or -1
	end)
	return goodsdata
end

function ShopPlug:onLevelUp()
	if server.funcOpen:Check(self.player, server.configCenter.MysticalShopBaseConfig.open) then
		self:OpenMysticalShop()
	end
end

function ShopPlug:Release()
end

function ShopPlug:onDayTimer()
	self:RefreshShopByDay()
	self.cache.mystical.refreshcount = 0
	self:SendMysticalClient()
end

function ShopPlug:Test()
	table.ptable(self.cache.mystical, 3)
end

server.playerCenter:SetEvent(ShopPlug, "shop")
return ShopPlug