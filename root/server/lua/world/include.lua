local oo = require "class"

-- 本文件用于辅助热更使用
-- 针对对象类lua文件

local modules =
{
	"lua_util",

	"modules.Event",
	"modules.BaseCenter",
	"modules.DropMgr",
	"modules.Timer",
	"config.config",

	"mysql.MysqlCenter",
	"mysql.config",
	"mysql.update",
	"mysql.MysqlBlob",

	"svrmgr.ServerConfig",
	"svrmgr.ServerMgr",

	"resource.BaseConfig",
	"resource.RankConfig",
	"resource.ActivityConfig",
	"resource.GenActivity",
	"resource.ItemConfig",

	"rank.RankCenter",

	"auction.AuctionCenter",

	"activity.ActivityBase",
	"activity.ActivityMgr",
	"activity.ActivityBaseType",
	"activity.ActivityUpgrade",
	"activity.ActivityWeekLogin",
	"activity.ActivityDayLogin",
	"activity.ActivitySingleRecharge",
	"activity.RechargeContinue",
	"activity.ActivityArenaTarget",
	"activity.ActivityDayRecharge",
	"activity.PackageDiscount",
	"activity.ActivityDiscountShop",
	"activity.ActivityRechargeGroupon",
	"activity.ActivityPowerTarget",
	"activity.ActivityOrangePetTarget",
	"activity.ActivityCashGift",
	"activity.ActivityOadvance",
	"activity.ActivityInvest",
	"activity.ActivityGrowFund",
	"activity.ActivitySpendGift",
	"activity.SpendWheel",
	"activity.DailyRecharge",
	"activity.ActivityRechargeTotal",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
