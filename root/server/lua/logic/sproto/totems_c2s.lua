--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#激活
cs_totems_open 6201 {
	request {
		id 			0 : integer #图腾编号
	}
	response {
		ret 		0 : boolean #
		id 			1 : integer #编号
		lv 			2 : integer #等级
		upNum 		3 : integer #升级次数
		todayNum  	4 : integer #当天强化暴击阶段次数，配置num减当前参数则为下次必定暴击次数
		todayId 	5 : integer #当天强化暴击阶段编号，在哪个暴击阶段
		breach 		6 : integer #是否要突破，不需要为0，需要的话则为这个参数为等级，上面的lv参数不生效
	}
}
]]
function server.cs_totems_open(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.totems:Open(msg.id)
end

--[[
#升级
cs_totems_add_exp 6202 {
	request {
		id 			0 : integer #图腾编号
		num 		1 : integer #次数
		autobuy 	2 : integer #是否自动购买#0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
	response {
		ret 		0 : boolean #
		id 			1 : integer #编号
		lv 			2 : integer #等级
		upNum 		3 : integer #升级次数
		todayNum  	4 : integer #当天强化暴击阶段次数，配置num减当前参数则为下次必定暴击次数
		todayId 	5 : integer #当天强化暴击阶段编号，在哪个暴击阶段
		breach 		6 : integer #是否要突破，不需要为0，需要的话则为这个参数为等级，上面的lv参数不生效
	}
}
]]
function server.cs_totems_add_exp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.totems:AddExp(msg.id, msg.num, msg.autobuy)
end

--[[
#突破
cs_totems_breach 6203 {
	request {
		id 			0 : integer #图腾编号
	}
	response {
		ret 		0 : boolean #
		id 			1 : integer #编号
		lv 			2 : integer #等级
		upNum 		3 : integer #升级次数
		todayNum  	4 : integer #当天强化暴击阶段次数，配置num减当前参数则为下次必定暴击次数
		todayId 	5 : integer #当天强化暴击阶段编号，在哪个暴击阶段
		breach 		6 : integer #是否要突破，不需要为0，需要的话则为这个参数为等级，上面的lv参数不生效
	}
}
]]
function server.cs_totems_breach(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.totems:Breach(msg.id)
end
