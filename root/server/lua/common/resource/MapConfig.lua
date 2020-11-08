local server = require "server"
local MapConfig = {}

MapConfig.status = {
	Act			= 1,	--自由活动
	Fighting	= 2,	--战斗中
	Dead		= 3,	--死亡
}

MapConfig.CanMoveStatus = {
	[MapConfig.status.Act]	= true,
}

server.SetCenter(MapConfig, "mapConfig")
return MapConfig