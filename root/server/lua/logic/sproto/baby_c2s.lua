--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 灵童激活
cs_baby_active 8201 {
	request {
		sex		0 : integer
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_baby_active(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby:Active(msg.sex)
end

--[[
# 升级天赋
cs_baby_addgift 8202 {
	request {
	}
	response {
		ret 	0 : boolean
		exp		1 : integer
		level	2 : integer
	}
}
]]
function server.cs_baby_addgift(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby:AddGift()
end

--[[
cs_baby_rename 8203 {
	request {
		name 	1 : string
	}
	response {
		ret 	0 : boolean
		name 	1 : string
	}
}
]]
function server.cs_baby_rename(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby:Rename(msg.name)
end

--[[
cs_baby_refreshskill 8204 {
	request {
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
function server.cs_baby_refreshskill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby:RefreshSkill(msg.type, msg.locklist, msg.autoBuy)
end

--[[
cs_baby_setskillin 8205 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
		buffs 	1 : *integer
	}
}
]]
function server.cs_baby_setskillin(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby:SetSkillIn()
end

--[[
#逆命
cs_baby_start_get 8206 {
	request {
		num 		0 : integer #次数
	}
	response {
		ret 		0 : boolean #
		num 		1 : integer #次数
		cost 		2 : integer #花费
		star 		3 : integer #当前等级
		data 		4 : *baby_start_data #命格列表
		msgData 	5 : *baby_star_msg #灵童命格公告
	}
}
]]
function server.cs_baby_start_get(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby.babyStar:GetStar(msg.num)
end

--[[
#使用
cs_baby_start_use 8207 {
	request {
		id 		0 : integer #道具id
		pos 	1 : integer #装到第几个位置
	}
	response {
		ret 	0 : boolean
		pos 	1 : integer #装到第几个位置
		no 		2 : integer #装上的no
	}
}
]]
function server.cs_baby_start_use(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby.babyStar:Use(msg.id, msg.pos)
end

--[[
#升级
cs_baby_start_up_lv 8208 {
	request {
		pos 	1 : integer #升级第几个位置上的
	}
	response {
		ret 	0 : boolean
		pos 	1 : integer #装到第几个位置
		no 		2 : integer #装上的no
	}
}
]]
function server.cs_baby_start_up_lv(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby.babyStar:UpLv(msg.pos)
end

--[[
#分解
cs_baby_start_smelt 8209 {
	request {
		idList 	1 : *baby_start_smelt #需要分解的列表
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_baby_start_smelt(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby.babyStar:Smelt(msg.idList)
end

--[[
#点亮混元
cs_baby_start_light 8210 {
	request {
		
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_baby_start_light(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.baby.babyStar:Light()
end
