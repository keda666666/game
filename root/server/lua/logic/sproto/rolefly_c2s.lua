--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 人物飞升
cs_rolefly_up 3000 {
	request {
	}
	response {
		ret 	0 : boolean
		xiuWei			1 : integer
		skillList		2 : *integer
	}
}
]]
function server.cs_rolefly_up(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.role.fly:UpLevel()
end

--[[
#升级技能
cs_rolefly_up_skill 3001 {
	request {
		skillNo			1 : integer
	}
	response {
		ret 			0 : boolean #
		skillList		1 : *integer
	}
}
]]
function server.cs_rolefly_up_skill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.role.fly:UpLevel()
end

--[[
#添加修为
cs_rolefly_add_xiuwei 3002 {
	request {
		type			1 : integer #消耗物品类型
		id				2 : integer #消耗物品id
	}
	response {
		ret 			0 : boolean #
		xiuWei			1 : integer
	}
}
]]
function server.cs_rolefly_add_xiuwei(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.role.fly:addXiuWei()
end

--[[
#获取添加修为次数
cs_rolefly_get_addnum 3003 {
	request {
	}
	response {
		ret 			0 : boolean #
		number			1 : integer
	}
}
]]
function server.cs_rolefly_get_addnum(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.role.fly:getExchangeCount()
end
