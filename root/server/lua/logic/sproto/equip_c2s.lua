--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 穿戴装备
cs_equip_wear 501 {
	request {
		itemHandle		0 : integer
		pos 			1 : integer
	}
}
]]
function server.cs_equip_wear(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.equip:EquipItem(msg.itemHandle, msg.pos)
end

--[[
# 装备升级
cs_equip_upgrade 503 {
	request {
		pos			0 : integer
		isgodequip	1 : boolean
	}	
}
]]
function server.cs_equip_upgrade(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 装备煅造
cs_equip_forge 511 {
	request {
		forgeType	0 : integer			#煅造类型 0 强化， 1 精炼 ，2 煅炼， 3 宝石
	}
}
]]
function server.cs_equip_forge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.equip:ForgeUpGrade(msg.forgeType)
end

--[[
# 红装注灵
cs_equip_red_inject 521 {
	request {
		slot 			0 : integer
		mode 			1 : integer 		#消耗类型 0=道具，1=道具、绑元，2=道具、绑元、元宝
	}
	response {
		ret 			0 : boolean
	}
}
]]
function server.cs_equip_red_inject(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.role.equip:InjectEqiup(msg.slot, msg.mode)
    }
end

--[[
# 红装合成并装备
cs_equip_red_generate 522 {
	request {
		slot 			0 : integer
	}
}
]]
function server.cs_equip_red_generate(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
     player.role.equip:RedGenerate(msg.slot)
end

--[[
# 红装觉醒
cs_equip_red_upgrade 523 {
	request {
		slot 			0 : integer
	}
}
]]
function server.cs_equip_red_upgrade(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.equip:RedUpgrade(msg.slot)
end
