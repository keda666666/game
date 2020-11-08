--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#进入护送
cs_escort_enter 20001 {
	request {

	}
}
]]
function server.cs_escort_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.escort:Enter()
end

--[[
#刷新品质
cs_escort_refresh_quality 20002 {
	request {
		type 		0 : integer  #刷新类型 1=道具刷橙，2=货币刷橙，3=货币普通刷新
	}
}
]]
function server.cs_escort_refresh_quality(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.escort:RefreshByPay(msg.type)
end

--[[
#可拦截的列表
cs_escort_rob_list 20004 {
	request {

	}
	response {
		escortList 		0 : *escort_info
	}
}
]]
function server.cs_escort_rob_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	escortList = server.escortCenter:GetEscortList(player.dbid)
	}
end

--[[
#拦截
cs_escort_rob_perform 20005 {
	request {
		playerId 		0 : integer  #拦截玩家id
	}
}
]]
function server.cs_escort_rob_perform(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
   	player.escort:Rob(msg.playerId)
end

--[[
#复仇
cs_escort_avenge 20006 {
	request {
		recordId 		0 : integer  #记录Id
	}
}
]]
function server.cs_escort_avenge(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.escort:Avenge(msg.recordId)
end

--[[
#领取奖励
cs_escort_get_reward 20010 {
	request {

	}
}
]]
function server.cs_escort_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.escort:GrantReward()
end

--[[
#开始护送
cs_escort_perform 20015 {
	request {

	}
}
]]
function server.cs_escort_perform(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.escort:PerformEscort()
end

--[[
#护送完成
cs_escort_quick_complete 20003 {
	request {

	}
}
]]
function server.cs_escort_quick_complete(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.escortCenter:QuickCompleteEscort(player.dbid)
end

--[[
#拦截信息
cs_escort_catch_info 20016 {
	request {
		playerId 		0 : integer
	}
	response {
		escortInfo 		0 : escort_info 		#玩家护送信息
	}
}
]]
function server.cs_escort_catch_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	escortInfo = server.escortCenter:GetEscortInfo(player.dbid, msg.playerId),
    }
end
