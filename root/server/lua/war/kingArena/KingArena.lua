local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local KingArena = {}

function KingArena:Init()
	self.type = server.raidConfig.type.KingArena
	self.arenalist = {}
	server.raidMgr:SetRaid(self.type, KingArena)
end

function KingArena:Enter(dbid, datas)
	local info = self.arenalist[dbid]
	if not info then
		info = {}
		self.arenalist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("KingArena:Enter player is in fighting", dbid)
		return false
	end
	local KingSportsBaseConfig = server.configCenter.KingSportsBaseConfig
	local fighting = server.NewFighting()
	fighting:InitPvP(KingSportsBaseConfig.fbid, self)
	fighting:AddPlayer(FightConfig.Side.Def, nil, datas.exinfo.rival)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.fighting = fighting
	info.grade = datas.exinfo.grade
	info.serverid = datas.serverid
	fighting:StartRunAll()
	return true
end

function KingArena:Exit(dbid)
	local info = self.arenalist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function KingArena:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.arenalist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil

			local GradeConfig = server.configCenter.KingSportsConfig[info.grade]
			local msg = {}
			if iswin then
				info.rewards = {table.wcopy(GradeConfig.winreward)}
				msg.result = 1
			else
				info.rewards = {table.wcopy(GradeConfig.losereward)}
				msg.result = 3
			end
			info.iswin = iswin
			msg.rewards = info.rewards
			server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			server.serverCenter:SendOneMod("logic", player.nowserverid, "kingArenaMgr", "FightResult", dbid, iswin, info.rewards)
		end
	end
end

function KingArena:GetReward(dbid)
	local info = self.arenalist[dbid]
	if info.rewards and info.iswin then
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if player then
			player:GiveRewardAsFullMailDefault(info.rewards, "跨服王者争霸", server.baseConfig.YuanbaoRecordType.KingArena)
		end
	end
end

server.SetCenter(KingArena, "kingArena")
return KingArena