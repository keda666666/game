--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#进入矿山争夺
cs_guildmine_enter 25001 {
	request {

	}
}
]]
function server.cs_guildmine_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildMinewarMgr:Portal(player, "EnterMinewar")
end

--[[
#查看矿脉信息
cs_guildmine_mine_info 25002 {
	request {
		mineId 			0 : integer
	}
}
]]
function server.cs_guildmine_mine_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildMinewarMgr:Portal(player, "GetMineInfoById", msg.mineId)
end

--[[
#加入守护
cs_guildmine_join_mine 25006 {
	request {
		mineId 		0 : integer		#矿脉id
	}
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_guildmine_join_mine(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildMinewarMgr:Portal(player, "JoinMine", msg.mineId)
	}
end

--[[
#抢占矿脉
cs_guildmine_force_join 25007 {
	request {
		mineId 		0 : integer		#矿脉id
	}
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_guildmine_force_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildMinewarMgr:Portal(player, "ForceJoinMine", msg.mineId)
	}

end

--[[
#采矿
cs_guildmine_gather 25011 {
	request {

	}
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_guildmine_gather(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.guildMinewarMgr:Portal(player, "MineCompleteGather")
	}
end

--[[
#帮派积分排行榜
cs_guildmine_score_rank 25016 {
	request {
		rankType 		0 : integer  #1=当天活动，2=月度排行
	}
}
]]
function server.cs_guildmine_score_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if msg.rankType ~= 2 then
    	server.guildMinewarMgr:Portal(player, "GetGuildScoreRank", msg.rankType)
    else
    	server.guildMinewarMgr:GetGuildScoreRank(player.dbid, msg.rankType)
    end
end

--[[
#离开守护
cs_guildmine_leave_mine 25008 {
	request {
	}
}
]]
function server.cs_guildmine_leave_mine(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.guildMinewarMgr:Portal(player, "LeaveMine")
end
