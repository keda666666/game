local oo = require "class"

-- 本文件用于辅助热更使用
-- 针对对象类lua文件

local modules =
{
	"cross.client.SendMsg",
	"svrmgr.PlayerMgr",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
