--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#获取活动数据
cs_activity_info_req 22001 {
	request {
	}
}
]]
function server.cs_activity_info_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.dailyActivityCenter:ActData(player.dbid)
end

--[[
#进入活动
cs_activity_enter 22002 {
	request {
		activity 			0 : integer #活动编号
	}
}
]]
function server.cs_activity_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.dailyActivityCenter:Enter(player, msg.activity)
end

--[[
#活动大厅
cs_activity_hall 22003 {
	request { }
}
]]
function server.cs_activity_hall(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.dailyActivityCenter:Hall(player)
end
