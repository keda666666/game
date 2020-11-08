--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#银两兑换信息
cs_exchange_gold_info 19001 {
	request {

	}
	response {
		exchangeCount 		0 : integer 	#兑换次数
		goldnum 			1 : integer 	#可兑换银两
	}
}
]]
function server.cs_exchange_gold_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	exchangeCount = player.exchange:GetExchangeGoldCount(),
    	goldnum = player.exchange:GetExchangeGoldnum(),
	}
end

--[[
#银两兑换
cs_exchange_gold_perform 19002 {
	request {

	}
	response {
		ret 			0 : boolean
		exchangeCount 	1 : integer 		#兑换次数
	}
	
}
]]
function server.cs_exchange_gold_perform(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.exchange:ExchangeGold(),
    	exchangeCount = player.exchange:GetExchangeGoldCount(),
	}
end
