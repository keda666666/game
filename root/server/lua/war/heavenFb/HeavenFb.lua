local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local HeavenFb = {}

function HeavenFb:Init()
	self.type = server.raidConfig.type.HeavenFb
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, HeavenFb)
end

function HeavenFb:Enter(dbid, packinfo)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local heavenFb = player.cache.heavenFb()
	local fubenNo = heavenFb.todayLayer + 1
	local heavenFbData = server.configCenter.HeavenFbConfig[fubenNo]
	if not heavenFbData then return end

	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end
	-- if 	info.fighting then
	-- 	lua_app.log_error("HeavenFb:Enter player is in fighting", dbid)
	-- 	return false
	-- end
	info.fubenNo = fubenNo
	local fighting = server.NewFighting()

	fighting:Init(heavenFbData.fbId, self, nil, server.configCenter.InstanceConfig[heavenFbData.fbId].initmonsters)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, packinfo)
	info.fighting = fighting
	info.rewards = info.rewards or table.wcopy(heavenFbData.dayAward)
	-- info.firstAward = table.wcopy(heavenFbData.firstAward)
	fighting:StartRunAll()
	return 1
end

function HeavenFb:Exit(dbid)--强行退出 ，没奖励 当失败
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

function HeavenFb:FightResult(retlist)--round 回合数战斗结束后吧奖励列表显示给玩家看 
	for dbid, iswin in pairs(retlist) do
		local info = self.playerlist[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		local msg = {}
		if iswin then
			msg.result = 1
			msg.rewards = info.rewards
		else
			msg.result = 0
			msg.rewards = {}
		end

		info.iswin = iswin
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function HeavenFb:GetReward(dbid)
	local info = self.playerlist[dbid]
	local rewards = info.rewards
	if rewards and info.iswin then
		info.rewards = nil
		info.iswin = nil
		local fubenNo = info.fubenNo
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		-- 增加挑战材料副本的次数
		local heavenFb = player.cache.heavenFb()
		if heavenFb.layer == heavenFb.todayLayer then
			heavenFb.layer = fubenNo
		end
		heavenFb.todayLayer = fubenNo
		-- player.cache.heavenFb = heavenFb
		player.heavenFb:SetValue(heavenFb)
		-- 发放奖励

		self:upMsg(player.dbid, heavenFb)
		player:GiveRewardAsFullMailDefault(rewards, "勇闯天庭", server.baseConfig.YuanbaoRecordType.HeavenFb, "勇闯天庭首通"..fubenNo)
		player.activityPlug:onDoTarget()
	end
end

function HeavenFb:upMsg(dbid, heavenFb)
	local msg = {
		layer = heavenFb.layer,
		todayLayer = heavenFb.todayLayer,
		rewardNo = {},
	}
	for k,_ in pairs(heavenFb.rewardNo) do
		table.insert(msg.rewardNo, k)
	end
	server.sendReqByDBID(dbid, "sc_fuben_heavenFb_info", msg)
end

server.SetCenter(HeavenFb, "heavenFb")
return HeavenFb