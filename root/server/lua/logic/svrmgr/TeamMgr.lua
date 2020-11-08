local server = require "server"
local lua_app = require "lua_app"
local RaidCheck = require "resource.RaidCheck"
local tbname = "players"

local TeamMgr = {}
local _MaxCount = 3

function TeamMgr:Call(raidtype, funcname, ...)
	if RaidCheck:CheckCross(raidtype) then
		lua_app.log_info("-------------------------999:",funcname)
		return server.serverCenter:CallDtb("war", "TeamCall", funcname, ...)
	else
		return server.serverCenter:CallLocal("war", "TeamCall", funcname, ...)
	end
end

function TeamMgr:Send(raidtype, funcname, ...)
	if RaidCheck:CheckCross(raidtype) then
		server.serverCenter:SendDtb("war", "TeamSend", funcname, ...)
	else
		server.serverCenter:SendLocal("war", "TeamSend", funcname, ...)
	end
end

function TeamMgr:Init()
	self.palyerraidtype = {}
	self.onlinelist = {}
	self.offlinelist = {}
end

function TeamMgr:GetMemberInfo(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if player then
		local packinfo = server.dataPack:SimpleFightInfo(player)
		local baseinfo = {
			dbid = dbid,
			power = player.cache.totalpower,
			name = player.cache.name,
			level = player.cache.level,
			job = player.cache.job,
			sex = player.cache.sex,
			guildid = player.cache.guildid,
		}
		return {packinfo = packinfo, baseinfo = baseinfo}
	else
		return
	end
end

function TeamMgr:GetGuildid(dbid, raidtype)
	if raidtype == server.raidConfig.type.GuildFb or 
		raidtype == server.raidConfig.type.GuildMine or 
		raidtype == server.raidConfig.type.Guildwar then
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		return player.cache.guildid
	else
		return 1
	end
end

-- 获取我加入的队伍
function TeamMgr:GetTeamInfo(dbid)
	self:Send(self.palyerraidtype[dbid], "SendTeamInfo", dbid)
end

-- 获取副本的队伍列表
function TeamMgr:GetTeamList(dbid, raidtype, level)
	self:Send(raidtype, "SendTeamList", dbid, raidtype, level, self:GetGuildid(dbid, raidtype))
end

-- 创建队伍
function TeamMgr:Create(dbid, raidtype, level)
	lua_app.log_info("--------3-------：", dbid,level)
	if not RaidCheck:Check(dbid, raidtype, level) then
		return false
	end

	local memberinfo = self:GetMemberInfo(dbid)
    if memberinfo then
	lua_app.log_info("--------33-------：", dbid,level)
    	self.palyerraidtype[dbid] = raidtype
		local ret = self:Call(raidtype, "Create", memberinfo, raidtype, level, 
			self:GetGuildid(dbid, raidtype), self:GetWaitRobots(dbid, raidtype, level, {}))
		if ret then
			server.chatCenter:NoticeFb(raidtype, dbid, level)
		end
		return ret
	else
	lua_app.log_info("--------333-------：", dbid,level)
		return false
	end
end

-- 快速加入队伍
function TeamMgr:QuickJoin(dbid, raidtype, level)
	if not RaidCheck:Check(dbid, raidtype, level) then
		return false
	end

	local memberinfo = self:GetMemberInfo(dbid)
    if memberinfo then
    	self.palyerraidtype[dbid] = raidtype
		return self:Call(raidtype, "QuickJoin", memberinfo, raidtype, level, self:GetGuildid(dbid, raidtype))
	else
		return false
	end
end

-- 加入队伍
function TeamMgr:Join(dbid, leaderid, raidtype, level)
	if not RaidCheck:Check(dbid, raidtype, level) then
		return false
	end

	local memberinfo = self:GetMemberInfo(dbid)
    if memberinfo then
    	self.palyerraidtype[dbid] = raidtype
		return self:Call(raidtype, "Join", memberinfo, leaderid, raidtype, level, self:GetGuildid(dbid, raidtype))
	else
		return false
	end
end

-- 离开队伍
function TeamMgr:Leave(dbid, logout)
	if self.palyerraidtype[dbid] then
		self:Send(self.palyerraidtype[dbid], "Leave", dbid, logout)
		self.palyerraidtype[dbid] = nil
	end
end

-- 解散队伍
function TeamMgr:Dismiss(dbid, raidtype, level)
	return self:Call(raidtype, "Dismiss", dbid, raidtype, level, self:GetGuildid(dbid, raidtype))
end

-- 踢人
function TeamMgr:Kick(dbid, memberid, raidtype, level)
	if dbid == memberid then return false end
	return self:Call(raidtype, "Kick", dbid, memberid, raidtype, level, self:GetGuildid(dbid, raidtype))
end

-- 快速加入或创建
function TeamMgr:Quick(dbid, raidtype, level)
	if not RaidCheck:Check(dbid, raidtype, level) then
		return false
	end
	
	local memberinfo = self:GetMemberInfo(dbid)
    if memberinfo then
    	self.palyerraidtype[dbid] = raidtype
		local ret, iscreate = self:Call(raidtype, "Quick", memberinfo, raidtype, level, 
			self:GetGuildid(dbid, raidtype), self:GetWaitRobots(dbid, raidtype, level, {}))
		if iscreate then
			server.chatCenter:NoticeFb(raidtype, dbid, level)
		end
		return ret
	else
		return false
	end
end

-- 进入战斗
function TeamMgr:Fight(dbid, raidtype, level, ext)
	local ret = self:Call(raidtype, "Fight", dbid, raidtype, level, self:GetGuildid(dbid, raidtype), ext)
	return ret
end

-- 客户端自己呼叫机器人
function TeamMgr:ClientCallRobot(dbid, raidtype, level)
	local robots = self:GetWaitRobots(dbid, raidtype, level, {})
	if robots and #robots > 0 then
		self:Send(raidtype, "ClientAddRobotList", dbid, robots)
	end
end

-- 战斗服呼叫机器人去填充队伍
function TeamMgr:CallRobot(raidtype, calllist)
	for _, back in ipairs(calllist) do
		back.robots = self:GetWaitRobots(back.leaderid, back.raidtype, back.level, back.kicklist, true)
	end

	self:Send(raidtype, "AddRobotList", calllist)
end

function TeamMgr:SetCondition(dbid, raidtype, level, needpower)
	if needpower <= 0 then return end
	self:Send(raidtype, "SetCondition", dbid, raidtype, level, self:GetGuildid(dbid, raidtype), needpower)
end

function TeamMgr:onLogout(player)
	server.teamMgr:Leave(player.dbid, true)
	local level = player.cache.level
	self.onlinelist[level] = self.onlinelist[level] or {}
	self.onlinelist[level][player.dbid] = nil

	self.offlinelist[level] = self.offlinelist[level] or {}
	self.offlinelist[level][player.dbid] = {guildid = player.cache.guildid}
end

function TeamMgr:onLogin(player)
	local level = player.cache.level
	self.offlinelist[level] = self.offlinelist[level] or {}
	self.offlinelist[level][player.dbid] = nil

	self.onlinelist[level] = self.onlinelist[level] or {}
	self.onlinelist[level][player.dbid] = {guildid = player.cache.guildid}
end

function TeamMgr:onLevelUp(player, oldlevel, level)
	self.onlinelist[oldlevel] = self.onlinelist[oldlevel] or {}
	self.onlinelist[oldlevel][player.dbid] = nil

	self.onlinelist[level] = self.onlinelist[level] or {}
	self.onlinelist[level][player.dbid] = {guildid = player.cache.guildid}
end

-- 获得预备机器人
function TeamMgr:GetWaitRobots(dbid, raidtype, level, exclude, isoffline)
	local waitrobots = {}

	if not RaidCheck:CheckNeedRobot(raidtype) then
		return waitrobots
	end

	local function _CheckLevelRobot(list, lv)
		if list[lv] then
			for playerid, playerinfo in pairs(list[lv]) do
				if playerid ~= dbid and
					not exclude[playerid] and
					RaidCheck:CheckRobot(dbid, playerinfo, raidtype, level) then
					table.insert(waitrobots, self:GetMemberInfo(playerid))
				end
				if #waitrobots >= _MaxCount then
					return
				end
			end
		end
	end

	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		return waitrobots
	end
	-- local level = player.cache.level
	if raidtype == server.raidConfig.type.CrossTeamFb then
		for i=1, 100 do
			local lv = level + i - 1
			_CheckLevelRobot(self.onlinelist, lv)
			if #waitrobots >= _MaxCount then
				return waitrobots
			end
		end

		if isoffline then
			for i=1, 100 do
				local lv = level + i - 1
				_CheckLevelRobot(self.offlinelist, lv)
				if #waitrobots >= _MaxCount then
					return waitrobots
				end
			end
		end
	elseif raidtype == server.raidConfig.type.GuildFb then
		local players = player.guild:GetPlayers()
		if #players > 0 then
			for i=1,5 do
				local guildplayer = players[math.random(#players)]
				table.insert(waitrobots, self:GetMemberInfo(guildplayer.playerid))
			end
			return waitrobots
		end
	end

	return waitrobots
end

function server.TeamCall(src, funcname, ...)
	return lua_app.ret(server.teamMgr[funcname](server.teamMgr, ...))
end

function server.TeamSend(src, funcname, ...)
	server.teamMgr[funcname](server.teamMgr, ...)
end


server.SetCenter(TeamMgr, "teamMgr")
return TeamMgr
