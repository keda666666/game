local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local GuildFb = {}

function GuildFb:Init()
	self.type = server.raidConfig.type.GuildFb
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, GuildFb)
end

function GuildFb:Enter(dbid, team)
	local fighting = server.NewFighting()
	local GuildFubenConfig = server.configCenter.GuildFubenConfig
	local fbId = GuildFubenConfig[team.level].fbid
	fighting:Init(fbId, self, nil, server.configCenter.InstanceConfig[fbId].initmonsters)
	fighting:AddTeam(FightConfig.Side.Attack, team)

	local fbinfo = {
		fbId = team.level,
		leaderid = dbid,
		membercount = team.membercount,
	}

	for playerid,member in pairs(team.playerlist) do
		local info = self.fblist[playerid]
		if not info then
			info = {}
		end
		if info.fighting then
			lua_app.log_error("GuildFb:Enter player is in fighting", playerid)
			return false
		end
		info.fighting = fighting
		info.fbinfo = fbinfo
		self.fblist[playerid] = info
	end

	fighting:StartRunAll()
	return true
end

function GuildFb:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function GuildFb:FightResult(retlist)
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
			player.guild.guildDungeon:DoResult(iswin, table.wcopy(info.fbinfo))
		end
	end
end

function GuildFb:GetReward(dbid)
	local info = self.fblist[dbid]
	if info.iswin then
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player.guild.guildDungeon:GetReward()
		end
	end
end

server.SetCenter(GuildFb, "GuildFb")
return GuildFb