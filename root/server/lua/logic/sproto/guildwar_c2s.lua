--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#进入帮会战
cs_guildwar_enter 27001 {
	request {

	}
	response {
       ret 		0 : boolean
    }
}
]]
function server.cs_guildwar_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildwarMgr:Invoke(player, "EnterGuildwar")
	}
end

--[[
#进入下一关
cs_guildwar_next_barrier 27002 {
	request {

	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_guildwar_next_barrier(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
   		ret = server.guildwarMgr:Invoke(player, "EnterNextBarrier")
	}
end

--[[
#攻击玩家
cs_guildwar_attack_player 27005 {
	request {
		targetid 		0 : integer
	}
	response {
		ret 		0 : integer   #0=成功，1=同帮玩家，2=玩家等待复活，3=不是队长
	}
}
]]
function server.cs_guildwar_attack_player(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return {
		ret = server.guildwarMgr:Invoke(player, "Pk", msg.targetid)
	}
end

--[[
#攻击boss
cs_guildwar_attack_boss 27006 {
	request {
		bossid 		0 : integer #只有第二关需传入
	}
}
]]
function server.cs_guildwar_attack_boss(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildwarMgr:Invoke(player, "Attack", msg.bossid)
end

--[[
#清除攻击cd
cs_guildwar_clear_attackcd 27011 {
	request {

	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_guildwar_clear_attackcd(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
#清除复活cd
cs_guildwar_clear_reborncd 27012 {
	request {

	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_guildwar_clear_reborncd(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildwarMgr:Invoke(player, "PayReborn")
	}
end

--[[
#查看帮派排行榜
cs_guildwar_all_guild_rank_info 27030 {
	request {

	}
}
]]
function server.cs_guildwar_all_guild_rank_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildwarMgr:Invoke(player, "SendGuildRank")
end

--[[
#查看个人排行
cs_guildwar_all_player_rank_info 27031 {
	request {

	}
}
]]
function server.cs_guildwar_all_player_rank_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildwarMgr:Invoke(player, "SendPersonRank")
end

--[[
#退出副本
cs_guildwar_exit_barrier 27036 {
	request {

	}
}
]]
function server.cs_guildwar_exit_barrier(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildwarMgr:Invoke(player, "ExitGuildwar")
end

--[[
#领取奖励
cs_guildwar_get_score_reward 27041 {
	request {
		rewardid 		0 : integer 		#奖励id
	}
}
]]
function server.cs_guildwar_get_score_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildwarMgr:GetScoreReward(player.dbid, msg.rewardid)
end

--[[
#返回上一关
cs_guildwar_last_barrier 27003 {
	request {

	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_guildwar_last_barrier(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildwarMgr:Invoke(player, "EnterLastBarrier", msg.rewardid),
    }
end

--[[
#组队招募
cs_guildwar_team_recruit 27042 {
	request {
	}
}
]]
local _TeamRecruitRecord = {}
function server.cs_guildwar_team_recruit(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if not server.chatCenter:EmitTeamRecruit(player.dbid) then return end
   	server.guildwarMgr:TeamRecruit(player.dbid)
end
