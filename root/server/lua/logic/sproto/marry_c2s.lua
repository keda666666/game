--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求结婚
cs_marry_propose 8102 {
	request {
		targetid		0 : integer
		grade			1 : integer
		spouse			2 : integer 	# 1夫君 2妻子
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_propose(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:Propose(msg)}
end

--[[
# 回应
cs_marry_answer 8103 {
	request {
		agree		0 : integer		# 答应或拒绝 1 0
		fromid		1 : integer		
	}
}
]]
function server.cs_marry_answer(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:Answer(msg.agree, msg.fromid)
end

--[[
# 获得结婚对象状态
cs_marry_friends 8101 {}
]]
function server.cs_marry_friends(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:SendFrinds()
    player.marry:GetMarryInfo()
end

--[[
# 贺礼
cs_marry_greeting 8104 {
	request {
		dbid		0 : integer
		quantity	1 : integer
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_greeting(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:SendGreeting(msg.dbid, msg.quantity)}
end

--[[
# 升级
cs_marry_levelup 8105 { }
]]
function server.cs_marry_levelup(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:LevelUp()
end

--[[
# 送花
cs_marry_flower 8106 {
	request {
		quantity	0 : integer
		count		1 : integer
		autobuy		2 : integer		#0不自动购买道具 1使用绑元宝 2使用绑元宝和元宝
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_flower(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:SendFlower(msg.quantity, msg.count, msg.autobuy)}
end

--[[
# 离婚
cs_marry_divorce 8107 { }
]]
function server.cs_marry_divorce(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:Divorce()
end

--[[
# 使用贺礼
cs_use_gift 8108 {
	request {
		quantity	0 : integer
		count 		1 : integer
	}
}
]]
function server.cs_use_gift(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:UseGift(msg.quantity, msg.count)
end

--[[
# 获得恩爱信息
cs_marry_love_info 8109 {}
]]
function server.cs_marry_love_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:GetLoveInfo()
end

--[[
# 使用恩爱互动
cs_marry_love_use 8110 {
	request {
		lovetype	0 : integer
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_love_use(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:LoveUse(msg.lovetype)}
end

--[[
# 恢复恩爱次数
cs_marry_love_revert 8111 {
	request {
		lovetype	0 : integer
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_love_revert(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:LoveRevert(msg.lovetype)}
end

--[[
# 房屋升阶
cs_marry_house_addexp 8112 {}
]]
function server.cs_marry_house_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:HouseAddExp()
end

--[[
# 房屋装修
cs_marry_house_grade 8113 {
	request {
		grade			0 : integer
	}
	response {
		ret 			0 : integer
	}
}
]]
function server.cs_marry_house_grade(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {ret = player.marry:HouseUpGrade(msg.grade)}
end

--[[
# 使用伴侣的共享房屋升阶
cs_marry_house_use_partner_up 8114 { }
]]
function server.cs_marry_house_use_partner_up(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.marry:HouseUsePartner()
end
