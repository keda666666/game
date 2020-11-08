local server = require "server"
local lua_app = require "lua_app"
local RankConfig = require "resource.RankConfig"

local RankMgr = {}

function RankMgr:RealtimeUpdates(player, type)
	local dbDatas1, dbDatas2 = player:GetPlayerCacheStr(RankConfig:GetRankSqlDatas(type))
	return dbDatas1 and server.serverCenter:CallLocalMod("world", "rankCenter", "RealtimeUpdates", type, player.dbid, dbDatas1),
		dbDatas2 and server.serverCenter:CallDtbMod("world", "rankCenter", "RealtimeUpdates", type, player.dbid, dbDatas2)
end

server.SetCenter(RankMgr, "rankMgr")
return RankMgr