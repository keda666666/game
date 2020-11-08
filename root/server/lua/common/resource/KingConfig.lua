local server = require "server"
local KingConfig = {}

-- 阵营
KingConfig.camp = {
	Human = 1,		--人
	God = 2,		--仙
	Devil = 3,		--魔
}

KingConfig.status = {
	Ready = 1,		--准备
	Act = 2,		--自由行动
	Dead = 3,		--死亡
	Guard = 4,		--守城
}

KingConfig.campname = {
	[KingConfig.camp.Human] = "人族",
	[KingConfig.camp.God]   = "仙族",
	[KingConfig.camp.Devil] = "魔族",
}

server.SetCenter(KingConfig, "kingConfig")
return KingConfig