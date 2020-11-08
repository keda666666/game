--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
cs_tiannv_wash_req 5301 {
	request {
		pos				0 : integer #洗练位置
		washType		1 : integer #洗练类型1普通2高级
		lock			2 : *integer #锁了的位置{2,3}
	}
}
]]
function server.cs_tiannv_wash_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.tiannv:Wash(msg.pos, msg.washType, msg.lock)
end

--[[
cs_tiannv_wash_replace_req 5302 {
	request {
		pos				0 : integer #替换位置
	}
}
]]
function server.cs_tiannv_wash_replace_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.tiannv:WashCover(msg.pos)
end
