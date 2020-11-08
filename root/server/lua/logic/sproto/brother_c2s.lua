--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#激活
cs_brother_activation 8001 {
	request {
		no				0 : integer #激活的编号
	}
	response {
		ret				0 : boolean #
		no 				1 : integer
	}
}
]]
function server.cs_brother_activation(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.brother:activation(msg.no)
end
