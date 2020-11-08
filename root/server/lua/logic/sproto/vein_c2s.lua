--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#经脉升级
cs_vein_Breakthrough 15001 {
	request {}
}
]]
function server.cs_vein_Breakthrough(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if server.funcOpen:Check(player, 30) then
    	player.role.vein:Breakthrough()
    end
end
