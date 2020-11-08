--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
cs_position_getawards 6501 {
	request {
		no			0 : integer
	}
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_position_getawards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.position:GetReward(msg.no)
end
