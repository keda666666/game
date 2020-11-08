--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
cs_mail_get_content 901 {
	request {
		handle 	0 : integer
	}
}
]]
function server.cs_mail_get_content(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.mail:ReadMail(msg.handle)
end

--[[
cs_mail_get_reward 902 {
	request {
		handle 	0 : *integer
	}
}
]]
function server.cs_mail_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.mail:GetMailsAward(msg.handle)
end
