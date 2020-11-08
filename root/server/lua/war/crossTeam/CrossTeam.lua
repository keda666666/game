local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local CrossTeam = {}

function CrossTeam:Init()
	self.type = server.raidConfig.type.CrossTeamFb
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, CrossTeam)
end

function CrossTeam:Enter(dbid, team)
	local fighting = server.NewFighting()
	local fb = server.configCenter.CrossTeamFbConfig[team.level]
	if not fb then
		return false
	end
	fighting:Init(fb.fbid, self, nil, server.configCenter.InstanceConfig[fb.fbid].initmonsters)
	fighting:AddTeam(FightConfig.Side.Attack, team)

	for playerid,member in pairs(team.playerlist) do
		local info = self.fblist[playerid]
		if not info then
			info = {}
		end
		-- if info.fighting then
		-- 	lua_app.log_error("CrossTeam:Enter player is in fighting", playerid)
		-- 	return false
		-- end
		info.fighting = fighting
		info.level = team.level
		info.membercount = team.membercount
		self.fblist[playerid] = info
	end
	
	fighting:StartRunAll()
	return true
end

function CrossTeam:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	-- else
	-- 	lua_app.log_error("CrossTeam:Exit no chapter fighting", dbid)
	end
	return true
end

function CrossTeam:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info.fighting then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = iswin
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player.crossTeam:DoResult(iswin, info.level, info.membercount)
		end
	end
end

function CrossTeam:GetReward(dbid)
	local info = self.fblist[dbid]
	if info.iswin then
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player.crossTeam:GetReward()
		end
	end
end

server.SetCenter(CrossTeam, "crossTeam")
return CrossTeam