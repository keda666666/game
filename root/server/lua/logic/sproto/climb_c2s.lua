--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求进入九重天
cs_crimb_join 26001 {
	request {

	}
	response {
       ret 		0 : boolean
    }
}
]]
function server.cs_crimb_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:Enter(player)
end

--[[
# pk
cs_crimb_pk 26002 {
	request {
		targetid	0 : integer
	}
}
]]
function server.cs_crimb_pk(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:PK(player, msg.targetid)
end

--[[
# 周排行榜
cs_climb_all_rank 26003 {
	request { }
}
]]
function server.cs_climb_all_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:GetAllRank(player.dbid)
end

--[[
# 当前排行榜
cs_climb_curr_rank 26004 {
	request { }
}
]]
function server.cs_climb_curr_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:GetCurrRank(player.dbid)
end

--[[
# 领取积分奖励
cs_climb_get_reward 26005 {
	request { }
}
]]
function server.cs_climb_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:GetReward(player.dbid)
end

--[[
# 离开
cs_climb_leave 26006 {
	request { }
}
]]
function server.cs_climb_leave(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.climbMgr:Leave(player.dbid)
end

--[[
# 上次离开的时间
cs_climb_leave_time 26007 {
	request { }
	response {
       time 		0 : integer
    }
}
]]
function server.cs_climb_leave_time(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {time = server.climbMgr:GetLeaveTime(player.dbid)}
end
