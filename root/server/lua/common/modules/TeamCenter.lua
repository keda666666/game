local server = require "server"
local lua_app = require "lua_app"
local RaidCheck = require "resource.RaidCheck"
local EntityConfig = require "resource.EntityConfig"

local TeamCenter = {}
local _CallTime = 5000 --毫秒
local _AutoRobotTime = 10	--秒
local _MaxCount = 3

function TeamCenter:Call(raidtype, funcname, ...)
	if RaidCheck:CheckCross(raidtype) then
		return server.serverCenter:CallLogics("TeamCall", funcname, ...)
	else
		return {server.serverCenter:CallLocal("logic", "TeamCall", funcname, ...)}
	end
end

function TeamCenter:Send(raidtype, funcname, ...)
	if RaidCheck:CheckCross(raidtype) then
		server.serverCenter:SendLogics("TeamCall", funcname, ...)
	else
		server.serverCenter:SendLocal("logic", "TeamSend", funcname, ...)
	end
end

function TeamCenter:Init()
	--[[
		结构:self.teamlist
		self.teamlist[raidtype][level][guildid][leader] = team
		team = {playerlist, robotlist, kicklist, createtime}
		playerlist = {dbid1 = memberinfo1, dbid2 = memberinfo2, dbid3 = memberinfo3} 真实玩家
		robotlist = {dbid1 = memberinfo1, dbid2 = memberinfo2, dbid3 = memberinfo3} 镜像玩家
		memberinfo = {packinfo = packinfo, baseinfo = baseinfo}
		packinfo = 战斗pack
		baseinfo = {dbid, power, name, level, job, sex}
		
		kicklist[dbid] = kicktime

		结构:self.playerlist
		self.playerlist[dbid] = {leaderid = leader, raidtype = raidtype, level = level, guildid = guildid}

		结构:self.waitlist
		self.waitlist[raidtype][leaderid] = {raidtype = raidtype, level = level, guildid = guildid}
	]] 
	self.teamlist = {}
	self.playerlist = {}
	self.waitlist = {}
	self.observerlist = {}

	local function _CallRobot()
		self.calltimer = lua_app.add_timer(_CallTime, _CallRobot)
		self:CallRobot()
	end
	self.calltimer = lua_app.add_timer(_CallTime, _CallRobot)
end

function TeamCenter:CheckRaid(raidtype, level, guildid)
	level = level or 1
	guildid = guildid or 1
	if not self.teamlist[raidtype] then
		self.teamlist[raidtype] = {}
	end
	if not self.teamlist[raidtype][level] then
		self.teamlist[raidtype][level] = {}
	end
	if not self.teamlist[raidtype][level][guildid] then
		self.teamlist[raidtype][level][guildid] = {}
	end
end

function TeamCenter:CheckObserver(raidtype, level, guildid)
	level = level or 1
	guildid = guildid or 1
	if not self.observerlist[raidtype] then
		self.observerlist[raidtype] = {}
	end
	if not self.observerlist[raidtype][level] then
		self.observerlist[raidtype][level] = {}
	end
	if not self.observerlist[raidtype][level][guildid] then
		self.observerlist[raidtype][level][guildid] = {}
	end
end

function TeamCenter:GetObserver(raidtype, level, guildid)
	level = level or 1
	guildid = guildid or 1
	self:CheckObserver(raidtype, level, guildid)
	return self.observerlist[raidtype][level][guildid]
end

function TeamCenter:RemoveObserver(dbid)
	for _, raids in pairs(self.observerlist) do
		for _, levels in pairs(raids) do
			for _, guilds in pairs(levels) do
				guilds[dbid] = nil
			end
		end
	end
end

function TeamCenter:TeamInit()
	return {playerlist = {}, robotlist = {}, kicklist = {}, createtime = lua_app.now(), needpower = 0}
end

