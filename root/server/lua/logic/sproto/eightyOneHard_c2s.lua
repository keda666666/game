--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#扫荡
cs_eightyOneHard_sweep 28001 {
	request {
		id	0 : integer #
	}
}
]]
function server.cs_eightyOneHard_sweep(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.eightyOneHard:Sweep(msg.id)
end

--[[
#一键扫荡
cs_eightyOneHard_sweep_all 28002 {
	request {

	}
}
]]
function server.cs_eightyOneHard_sweep_all(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.eightyOneHard:SweepAll()
end

--[[
#购买宝箱
cs_eightyOneHard_buy 28003 {
	request {
		id	0 : integer #
	}
}
]]
function server.cs_eightyOneHard_buy(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.eightyOneHard:Buy(msg.id)
end

--[[
#查看记录
cs_eightyOneHard_record 28004 {
	request {
		id	0 : integer #
	}
	response {
		first	0 : eightyOneHard_clear_data #
		fast	1 : eightyOneHard_clear_data #
	}
}
]]
function server.cs_eightyOneHard_record(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local resMsg = {}
    resMsg.first, resMsg.fast = server.eightyOneHardCenter:GetData(msg.id)
    return resMsg
end
