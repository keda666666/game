--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求boss列表数据
cs_field_boss_boss_list 11001 {
}
]]
function server.cs_field_boss_boss_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:SendRaidType(server.raidConfig.type.FieldBoss, "SendBossList", player.dbid)
end

--[[
# 请求挑战
cs_field_boss_challenge 11004 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_field_boss_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local packinfo = server.dataPack:FightInfo(player)
    packinfo.exinfo = {
        sex = player.cache.sex,
        job = player.cache.job,
        index = msg.id,
    }
    local ret = server.raidMgr:Enter(server.raidConfig.type.FieldBoss, player.dbid, packinfo)
    if ret then
        player.enhance:AddPoint(22, 1)
    end
end
