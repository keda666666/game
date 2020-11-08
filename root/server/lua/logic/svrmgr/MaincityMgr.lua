local server = require "server"
local lua_app = require "lua_app"

local MaincityMgr = {}

function MaincityMgr:Init()
	self.playerlist = {}
	self.worshiplist = {}
end

--选线路时调用
function MaincityMgr:Enter(dbid, channelId)
	local ret = self:Call("Enter", dbid, channelId)
	if ret then
		self.playerlist[dbid] = channelId
	end
	return ret
end

function MaincityMgr:GetChannelMsg()
	return self:Call("GetChannelMsg")
end

--膜拜一次
function MaincityMgr:WorshipOnce(dbid, type)
	return self:Call("WorshipOnce", dbid, type)
end

function MaincityMgr:Debug(dbid, ...)
	self:Call("Debug", dbid, ...)
end

function MaincityMgr:Call(funcname, ...)
	return server.serverCenter:CallLocal("war", "MaincityCall", funcname, ...)
end

function MaincityMgr:Send(funcname, ...)
	server.serverCenter:SendLocal("war", "MaincitySend", funcname, ...)
end

server.SetCenter(MaincityMgr, "maincityMgr")
return MaincityMgr