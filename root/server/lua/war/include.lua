local oo = require "class"

-- 本文件用于辅助热更使用
-- 针对对象类lua文件

local modules =
{
	"lua_util",

	"modules.Event",
	"modules.BaseCenter",
	"modules.DropMgr",
	"modules.TeamCenter",
	"modules.Timer",
	"config.config",

	"mysql.MysqlCenter",
	"mysql.config",
	"mysql.update",
	"mysql.MysqlBlob",

	"svrmgr.ServerConfig",
	"svrmgr.ServerMgr",

	"resource.EntityConfig",
	"resource.RaidConfig",
	"resource.MapConfig",
	"resource.FightConfig",
	"resource.BaseConfig",
	"resource.KingConfig",
	"resource.RaidCheck",
	"resource.TaskConfig",
	"resource.GuildwarConfig",
	"resource.ChatConfig",
	"resource.ItemConfig",

	"raid.RaidMgr",

	"warReport.WarReport",
	"fight.skill.BuffArgs",
	"fight.skill.Buff",
	"fight.skill.Action",
	"fight.skill.SkillArgs",
	"fight.skill.Skill",
	"fight.entity.SkillPlug",
	"fight.entity.Entity",
	"fight.AttackSort",
	"fight.Target",
	"fight.Fight",
	"fight.FightCenter",
	"activity.OrangePetFb",
	"chapter.ChapterBoss",
	"material.Material",
	"treasureMap.TreasureMap",
	"wildgeeseFb.WildgeeseFb",
	"heavenFb.HeavenFb",
	"crossTeam.CrossTeam",
	"eightyOneHard.EightyOneHard",
	"king.KingCenter",
	"king.KingCityFb",
	"king.KingPK",
	"king.KingCamp",
	"king.KingCity",
	"king.KingMap",
	"mine.Mine",
	"mine.Mountain",
	"mine.GuildMinewayCenter",
	"climb.ClimbCenter",
	"climb.ClimbMap",
	"climb.ClimbLayer",
	"climb.ClimbPK",
	"kingArena.KingArenaCenter",
	"kingArena.KingArena",

	"boss.FieldBoss",
	"boss.PublicBoss",
	"boss.VIPBoss",
	"boss.ContestBossBase",
	"boss.GuildBoss",
	"kfboss.KfBoss",

	"guild.GuildSprite",
	"guild.GuildFb",
	"guild.GuildMineFb",
	"guildwar.GuildwarCenter",
	"guildwar.GuildwarMap",
	"guildwar.GuildwarPlayerCtrl",
	"guildwar.GuildwarFb",
	"guildwar.GuildwarPk",
	"guildwar.BaseBarrier",
	"guildwar.SouthDoor",
	"guildwar.SkyHallOut",
	"guildwar.SkyHallInside",
	"guildwar.DragonHall",
	"guildwar.GuildwarNotice",


	"escort.Escort",

	"arena.Arena",

	"map.MapCenter",
	"map.Map",
	"map.MaincityCenter",

	"modules.QualifyingCenter",

	"qualifying.Qualifying",

	"dailyTaskmonster.DailyTaskmonster",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
