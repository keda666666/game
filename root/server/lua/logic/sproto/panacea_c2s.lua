--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 丹药使用
cs_panacea_use 16001 {
	request {
		posid			0 : integer			#请求id
	}
}
]]
function server.cs_panacea_use(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if server.funcOpen:Check(player, 29) then
    	player.role.panacea:UsePanacea(msg.posid)
    end
end
