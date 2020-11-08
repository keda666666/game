local server = require "server"
local lua_app = require "lua_app"

local MapMgr = {}

function MapMgr:Init()
	self.playerlist = {}
	self.mainplayerlist = {}
end

function MapMgr:GetMapid(dbid)
	return self.playerlist[dbid]
end

function MapMgr:InMap(dbid, mapid)
	return self:Call(mapid, "InMap", dbid, mapid)
end

function MapMgr:Enter(dbid, mapid)
	local ret = self:Call(mapid, "Enter", dbid, mapid, 0, 0)
	if ret then
		self.playerlist[dbid] = mapid
	end
	return ret
end

function MapMgr:Leave(dbid, mapid)
	local ret = self:Call(mapid, "LogicLeave", dbid)
	if ret then
		self.playerlist[dbid] = nil
	end
	return ret
end

function MapMgr:SetPlayerMapid(dbid, mapid)
	self.playerlist[dbid] = mapid
end

function MapMgr:SetPlayerMainMapid(dbid, mapid)
	self.mainplayerlist[dbid] = mapid
end

function MapMgr:Move(dbid, mapid, x, y)
	self:Send(mapid, "Move", mapid, dbid, x, y)
end

function MapMgr:Fly(dbid, mapid, x, y)
	self:Send(mapid, "Fly", mapid, dbid, x, y)
end

function MapMgr:SetTitle(dbid, mapid, titleid)
	self:Send(mapid, "SetTitle", dbid, titleid)
end

function MapMgr:SetShow(dbid, shows)
	if self.mainplayerlist[dbid] then
		self:Send(self.mainplayerlist[dbid], "SetShow", dbid, shows)
	end
end

function MapMgr:SetStatus(dbid, status)
	local mapid = self.playerlist[dbid]
	if mapid then
		self:Send(mapid, "SetStatus", dbid, status)
	end
	
	local mainmapid = self.mainplayerlist[dbid]
	if mainmapid then
		self:Send(mainmapid, "SetStatus", dbid, status)
	end
end

function MapMgr:IsCross(mapid)
	if not server.kfBossCenter:EnterCrossMap(mapid) then
		return false
	end
	return true
end

function MapMgr:Call(mapid, funcname, ...)
	local map = server.configCenter.MapConfig[mapid]
	if not map then return end
	if map.cross == 1 and self:IsCross(mapid) then
		return server.serverCenter:CallDtb("war", "MapCall", funcname, ...)
	else
		return server.serverCenter:CallLocal("war", "MapCall", funcname, ...)
	end
end

function MapMgr:Send(mapid, funcname, ...)
	local map = server.configCenter.MapConfig[mapid]
	if not map then return end
	if map.cross == 1 then
		server.serverCenter:SendDtb("war", "MapSend", funcname, ...)
	else
		server.serverCenter:SendLocal("war", "MapSend", funcname, ...)
	end
end

function server.MapCall(src, funcname, ...)
	return lua_app.ret(server.mapMgr[funcname](server.mapMgr, ...))
end

function server.MapSend(src, funcname, ...)
	server.mapMgr[funcname](server.mapMgr, ...)
end


server.SetCenter(MapMgr, "mapMgr")
return MapMgr