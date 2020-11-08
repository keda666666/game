local server = require "server"
local DailyTaskConfig = {}

DailyTaskConfig.DailyActivity = {
	ChapterWar = "chapterWar",
	TeamFb = "teamFB",
}

DailyTaskConfig.DailyTaskType = {
	MyBoss = 1,			-- 个人boss
	PublicBoss = 2,		-- 全民boss
	EquipSmelt = 3,		-- 装备熔炼
	Arena = 4,			-- 武林擂台
	MaterialFb = 5,		-- 材料副本
	Escort = 6,			-- 西游护送
	TeamFb = 7,			-- 组队副本
	Login = 8,			-- 每日登录
	Recharge = 9,		-- 每日充值
}

return DailyTaskConfig