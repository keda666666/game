local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local DailyTaskMonster = {}

function DailyTaskMonster:Init()
	self.type = server.raidConfig.type.DailyTaskMonster
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, DailyTaskMonster)
end

function DailyTaskMonster:Enter(dbid, packinfo)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	-- local fubenNo = packinfo.exinfo.fubenNo
	local dungeonStar = server.configCenter.DailyExpDungeonStar
	local data = dungeonStar[packinfo.exinfo.monsterNo]
	local fbId = data.dungeon
	-- local monster = player.cache.monster()
	-- 上一关是否通关
	-- if fubenNo ~= 1 then
	-- 	if not monster.clearanceNum[fubenNo - 1] then return end
	-- end
	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end
	info.no = packinfo.exinfo.no
	info.rewards = data.reward
	local fighting = server.NewFighting()
	fighting:Init(fbId, self, nil, server.configCenter.InstanceConfig[fbId].initmonsters)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, packinfo)
	info.fighting = fighting
	fighting:StartRunAll()
	return 1
end

function DailyTaskMonster:Exit(dbid)--强行退出 ，没奖励 当失败
	local info = self.playerlist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function DailyTaskMonster:FightResult(retlist, round)--round 回合数战斗结束后吧奖励列表显示给玩家看 
	for dbid, iswin in pairs(retlist) do
		local info = self.playerlist[dbid]
		local msg = {}
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
			if iswin then
				local player = server.playerCenter:GetPlayerByDBID(dbid)
				player.dailyTask:GetMonsterReward(info.no)
				msg.result = 1
				msg.rewards = info.rewards
			else
				msg.result = 0
				msg.rewards = {}
			end
		end
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function DailyTaskMonster:GetReward(dbid)
end

server.SetCenter(DailyTaskMonster, "dailyTaskmonster")
return DailyTaskMonster