--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#领取奖励
cs_enhance_get_reward 6301 {
	request {
		no 			0 : integer #奖励编号
	}
	response {
		ret 		0 : boolean #
		no 			1 : integer #领取了哪个奖励
	}
}
]]
function server.cs_enhance_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.enhance:GetReward(msg.no)
end
