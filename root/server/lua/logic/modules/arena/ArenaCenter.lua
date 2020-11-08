local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local tbname = "arena"

local ArenaCenter = {}

function ArenaCenter:Init()
	self.ranklist = {}
	self.playerlist = {}
	self.playertargets = {}
	local caches = server.mysqlBlob:LoadDmg(tbname)
	for _, cache in ipairs(caches) do
		self.ranklist[cache.rank] = cache
		self.playerlist[cache.playerid] = cache
	end

	local ArenaConfig = server.configCenter.ArenaConfig
	local rewardTime = string.format("%02d:%02d:00", ArenaConfig.rewardHour, ArenaConfig.rewardMinute)
	lua_timer.add_timer_day(rewardTime, -1, self.RewardAllRank, self)
end

function ArenaCenter:Release()
	for _, cache in pairs(self.ranklist) do
		cache(true)
	end
	self.ranklist = {}
end

-- 获得玩家的排名
function ArenaCenter:GetRank(dbid)
	return self.playerlist[dbid] and self.playerlist[dbid].rank or server.configCenter.ArenaConfig.initRank
end

-- 根据排名获得对应玩家id
function ArenaCenter:GetRankPlayerId(rank)
	local cache = self.ranklist[rank]
	if cache then
		return cache.playerid
	else
		return nil
	end
end

-- 根据排名获得对应玩家
function ArenaCenter:GetRankPlayer(rank)
	return self.ranklist[rank]
end

-- 刷新玩家对手
function ArenaCenter:GenTargets(dbid)
	local rank = self:GetRank(dbid)
	local ArenaConfig = server.configCenter.ArenaConfig

	self.playertargets[dbid] = {}
	local lenght
	local addOneLv = ArenaConfig.addOneLv
	if rank <= addOneLv then
		-- addOneLv排名前的区间取1
		lenght = 1
	else
		local correctNumerator = ArenaConfig.correctNumerator
		local correctDenominator = ArenaConfig.correctDenominator
		lenght = math.ceil((rank + correctNumerator) / correctDenominator)
	end

	if rank <= 5 then
		-- 排名前五的人特殊处理
		for i=1,5 do
			if i ~= rank then
				table.insert(self.playertargets[dbid], i)
			end
		end
	else
		for i=1,4 do
			local tail = rank - (lenght * (i - 1)) - 1
			local head = rank - (lenght * i)
			local target = math.random(head, tail)
			table.insert(self.playertargets[dbid], target)
		end
	end

	table.sort(self.playertargets[dbid], function(a, b)
			return a < b
		end)

	-- 取比自己弱的一个人
	local intervalLeft = ArenaConfig.intervalLeft
	local intervalRight = ArenaConfig.intervalRight
	local head = rank + intervalLeft
	local tail = rank + intervalRight
	local dev = intervalRight - intervalLeft
	if rank >= ArenaConfig.initRank - 1 then
		head = rank - dev
		tail = ArenaConfig.initRank - 2
	elseif tail > ArenaConfig.initRank - 1 then
		tail = ArenaConfig.initRank - 1
		head = math.max(rank + 1, tail - dev)
	end

	local target = math.random(head, tail)
	table.insert(self.playertargets[dbid], target)

	return self.playertargets[dbid]
end

-- 检查对手是否可挑战
function ArenaCenter:CheckTarget(dbid, targetrank)
	local targets = self.playertargets[dbid]
	if not targets then
		return false
	end
	for i,v in ipairs(targets) do
		if v == targetrank then
			return true
		end
	end
	return false
end

-- 是否是最后一个对手（允许秒杀的）
function ArenaCenter:IsLastTarget(dbid, targetrank)
	local targets = self.playertargets[dbid]
	if not targets then
		return false
	end
	for i,v in ipairs(targets) do
		if i == 5 and v == targetrank then
			return true
		end
	end
	return false
end

-- 胜利后交换排名
function ArenaCenter:ExchangeRank(dbid, targetrank)
	local rank = self:GetRank(dbid)
	local targetid = self:GetRankPlayerId(targetrank)
	local targetname
	if targetrank < rank then
		if not targetid then
			-- 原来是机器人就直接占据
			local newtime = lua_app.now()
			local arenarank = {
				rank = targetrank,
				playerid = dbid,
				updatetime = lua_app.now(),
			}
			local cache = server.mysqlBlob:CreateDmg(tbname, arenarank)
			self.ranklist[targetrank] = cache
			self.playerlist[dbid] = cache

			local oldcache = self.ranklist[rank]
			if oldcache then
				server.mysqlBlob:DelDmg(tbname, oldcache)
				self.ranklist[rank] = nil
			end
			if targetrank == 1 then
				targetname = "挑战者"
			end
		else
			-- 真人需要交换
			local targetcache = self.ranklist[targetrank]
			targetcache.playerid = dbid

			local cache = self.playerlist[dbid]
			if cache then
				cache.playerid = targetid
				self.ranklist[cache.rank] = cache
			end

			self.playerlist[dbid] = targetcache
			self.playerlist[targetid] = cache
			if targetrank == 1 then
				local target = server.playerCenter:DoGetPlayerByDBID(targetid)
				targetname = target.cache.name
			end
		end
		if targetrank == 1 then
			local ArenaConfig = server.configCenter.ArenaConfig
			local player = server.playerCenter:DoGetPlayerByDBID(dbid)
			server.noticeCenter:Notice(ArenaConfig.notice, player.cache.name, targetname)
		end
	end
end

-- 每日发放排行榜奖励
function ArenaCenter:RewardAllRank()
	lua_app.log_info("ArenaCenter:RewardAllRank...")
	local ArenaRankRewardConfig = server.configCenter.ArenaRankRewardConfig
	for _,v in ipairs(ArenaRankRewardConfig) do
		for i=v.rankBegin, v.rankEnd do
			local cache = self.ranklist[i]
			if cache then
				local rewards = server.dropCenter:DropGroup(v.dropId)
				local mailContent = string.format("您今日竞技场排名为%d，获得排名奖励", cache.rank)
				server.mailCenter:SendMail(cache.playerid, "竞技场排名奖励", mailContent, rewards, server.baseConfig.YuanbaoRecordType.Arena)
			end
		end
	end
end

-- 获取排行榜
function ArenaCenter:GetArenaRank()
	local ranklist = {}
	for i=1,20 do
		local data = {}
		data.rank = i
		local playerid = self:GetRankPlayerId(i)
		local player
		if playerid then
			player = server.playerCenter:DoGetPlayerByDBID(playerid)
		end
		if player then
			data.id = playerid or 0
			data.name = player.cache.name
			data.value = player.cache.totalpower
		else
			local ArenaRobotConfig = server.configCenter.ArenaRobotConfig
			data.id = 0
			data.name = "挑战者"
			data.value = ArenaRobotConfig[i] and ArenaRobotConfig[i].power or 0
		end
		table.insert(ranklist, data)
	end
	return {ranklist = ranklist}
end

server.SetCenter(ArenaCenter, "arenaCenter")
return ArenaCenter
