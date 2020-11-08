local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local Teachers = oo.class()

function Teachers:ctor(player)
	self.player = player
end

-- function Teachers:onCreate()
-- 	self:onLoad()
-- end

-- function Teachers:onLoad()
-- end

function Teachers:onLevelUp(oldlevel, level)
	server.teachersCenter:UpdateData(self.player.dbid, level)
end

function Teachers:onInitClient()
	server.teachersCenter:UpdateOnLine(self.player.dbid, true)
	server.teachersCenter:SendMsg(self.player.dbid)
end

function Teachers:onLogout()
	server.teachersCenter:UpdateOnLine(self.player.dbid, false)
end

server.playerCenter:SetEvent(Teachers, "teachers")
return Teachers