--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
cs_shop_buy 1701 {
	request {
		shopType 	0 : integer
		index 		1 : integer
		buynum		2 : integer
	}
}
]]
function server.cs_shop_buy(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.shop:BuyItem(msg.shopType, msg.index, msg.buynum)
end

--[[
cs_shop_mystical_buy 1706 {
	request {
		index 		0 : integer
		buynum		1 : integer
	}
	
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_shop_mystical_buy(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.shop:BuyMysticalGoods(msg.index, msg.buynum)
    }
end

--[[
cs_shop_mystical_refresh 1707 {
	request {
	}

	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_shop_mystical_refresh(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.shop:PayRefreshMysticalShop()
	}
end
