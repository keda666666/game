--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
cs_rechargew_setpop 6401 {
	request {
		payType			0 : integer
		gid				1 : integer
		nopop			2 : boolean
	}
}
]]
function server.cs_rechargew_setpop(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.heavenGifts:SetPop(player, msg.payType, msg.gid, msg.nopop)
end

--[[
cs_rechargew_getawards 6402 {
	request {
		payType			0 : integer
		gid				1 : integer
		index			2 : integer
	}
}
]]
function server.cs_rechargew_getawards(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.heavenGifts:GetAward(player, msg.payType, msg.gid, msg.index)
end