-- 根据副本类型和等级获得队伍列表
function TeamCenter:GetRaidTeamList(raidtype, level, guildid)
	level = level or 1
	guildid = guildid or 1
	self:CheckRaid(raidtype, level, guildid)
	return self.teamlist[raidtype][level][guildid]
end

-- 根据副本类型和等级和队长获得具体队伍
function TeamCenter:GetTeam(leaderid, raidtype, level, guildid)
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	return teamlist[leaderid]
end

function TeamCenter:SignPlayer(dbid, leaderid, raidtype, level, guildid)
	level = level or 1
	guildid = guildid or 1
	self.playerlist[dbid] = {raidtype = raidtype, level = level, leaderid = leaderid, guildid = guildid}
end

function TeamCenter:AddWait(dbid, raidtype, level, guildid, waitrobots)
	level = level or 1
	guildid = guildid or 1
	self.waitlist[raidtype] = self.waitlist[raidtype] or {}
	self.waitlist[raidtype][dbid] = {raidtype = raidtype, level = level, guildid = guildid, waitrobots = waitrobots}
end

-- 获得玩家所在的队伍
function TeamCenter:GetPlayerTeam(dbid)
	local myteam = self.playerlist[dbid]
	if myteam then
		local leaderid = myteam.leaderid
		local raidtype = myteam.raidtype
		local level = myteam.level
		local guildid = myteam.guildid
		return self:GetTeam(leaderid, raidtype, level, guildid), myteam
	end
end

-- 创建队伍
function TeamCenter:Create(memberinfo, raidtype, level, guildid, waitrobots)
	lua_app.log_info("--------4-------：", level)
	local ret = false
	local dbid = memberinfo.baseinfo.dbid
	self:Leave(dbid)
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	if self:GetPlayerTeam(dbid) then
		lua_app.log_info("TeamCenter:Create has in team", dbid, raidtype, level, guildid)
		ret = false
	elseif not RaidCheck:CheckCanTeam(dbid, raidtype, level) then
		lua_app.log_info("TeamCenter:Create can not team", dbid, raidtype, level, guildid)
		ret = false
	else
		teamlist[dbid] = {}
		teamlist[dbid] = self:TeamInit()
		teamlist[dbid].playerlist[dbid] = memberinfo
		teamlist[dbid].raidtype = raidtype
		self:SignPlayer(dbid, dbid, raidtype, level, guildid)
		self:AddWait(dbid, raidtype, level, guildid, waitrobots)
		ret = true
	end
	if ret then
		lua_app.log_info("--------5-------：", dbid)
		self:BroadcastTeamInfo(dbid)
		self:BroadcastObserver(raidtype, level, guildid)
	end
	self:PrintDebug()
	return ret
end

-- 快速加入队伍
function TeamCenter:QuickJoin(memberinfo, raidtype, level, guildid)
	local ret = false
	local dbid = memberinfo.baseinfo.dbid
	self:Leave(dbid)
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	if self:GetPlayerTeam(dbid) then
		lua_app.log_info("TeamCenter:QuickJoin has in team", dbid, raidtype, level, guildid)
		ret = false
	else
		-- 加入最早创建并人数最多人的未满队伍中
		local currcreatetime = 0
		local currcount = 0
		local currteam
		local currleaderid = 0
		for leaderid,team in pairs(teamlist) do
			local count = self:GetMemberCount(team)
			if self:CanJoin(team ,memberinfo, leaderid) then
				if not currteam then
					currcreatetime = team.createtime
					currcount = count
					currteam = team
					currleaderid = leaderid
				elseif team.createtime < currcreatetime or (team.createtime == currcreatetime and count > currcount) then
					currcreatetime = team.createtime
					currcount = count
					currteam = team
					currleaderid = leaderid
				end
			end
		end
		if currteam then
			currteam.playerlist[dbid] = memberinfo
			currteam.robotlist[dbid] = nil
			self:SignPlayer(dbid, currleaderid, raidtype, level, guildid)
			self:BroadcastTeamInfo(currleaderid)
			self:BroadcastObserver(raidtype, level, guildid)
			ret = true
		else
			-- lua_app.log_info("TeamCenter:QuickJoin no team to join", dbid, raidtype, level, guildid)
			ret = false
		end 
	end
	self:PrintDebug()
	return ret
