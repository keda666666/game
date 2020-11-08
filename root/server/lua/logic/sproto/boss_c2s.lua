--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#购买挑战次数
cs_public_boss_buy_challenge 12001 {}
]]
function server.cs_public_boss_buy_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.publicboss:BuyChallenge()
end

--[[
#请求BOSS信息
cs_public_boss_info_list 12002 {}
]]
function server.cs_public_boss_info_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:SendRaidType(server.raidConfig.type.PublicBoss, "SendClientList", player.dbid)
end

--[[
# 请求挑战
cs_public_boss_challenge 12010 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_public_boss_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.publicboss:EnterDefi(msg.id)
end

--[[
#复活挑战
cs_public_boss_challenge_reborn 12011 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_public_boss_challenge_reborn(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.publicboss:RebornEnterDefi(msg.id)
end

--[[
#伤害记录
cs_public_boss_record_attack 12015 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_public_boss_record_attack(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:SendRaidType(server.raidConfig.type.PublicBoss, "SendAttackinfos", player.dbid, msg.id)
end

--[[
#击杀记录
cs_public_boss_record_kill 12016 {
	request {
		id 	0 : integer
	}
}
]]
function server.cs_public_boss_record_kill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:SendRaidType(server.raidConfig.type.PublicBoss, "SendKillInfos", player.dbid, msg.id)
end

--[[
#复活标记
cs_public_boss_reborn_mark 12030 {
	request {
		rebornmark 	0 : integer
	}
}
]]
function server.cs_public_boss_reborn_mark(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.publicboss:UpdateBossMark(msg.rebornmark)
end
