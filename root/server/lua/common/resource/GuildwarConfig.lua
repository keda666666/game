local server = require "server"

local GuildwarConfig = {}

--关卡
GuildwarConfig.Barrier = {
	SouthDoor = 0,			--南天门
	SkyHallOut = 1,			--凌霄殿外
	SkyHallInside = 2,		--凌霄殿
	DragonHall = 3,			--龙殿
}

--注册功能key 1 表示类型 2表示名字
-- 3bit 1bit = addkey(1), 2bit = synckey(2), 3bit = rankkey(4)
GuildwarConfig.Datakeys = {
	--[[全局数据--]]
	global = {
		keys = {
			{"score", 7}, {"scoreRank", 0}, {"kill", 7}, {"killRank", 0}, {"rewardMark", 0}, {"reborntime", 0}, {"enternumber", 1}, {"multikill", 1}, {"terminator", 0}, {"online", 0},
		},
		PlayerEvent = {
			onUpdatePlayer = {"score", "rewardMark", "reborntime", "online"},
			onMultikill = {"multikill"},
		},
		GuildEvent = {
			onUpdateGuild = {"enternumber"},
		},
	},
	--[[南天门--]]
	[GuildwarConfig.Barrier.SouthDoor] = {
		keys = {
			{"southdoor_injure", 7}, {"southdoor_injureRank", 0}, {"southdoor_attacktime", 0}
		},
		PlayerEvent = {
			onUpdatePlayer = {"southdoor_attacktime"},
		},
		GuildEvent = {
			onUpdateGuild = {"southdoor_injure"},
			onGuildRank = {"southdoor_injureRank"},
		},
	},
	--[[凌霄殿外--]]
	[GuildwarConfig.Barrier.SkyHallOut] = {
		keys = {
			{"skyhallout_through", 1}, {"skyhallout_staytime", 1}, {1001, 0}, {1002, 0}, {1003, 0}, {1004, 0}
		},
		PlayerEvent = {
			onUpdatePlayer = {"score", 1001, 1002, 1003, 1004},
			onStayEvent = {"skyhallout_staytime"}
		},
		GuildEvent = {
			onUpdateGuild = {"skyhallout_through", "score"},
			onGuildRank = {"scoreRank", "skyhallout_through"},
		},
	},
	--[[凌霄殿中--]]
	[GuildwarConfig.Barrier.SkyHallInside] = {
		keys = {
			{"skyhallinside_injure", 7}, {"skyhallinside_injureRank", 0},
		},
		PlayerEvent = {
			onUpdatePlayer = {"skyhallinside_injure"},
			onPlayerRank = {"skyhallinside_injureRank"},
		},
		GuildEvent = {
			onUpdateGuild = {"skyhallinside_injure"},
			onGuildRank = {"skyhallinside_injureRank"},
		},
	},
	--[[神龙殿--]]
	[GuildwarConfig.Barrier.DragonHall] = {
		keys = {

		},
		PlayerEvent = {
			onUpdatePlayer = {"kill"},
			onPlayerRank = {"killRank"},
		},
		GuildEvent = {
			onUpdateGuild = {"score"},
			onGuildRank = {"scoreRank"},
		},
	},
}

server.SetCenter(GuildwarConfig, "guildwarConfig")
return GuildwarConfig