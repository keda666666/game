
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_timer = require "lua_timer"

local KingArenaCenter = {}

function KingArenaCenter:Init()
	if not server.serverCenter:IsCross() then return end
	local opentime = server.configCenter.KingSportsBaseConfig.opentime
	self.opentimer = lua_timer.add_timer_week(opentime[1], -1, self.Open, self)
	self.closetimer = lua_timer.add_timer_week(opentime[2], -1, self.Close, self)
	self.isopen = false
	lua_app.add_update_timer(30000, self, "ServerStart")
end

function KingArenaCenter:ServerStart()
	if self:IsActivityDuration() then
		if not self.isopen then
			self:Resume()
		end
	else
		self:Close()
	end
end

local function _ConvertWeekTime(time)
	local ttime = lua_util.split(time, ":")
	local TW = tonumber(ttime[1])
	local TH = tonumber(ttime[2])
	local TM = tonumber(ttime[3])
	local TS = tonumber(ttime[4])
	return TW*3600*24 + TH*3600 + TM*60 + TS
end

function KingArenaCenter:IsActivityDuration()
	local opentime = server.configCenter.KingSportsBaseConfig.opentime
	local nowtimeOfWeek = _ConvertWeekTime(lua_app.week()..":"..os.date("%H:%M:%S"))
	local opentimeOfWeek = _ConvertWeekTime(os.date(opentime[1]))
	local closetimeOfWeek = _ConvertWeekTime(os.date(opentime[2]))
	return opentimeOfWeek < nowtimeOfWeek and nowtimeOfWeek < closetimeOfWeek
end

function KingArenaCenter:Open()
	self.matchlist = {}
	self.athleticsGroup = {}
	self.athleteinfos = {}
	self:CallKingArenaMgr("Open")
	self:CollectFightInfo()
	self.isopen = true
	lua_app.log_info("KingArenaCenter----------------------Open")
end

function KingArenaCenter:Resume()
	self.matchlist = {}
	self.athleticsGroup = {}
	self.athleteinfos = {}
	self:CallKingArenaMgr("Resume")
	self:CollectFightInfo()

	self.isopen = true
	self.rankdatas = false
	lua_app.log_info("KingArenaCenter----------------------Resume")
end

function KingArenaCenter:Close()
	self.rankdatas = false
	self.isopen = false

	self:SendKingArenaMgr("Close")
	if self.collecttimer then
		lua_app.del_local_timer(self.collecttimer)
		self.collecttimer = nil
	end
	lua_app.log_info("KingArenaCenter----------------------Close")
end

function KingArenaCenter:onInitClient(player)
	if self.isopen and self.matchlist[player.dbid] then
		self:SendMatchMsg(player.dbid)
	end
end

function KingArenaCenter:GetRankDatas()
	if not self.rankdatas then
		local serverlist = self:CallKingArenaMgr("LastFightData")
		local rankdatas = {}
		for serverid, playerlist in pairs(serverlist) do
			for dbid, info in pairs(playerlist) do
				table.insert(rankdatas, info)
			end
		end

		table.sort(rankdatas, function(currdata, latedata)
			local larger = currdata.grade >= latedata.grade and (
				currdata.grade > latedata.grade or
				currdata.wincount > latedata.wincount)
			return larger
		end)
		self.rankdatas = rankdatas
	end
	return self.rankdatas
end

function KingArenaCenter:CollectFightInfo()
	if self.collecttimer then
		lua_app.del_local_timer(self.collecttimer)
		self.collecttimer = nil
	end

	local serverlist = self:CallKingArenaMgr("LastFightData")
	for serverid, playerlist in pairs(serverlist) do
		for dbid, info in pairs(playerlist) do
			self.athleteinfos[dbid] = info
		end
	end

	self:DivideGroup()
	self.collecttimer = lua_app.add_update_timer(3600*1000, self, "CollectFightInfo")
	lua_app.log_info("update fightdata-------------------")
end

