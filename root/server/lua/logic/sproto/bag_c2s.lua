--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 添加背包格子数
cs_bag_add_grid 401 {
	request {
		bagNum	0 : integer
	}
}
]]
function server.cs_bag_add_grid(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.bag:AddMaxEquipCount(msg.bagNum)
end

--[[
# 使用道具
cs_bag_use_item 402 {
	request {
		id		0 : integer
		count	1 : integer
	}	
}
]]
function server.cs_bag_use_item(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.bag:UseItem(msg.id, msg.count)
end

--[[
# 发送取出宝物
cs_bag_get_goods_by_store 403 {
	request {
		uuid	0 : integer
	}	
}
]]
function server.cs_bag_get_goods_by_store(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.bag:GetItemsByTreasure(msg.uuid)
end

--[[
# 熔炼装备
cs_bag_smelt 409 {
	request {
		type		0 : integer				
		itemHandle	1 : *integer			
	}	
}
]]
function server.cs_bag_smelt(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.bag:SmeltEquip(msg.itemHandle)
end

--[[
# 回收道具
cs_bag_recycle 410 {
	request {			
		itemHandle	1 : *integer			
	}	
}
]]
function server.cs_bag_recycle(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.bag:SmeltItems(msg.itemHandle)
end
