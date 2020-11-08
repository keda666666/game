local lua_app = require "lua_app"
local server = require "server"

local MysqlConfig = {
update = require "mysql.update",
db = {

wardatas = {
	columns = {
		{ "uniquevalue"		,"int(11)"			,1		,"类型唯一" },
		{ "fieldboss"		,"mediumblob"		,{
					borntime = 0,
					bosslist = {},
				}		,"野外boss" },
		{ "publicboss"		,"mediumblob"		,{
					bosslist = {},
				}		,"全民boss" },
		{ "guildboss"		,"mediumblob"		,{
					bosslist = {},
				}		,"帮会boss" },
		{ "qualifying_audition"		,"mediumblob"		,{
					typ = 0,
					recordNo = 1,
					memberList = {},
					audition = {{},{},{},{},},--报名数据,存了战斗记录，key为玩家id	
				}		,"仙道会_audition" },
		{ "qualifying_auditionFight"		,"mediumblob"		,{
				auditionFight = {{},{},{},{},},--顺序排放的玩家id
				}		,"仙道会_auditionFight" },
		{ "qualifying_rank"		,"mediumblob"		,{
				auditionRank = {{},{},{},{},}, --海选排行榜
				}		,"仙道会_rank" },
		{ "qualifying_key"		,"mediumblob"		,{
				keyList = {},--玩家的key 用于判断玩家是否报名了,找玩家是哪个赛场的
				}		,"仙道会_key" },
		{ "qualifying_last"		,"mediumblob"		,{
					lastData = {{},{},{},{},},--存储进入16强的玩家数据
				}		,"仙道会_last" },
		{ "qualifying_the"		,"mediumblob"		,{
					the16 = {{},{},{},{},},--16强名单
					the8 = {{},{},{},{},},
					the4 = {{},{},{},{},},
					the2 = {{},{},{},{},},
				}		,"仙道会_the" },
		{ "qualifying_bets"		,"mediumblob"		,{
					bets16 = {{},{},{},{},},--下注
					bets8 = {{},{},{},{},},
					bets4 = {{},{},{},{},},
					bets2 = {{},{},{},{},},
				}		,"仙道会bets" },
		{ "climb"		,"mediumblob"		,{
					session = 1,
					scorelist = {},
					champion = {},
					recordlist = {},
					currrank = {},
				}		,"九重天" },
		{ "guildwar"		,"mediumblob"		,{
					champions = {}
				}		,"帮会战" },
		{ "guildmine"		,"mediumblob"		,{
					guildRecord = {},
				}		,"矿山争夺" },
		{ "maincity"		,"mediumblob"		,{

					champion = 0,
					worships = {},
					worshipRecord = {},
				}		,"主城地图" },
	},
	prikey = { "uniquevalue" },
	comment = "战斗数据表",
	uniquevalue = true,
},

qualifying_player = {
	columns = {
		{ "dbid"			,"bigint(20)"		,0		,"玩家id" },
		{ "rank"			,"int(2)"			,0		,"玩家赛场" },
		{ "data" 			,"mediumblob"		,{}		,"玩家数据" },
	},
	prikey = { "dbid" },
	comment = "仙道会玩家数据",
},

qualifying_record = {
	columns = {
		{ "no"				,"int(11)"			,0		,"录像编号" },
		{ "data"			,"mediumblob"		,{}		,"战斗录像" },
	},
	prikey = { "no" },
	comment = "仙道会战斗录像",
},


},
}
server.SetCenter(MysqlConfig, "mysqlConfig")
return MysqlConfig