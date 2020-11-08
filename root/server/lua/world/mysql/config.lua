local lua_app = require "lua_app"
local server = require "server"

local MysqlConfig = {
update = require "mysql.update",
db = {

ranks = {
	columns = {
		{ "type"			,"int(11)"			,0		,"类型" },
		{ "rank"			,"int(11)"			,0		,"排名" },
		{ "data"			,"mediumblob"		,{}		,"数据" },
	},
	prikey = { "type", "rank" },
	key = {
		type = { "type" },
	},
	comment = "排行榜表",
},

activitys = {
	columns = {
		{ "activity_id"				,"int(11)"			,0		,"活动id" },
		{ "activity_init_status"	,"int(11)"			,0		,"开启标记" },
		{ "activity_over_status"	,"int(11)"			,0		,"结束标记" },
		{ "activity_data"			,"mediumblob"		,{}		,"活动数据" },
	},
	prikey = { "activity_id" },
	key = {
		type = { "activity_id" },
	},
	comment = "活动表",
},

auctions = {
	columns = {
		{ "dbid"			,"int(11)"			,0		,"索引ID" 	,"AUTO_INCREMENT"},
		{ "playerid"		,"bigint(20)"		,0		,"玩家ID" },
		{ "playername"		,"varchar(128)"		,""		,"玩家名字"},
		{ "guildid" 	 	,"bigint(20)"		,0		,"公会ID" },
		{ "itemid"			,"int(11)"			,0		,"物品ID" },
		{ "count"			,"int(11)"			,0		,"物品数量" },
		{ "createtime" 		,"int(11)"			,0		,"创建时间" },
		{ "status" 			,"int(11)"			,0		,"阶段" },
		{ "price"			,"mediumblob"		,{}		,"当前价格"},
		{ "offerid"			,"bigint(20)"		,0		,"当前出价者"},
		{ "offername"		,"varchar(128)"		,""		,"当前出价者"},
		{ "offertime" 		,"int(11)"			,0		,"出价时间" },
		{ "dealtime" 		,"int(11)"			,0		,"成交时间" },
		{ "isbuy" 			,"int(11)"			,0		,"是否是一口价" },
		{ "dealprice" 		,"int(11)"			,0		,"一口价" },
		{ "addprice" 		,"int(11)"			,0		,"增加值" },
		{ "numerictype" 	,"int(11)"			,0		,"货币类型" },
		{ "record"			,"mediumblob"		,{}		,"出价记录"},
	},
	prikey = { "dbid" },
	comment = "拍卖行",
},

worlddatas = {
  columns = {
    { "uniquevalue"    ,"int(11)"      ,1    ,"类型唯一" },
    { "record_activity"  ,"mediumblob"    ,{
        list = {},
      }    ,"后台推送活动表" },
  },
  prikey = { "uniquevalue" },
  comment = "基础数据表",
  uniquevalue = true,
},

},
}
server.SetCenter(MysqlConfig, "mysqlConfig")
return MysqlConfig