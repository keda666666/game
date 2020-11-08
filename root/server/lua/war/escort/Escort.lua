local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local Escort = {}

function Escort:Init()
	self.type = server.raidConfig.type.Escort
	self.playerinfos = {}
	server.raidMgr:SetRaid(self.type, Escort)
end

function Escort:Release()
end

function Escort:Enter(dbid, datas)
	local info = self.playerinfos[dbid]
	if not info then
		info = {}
		self.playerinfos[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("Escort:Enter player is in fighting", dbid)
		return false
	end
	local EscortBaseConfig = server.configCenter.EscortBaseConfig

	local fighting = server.NewFighting()
	fighting:InitPvP(EscortBaseConfig.fbid, self)
	local enemyData = datas.exinfo.enemyinfo
	fighting:AddPlayer(FightConfig.Side.Def, nil, enemyData)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.datas = datas.exinfo.data
	info.fighting = fighting
	info.enemyinfo = enemyData
	fighting:StartRunAll()
	return true
end

function Escort:Exit(dbid)
	local info = self.playerinfos[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
	end
	return true
end

function Escort:FightResult(retlist, round)
	for dbid, iswin in pairs(retlist) do
		local info = self.playerinfos[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		info.iswin = iswin
		local msg = {}
		if iswin then
			msg.result = 1
		else
			msg.result = 0
		end
		msg.rewards = info.datas.rewards
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.escort:onFightResult(iswin, info.enemyinfo, info.datas)
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function Escort:GetReward(dbid)
	local info = self.playerinfos[dbid]
	local rewards = info.datas.rewards
	if rewards and info.iswin then
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player:GiveRewardAsFullMailDefault(rewards, "西游护送", server.baseConfig.YuanbaoRecordType.Escort)
	end
end

server.SetCenter(Escort, "Escort")
return Escort