--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求boss列表数据
cs_vipboss_list 6001 {
}
]]
function server.cs_vipboss_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.vipBoss:SendBossInfo()
end

--[[
# 请求挑战
cs_vipboss_challenge 6004 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_vipboss_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local packinfo = server.dataPack:FightInfo(player)
    packinfo.exinfo = {
        index = msg.id
    }
    server.raidMgr:Enter(server.raidConfig.type.VIPBoss, player.dbid, packinfo)
end
