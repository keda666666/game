local server = require "server"
local RaidConfig = {}

RaidConfig.type = {
	ChapterBoss		= 1,	--关卡boss
	MyBoss			= 2,	--个人boss
	PublicBoss		= 3,	--全民boss
	FieldBoss		= 4,	--野外boss
	EightyOneHard 	= 5,	--生死劫
	Material		= 6,	--材料副本
	TreasureMap		= 7,	--藏宝图
	WildgeeseFb		= 8,	--大雁塔(玲珑宝塔)
	HeavenFb		= 9,	--勇闯天庭
	Arena			= 10,	--竞技场
	CrossTeamFb		= 11,	--跨服组队
	GuildSprite		= 12,	--帮会精灵
	GuildFb			= 13,	--帮会副本
	Escort			= 14,	--护送
	GuildBoss		= 15,	--帮会boss
	VIPBoss			= 16,	--至尊boss 付费boss
	KingCity		= 17,	--跨服争霸攻城
	KingPK			= 18,	--跨服争霸自由pk
	GuildMine		= 19,	--帮会矿山争夺
	KFBoss			= 20,	--跨服Boss
	Guildwar		= 21,	--帮会战
	GuildwarPk		= 22,	--帮会战Pk
	ClimbPK			= 25,	--九重天
	Qualifying		= 26,	--仙道会
	DailyTaskMonster= 27,	--师门任务
	GuildMap 		= 29, 	--帮会地图
	MainCity 		= 30, 	--主城地图
	OrangePetFb 	= 31, 	--橙宠副本
	KingArena 	 	= 32, 	--王者争霸
}

RaidConfig.PublicBoss = {
	KillRecord = 5,
	KillMaxRecord = 50,
	AttackRecord = 5,
	AttackMaxRecord = 50,
}


server.SetCenter(RaidConfig, "raidConfig")
return RaidConfig