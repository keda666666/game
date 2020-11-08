--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 仙君激活
cs_xianjun_active 76501 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_xianjun_active(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.xianjun:Active(msg.id)
end

--[[
cs_xianjun_outbound 76502 {
	request {
		first	0 : integer
		second	1 : integer
	}
}
]]
function server.cs_xianjun_outbound(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.xianjun:OutBound(msg.first, msg.second, msg.third, msg.four)
end

--[[
cs_xianjun_addexp 76503 {
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
function server.cs_xianjun_addexp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.xianjun:AddExp(msg.id, msg.autoBuy)
end

--[[
cs_xianjun_upstar 76504 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
		star	1 : integer
	}
}
]]
function server.cs_xianjun_upstar(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	return player.xianjun:UpStar(msg.id)
end
