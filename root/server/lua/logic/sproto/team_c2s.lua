--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#获取我加入的队伍信息
cs_team_info 17001 {
	request { }
}
]]
function server.cs_team_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teamMgr:GetTeamInfo(player.dbid)
end

--[[
#获取队伍列表
cs_team_list 17002 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
}
]]
function server.cs_team_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teamMgr:GetTeamList(player.dbid, msg.raidtype, msg.level)
end

--[[
# 创建队伍
cs_team_create 17003 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_create(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Create(player.dbid, msg.raidtype, msg.level)
    return {ret = ret}
end

--[[
# 快速加入队伍
#cs_team_quick_join 17004 {
#	request {
#		raidtype	0 : integer
#		level		1 : integer
#	}
#	response {
#        ret 		0 : boolean
#    }
#}
]]
function server.cs_team_quick_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:QuickJoin(player.dbid, msg.raidtype, msg.level)
    return {ret = ret}
end


--[[
# 加入队伍
cs_team_join 17005 {
	request {
		raidtype	0 : integer
		level		1 : integer
		leaderid	2 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Join(player.dbid, msg.leaderid, msg.raidtype, msg.level)
    return {ret = ret}
end

--[[
# 离开队伍
cs_team_leave 17006 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_leave(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Leave(player.dbid)
    return {ret = ret}
end

--[[
# 解散队伍
cs_team_dismiss 17007 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_dismiss(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Dismiss(player.dbid, msg.raidtype, msg.level)
    return {ret = ret}
end

--[[
# 踢人
cs_team_kick 17008 {
	request {
		raidtype	0 : integer
		level		1 : integer
		memberid	2 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_kick(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Kick(player.dbid, msg.memberid, msg.raidtype, msg.level)
    return {ret = ret}
end



--[[
# 快速加入队伍(如果没有就创建)
cs_team_quick 17009 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_quick(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Quick(player.dbid, msg.raidtype, msg.level)
    return {ret = ret}
end

--[[
# 战斗
cs_team_fight 17010 {
	request {
		raidtype	0 : integer
		level		1 : integer
		ext			2 : integer 	#额外参数 
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_team_fight(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.teamMgr:Fight(player.dbid, msg.raidtype, msg.level, msg.ext)
    return {ret = ret}
end



--[[
# 呼叫机器人
cs_team_call_robot 17011 {
	request {
		raidtype	0 : integer
		level		1 : integer
	}
}
]]
function server.cs_team_call_robot(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teamMgr:ClientCallRobot(player.dbid, msg.raidtype, msg.level)
end

--[[
#设置加入条件
cs_team_condition 17012 {
	request {
		raidtype	0 : integer
		level		1 : integer
		needpower	2 : integer
	}
}
]]
function server.cs_team_condition(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teamMgr:SetCondition(player.dbid, msg.raidtype, msg.level, msg.needpower)
end