end

-- 加入队伍
function TeamCenter:Join(memberinfo, leaderid, raidtype, level, guildid)
	local ret = false
	local team = self:GetTeam(leaderid, raidtype, level, guildid)
	local dbid = memberinfo.baseinfo.dbid
	self:Leave(dbid)
	if team then
		if self:CanJoin(team, memberinfo, leaderid, true) then
			team.playerlist[dbid] = memberinfo
			team.robotlist[dbid] = nil
			self:SignPlayer(dbid, leaderid, raidtype, level, guildid)
			self:BroadcastTeamInfo(leaderid)
			self:BroadcastObserver(raidtype, level, guildid)
			ret = true
		else
			lua_app.log_info("TeamCenter:Join team is full", dbid, raidtype, level, guildid)
			ret = false
		end
	else
		server.sendErrByDBID(dbid, "队伍已解散")
		-- lua_app.log_info("TeamCenter:Join no team to join", dbid, raidtype, level, guildid)
		ret = false
	end
	self:PrintDebug()
	return ret
end

-- 离开队伍
function TeamCenter:Leave(dbid, logout)
	if logout then
		self:RemoveObserver(dbid)
	end
	local ret = false
	local team, info = self:GetPlayerTeam(dbid)

	local member
	-- 真人玩家数量
	local count = 0
	if team then
		member = team.playerlist[dbid]
		for _, _ in pairs(team.playerlist) do
			count = count + 1
		end
	end
	
	if count > 0 and member and info then
		if count > 1 then
			if info.leaderid == dbid then
				-- 大于1个玩家 队长离开 队长位置给下一个人
				team.playerlist[dbid] = nil
				self.playerlist[dbid] = nil

				local teamlist = self:GetRaidTeamList(info.raidtype, info.level, info.guildid)
				local newleaderid
				for playerid, _ in pairs(team.playerlist) do
					if not newleaderid then
						newleaderid = playerid
						teamlist[newleaderid] = team
					end
					self:SignPlayer(playerid, newleaderid, info.raidtype, info.level, info.guildid)
				end
				teamlist[dbid] = nil
				self.waitlist[info.raidtype][newleaderid] = self.waitlist[info.raidtype][dbid]
				self:BroadcastTeamInfo(newleaderid)
				self:BroadcastObserver(info.raidtype, info.level, info.guildid)
				self:SendTeamInfo(dbid)
				self:BroadcastMapDimiss(dbid, info.raidtype, info.level)
				ret = true
			else
				-- 大于1个玩家 非队长离开
				team.playerlist[dbid] = nil
				self.playerlist[dbid] = nil
				self:BroadcastTeamInfo(info.leaderid)
				ret = true
			end
		else
			--只有一个玩家，离开的就是队长
			ret = self:Dismiss(info.leaderid, info.raidtype, info.level, info.guildid, logout)
		end
		self:PrintDebug()
	else
		-- lua_app.log_info("TeamCenter:Leave no team", dbid)
		ret = false
	end
	return ret
end

-- 解散队伍
function TeamCenter:Dismiss(dbid, raidtype, level, guildid, logout)
	local ret = false
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	local team = teamlist[dbid]
	if not team then
		lua_app.log_info("TeamCenter:Dismiss no team to dismiss", dbid, raidtype, level, guildid)
		ret = false
	else
		for k,v in pairs(team.playerlist) do
			if not (logout and k == dbid) then
				server.sendReqByDBID(k, "sc_team_info", {})
			end
			self.playerlist[k] = nil
		end
		teamlist[dbid] = nil
		self.waitlist[raidtype] = self.waitlist[raidtype] or {}
		self.waitlist[raidtype][dbid] = nil
		self:BroadcastMapDimiss(dbid, raidtype, level)
		self:BroadcastObserver(raidtype, level, guildid)
		ret = true
	end
	self:PrintDebug()
	return ret
