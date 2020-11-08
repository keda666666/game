--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求任务数据
cs_task_info 18001 {
	request {
		type	0 : integer # 类型: 1主线
	}
}
]]
function server.cs_task_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.task:SendTaskInfo(msg.type)
end

--[[
# 领取任务奖励
cs_task_reward 18002 {
	request {
		id 		0 : integer
	}
}
]]
function server.cs_task_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.task:GetReward(msg.id)
end
