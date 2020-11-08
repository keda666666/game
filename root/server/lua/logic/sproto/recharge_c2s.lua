--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 充值请求
cs_recharge_normal 1801 {
	request {
		rechargeid	0 : integer	# 充值套餐序号
	}
}
]]
function server.cs_recharge_normal(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if player.gm_level == 100 then
	    player.recharge:RechargeNormal(msg.rechargeid)
	end
end

--[[
# 获取订单号
cs_recharge_get_order_number 1802 {
	response {
		order_number 	0 : integer
	}
}
]]
function server.cs_recharge_get_order_number(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local order_number = server.serverCenter:CallNextMod("mainplat", "platCenter", "GetUniqueNum")
    return { order_number = order_number }
end

--[[
#领取首冲奖励
cs_recharge_first_reward 1803 {
	request {
		id 				0 : integer #
	}
}
]]
function server.cs_recharge_first_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.recharge:FirstReward(msg.id)
end

--[[
# 获取每日充值奖励
cs_recharge_get_dailyrecharge_reward 1806 {
	request {
		rewardid 			0 : integer #1=任意金额奖励，2=48元奖励
	}
}
]]
function server.cs_recharge_get_dailyrecharge_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.recharge:GetReward(msg.rewardid)
end


--[[
# 领取特惠充值奖励
cs_recharge_get_choice_reward 1807 {
	request {
	}
}
]]
function server.cs_recharge_get_choice_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.recharge:GetChoiceReward()
end