end

-- 踢人
function TeamCenter:Kick(dbid, memberid, raidtype, level, guildid)
	local ret = false
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	local team = teamlist[dbid]
	if not team then
		lua_app.log_info("TeamCenter:Kick no team to kick", dbid, raidtype, level, guildid)
		ret = false
	else
		local member = team.playerlist[memberid]
		local robot = team.robotlist[memberid]
		if member then
			team.playerlist[memberid] = nil
			self.playerlist[memberid] = nil
			self:BroadcastTeamInfo(dbid)
			team.kicklist[memberid] = lua_app.now()
			server.sendReqByDBID(memberid, "sc_team_info", {})
			ret = true
		elseif robot then
			team.robotlist[memberid] = nil
			team.kicklist[memberid] = lua_app.now()
			self:BroadcastTeamInfo(dbid)
			self:BroadcastObserver(raidtype, level, guildid)
			ret = true
		else
			lua_app.log_info("TeamCenter:Kick no member to kick", dbid, raidtype, level, guildid)
			ret = false
		end
	end
	self:PrintDebug()
	return ret
end

-- 快速加入或创建
function TeamCenter:Quick(memberinfo, raidtype, level, guildid, waitrobots)
	local ret = false
	local iscreate = false
	if self:QuickJoin(memberinfo, raidtype, level, guildid) then
		ret = true
	else
		if self:Create(memberinfo, raidtype, level, guildid, waitrobots) then
			ret = true
			iscreate = true
		end
	end
	self:PrintDebug()
	return ret, iscreate
end

-- 向全服呼叫机器人
function TeamCenter:CallRobot()
	local now = lua_app.now()
	local calllist = {}
	for raidtype, waitteams in pairs(self.waitlist) do
		waitteams = waitteams or {}
		for leaderid, wait in pairs(waitteams) do
			local team = self:GetTeam(leaderid, wait.raidtype, wait.level, wait.guildid)
			if (team and now - team.createtime >= _AutoRobotTime) or 
				(team and wait.raidtype == server.raidConfig.type.CrossTeamFb and wait.level == 40) then
				if wait.waitrobots then
					for _, robot in ipairs(wait.waitrobots) do
						self:AddRobot(robot, leaderid, wait.raidtype, wait.level, wait.guildid)
					end
					wait.waitrobots = nil
				end

				local members = {}
				local count = self:GetMemberCount(team)
				for playerid,_ in pairs(team.playerlist) do
					table.insert(members, playerid)
				end
				for robotid,_ in pairs(team.robotlist) do
					table.insert(members, robotid)
				end
				local need = _MaxCount - count
				if need > 0 then
					local call = {
						raidtype = wait.raidtype,
						level = wait.level,
						guildid = wait.guildid,
						leaderid = leaderid, 
						members = members, 
						need = need,
						kicklist = team.kicklist,
					}
					table.insert(calllist, call)
				end
			end
		end
		if #calllist > 0 and RaidCheck:CheckNeedRobot(raidtype) then
			self:Send(raidtype, "CallRobot", raidtype, calllist)
		end
	end
end

-- 批量填充机器人
function TeamCenter:AddRobotList(calllist)
	for _, back in ipairs(calllist) do
		local raidtype = back.raidtype
		local level = back.level
		local guildid = back.guildid
		local leaderid = back.leaderid
		back.robots = back.robots or {}
		for _, v in ipairs(back.robots) do
			self:AddRobot(v, leaderid, raidtype, level, guildid)
		end
	end
end

