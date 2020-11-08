--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 进入帮会boss地图
cs_guildboss_entermap 32001 {}
]]
function server.cs_guildboss_entermap(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = player.guild:GetGuild()
    if not guild or guild:GetLevel() < server.configCenter.GuildBossBaseConfig.guildlv then
    	return
    end
	server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "Join", player.dbid, {
			serverid	= server.serverid,
			name		= player.cache.name,
			job			= player.cache.job,
			sex			= player.cache.sex,
			guildid		= player.cache.guildid,
			guildname	= player.guild:GetGuildName(),
		})
	server.dailyActivityCenter:SendJoinActivity("guildboss", player.dbid)
end

--[[
# 请求挑战
cs_guildboss_challenge 32002 {
	request {
		challengeid 	0 : integer	# 挑战玩家id，为空则挑战boss
	}
}
]]
function server.cs_guildboss_challenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	local packinfo = msg.challengeid and {} or server.dataPack:FightInfo(player)
	packinfo.exinfo = {
		challengeid = msg.challengeid,
	}
	server.raidMgr:Enter(server.raidConfig.type.GuildBoss, player.dbid, packinfo)
end

--[[
# 采集宝箱
cs_guildboss_collect_box_start 32003 {
	request {
		boxid		0 : integer
	}
}
]]
function server.cs_guildboss_collect_box_start(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "CollectStart", player.dbid, msg.boxid)
end

--[[
cs_guildboss_collect_box_cancel 32004 {}
]]
function server.cs_guildboss_collect_box_cancel(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "CollectCancel", player.dbid)
end

--[[
# 复活
cs_guildboss_relive 32005 {}
]]
function server.cs_guildboss_relive(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "BuyRelive", player.dbid)
end

--[[
# 获取上届排行
cs_guildboss_getranks 32006 {}
]]
function server.cs_guildboss_getranks(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kfBossCenter:GetRanks(player.dbid)
end

--[[
# 领取奖励
cs_guildboss_get_rewards 32007 {
	response {
		success		0 : boolean
	}
}
]]
function server.cs_guildboss_get_rewards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return { success = server.raidMgr:CallRaidType(server.raidConfig.type.GuildBoss, "GetRewards", player.dbid) }
end
