--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
cs_money_tree_play 3702 {}
]]
function server.cs_money_tree_play(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_money_tree_reward 3703 {
	request {
		id			0 : integer
	}
}
]]
function server.cs_money_tree_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_money_recharge_get 3704 {
	request {
		day			0 : integer 	# 天数
	}
}
]]
function server.cs_money_recharge_get(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_qd_recharge_info 3705 {       #30天签到数据
}
]]
function server.cs_qd_recharge_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_qd_recharge_get 3706 {        #30天签到
    request {
	    day         0 : integer      # 签到第天数
	}
}
]]
function server.cs_qd_recharge_get(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_qd_get_reward 3707 {			#累计签到奖励
	request {
		index 		0 : integer
	}
}
]]
function server.cs_qd_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end
