local server = require "server"

local GuildConfig = {}

GuildConfig.Office = {
	Common = 0,			-- 普通成员
	AssistLeader = 1,	-- 副帮主
	Leader = 2,			-- 会长
}

GuildConfig.RecordType = {
	Join			= 1,		-- time + "  [" + name1 + "]加入工会";
	Quit			= 2,		-- time + "  [" + name1 + "]离开工会";
	ForceQuit		= 3,		-- time + "  [" + name1 + "]踢出公会";
	AssistLeader	= 4,		-- time + "  [" + name1 + "]被任命副会长";
	Leader			= 5,		-- time + "  [" + name1 + "]成为新的会长";
}

GuildConfig.Task = {
	GuildMonster	= 1001,		--帮会小妖
	GuildGather		= 1002,		--帮会采集
	BuyOrange		= 1003,		--橙色购买
	BuyPurple		= 1004,		--紫色购买
	BuyBlue			= 1005,		--蓝色购买
	BuyGreen		= 1006,		--绿色购买
	GuildPeach 		= 1007,		--帮会蟠桃
	GuildFuBen 		= 1008,		--帮会副本
}

--帮派地图任务数据字段
GuildConfig.MapDataname = {
	[GuildConfig.Task.GuildMonster] = "monsterTask",
	[GuildConfig.Task.GuildGather] = "gatherTask",
}

local _noticeChatFunc = {}
_noticeChatFunc[GuildConfig.RecordType.Join] = function(data)
	local GuildConfig = server.configCenter.GuildConfig
	return string.format("|C:0x16b2ff&T:%s|%s", data.name1, GuildConfig.notice1)
end
_noticeChatFunc[GuildConfig.RecordType.AssistLeader] = function(data)
	local GuildConfig = server.configCenter.GuildConfig
	return string.format("|C:0x16b2ff&T:%s|%s", data.name1, GuildConfig.notice3)
end
_noticeChatFunc[GuildConfig.RecordType.Leader] = function(data)
	local GuildConfig = server.configCenter.GuildConfig
	return string.format("|C:0x16b2ff&T:%s|%s", data.name1, GuildConfig.notice5)
end

function GuildConfig.GetNoticeStr(data)
	if not _noticeChatFunc[data.type] then return end
	return _noticeChatFunc[data.type](data)
end

return GuildConfig