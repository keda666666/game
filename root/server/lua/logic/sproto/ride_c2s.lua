--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#座骑升阶
cs_ride_upgrade_level 5001 {
	request {}
}
]]
function server.cs_ride_upgrade_level(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
#座骑升级技能
cs_ride_upgrade_skill 5002 {
	request {
		skillId			0 : integer			#技能id
	}
}
]]
function server.cs_ride_upgrade_skill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
#座骑穿戴装备
cs_ride_equip 5003 {
	request {
		itemHandle		0 : integer
		pos 			1 : integer
	}
}
]]
function server.cs_ride_equip(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
#座骑幻化
cs_ride_dress 5004 {
	request {
		dressId 		0 : integer			#装扮id
	}
	response {
		result			0 : integer
		dressId			1 : integer
	}
}
]]
function server.cs_ride_dress(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
#座骑使用属性丹
cs_ride_drug 5005 {
	request {
		drugNum 		0 : integer			#属性丹数量
	}
	response {
		result			0 : integer
		drugTotal		1 : integer			#总属性丹数
	}
}
]]
function server.cs_ride_drug(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end
