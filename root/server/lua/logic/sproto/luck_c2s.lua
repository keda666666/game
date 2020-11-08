--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
cs_luck_info 2701 {
	request {
	}
}
]]
function server.cs_luck_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.luckPlug:GetInfo()
end

--[[
#抽
cs_luck_draw 2702 {
	request {
		type 			0 : integer#抽奖类型 1,转盘 2,神装抽奖 3,图腾抽奖
		index 			1 : integer #编号
	}
}
]]
function server.cs_luck_draw(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.luckPlug:Draw(msg.type, msg.index)
end

--[[
#抽奖
cs_luck_tianshen 2703 {
	request {
		typ 	0 : integer #1绑元10次 2元宝1次 3元宝10次
	}
	response {
		ret 		0 : boolean #
		rewards 	1 : *luck_tianshen_rewards #抽到了啥
		tenNum		3 : integer #10连次数
	}
}
]]
function server.cs_luck_tianshen(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.luckPlug:DrawTianshen(msg.typ)
end
