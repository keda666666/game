local server = require "server"
local TaskConfig = {}

TaskConfig.TaskType = {
	Main = 1,	-- 主线
}

TaskConfig.TaskStatus = {
	Received = 1,		-- 已接
	Completed = 2,		-- 已完成
}

TaskConfig.ConditionType = {
	EquipWearCount = 10010,		-- 穿戴装备 穿戴N件任意装备
	EquipWearAssign = 10011,	-- 穿戴装备 穿戴一件指定装备

	EquipSmelt = 10020,			-- 装备熔炼

	EquipEnhanceAll = 10030,	-- 装备强化 装备强化总等级达N级
	EquipEnhanceAcc = 10031,	-- 装备强化

	EquipRefineAll = 10040,		-- 装备精炼 装备精炼总等级达N级
	EquipRefineAcc = 10041,		-- 装备精炼 装备精炼N次

	EquipAnnealAll = 10050,		-- 装备锻炼 装备锻炼总等级达N级
	EquipAnnealAcc = 10051,		-- 装备锻炼 装备锻炼N次

	EquipGemAll = 10060,		-- 装备宝石 装备宝石总等级达N级
	EquipGemAcc = 10061,		-- 装备宝石 升级宝石N次

	SkillUpgrade = 20010,		-- 技能升级 角色所有技能总等级达N级

	ChapterClear = 30010,		-- 关卡通关
	ChapterGoto = 30020,		-- 到达指定地图

	PetActive = 40010,			-- 激活宠物 激活指定宠物
	PetUpgrade = 40020,			-- 升级宠物

	XianlvActive = 40110,		-- 激活仙侣 激活指定仙侣
	XianlvUpgrade = 40120,		-- 升级仙侣

	RideUpgrade = 50010,		-- 坐骑进阶
	FairyUpgrade = 50020,		-- 天仙进阶

	TeamFb = 60010,				-- 挑战组队副本
	MyBoss = 60020,				-- 挑战个人boss
	PublicBoss = 60030,			-- 挑战全民boss
	Arena = 60040,				-- 挑战竞技场
	MaterialFb = 60050,			-- 挑战材料副本
	Treasuremap = 60060,		-- 藏宝图
	HeavenFb = 60070,			-- 勇闯天庭
	WildgeeseFb = 60080,		-- 大雁塔
	WildgeeseFbLayer = 60081,	-- 大雁塔层数
	DailyTaskMonster = 60090,	-- 师门任务

	ChatWorld = 70010,			-- 世界说话
	RoleLevelup = 70020,		-- 角色升级
	AutoPK = 70030,				-- 开启自动挑战
	HookKill = 70040,			-- 挂机遇怪N次
	DayLogin = 70050,			-- 每天登陆

}

server.SetCenter(TaskConfig, "taskConfig")
return TaskConfig