--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 领取累计充值奖励
cs_advanced_charger_reward 5901 {
	request {
		id 			0 : integer	# 奖励编号
	}
}
]]
function server.cs_advanced_charger_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.advanced:GetChargerReward(msg.id)
end

--[[
# 领取进阶排名奖励
cs_advanced_lv_reward 5902 {
	request {
		typ 		0 : integer # 进阶类型
		id 			1 : integer	# 奖励编号
	}
}
]]
function server.cs_advanced_lv_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.advanced:GetAdvancedLvReward(msg.typ, msg.id)
end

--[[
# 获取活动排行榜
cs_advanced_rank 5903 {
	request {
	}
}
]]
function server.cs_advanced_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.advanced:GetRank()
end

--[[
# 购买商品
cs_advanced_buy 5904 {
	request {
		id 			0 : integer	# 商品编号
		num 		1 : integer # 购买数量
		typ 		2 : integer # 进阶类型
	}
}
]]
function server.cs_advanced_buy(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.advanced:Buy(msg.id, msg.num, msg.typ)
end
