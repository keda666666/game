local oo = require "class"

-- 本文件用于辅助热更使用
-- 针对对象类lua文件

local modules =
{
	"lua_util",

	"modules.Event",
	"modules.BaseCenter",
	"modules.DropMgr",
	"config.config",

	"mysql.MysqlCenter",
	"mysql.config",
	"mysql.update",
	"mysql.MysqlBlob",

	"sproto.SprotoMgr",
	"config.name",

	"resource.BaseConfig",
	"resource.EntityConfig",
	"resource.ItemConfig",
	"resource.RaidConfig",
	"resource.RankConfig",
	"resource.ShopConfig",
	"resource.GuildConfig",
	"resource.TaskConfig",
	"resource.DailyTaskConfig",
	"resource.DailyActivityConfig",
	"resource.ChatConfig",
	"resource.GuildwarConfig",
	"resource.RaidCheck",
	"resource.ActivityConfig",

	"svrmgr.ServerConfig",
	"svrmgr.ServerMgr",
	"svrmgr.CenterMgr",
	"svrmgr.PlatMgr",
	"svrmgr.DataPack",
	"svrmgr.RaidMgr",
	"svrmgr.RankMgr",
	"svrmgr.FightMgr",
	"svrmgr.TeamMgr",
	"svrmgr.MapMgr",
	"svrmgr.MaincityMgr",
	"svrmgr.PlatMgr",
	"svrmgr.RecordMgr",

	"modules.time.Timer",

	"client.ClientMsg",
	"client.Login",
	"client.LoginCheck",
	"client.LoginerMgr",

	"modules.BaseRecord",
	"modules.LogicEntity",

	"player.template.Template",

	"player.Player",
	"player.PlayerMgr",
	"player.gm.GM",

	"player.item.GivePlayerNumeric",
	"player.item.PayPlayerNumeric",
	"player.item.CheckPlayerNumeric",
	"player.item.Item",
	"player.item.Bag",

	"player.mail.Mail",
	"player.mail.MailPlug",

	"player.role.Role",
	"player.role.skill.Skill",
	"player.role.equip.Equip",
	"player.role.equip.EquipPlug",
	"player.role.wing.Wing",
	"player.role.ride.Ride",
	"player.role.fairy.Fairy",
	"player.role.weapon.Weapon",
	"player.role.effect.EffectBase",
	"player.role.effect.TitleEffect",
	"player.role.effect.SkinEffect",
	"player.role.vein.Vein",
	"player.role.panacea.Panacea",
	"player.role.spellsRes.SpellsRes",
	"player.role.fly.Fly",

	"player.xianlv.Xianlv",
	"player.xianlv.circle.Circle",
	"player.xianlv.position.Position",

	
	"player.xianjun.Xianjun",
	
	"player.tianshen.Tianshen",
	"player.tianshen.TianshenSpells",

	"player.formation.Formation",

	"player.pet.Pet",
	"player.pet.soul.Soul",
	"player.pet.psychic.Psychic",

	"player.recharge.Recharge",

	"player.shop.ShopPlug",
	"modules.teachers.TeachersCenter",
	
	"player.escort.Escort",

	"player.clothes.Clothes",

	"player.task.Task",
	"player.task.TaskEvent",

	"player.fuben.Material",
	"player.fuben.TreasureMap",
	"player.fuben.HeavenFb",
	"player.fuben.PublicBossPlug",
	"player.fuben.ArenaPlug",
	"player.fuben.CrossTeamPlug",
	"player.fuben.VIPBossPlug",

	"player.tiannv.Tiannv",
	"player.tiannv.TianNvPlug",
	"player.tiannv.nimbus.Nimbus",
	"player.tiannv.flower.Flower",

	"player.guild.GuildCtrl",
	"player.guild.GuildDonate",
	"player.guild.GuildPeach",
	"player.guild.GuildProtector",
	"player.guild.GuildSkill",
	"player.guild.GuildMap",
	"player.guild.GuildDungeon",

	"player.exchange.Exchange",

	"player.team.TeamPlug",
	"player.fuben.EightyOneHardPlug",
	"player.vip.Vip",
	"player.marry.Marry",

	"player.answer.Answer",

	"player.dailytask.dailyTask",
	"player.welfare.Welfare",
	"player.friend.Friend",
	"player.welfare.SignIn",
	"player.welfare.LoginGift",
	"player.advanced.Advanced",
	"player.teachers.Teachers",

	"player.brother.Brother",

	"player.baby.Baby",
	"player.baby.BabyPlug",
	"player.baby.BabyStar",
	"player.activity.ActivityPlug",
	"player.luck.LuckPlug",
	"player.auction.AuctionPlug",
	"player.totems.Totems",
	"player.enhance.Enhance",
	"player.cashCow.CashCow",
	"player.position.Position",
	"player.head.Head",

	"modules.mail.MailCenter",
	"modules.shop.ShopCenter",
	"modules.notice.NoticeCenter",
	"modules.arena.ArenaCenter",
	"modules.clock.ClockCenter",
	"modules.escort.EscortCenter",
	"modules.king.KingMgr",
	"modules.climb.ClimbMgr",
	"modules.kfboss.KfBossCenter",
	"modules.offline.Offline",
	"modules.bonus.BonusMgr",
	"modules.openfunc.FuncOpen",
	"modules.auction.AuctionMgr",
	"modules.luck.LuckCenter",
	"modules.dailyActivity.AdvancedrCenter",
	"modules.baby.BabyStarCenter",
	"modules.pet.CatchPetMgr",
	"modules.publicBoss.PublicBossMgr",
	"modules.kingArena.KingArenaMgr",
	"player.chapter.Chapter",

	"modules.guild.Guild",
	"modules.guild.GuildCenter",
	"modules.guild.GuildFinancial",
	"modules.guild.GuildRecord",


	"modules.guild.GuildMinewarMgr",
	"modules.guild.GuildwarMgr",
	"modules.guild.GuildBossMgr",

	"modules.chat.ChatCenter",
	"modules.friend.FriendMgr",

	"modules.dailyActivity.AnswerCenter",
	"modules.dailyActivity.DailyActivityCenter",
	"modules.dailyActivity.EightyOneHardCenter",

	"modules.qualifying.QualifyingMgr",

	"modules.holyPet.HolyPetCenter",

	"modules.rechargew.RechargeCenter",
	"modules.rechargew.HeavenGifts",

	
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