-- 客户端呼叫的机器人
function TeamCenter:ClientAddRobotList(leaderid, robots)
	local team, info = self:GetPlayerTeam(dbid)
	if info and info.leaderid == leaderid then
		for _, memberinfo in pairs(robots) do
			self:AddRobot(memberinfo, leaderid, info.raidtype, info.level, info.guildid)
		end
	end
end

-- 加入机器人
function TeamCenter:AddRobot(memberinfo, leaderid, raidtype, level, guildid)
	local ret = false
	local team = self:GetTeam(leaderid, raidtype, level, guildid)
	local dbid = memberinfo.baseinfo.dbid
	if team then
		if self:CanJoin(team ,memberinfo, leaderid) then
			team.robotlist[dbid] = memberinfo
			self:BroadcastTeamInfo(leaderid)
			self:BroadcastObserver(raidtype, level, guildid)
			ret = true
			self:PrintDebug()
		end
	else
		lua_app.log_info("TeamCenter:AddRobot no team to join", dbid, raidtype, level, guildid)
		ret = false
	end
	return ret
end

-- 进入战斗
function TeamCenter:Fight(dbid, raidtype, level, guildid, ext)
	local ret = false
	local ids = {}
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	local team = table.wcopy(teamlist[dbid])
	if not team then
		lua_app.log_info("TeamCenter:Fight not team to fight", dbid, raidtype, level, guildid)
		ret = false
	else
		team.level = level
		local count = self:GetMemberCount(team)
		team.membercount = count
		team.ext = ext
		for playerid, _ in pairs(team.playerlist) do
			table.insert(ids, playerid)
		end
		self:FilterEntitys(team)
		local retraid = server.raidMgr:Enter(raidtype, dbid, team, ids)
		if retraid ~= raidtype then
			lua_app.log_info("TeamCenter:Fight enter raid fail", dbid, raidtype, level, guildid)
			ret = false
		else
			
			self:Dismiss(dbid, raidtype, level, guildid)
			ret = true
		end
	end
	self:PrintDebug()
	return ret
end

-- 设置条件
function TeamCenter:SetCondition(dbid, raidtype, level, guildid, needpower)
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	local team = teamlist[dbid]
	if team then
		team.needpower = needpower
		self:BroadcastTeamInfo(dbid)
	end
end

--获取我加入的队伍
function TeamCenter:SendTeamInfo(dbid)
	local team, info = self:GetPlayerTeam(dbid)
	if team then
		local msg = {
			members = self:GetMemberMsg(team),
			leaderid = info.leaderid,
			raidtype = info.raidtype,
			level = info.level,
			needpower = team.needpower,
		}
		server.sendReqByDBID(dbid, "sc_team_info", msg)
	else
		server.sendReqByDBID(dbid, "sc_team_info", {})
	end
end

function TeamCenter:GetTeamListMsg(raidtype, level, guildid)
	local teamlist = self:GetRaidTeamList(raidtype, level, guildid)
	local msg = {raidtype = raidtype, level = level, teamlist = {}}
	for leaderid,team in pairs(teamlist) do
		local count = self:GetMemberCount(team)
		local members = self:GetMemberMsg(team)
		local info = {leaderid = leaderid, count = count, members = members, needpower = team.needpower}
		table.insert(msg.teamlist, info)
	end
	return msg
end

--获取副本的队伍列表
function TeamCenter:SendTeamList(dbid, raidtype, level, guildid)
	local msg = self:GetTeamListMsg(raidtype, level, guildid)
	server.sendReqByDBID(dbid, "sc_team_list", msg)
	self:GetObserver(raidtype, level, guildid)[dbid] = true
end

function TeamCenter:BroadcastObserver(raidtype, level, guildid)
	local msg = self:GetTeamListMsg(raidtype, level, guildid)
	for dbid, _ in pairs(self:GetObserver(raidtype, level, guildid)) do
		server.sendReqByDBID(dbid, "sc_team_list", msg)
	end
