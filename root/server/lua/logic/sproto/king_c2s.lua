--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求参加跨服争霸
cs_king_join 24001 {
	request {

	} 
	response {
       ret 		0 : boolean
    }
}
]]
function server.cs_king_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.kingMgr:Join(player)
    return {ret = ret}
end

--[[
# 请求城池数据
cs_king_city_data 24002 {
	request {
		camp 		0 : integer # 0主城 或边城：1人 2仙 3魔
	}
}
]]
function server.cs_king_city_data(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:GetCityData(player.dbid, msg.camp)
end

--[[
# 参与守卫
cs_king_city_guard 24003 {
	request {
		camp 		0 : integer # 0主城 或边城：1人 2仙 3魔
	}
}
]]
function server.cs_king_city_guard(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:Guard(player, msg.camp)
end

--[[
# 攻城
cs_king_city_attack 24004 {
	request {
		camp 		0 : integer # 0主城 或边城：1人 2仙 3魔
	}
}
]]
function server.cs_king_city_attack(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:AttackCity(player, msg.camp)
end

--[[
# 自由pk
cs_king_pk 24005 {
	request {
		targetid 		0 : integer
	}
}
]]
function server.cs_king_pk(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:PK(player, msg.targetid)
end

--[[
# 花钱复活
cs_king_pay_revive 24006 {
	request { }
}
]]
function server.cs_king_pay_revive(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:PayRevive(player.dbid)
end

--[[
# 退出游戏
cs_king_leave 24007 {
	request { }
}
]]
function server.cs_king_leave(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:Leave(player.dbid)
end

--[[
#玩家领取积分奖励
cs_king_get_point_reward 24008 {
	request {
		pointtype 			0 : integer 	# 积分类型 1王城积分 2个人积分
		index				1 : integer		# 配置索引
	}
}
]]
function server.cs_king_get_point_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:GetPointReward(player.dbid, msg.pointtype, msg.index)
end

--[[
#玩家积分数据
cs_king_point_data 24009 {
	request { }
}
]]
function server.cs_king_point_data(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:GetPointData(player.dbid)
end

--[[
#玩家变身
cs_king_transform 24010 {
	request { }
}
]]
function server.cs_king_transform(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:Transform(player.dbid)
end

--[[
#我在守的城 
cs_king_my_guard_city 24011 {
	request { }
}
]]
function server.cs_king_my_guard_city(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingMgr:GetMyGuard(player.dbid)
end

--[[
#组队招募 
cs_king_team_recruit 24012 {
	request { }
}
]]
function server.cs_king_team_recruit(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if not server.chatCenter:EmitTeamRecruit(player.dbid) then return end
    server.kingMgr:TeamRecruit(player.dbid)
end
