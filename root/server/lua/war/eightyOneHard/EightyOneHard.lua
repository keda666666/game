local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local EightyOneHard = {}

function EightyOneHard:Init()
	self.type = server.raidConfig.type.EightyOneHard
	self.fblist = {}
	self.teamData = {}
	server.raidMgr:SetRaid(self.type, EightyOneHard)
end

function EightyOneHard:Enter(dbid, team)
	local fighting = server.NewFighting()
	local fb = server.configCenter.DisasterFbConfig[team.level]
	if not fb then return false end

	fighting:Init(fb.fbid, self, nil, server.configCenter.InstanceConfig[fb.fbid].initmonsters)
	fighting:AddTeam(FightConfig.Side.Attack, team)
	local helpReward = false
	for playerid,member in pairs(team.playerlist) do
		local player = server.playerCenter:GetPlayerByDBID(playerid)
		if not player.eightyOneHard:Clear(team.level) then
			helpReward = true
			break
		end
	end

	local data = {}
	local num = 1
	for playerid,member in pairs(team.playerlist) do	
		local info = self.fblist[playerid]
		if not info then
			info = {}
		end
		if info.fighting then
			lua_app.log_error("EightyOneHard:Enter player is in fighting", playerid)
		return false
		end
		info.fighting = fighting
		info.level = team.level
		info.membercount = team.membercount
		info.helpReward = helpReward
		self.fblist[playerid] = info

		data["name"..num] = member.baseinfo.name
		num = num + 1
	end
	self.teamData[dbid] = data
	fighting:StartRunAll()
	return true
end

function EightyOneHard:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	-- else
	-- 	lua_app.log_error("EightyOneHard:Exit no chapter fighting", dbid)
	end
	return true
end

function EightyOneHard:FightResult(retlist, round)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info.fighting then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = iswin
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.eightyOneHard:DoResult(iswin, info.level, info.helpReward)
		if iswin then
			local data = self.teamData[dbid]
			self.teamData[dbid] = nil
			if data then
				data.round = round
				data.time = lua_app.now()
				player.eightyOneHard:SetData(info.level, data)
			end
		end
	end
end

function EightyOneHard:GetReward(dbid)
	local info = self.fblist[dbid]
	if info.iswin then
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.eightyOneHard:GetReward()
	end
end

server.SetCenter(EightyOneHard, "eightyOneHard")
return EightyOneHard