function KingArenaCenter:UpdateAthlete(playerinfo)
	local athlete = self.athleteinfos[playerinfo.dbid]
	local oldGroup = self.athleticsGroup[athlete.grade]
	oldGroup[playerinfo.dbid] = nil

	local newGroup = self.athleticsGroup[playerinfo.grade]
	newGroup[playerinfo.dbid] = playerinfo

	self.athleteinfos[playerinfo.dbid] = playerinfo
	self.rankdatas = false
end

function KingArenaCenter:DivideGroup()
	local KingSportsConfig = server.configCenter.KingSportsConfig
	local length = #KingSportsConfig
	self.athleticsGroup = lua_util.CreateArray(length)

	for __, athlete in pairs(self.athleteinfos) do
		local group = self.athleticsGroup[athlete.grade]
		group[athlete.dbid] = athlete
	end
end

local function _RandomMatch(group, playerinfo)
	local rivallist = lua_util.randTB(group, 2)
	for dbid, rival in pairs(rivallist) do
		if dbid ~= playerinfo.dbid then
			return rival
		end
	end
end

function KingArenaCenter:Match(playerinfo)
	local dbid = playerinfo.dbid
	if self.matchlist[dbid] then 
		self:SendMatchMsg(playerinfo.dbid)
		return 
	end

	local rival = self:NormalMatch(playerinfo)
	if not rival then
		rival = self:AllMatch(playerinfo)
	end

	self.matchlist[dbid] = rival
	self:SendMatchMsg(playerinfo.dbid)
end

function KingArenaCenter:NormalMatch(playerinfo)
	local matchCfg = server.configCenter.KingSportsConfig[playerinfo.grade].pytype
	local begenGrade = math.max(table.unpack(matchCfg))
	local endGrade = math.min(table.unpack(matchCfg))
	local rival
	for grade = begenGrade, endGrade, -1 do
		rival = _RandomMatch(self.athleticsGroup[grade], playerinfo)
		if rival then break end
	end
	return rival
end

function KingArenaCenter:AllMatch(playerinfo)
	local rival
	local gradeMax = #self.athleticsGroup
	local matchgrade = playerinfo.grade
	local increment = 1
	repeat
		local diffvalue = matchgrade - increment
		local grade = diffvalue > 0 and diffvalue or matchgrade - diffvalue
		rival = _RandomMatch(self.athleticsGroup[grade], playerinfo)
		increment = increment + 1
	until rival or gradeMax <= increment

	return rival
end

function KingArenaCenter:Enter(playerinfo)
	local rival = self.matchlist[playerinfo.dbid]
	if not rival then
		lua_app.log_info("enter necessary match rival.")
		return
	end
	local fightdata = playerinfo.fightdata
	fightdata.exinfo = {
		grade = playerinfo.grade,
		serverid = playerinfo.serverid,
		rival = rival.fightdata,
	}
	local ret = server.raidMgr:Enter(server.raidConfig.type.KingArena, playerinfo.dbid, fightdata)
	if ret then
		self.matchlist[playerinfo.dbid] = nil
	end
end

function KingArenaCenter:SendMatchMsg(dbid)
	local msg
	local rival = self.matchlist[dbid]
	if rival then
		local playerinfo = rival.fightdata.playerinfo
		msg = {
			type = true,
			id = rival.dbid,
			grade = rival.grade,
			star = rival.star,
			name = playerinfo.name,
			job = playerinfo.job,
			sex = playerinfo.sex,
			serverid = playerinfo.serverid,
		}
	else
		msg = {
			type = false
		}
	end
	msg.ladderType = 1
	server.sendReqByDBID(dbid, "sc_ladder_player_back", msg)
end

function KingArenaCenter:CallKingArenaMgr(funcname, ...)
	return server.serverCenter:CallLogicsMod("kingArenaMgr", funcname, ...)
end

function KingArenaCenter:SendKingArenaMgr(funcname, ...)
	server.serverCenter:SendLogicsMod("kingArenaMgr", funcname, ...)
end

function KingArenaCenter:TestPrint()
	table.ptable(self.athleticsGroup, 3)
end

server.SetCenter(KingArenaCenter, "kingArenaCenter")
return KingArenaCenter