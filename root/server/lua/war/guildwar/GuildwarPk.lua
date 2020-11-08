local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local GuildwarPk = {}

function GuildwarPk:Init()
	self.type = server.raidConfig.type.GuildwarPk
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, GuildwarPk)
end

function GuildwarPk:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("GuildwarPk:Enter player is in fighting", dbid)
		return false
	end
	local guildwarMap = datas.exinfo.guildwarMap
	local fighting = server.NewFighting()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local fbid = GuildBattleBaseConfig.pk_fbid
	info.players = {}
	info.targets = {}

	fighting:InitPvP(fbid, self)
	for i, data in ipairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
	end

	for i, data in ipairs(datas.exinfo.target.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.targets, playerid)
		fighting:AddPlayer(FightConfig.Side.Def, playerid, data, i)
	end

	info.guildwarMap = guildwarMap
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function GuildwarPk:Exit(dbid)
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

function GuildwarPk:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.guildwarMap:PkResult(iswin, info.players, info.targets)
			info.fighting = nil
			local winmsg = {
				result = 1, 
				rewards = {}
			}
			local losemsg = {
				result = 0,
				rewards = {},
			}
			
			for _,playerid in ipairs(info.players) do
				server.sendReqByDBID(playerid, "sc_raid_chapter_boss_result", iswin and winmsg or losemsg)
			end

			for _,targetid in ipairs(info.targets) do
				server.sendReqByDBID(targetid, "sc_raid_chapter_boss_result", iswin and losemsg or winmsg)
			end

			self.fblist[dbid] = nil
		end
	end
end

function GuildwarPk:GetReward(dbid)
end

server.SetCenter(GuildwarPk, "guildwarPk")
return GuildwarPk