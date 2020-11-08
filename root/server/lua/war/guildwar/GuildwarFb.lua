local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local GuildwarFb = {}

function GuildwarFb:Init()
	self.type = server.raidConfig.type.Guildwar
	self.fblist = {}
	self.rewards = {}
	server.raidMgr:SetRaid(self.type, GuildwarFb)
end

function GuildwarFb:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("GuildwarFb:Enter player is in fighting", dbid)
		return false
	end

	--处理四天王
	if datas.exinfo.bossid then
		return self:EnterFourKing(dbid, datas)
	end

	local barrier = datas.exinfo.barrier
	local fbid = barrier.fbid
	local fighting = server.NewFighting()
	if not next(barrier.guards) then
		-- 防守玩家是空就打防守怪物
		local monsterhps = barrier.monsterhps or {}
		fighting:Init(fbid, self, table.wcopy(monsterhps), nil, nil, barrier:GetExconfig())
	else
		-- 打防守玩家
		fighting:InitPvP(fbid, self)
		for i, guardData in pairs(barrier.guards) do
			fighting:AddPlayer(FightConfig.Side.Def, nil, guardData, i)
		end
	end
	info.players = {}
	for i, data in pairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
	end
	info.barrier = barrier
	info.fighting = fighting
	info.attackers = datas.playerlist
	fighting:StartRunAll()
	print("-----------GuildwarFb:Enter-------------")
	return true
end

--四大天王
function GuildwarFb:EnterFourKing(dbid, datas)
	local bossid = datas.exinfo.bossid
	local fbid = datas.exinfo.fbid
	local barrier = datas.exinfo.barrier
	local info = self.fblist[dbid]
	local fighting = server.NewFighting()
	fighting:Init(fbid, self)
	info.players = {}
	for i, data in pairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
	end
	info.barrier = barrier
	info.fighting = fighting
	info.attackers = datas.playerlist
	info.bossid = bossid
	fighting:StartRunAll()
	return true
end

function GuildwarFb:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
		self.fblist[dbid] = nil
	end
	return true
end

function GuildwarFb:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()

			local poshps = info.fighting:GetHPs(FightConfig.Side.Def)
			info.barrier:AttackResult(iswin, dbid, info.attackers, poshps, info.bossid)
			info.fighting = nil

			local rewards, result = info.barrier:GetReward(iswin, poshps, info.bossid)
			local msg = {
				rewards = rewards,
				result = result,
			}
			for _, playerid in ipairs(info.players) do
				self.rewards[playerid] = rewards
				server.sendReqByDBID(playerid, "sc_raid_chapter_boss_result", msg)
			end
		end
	end
end

function GuildwarFb:GetReward(dbid)
	if self.rewards[dbid] then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player:GiveRewardAsFullMailDefault(self.rewards[dbid], "帮会战", server.baseConfig.YuanbaoRecordType.Guildwar)
		self.rewards[dbid] = nil
	end
end

server.SetCenter(GuildwarFb, "guildwarFb")
return GuildwarFb