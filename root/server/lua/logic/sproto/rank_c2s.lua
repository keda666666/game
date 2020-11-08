--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求排行榜数据
cs_rank_req 1901 {
	request {
		type		0 : integer
	}
}
]]
function server.cs_rank_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.serverCenter:SendLocalMod("world", "rankCenter", "SendRankDatas", player.dbid, msg.type)
end

--[[
# 请求膜拜数据
cs_rank_worship_data_req 1902 {
	request {
		type		0 : integer
	}
}
]]
function server.cs_rank_worship_data_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 膜拜一次
cs_rank_worship_once 1903 {
	request {
		type		0 : integer
	}
}
]]
function server.cs_rank_worship_once(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求所有膜拜次数
cs_rank_worship_all_count 1904 {
	request {}
}
]]
function server.cs_rank_worship_all_count(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end
