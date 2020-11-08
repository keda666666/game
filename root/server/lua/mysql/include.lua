local oo = require "class"

-- 本文件用于辅助热更使用
-- 针对对象类lua文件

local modules =
{
	"lua_util",

	"modules.Event",
	"modules.BaseCenter",

	"mysql.MysqlPool",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
