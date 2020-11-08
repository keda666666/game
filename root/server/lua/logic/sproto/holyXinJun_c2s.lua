--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#抽奖
cs_holy_xinjun_luck_draw 6603 {
	request {
	}
	response {
		ret 	0 : boolean #
		no 		1 : integer #抽到了啥
		data 	2 : *holy_xinjun_msg #抽奖信息
		luckLog	3 : *integer #玩家抽取记录
	}
}
]]
function server.cs_holy_xinjun_luck_draw(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.holyPetCenter:XinJunLuckDraw(player.dbid)
end

--[[
#获取抽奖信息
cs_holy_xinjun_get_info 6602 {
	request {
	}
	response {
		data 		0 : *holy_xinjun_msg #抽奖信息
		luckLog		1 : *integer #玩家抽取记录
	}
}
]]
function server.cs_holy_xinjun_get_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local msg = {}
    msg.data = server.holyPetCenter:GetXinJunData()
    msg.luckLog = server.holyPetCenter:GetXinJunLuckLog(player.dbid)
    return msg
end
