--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#获取信息
cs_qualifyingMgr_info 22101 {
	request {
	}
}
]]
function server.cs_qualifyingMgr_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.qualifyingMgr:GetMsg(player.dbid)
end

--[[
#报名
cs_qualifyingMgr_sign_up 22102 {
	request {
	}
	response {
		ret			0 : boolean #成功/已报名
	}
}
]]
function server.cs_qualifyingMgr_sign_up(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local baseConfig = server.configCenter.XianDuMatchBaseConfig
    local openConfig = server.configCenter.FuncOpenConfig
    local lv = openConfig[baseConfig.openlv].conditionnum
    if player.cache.level < lv then return end
    return server.qualifyingMgr:Sign(player.dbid)
end

--[[
#下注
cs_qualifyingMgr_gamble 22104 {
	request {
		field 		0 : integer #那个组
		no 			1 : integer #对1下注还是2
		typ 		2 : integer #赌注是啥123对应押注配置
	}
	response {
		ret			0 : boolean #成功/重复下注
	}
}
]]
function server.cs_qualifyingMgr_gamble(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.qualifyingMgr:Gamble(player.dbid, msg.field, msg.no, msg.typ)
end

--[[
#观看录像
cs_qualifyingMgr_video 22105 {
	request {
		the 		0 : integer #几强
		field 		1 : integer #场次
		round 		2 : integer #第几回合123
	}
}
]]
function server.cs_qualifyingMgr_video(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.qualifyingMgr:Video(player.dbid,msg.the,msg.field,msg.round)
end

--[[
#海选排行榜
cs_qualifyingMgr_rank 22103 {
	request {
	}
	response {
		rank_data 		0 : *qualifyingMgr_rank_data #排行榜
		fightRecord 	1 : *qualifyingMgr_fight_data #战斗记录
		rankNo 			2 : integer #玩家排名,0则未进入排行榜
		point 			3 : integer #积分
	}
}
]]
function server.cs_qualifyingMgr_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.qualifyingMgr:Rank(player.dbid)
end

--[[
#获取场景数据,收到回复才能入场
cs_qualifyingMgr_map_info 22106 {
	request {
		}
}
]]
function server.cs_qualifyingMgr_map_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.qualifyingMgr:GetMiniMsg(player.dbid)
end

--[[
cs_qualifyingMgr_timeout 22107 {
	request {
	}
	response {
		ret			0 : boolean #成功/失败
		timeout 	1 : integer #下次战斗倒计时
	}
}
]]
function server.cs_qualifyingMgr_timeout(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.qualifyingMgr:GetTimeOut(player.dbid)
end
