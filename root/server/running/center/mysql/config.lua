local lua_app = require "lua_app"
local server = require "server"

local MysqlConfig = {
update = require "mysql.update",
db = {

dispatchlist = {
	columns = {
		{ "name"			,"varchar(16)"		,""		,"服务名称" },
		{ "serverid"		,"int(11)"			,0		,"服务器ID" },
		{ "area"			,"int(11)"			,0		,"所在分区" },
	},
	prikey = { "name", "serverid" },
	key = {
		name = { "name" },
	},
	comment = "服务器分配表",
},
nodelist = {
	columns = {
		{ "name"		,"varchar(16)"		,""		,"服务名称" },
		{ "area"		,"int(11)"			,0		,"服务序号" },
		{ "node"		,"int(11)"			,0		,"跨服节点" },
	},
	prikey = { "name", "area" },
	comment = "跨服节点列表",
},

},
}
server.SetCenter(MysqlConfig, "mysqlConfig")
return MysqlConfig