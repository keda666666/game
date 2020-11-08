--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 领取VIP奖励
cs_vip_get_awards 21001 {
	request {
		lv		0 : integer
	}
}
]]
function server.cs_vip_get_awards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.vip:GiveReward(msg.lv)
end

--[[
# 领取VIP额外奖励
cs_vip_get_other_awards 21002 {
	request {
		lv		0 : integer
	}
}
]]
function server.cs_vip_get_other_awards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.vip:GiveOtherReward(msg.lv)
end
