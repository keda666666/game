local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local TreasureMap = {}

function TreasureMap:Init()
	self.type = server.raidConfig.type.TreasureMap
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, TreasureMap)
end

function TreasureMap:Enter(dbid, packinfo)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local fubenNo = packinfo.exinfo.fubenNo
	local treasureMapConfig = server.configCenter.TreasureMapConfig[fubenNo]
	if not treasureMapConfig then return end
	local treasuremap = player.cache.treasuremap()
	-- 上一关是否通关
	if fubenNo ~= 1 then
		if not treasuremap.clearanceNum[fubenNo - 1] then
			server.sendErr(player, "请先通关上一关")
			return
		end
	end
	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end
	info.fubenNo = fubenNo
	local fighting = server.NewFighting()

	fighting:Init(treasureMapConfig.fbId, self, nil, server.configCenter.InstanceConfig[treasureMapConfig.fbId].initmonsters)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, packinfo)
	info.fighting = fighting
	if not treasuremap.todayNum[fubenNo] then
		info.rewards = table.wcopy(treasureMapConfig.everydayaward)
	else
		info.rewards = {}
	end
	if not treasuremap.clearanceNum[fubenNo] then
		info.firstReward = true
		for _,v in pairs(treasureMapConfig.firstAward) do
			table.insert(info.rewards, v)
		end
	end


	fighting:StartRunAll()
	return 1
end

function TreasureMap:Exit(dbid)--强行退出 ，没奖励 当失败
	local info = self.playerlist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		self.playerlist[dbid] = nil
	end
	return true
end

function TreasureMap:FightResult(retlist, round)--round 回合数战斗结束后吧奖励列表显示给玩家看 
	for dbid, iswin in pairs(retlist) do
		local info = self.playerlist[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		local msg = {}
		local baseConfig = server.configCenter.TreasureMapBaseConfig
		local star = 1
		if round <= baseConfig.twostar then 
			star = 3
		elseif round <= baseConfig.onestar then
			star = 2
		end

		if iswin then
			msg.result = 1
			msg.rewards = info.rewards
			msg.star = star
		else
			msg.result = 0
			msg.rewards = {}
		end
		info.star = star
		info.iswin = iswin
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function TreasureMap:GetReward(dbid)
	local info = self.playerlist[dbid]
	local rewards = info.rewards
	local firstReward = info.firstReward
	if rewards and info.iswin then
		-- info.rewards = nil
		-- info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		local fubenNo = info.fubenNo
		local star = info.star
		local treasuremap = player.cache.treasuremap()
		local treasureMapConfig = server.configCenter.TreasureMapConfig[fubenNo]
		--先判断星级，是否要更新星级
		-- 	-- 发放首胜奖励
		if firstReward then
			treasuremap.clearanceNum[fubenNo] = star
			treasuremap.star[treasureMapConfig.page] = (treasuremap.star[treasureMapConfig.page] or 0) + star
		elseif info.star > treasuremap.clearanceNum[fubenNo] then
			treasuremap.star[treasureMapConfig.page] = treasuremap.star[treasureMapConfig.page] - treasuremap.clearanceNum[fubenNo] + star
			treasuremap.clearanceNum[fubenNo] = star
		end
		treasuremap.todayNum[fubenNo] = 1
		self.playerlist[dbid]= nil
		--判断玩家今天是否已经打过这个副本了

		-- 发放奖励
		-- player.cache.treasuremap = treasuremap
		player.treasuremap:SetValue(treasuremap)
		self:upMsg(player.dbid, treasuremap)
		if #rewards ~= 0 then
			player:GiveRewardAsFullMailDefault(table.wcopy(rewards), "藏宝图副本", server.baseConfig.YuanbaoRecordType.TreasureMap, "藏宝图副本"..fubenNo)
		end
		player.activityPlug:onDoTarget()
	end
end

function TreasureMap:upMsg(dbid, treasuremap)
	local msg = {}
	msg.data= {}
	for k,v in pairs(treasuremap.clearanceNum) do
		table.insert(msg.data, {
			fubenNo = k,
			todayNum = (treasuremap.todayNum[k] or 0),
			star = v,
			})
	end
	msg.starReward = {}
	for k,v in pairs(treasuremap.starReward) do
		table.insert(msg.starReward, {no=k, reward=v})
	end
	server.sendReqByDBID(dbid, "sc_fuben_treasuremap_info", msg)
end

server.SetCenter(TreasureMap, "treasuremap")
return TreasureMap