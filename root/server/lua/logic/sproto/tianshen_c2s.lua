--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#兑换
cs_tianshen_exchange 5501 {
	request {
		no			0 : integer #天神编号
	}
}
]]
function server.cs_tianshen_exchange(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.tianshen:Exchange(msg.no)
end

--[[
#激活
cs_tianshen_activation 5502 {
	request {
		no			0 : integer #天神编号
	}
	response {
		ret			0 : boolean #
		no			1 : integer #
		lv			2 : integer #等级
		upNum		3 : integer #升经验次数，经验显示请参照template
		promotion	4 : integer #突破等级
	}
}
]]
function server.cs_tianshen_activation(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen:Activation(msg.no)
end

--[[
#使用属性丹
cs_tianshen_drug 5503 {
	request {
		useNum			0 : integer #使用多少个丹数
	}
	response {
		ret				0 : boolean #
		drugNum			1 : integer #已使用属性丹数量
	}
}
]]
function server.cs_tianshen_drug(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen:UseDrug(msg.useNum)
end

--[[
#进阶
cs_tianshen_up_level 5504 {
	request {
		no				0 : integer #
		autoBuy			1 : integer #0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
	response {
		ret				0 : boolean #
		no				1 : integer #
		lv				2 : integer #
		upNum			3 : integer #
	}
}
]]
function server.cs_tianshen_up_level(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen:UpLevel(msg.no, msg.autoBuy)
end

--[[
#突破
cs_tianshen_promotion 5505 {
	request {
		no				0 : integer #
	}
	response {
		ret				0 : boolean #
		no				1 : integer #
		promotion		2 : integer #突破等级
	}
}
]]
function server.cs_tianshen_promotion(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen:Promotion(msg.no)
end

--[[
#出战
cs_tianshen_fight 5506 {
	request {
		no				0 : integer #
		warType			1 : integer #0休息，1出战
	}
	response {
		ret				0 : boolean #
		use				1 : integer #出战的天神
		disuse			2 : integer #休息的天神
	}
}
]]
function server.cs_tianshen_fight(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen:Fight(msg.no , msg.warType)
end

--[[
#宝器升级
cs_tianshen_spells 5507 {
	request {
		pos				0 : integer #第几个宝器
		autoBuy			1 : integer #
	}
	response {
		ret				0 : boolean #
		pos				1 : integer #
		upNum			2 : integer #经验次数
		lv				3 : integer #等级
	}
}
]]
function server.cs_tianshen_spells(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.tianshen.spells:AddExp(msg.pos, msg.autoBuy)
end

--[[
cs_tianshen_fly_addexp 5508 {
	request {
		id 		0 : integer
		autoBuy	1 : integer  #0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
	response {
		ret 		0 : boolean
		flyexp		1 : integer
		flylevel	2 : integer
	}
}
]]
function server.cs_tianshen_fly_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = player.tianshen:AddFlyexp(msg.id, msg.autoBuy)
    return player.tianshen:PackFlyAddexpReply(msg.id, ret)
end
