--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#摇钱树

#摇钱
cs_cashCow_shake 2201 {
	request {}
}
]]
function server.cs_cashCow_shake(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.cashCow:Shake()
end

--[[
#摇钱树宝箱奖励
cs_cashCow_box_rewards 2202 {
	request {
		boxid 		0 : integer 
	}
}
]]
function server.cs_cashCow_box_rewards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.cashCow:GetBoxRewards(msg.boxid)
end
