--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 宠物激活
cs_pet_active 601 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_pet_active(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.pet:Active(msg.id)
end

--[[
cs_pet_outbound 602 {
	request {
		first	0 : integer
		second	1 : integer
		third	2 : integer
		four	3 : integer
	}
}
]]
function server.cs_pet_outbound(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.pet:OutBound(msg.first, msg.second, msg.third, msg.four)
end

--[[
cs_pet_addexp 603 {
	request {
		id 		0 : integer
		autoBuy	1 : integer  #0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
	response {
		ret 	0 : boolean
		exp		1 : integer
		level	2 : integer
	}
}
]]
function server.cs_pet_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.pet:AddExp(msg.id, msg.autoBuy)
end

--[[
cs_pet_addgift 604 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
		exp		1 : integer
		level	2 : integer
	}
}
]]
function server.cs_pet_addgift(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.pet:AddGift(msg.id)
end

--[[
cs_pet_rename 605 {
	request {
		id 		0 : integer
		name 	1 : string
	}
	response {
		ret 	0 : boolean
		name 	1 : string
	}
}
]]
function server.cs_pet_rename(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.pet:Rename(msg.id, msg.name)
end

--[[
cs_pet_refreshskill 606 {
	request {
		id 			0 : integer
		locklist 	1 : *integer
		type 		2 : integer	 # 0、洗练		1、高级洗练
		autoBuy		3 : integer  #0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
	response {
		ret 	0 : boolean
		xilian 	1 : integer
		xilianSkills 	2 : *integer
	}
}
]]
function server.cs_pet_refreshskill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.pet:RefreshSkill(msg.id, msg.type, msg.locklist, msg.autoBuy)
end

--[[
cs_pet_setskillin 607 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
		buffs 	1 : *integer
	}
}
]]
function server.cs_pet_setskillin(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.pet:SetSkillIn(msg.id)
end

--[[
# 设置展示的宠物
cs_pet_setshow 608 {
	request {
		id 		0 : integer
	}
}
]]
function server.cs_pet_setshow(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 宠物捕捉
cs_pet_catch 621 {}
]]
function server.cs_pet_catch(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.catchPetMgr:DisposeCatch(player)
end

--[[
cs_pet_fly_addexp 609 {
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
function server.cs_pet_fly_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = player.pet:AddFlyexp(msg.id, msg.autoBuy)
    return player.pet:PackFlyAddexpReply(msg.id, ret)
end

--[[
#宠物飞升重置
cs_pet_fly_restore 610 {
	request {
		id 		0 : integer
	}
}
]]
function server.cs_pet_fly_restore(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.pet:RestoreFlypet(msg.id)
end
