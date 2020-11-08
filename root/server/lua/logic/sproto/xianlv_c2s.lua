--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 仙侣激活
cs_xianlv_active 701 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_xianlv_active(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.xianlv:Active(msg.id)
end

--[[
cs_xianlv_outbound 702 {
	request {
		first	0 : integer
		second	1 : integer
	}
}
]]
function server.cs_xianlv_outbound(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.xianlv:OutBound(msg.first, msg.second)
end

--[[
cs_xianlv_addexp 703 {
	request {
		id 		0 : integer
		autoBuy	1 : integer
	}
	response {
		ret 	0 : boolean
		exp		1 : integer
		level	2 : integer
	}
}
]]
function server.cs_xianlv_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.xianlv:AddExp(msg.id, msg.autoBuy)
end

--[[
cs_xianlv_upstar 704 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
		star	1 : integer
	}
}
]]
function server.cs_xianlv_upstar(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.xianlv:UpStar(msg.id)
end
