local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local MapConfig = require "resource.MapConfig"

local Map = oo.class()

function Map:ctor(mapid, line)
	self.mapid = mapid
	self.line = line
	self.playerlist = {}
end

function Map:Release()

end

function Map:Enter(dbid, x, y, status)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then
		return false	
	end
	local baseinfo = player:BaseInfo()
	local playerinfo = {
		info = baseinfo,
		serverid = player.nowserverid,
		x = x, 
		y = y, 
		movetime = 0, 
		status = status or MapConfig.status.Act}
	local msg = {
		mapid = self.mapid,
		x = x,
		y = y,
		myself = self:GetEntityMsg(playerinfo),
		entitylist = self:PlayerListMsg(),
	}
	server.sendReqByDBID(dbid, "sc_map_enter", msg)
	self.playerlist[dbid] = playerinfo
	self:BroadcastPlayerEnter(playerinfo)
	server.onevent(server.event.entermap, dbid, self.mapid, self.line, x, y)

	print("Map:Enter------", self:Count(), self.mapid, self.line, baseinfo.name, x, y, dbid)
	return true
end

function Map:Leave(dbid)
	local mapplayer = self.playerlist[dbid]
	if mapplayer then
		server.onevent(server.event.leavemap, mapplayer.info.dbid, self.mapid, self.line, mapplayer.x, mapplayer.y)
		self:BroadcastPlayerLeave(dbid)
		self.playerlist[dbid] = nil
	end
	print("Map:Leave------", self:Count(), self.mapid, self.line, dbid)
	return true
end

function Map:Move(dbid, x, y)
	local now = lua_app.now()
	local playerinfo = self.playerlist[dbid]
	if playerinfo and MapConfig.CanMoveStatus[playerinfo.status] then
		playerinfo.x = x
		playerinfo.y = y
		if playerinfo.movetime ~= now then
			self:BroadcastPlayerMove(dbid, x, y)
		end
		playerinfo.movetime = now
	end
end

function Map:Fly(dbid, x, y, force)
	local playerinfo = self.playerlist[dbid]
	if playerinfo and (force or MapConfig.CanMoveStatus[playerinfo.status]) then
		playerinfo.x = x
		playerinfo.y = y
		self:BroadcastPlayerFly(dbid, x, y)
	end
	print("Map:Fly------", self.mapid, self.line, dbid, x, y, playerinfo.status)
end

function Map:SetStatus(dbid, status)
	local playerinfo = self.playerlist[dbid]
	if playerinfo and playerinfo.status ~= status then
		playerinfo.status = status
		server.broadcastList("sc_map_player_status", {
				mapid	= self.mapid,
				id		= dbid,
				status 	= status,
			}, self.playerlist)
	end
end

function Map:GetStatus(dbid)
	local playerinfo = self.playerlist[dbid]
	if playerinfo then
		return playerinfo.status
	else
		return 0
	end
end

-- 地图人数
function Map:Count()
	local count = 0
	for _ in pairs(self.playerlist) do
		count = count + 1
	end
	return count
end

-- 地图玩家
function Map:Players()
	local players = {}
	for dbid, _ in pairs(self.playerlist) do
		table.insert(players, dbid)
	end
	return players
end

function Map:SetTitle(dbid, titleid)
	local playerinfo = self.playerlist[dbid]
	if playerinfo then
		local shows = playerinfo.info.shows
		for i=1,6 do
			shows[i] = shows[i] or 0
		end
		shows[6] = titleid

		self:BroadcastPlayerUpdate(dbid)
	end
	print("Map:SetTitle------", dbid, titleid)
end

function Map:SetShow(dbid, shows)
	local playerinfo = self.playerlist[dbid]
	if playerinfo then
		for i=1,6 do
			playerinfo.info.shows[i] = shows[i] or playerinfo.info.shows[i]
		end

		self:BroadcastPlayerUpdate(dbid)
	end
	print("Map:SetShow------", dbid)
end

function Map:GetEntityMsg(playerinfo)
	local msg = {
		id = playerinfo.info.dbid,
		x = playerinfo.x,
		y = playerinfo.y,
		status = playerinfo.status,
		name = playerinfo.info.name,
		level = playerinfo.info.level,
		job = playerinfo.info.job,
		sex = playerinfo.info.sex,
		power = playerinfo.info.totalpower,
		shows = playerinfo.info.shows,
		guildid	= playerinfo.info.guildid,
    	guildname = playerinfo.info.guildname,
    	serverid = playerinfo.serverid,
	}
	return msg
end

function Map:PlayerListMsg()
	local list = {}
	for dbid, playerinfo in pairs(self.playerlist) do
		local msg = self:GetEntityMsg(playerinfo)
		table.insert(list, msg)
	end
	return list
end

function Map:BroadcastPlayerEnter(playerinfo)
	local msg = {
		entity = self:GetEntityMsg(playerinfo),
		mapid = self.mapid,
	}
	server.broadcastList("sc_map_other_enter", msg, self.playerlist, playerinfo.info.dbid)
	-- for playerid, _ in pairs(self.playerlist) do
	-- 	if playerid ~= playerinfo.info.dbid then
	-- 		server.sendReqByDBID(playerid, "sc_map_other_enter", msg)
	-- 	end
	-- end
	print("Map:BroadcastPlayerEnter------")
end

function Map:BroadcastPlayerLeave(dbid)
	local msg = {
		id = dbid,
		mapid = self.mapid,
	}
	server.broadcastList("sc_map_other_leave", msg, self.playerlist)
	-- for playerid, _ in pairs(self.playerlist) do
	-- 	if playerid ~= dbid then
	-- 		server.sendReqByDBID(playerid, "sc_map_other_leave", msg)
	-- 	end
	-- end
	print("Map:BroadcastPlayerLeave------")
end

function Map:BroadcastPlayerMove(dbid, x, y)
	local msg = {
		id = dbid,
		x = x,
		y = y,
		mapid = self.mapid,
	}
	server.broadcastList("sc_map_other_move", msg, self.playerlist)
	-- for playerid, _ in pairs(self.playerlist) do
	-- 	if playerid ~= dbid then
	-- 		server.sendReqByDBID(playerid, "sc_map_other_move", msg)
	-- 	end
	-- end
end

function Map:BroadcastPlayerFly(dbid, x, y)
	local msg = {
		id = dbid,
		x = x,
		y = y,
		mapid = self.mapid,
	}
	server.broadcastList("sc_map_other_fly", msg, self.playerlist)
	-- for playerid, _ in pairs(self.playerlist) do
	-- 	if playerid ~= dbid then
	-- 		server.sendReqByDBID(playerid, "sc_map_other_fly", msg)
	-- 	end
	-- end
end

function Map:BroadcastPlayerUpdate(dbid)
	local playerinfo = self.playerlist[dbid]
	if playerinfo then
		server.broadcastList("sc_map_player_update", {
				id		= dbid,
				mapid	= self.mapid,
				player 	= self:GetEntityMsg(playerinfo)
			}, self.playerlist)
	end
end

function Map:Broadcast(name, msg)
	server.broadcastList(name, msg, self.playerlist)
end

return Map