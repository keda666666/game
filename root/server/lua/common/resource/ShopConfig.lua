local server = require "server"
local lua_app = require "lua_app"
local ShopConfig = {}

ShopConfig.BuyType = {
	EverLimit = 1,		--永久限购
	Free	= 2,		--不限
	DayLimit = 3,		--每日限购
	Weekly = 4, 		--每周
}

ShopConfig.UnlockType = {
	Level = 1, 	--人物等级
	WildgeeseFb = 2, 	--大雁塔(玲珑宝塔)
	GuildLevel = 3, 	--帮会等级
	ArenaRank = 4, 	--竞技场排名
	EscortCount = 5, 	--护送次数
	AnswerCount = 6, 	--答题次数
	MyBossCount = 7, 	--个人Boss次数
	PublicBossCount = 8, 	--全民Boss次数
	EightyOneHard = 9, 	--八十一难通关等级
	Material = 10, 	--材料副本次数
	TianShen = 11, 	--天神抽奖次数
	LimitTime = 12, --限时商品
}

local _yuanbaoIdToConfig = false
local _bybIdToConfig = false

function ShopConfig:GetYuanBaoItemById(id)
	if not _yuanbaoIdToConfig then
		_yuanbaoIdToConfig = {}
		local YuanBaoStore = server.configCenter.YuanBaoStore
		for _, item in pairs(YuanBaoStore) do
			_yuanbaoIdToConfig[item.id] = item
		end
	end
	return _yuanbaoIdToConfig[id] or {}
end

function ShopConfig:GetBybItemById(id)
	if not _bybIdToConfig then
		_bybIdToConfig = {}
		local BangYuanStore = server.configCenter.BangYuanStore
		for _, item in pairs(BangYuanStore) do
			_bybIdToConfig[item.id] = item
		end
	end
	return _bybIdToConfig[id] or {}
end

function ShopConfig:GetShopConfig(shopType)
	local DuiYingStore = server.configCenter.DuiYingStore[shopType]
	if not DuiYingStore then
		lua_app.log_error(">>GetShopConfig DuiYingStore not exist config. type", shopType)
		return
	end
	return server.configCenter[DuiYingStore.tablename]
end

server.SetCenter(ShopConfig, "shopConfig")
return ShopConfig