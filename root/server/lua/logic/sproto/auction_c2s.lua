--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
cs_auction_useitem 2801 {
	request {
		id		0 : integer
	}
}
]]
function server.cs_auction_useitem(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 选择拍卖还是自用
cs_auction_select 2802 {
	request {
		choose		0 : integer		# 1自用 2拍卖
	}
}
]]
function server.cs_auction_select(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:Select(msg.choose)
end

--[[
# 查看列表
cs_auction_list 2803 {
	request {
		auctype		 0 : integer		# 1 表示帮会 0表示全服
	}
}
]]
function server.cs_auction_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:SendList(msg.auctype)
end

--[[
# 竞拍
cs_auction_offer 2804 {
	request {
		id			0 : integer		# 拍卖物品唯一id	
		guildid		1 : integer		# 必须有 0表示全服
	}
}
]]
function server.cs_auction_offer(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:Offer(msg.id, msg.guildid)
end

--[[
# 查看记录
cs_auction_record 2805 {
	request {
		auctype		 0: integer		# 1 表示帮会 0表示全服
	}
}
]]
function server.cs_auction_record(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:SendList(msg.auctype, "record")
end

--[[
# 一口价买走
cs_auction_buy 2806 {
	request {
		id			0 : integer		# 拍卖物品唯一id	
		guildid		1 : integer		# 必须有 0表示全服
	}
}
]]
function server.cs_auction_buy(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:Buy(msg.id, msg.guildid)
end

--[[
# 请求更新
cs_auction_update 2807 {
	request {
		id			0 : integer		# 拍卖物品唯一id	
		guildid		1 : integer		# 必须有 0表示全服
	}
}
]]
function server.cs_auction_update(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.auctionPlug:UpdateOne(msg.id, msg.guildid)
end

--[[
cs_auction_query_item 2808 {
	request {
		itemid 			0 : integer 	#上架物品id
	}
	response {
		dealprice 		0 : integer 	#一口价
		addprice 		1 : integer 	#增加值
		price 			2 : integer 	#起拍价
		numerictype 	3 : integer 	#货币类型
	}
}
]]
function server.cs_auction_query_item(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.auctionPlug:QueryShelf(msg.itemid)
end
