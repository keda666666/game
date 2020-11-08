--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 激活称号
cs_effect_title_activate 14001 {
	request {
		id			0 : integer
	}
}
]]
function server.cs_effect_title_activate(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.titleeffect:ActivatePart(msg.id)
end

--[[
# 改变称号
cs_effect_title_change 14002 {
	request {
		id			0 : integer
	}
}
]]
function server.cs_effect_title_change(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.titleeffect:ChangePart(msg.id)
end

--[[
# 激活皮肤
cs_effect_skin_activate 14011 {
	request {
		id			0 : integer
	}
}
]]
function server.cs_effect_skin_activate(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.skineffect:ActivatePart(msg.id)
end

--[[
# 改变皮肤
cs_effect_skin_change 14012 {
	request {
		id			0 : integer
	}
}
]]
function server.cs_effect_skin_change(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.skineffect:ChangePart(msg.id)
end
