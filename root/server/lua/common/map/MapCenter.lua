local server = require "server"
local lua_app = require "lua_app"
local Map = require "map.Map"
local RaidConfig = require "resource.RaidConfig"
local _RaidType = RaidConfig.type

local MapCenter = {}

function MapCenter:Init()
	self.maplist = {}
	self.playerlist = {}
	self.mainplayerlist = {}
end

function MapCenter:CheckMapData(mapid, line)
	self.maplist[mapid] = self.maplist[mapid] or {}
	self.maplist[mapid][line] = self.maplist[mapid][line] or Map.new(mapid, line)
end


local _GetLine = {}

_GetLine[_RaidType.KingCity] = function(dbid, mapid)
	return server.kingCenter:GetMapLine(dbid)
end

_GetLine[_RaidType.ClimbPK] = function(dbid, mapid)
	return server.climbCenter:GetMapLine(dbid, mapid)
end

_GetLine[_RaidType.GuildMap] = function(dbid, mapid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	return player.cache.guildid()
end

_GetLine[_RaidType.MainCity] = function(dbid, mapid)
	return server.maincityCenter:GetChannel(dbid)
end

_GetLine[_RaidType.Guildwar] = function(dbid, mapid)
	return server.guildwarCenter:GetMapLine(dbid)
end

_GetLine[_RaidType.GuildwarPk] = function(dbid, mapid)
	return server.guildwarCenter:GetMapLine(dbid)
end

local _GetPos = {}

_GetPos[_RaidType.GuildMap] = function()
	local GuildConfig = server.configCenter.GuildConfig
	local pos = GuildConfig.bron
	return pos[1], pos[2]
end

_GetPos[_RaidType.Qualifying] = function()
	local XianDuMatchBaseConfig = server.configCenter.XianDuMatchBaseConfig
	local pos = XianDuMatchBaseConfig.bronpos[math.random(2)]
	return pos[1], pos[2]
end

_GetPos[_RaidType.Guildwar] = function(mapid)
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local posCfg
	if mapid == GuildBattleBaseConfig.t_mapid then
		posCfg = GuildBattleBaseConfig.t_bronpos
	elseif mapid == GuildBattleBaseConfig.s_mapid then
		posCfg = GuildBattleBaseConfig.s_bronpos
	else
		posCfg = GuildBattleBaseConfig.l_bronpos
	end
	local randomIndex = math.random(1, #posCfg)
	return posCfg[randomIndex][1], posCfg[randomIndex][2]
end


function MapCenter:GetLine(dbid, mapid)
	local map = server.configCenter.MapConfig[mapid]
	if not map then
		print("MapCenter:GetLine no this map", mapid, dbid)
		return 1
	end
	if _GetLine[map.type] then
		return _GetLine[map.type](dbid, mapid)
	else
		return 1
	end
end

function MapCenter:GetPos(mapid)
	local map = server.configCenter.MapConfig[mapid]
	if not map then
		print("MapCenter:GetPos no this map", mapid)
		return false
	end
	if _GetPos[map.type] then
		return _GetPos[map.type](mapid)
	else
		return false
	end
end

function MapCenter:GetMap(mapid, dbid)
	local line = dbid and self:GetLine(dbid, mapid) or 1
	self:CheckMapData(mapid, line)
	return self.maplist[mapid][line]
end

function MapCenter:GetPlayerMap(mapid, dbid)
	local map = server.configCenter.MapConfig[mapid]
	if map.type == _RaidType.MainCity then
		return self.mainplayerlist[dbid]
	else
		return self.playerlist[dbid]
	end
end

function MapCenter:IsMainMap(mapid)
	local map = server.configCenter.MapConfig[mapid]
	return (map.type == _RaidType.MainCity)
end

function MapCenter:IsInMap(dbid)
	return self.playerlist[dbid] and true or false
end

-- 判断是否在地图
function MapCenter:InMap(dbid, mapid)
	local map = self.playerlist[dbid]
	if map and map.mapid == mapid then
		return true
	else
		return false
	end
end

function MapCenter:EnterMain(dbid, mapid, x, y, status)
	local ret = self:LogicEnterMain(dbid, mapid, x, y, status)
	if ret then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.server.mapMgr:SetPlayerMainMapid(dbid, mapid)
	end
	return ret
end

function MapCenter:LogicEnterMain(dbid, mapid, x, y, status)
	self:LeaveMain(dbid)
	local map = self:GetMap(mapid, dbid)
	self.mainplayerlist[dbid] = map
	return map:Enter(dbid, x, y, status)
end

function MapCenter:Enter(dbid, mapid, x, y, status)
	if self:IsMainMap(mapid) then
		return self:EnterMain(dbid, mapid, x, y, status)
	end
	local ret = self:LogicEnter(dbid, mapid, x, y, status)
	if ret then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player.server.mapMgr:SetPlayerMapid(dbid, mapid)
		end
	end
	return ret
end

function MapCenter:LogicEnter(dbid, mapid, x, y, status)
	if self:IsMainMap(mapid) then
		return self:LogicEnterMain(dbid, mapid, x, y, status)
	end
	local map = self:GetMap(mapid, dbid)
	self:Leave(dbid)
	local tx, ty = self:GetPos(mapid)
	if tx and ty then
		x, y = tx, ty
	end
	self.playerlist[dbid] = map
	return map:Enter(dbid, x, y, status)
end

function MapCenter:LeaveMain(dbid)
	local ret = self:LogicLeaveMain(dbid)
	if ret then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player.server.mapMgr:SetPlayerMainMapid(dbid)
		end
	end
	return ret
end

function MapCenter:LogicLeaveMain(dbid)
	local map = self.mainplayerlist[dbid]
	if map then
		map:Leave(dbid)
		self.mainplayerlist[dbid] = nil
	end
	return true
end

function MapCenter:Leave(dbid)
	local ret = self:LogicLeave(dbid)
	if ret then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.server.mapMgr:SetPlayerMapid(dbid)
	end
	return ret
end

function MapCenter:LogicLeave(dbid)
	local map = self.playerlist[dbid]
	if map then
		map:Leave(dbid)
		self.playerlist[dbid] = nil
	end
	return true
end

function MapCenter:Move(mapid, dbid, x, y)
	local map = self:GetPlayerMap(mapid, dbid)
	if map then
		map:Move(dbid, x, y)
	end
end

function MapCenter:Fly(mapid, dbid, x, y, force)
	local map = self:GetPlayerMap(mapid, dbid)
	if map then
		map:Fly(dbid, x, y, force)
	end
end

function MapCenter:Clear(mapid, line)
	local map = self.maplist[mapid] and self.maplist[mapid][line or 1]
	if not map then return end
	local players = {}
	for dbid, _ in pairs(map.playerlist) do
		players[dbid] = true
	end
	for dbid, _ in pairs(players) do
		self:Leave(dbid)
	end
end

function MapCenter:SetStatus(dbid, status)
	local map = self.playerlist[dbid]
	if map then
		map:SetStatus(dbid, status)
	end
	
	local mainmap = self.mainplayerlist[dbid]
	if mainmap then
		mainmap:SetStatus(dbid, status)
	end
end

function MapCenter:GetStatus(dbid)
	local map = self.playerlist[dbid]
	if map then
		return map:GetStatus(dbid)
	else
		return 0
	end
end

function MapCenter:Broadcast(dbid, name, msg)
	local map = self.playerlist[dbid]
	if map then
		map:Broadcast(name, msg)
	end
end

function MapCenter:SetTitle(dbid, titleid)
	local map = self.playerlist[dbid]
	if map then
		map:SetTitle(dbid, titleid)
	end
end

function MapCenter:SetShow(dbid, shows)
	local map = self.mainplayerlist[dbid]
	if map then
		map:SetShow(dbid, shows)
	end

	local map = self.playerlist[dbid]
	if map then
		map:SetShow(dbid, shows)
	end
end

function MapCenter:Call(mapid, funcname, ...)
	local map = server.configCenter.MapConfig[mapid]
	if not map then return end
	if map.cross == 1 then
		return server.serverCenter:CallLogics("MapCall", funcname, ...)
	else
		return server.serverCenter:CallLocal("logic", "MapCall", funcname, ...)
	end
end

function MapCenter:onLogout(player)
	if not player then return end
	self:Leave(player.dbid)
	self:LeaveMain(player.dbid)
end

function MapCenter:Send(mapid, funcname, ...)
	local map = server.configCenter.MapConfig[mapid]
	if not map then return end
	if map.cross == 1 then
		server.serverCenter:SendLogics("MapCall", funcname, ...)
	else
		server.serverCenter:SendLocal("logic", "MapSend", funcname, ...)
	end
end

function server.MapCall(src, funcname, ...)
	return lua_app.ret(server.mapCenter[funcname](server.mapCenter, ...))
end

function server.MapSend(src, funcname, ...)
	server.mapCenter[funcname](server.mapCenter, ...)
end

server.SetCenter(MapCenter, "mapCenter")
return MapCenter