local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local GuildMineFb = {}

function GuildMineFb:Init()
	self.type = server.raidConfig.type.GuildMine
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, GuildMineFb)
end

function GuildMineFb:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("GuildMineFb:Enter player is in fighting", dbid)
		return false
	end
	local mine = datas.exinfo.mine

	local fighting = server.NewFighting()
	if not next(mine.guards) then
		-- 防守玩家是空就打防守怪物
		local fbid = mine.fbId
		fighting:Init(fbid, self, table.wcopy(mine.monsterhps))
	else
		-- 打防守玩家
		local fbid = mine.fbId
		local index = 1
		fighting:InitPvP(fbid, self)
		for _, guardData in pairs(mine.guards) do
			fighting:AddPlayer(FightConfig.Side.Def, nil, guardData, index)
			index = index + 1
		end
	end
	info.players = {}
	for i, data in pairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
	end

	info.mine = mine
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function GuildMineFb:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
		info.mine:SetFightMark()
	end
	return true
end

function GuildMineFb:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info and info.fighting then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			local poshps = info.fighting:GetHPs(FightConfig.Side.Def)
			local players = table.wcopy(info.players)
			info.mine:AttackResult(players, poshps)
			info.fighting = nil

			local msg = {}
			if iswin then
				msg.result = 2
				msg.rewards = {}
			else
				msg.result = 0
				msg.rewards = {}
			end
			for _, playerid in ipairs(info.players) do
				server.sendReqByDBID(playerid, "sc_raid_chapter_boss_result", msg)
			end
		end
	end
end

function GuildMineFb:GetReward(dbid)
end

server.SetCenter(GuildMineFb, "GuildMineFb")
return GuildMineFb