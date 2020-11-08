local server = require "server"
local DailyActivityConfig = {}


-- 活动类型
DailyActivityConfig.type = {
	Answer = 1,			-- 科举比赛
	Escort = 2,			-- 取经东归
	GuildBoss = 3,		-- 帮派BOSS
	GuildMine = 4,		-- 矿山争夺
	King = 5,			-- 跨服争霸
	GuildWar = 6,		-- 帮会战
	Climb = 7,			-- 九重天
}

return DailyActivityConfig