--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 玩家进入地图
cs_map_enter 23001 {
	request {
		mapid 		0 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_map_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.mapMgr:Enter(player.dbid, msg.mapid)
    return {ret = ret}
end

--[[
# 玩家主动退出地图
cs_map_leave 23002 {
	request {
		mapid 		0 : integer
	}
	response {
        ret 		0 : boolean
    }
}
]]
function server.cs_map_leave(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret = server.mapMgr:Leave(player.dbid, msg.mapid)
    return {ret = ret}
end

--[[
# 玩家移动
cs_map_move 23003 {
	request {
		mapid 		0 : integer
		x			1 : integer
		y			2 : integer
	}
}
]]
function server.cs_map_move(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.mapMgr:Move(player.dbid, msg.mapid, msg.x, msg.y)
end

--[[
# 玩家玩家瞬移
cs_map_fly 23004 {
	request {
		mapid 		0 : integer
		x			1 : integer
		y			2 : integer
	}
}
]]
function server.cs_map_fly(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.mapMgr:Fly(player.dbid, msg.mapid, msg.x, msg.y)
end

--[[
cs_map_maincity_channel_info 23031 {
	request {

	}
	response {
		channels 		0 : *maincity_channel_data
	}
}
]]
function server.cs_map_maincity_channel_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	channels = server.maincityMgr:GetChannelMsg()
	}
end

--[[
# 玩家进入主城
cs_map_maincity_enter 23032 {
	request {
		channelId 		0 : integer  #线路Id
	}
	response {
		ret 			0 : boolean
	}
}
]]
function server.cs_map_maincity_enter(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.maincityMgr:Enter(player.dbid, msg.channelId)
	}
end

--[[
# 玩家膜拜
cs_map_maincity_worship 23033 {
	request {
		type 			0 : integer 	#1=普通，2=要钱
	}
	response {
		ret 			0 : boolean
	}
}
]]
function server.cs_map_maincity_worship(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = server.maincityMgr:WorshipOnce(player.dbid, msg.type)
	}
end