end

--向队员广播队伍信息
function TeamCenter:BroadcastTeamInfo(leaderid)
	local team, info = self:GetPlayerTeam(leaderid)
	lua_app.log_info("--------1-------：", leaderid)
	if team then
		local msg = {
			members = self:GetMemberMsg(team),
			leaderid = info.leaderid,	
			raidtype = info.raidtype,
			level = info.level,
			needpower = team.needpower,
		}
		for k, memberinfo in pairs(team.playerlist) do
			lua_app.log_info("--------2-------：", msg.leaderid)
			server.sendReqByDBID(k, "sc_team_info", msg)
		end
		if RaidCheck:CheckMapBroadcast(info.raidtype) then
			server.mapCenter:Broadcast(leaderid, "sc_team_one", msg)
		end
	end
end

function TeamCenter:BroadcastMapDimiss(leaderid, raidtype, level)
	local msg = {
			members = {},
			leaderid = leaderid,	
			raidtype = raidtype,
			level = level,
		}
	if RaidCheck:CheckMapBroadcast(raidtype) then
		server.mapCenter:Broadcast(leaderid, "sc_team_one", msg)
	end
end

function TeamCenter:GetMemberMsg(team)
	local members = {}
	for k,memberinfo in pairs(team.playerlist) do
		table.insert(members, memberinfo.baseinfo)
	end
	for k,memberinfo in pairs(team.robotlist) do
		table.insert(members, memberinfo.baseinfo)
	end
	return members
end

function TeamCenter:GetMemberCount(team)
	local count = 0
	for _,_ in pairs(team.playerlist) do
		count = count + 1
	end
	for _,_ in pairs(team.robotlist) do
		count = count + 1
	end
	return count
end

function TeamCenter:IsKick(team, dbid)
	local iskick = false
	local kicktime = team.kicklist[dbid]
	if kicktime and lua_app.now() - kicktime < 60 then
		iskick = true
	end
	return iskick
end

function TeamCenter:CanJoin(team, memberinfo, leaderid, istip)
	local dbid = memberinfo.baseinfo.dbid
	local power = memberinfo.baseinfo.power
	local count = self:GetMemberCount(team)
	local iskick = self:IsKick(team, dbid)
	if iskick then
		if istip then
			server.sendErrByDBID(dbid, "您刚被踢出此队伍不能加入")
			return false
		end
	end

	if count >= _MaxCount then
		if istip then
			server.sendErrByDBID(dbid, "此队伍已满")
			return false
		end
	end

	if power < team.needpower then
		if istip then
			server.sendErrByDBID(dbid, string.format("加入此队伍需要%d战力", team.needpower))
			return false
		end
	end

	if not RaidCheck:CheckExistMap(team.raidtype, dbid, leaderid) then
		return false
	end

	if not iskick and 
		count < _MaxCount and 
		not team.playerlist[dbid] then
		return RaidCheck:CheckCanTeam(dbid, team.raidtype, team.level)
	else
		return false
	end
end

-- 获得玩家的组队数据 让战斗可以兼容组队和个人 datas是datapack里获得的战斗packinfo
-- 返回: 
-- 是否可以参与战斗
-- newdatas = {exinfo = datas.exinfo, playerlist = {队伍成员的packinfo}}
-- idlist = 队伍成员的id列表
function TeamCenter:GetTeamData(datas, chkleader)
	-- 判断组队
	local dbid = datas.playerinfo.dbid
	local team, info = self:GetPlayerTeam(dbid)
	if team and info.leaderid ~= dbid and chkleader then
		print("KingMap:AttackCity you are not team leader", dbid)
		return false
	end

	local idlist = {}
	local newdatas = {playerlist = {}}
	newdatas.exinfo = datas.exinfo
	if team then
		self:FilterEntitys(team)
		for _, v in pairs(team.playerlist) do
			table.insert(newdatas.playerlist, v.packinfo)
			table.insert(idlist, v.baseinfo.dbid)
		end
	else
		table.insert(newdatas.playerlist, datas)
		table.insert(idlist, datas.playerinfo.dbid)
	end
	return true, newdatas, idlist
