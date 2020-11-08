--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 领取奖励
cs_activity_send_reward 2602 {
	request {
		id 		0 : integer
		index 	1 : integer
	}	
}
]]
function server.cs_activity_send_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.activityPlug:ActivityReward(msg.id, msg.index)
end

--[[
cs_activity_send_dabiao_info 2603 {
	request {
		activityID 		0 : integer
	}	
}
]]
function server.cs_activity_send_dabiao_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_activity_send_level_info 2604 {
	request {
		activityID		0 : integer
	}
}
]]
function server.cs_activity_send_level_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求达标历史记录
cs_activity_race_history 2605 {}
]]
function server.cs_activity_race_history(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求开启活动，目前仅限于投资计划和成长基金
cs_activity_open 2606 {
	request {
		id				0 : integer
	}
}
]]
function server.cs_activity_open(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.activityPlug:ActivityOpen(msg.id, msg.index)
end

--[[
#战斗
cs_activity_action 2607 {
	request {
		activityId 		0 : integer
	}
}
]]
function server.cs_activity_action(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.activityPlug:ActivityAction(msg.activityId)
end
