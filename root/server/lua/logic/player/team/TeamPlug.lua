local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local TeamPlug = oo.class()

function TeamPlug:ctor(player)
	self.player = player
end


function TeamPlug:onLevelUp(oldlevel, level)
	server.teamMgr:onLevelUp(self.player, oldlevel, level)
end

server.playerCenter:SetEvent(TeamPlug, "team")
return TeamPlug