end

function TeamCenter:GetTeamDataByDBID(dbid, chkleader)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		local datas = player.server.dataPack:FightInfoByDBID(dbid)
		return self:GetTeamData(datas, chkleader)
	else
		return false
	end
end

-- 筛选灵童,天女,神将 保留战力最高的那个灵童,天女,神将
function TeamCenter:FilterEntitys(team)
	self:FilterEntity(team, EntityConfig.EntityType.Baby)
	self:FilterEntity(team, EntityConfig.EntityType.Tiannv)
	self:FilterEntity(team, EntityConfig.EntityType.Tianshen)
end

function TeamCenter:FilterEntity(team, entitytype)
	local entity
	local dbid
	for _, v in pairs(team.playerlist) do
		local index
		for i, data in pairs(v.packinfo.entitydatas) do
			if data.etype == entitytype then
				entity = entity or data
				dbid = dbid or v.packinfo.playerinfo.dbid
				if data.power > entity.power then
					entity = data
					dbid = v.packinfo.playerinfo.dbid
					index = i
				end
				index = i
			end
		end
		if index then
			table.remove(v.packinfo.entitydatas, index)
		end
	end
	for _, v in pairs(team.robotlist) do
		local index
		for i, data in pairs(v.packinfo.entitydatas) do
			if data.etype == entitytype then
				entity = entity or data
				dbid = dbid or v.packinfo.playerinfo.dbid
				if data.power > entity.power then
					entity = data
					dbid = v.packinfo.playerinfo.dbid
					index = i
				end
				index = i
			end
		end
		if index then
			table.remove(v.packinfo.entitydatas, index)
		end
	end

	if entity then
		for _, v in pairs(team.playerlist) do
			if dbid == v.packinfo.playerinfo.dbid then
				table.insert(v.packinfo.entitydatas, entity)
				return
			end
		end
		for _, v in pairs(team.robotlist) do
			if dbid == v.packinfo.playerinfo.dbid then
				table.insert(v.packinfo.entitydatas, entity)
				return
			end
		end
	end
end

--打印所有队伍信息
function TeamCenter:PrintDebug()
	-- print("--------------------------------------------------")
	-- for raidtype,v in pairs(self.teamlist) do
	-- 	print(">>>>>raidtype:",raidtype)
	-- 	for level,levellist in pairs(v) do
	-- 		print("+++++++++level:",level)
	-- 		for guildid,guildlist in pairs(levellist) do
	-- 			print("+++++++++guild:",guildid)
	-- 			for leaderid,team in pairs(guildlist) do
	-- 				print("+++++++++++++leaderid:",leaderid)
	-- 				for dbid,player in pairs(team.playerlist) do
	-- 					print("++++++++++++++++++++player:", player.baseinfo.dbid, player.baseinfo.name)
	-- 					if self.playerlist[dbid] then
	-- 						print("*******************************", self.playerlist[dbid].leaderid, self.playerlist[dbid].raidtype, self.playerlist[dbid].level)
	-- 					end
	-- 				end
	-- 				for dbid,robot in pairs(team.robotlist) do
	-- 					print("++++++++++++++++++++robot", robot.baseinfo.dbid, robot.baseinfo.name)
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end
	-- print("--------------------------------------------------")
end

function server.TeamCall(src, funcname, ...)
	return lua_app.ret(server.teamCenter[funcname](server.teamCenter, ...))
end

function server.TeamSend(src, funcname, ...)
	server.teamCenter[funcname](server.teamCenter, ...)
end

server.SetCenter(TeamCenter, "teamCenter")
return TeamCenter
