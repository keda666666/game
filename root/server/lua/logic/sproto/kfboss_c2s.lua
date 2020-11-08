--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 进入跨服boss地图
cs_kfboss_entermap 2101 {}
]]
function server.cs_kfboss_entermap(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = player.guild:GetGuild()
    if not guild or guild:GetLevel() < server.configCenter.KfBossBaseConfig.guildlv then
    	return
    end
	server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "Join", player.dbid, {
			serverid	= server.serverid,
			name		= player.cache.name,
			job			= player.cache.job,
			sex			= player.cache.sex,
			guildid		= player.cache.guildid,
			guildname	= player.guild:GetGuildName(),
		})
	server.dailyActivityCenter:SendJoinActivity("kfboss", player.dbid)
end

--[[
# 请求挑战
cs_kfboss_challenge 2102 {
	request {
		challengeid 	0 : integer	# 挑战玩家id，为空则挑战boss
	}
}
]]
function server.cs_kfboss_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	local packinfo = msg.challengeid and {} or server.dataPack:FightInfo(player)
	packinfo.exinfo = {
		challengeid = msg.challengeid,
	}
	server.raidMgr:Enter(server.raidConfig.type.KFBoss, player.dbid, packinfo)
end

--[[
# 采集宝箱
cs_kfboss_collect_box_start 2103 {
	request {
		boxid		0 : integer
	}
}
]]
function server.cs_kfboss_collect_box_start(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "CollectStart", player.dbid, msg.boxid)
end

--[[
cs_kfboss_collect_box_cancel 2104 {}
]]
function server.cs_kfboss_collect_box_cancel(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "CollectCancel", player.dbid)
end

--[[
# 复活
cs_kfboss_relive 2105 {}
]]
function server.cs_kfboss_relive(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "BuyRelive", player.dbid)
end

--[[
# 获取上届排行
cs_kfboss_getranks 2106 {}
]]
function server.cs_kfboss_getranks(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kfBossCenter:GetRanks(player.dbid)
end

--[[
# 领取奖励
cs_kfboss_get_rewards 2107 {
	response {
		success		0 : boolean
	}
}
]]
function server.cs_kfboss_get_rewards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return { success = server.raidMgr:CallRaidType(server.raidConfig.type.KFBoss, "GetRewards", player.dbid) }
end
