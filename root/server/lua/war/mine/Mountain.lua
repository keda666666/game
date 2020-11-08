local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Mine = require "mine.Mine"

local Mountain = oo.class()
local _MaxWeave = 10
local _SingleRankReward = 1
local _MonthRankReward = 2
local _Status = {
		digging = 1,
		free = 2,
	}
local _MineRelateMap = {
	[1] = {1,2,3,4,5},
	[2] = {1,2,3,6,7},
	[3] = {1,2,3,7,8},
	[4] = {1,4,5,9},
	[5] = {1,4,5,9},
	[6] = {2,6,7},
	[7] = {2,3,6,7,8},
	[8] = {3,7,8},
	[9] = {4,5,9},
	[10] = {},
}

local _RewardRank = 10
--[[****************************调度接口****************************]]

function Mountain:ctor(index)
	self.index = index
	self.players = {}
	self.mineList = {}
	self.guildMine = {}
	self.guildRank = {}
	self.guildRecord = {}
end

function Mountain:Init(servers, serverIndex)
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local crossMine = GuildDiggingBaseConfig.crossminenum
	local normalMine = GuildDiggingBaseConfig.minenum
	local weaveNumber = self.index < serverIndex and normalMine or crossMine
	
	for id = 1, _MaxWeave * weaveNumber do
		self.mineList[id] = Mine.new(self, id)
	end
	self.servers = servers
	self:SecondTimer()
end

function Mountain:Release()
	self:GiveRankReward()

	for dbid,_ in pairs(self.players) do
		self:LeaveMine(dbid)
	end
	for _, mine in pairs(self.mineList) do
		if self.sectimer then
			lua_app.del_timer(self.sectimer)
			self.sectimer = nil
		end
		mine:Release()
	end

	self.players = {}
	self.guildMine = {}
	self.guildRank = {}
	self.guildRecord = {}
end

--玩家离线
function Mountain:Logout(dbid)
	self:LeaveMine(dbid)
end

--每秒定时器
function Mountain:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		local nowtime = lua_app.now()
		for __, mine in pairs(self.mineList) do
			mine:IncreaseSorce(nowtime)
			mine:GiveGatherRewards(nowtime)
		end
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

function Mountain:IncreaseScore()
	local nowtime = lua_app.now()
	for __, mine in pairs(self.mineList) do
		mine:IncreaseSorce(nowtime)
	end
end

--[[****************************功能接口****************************]]
function Mountain:GetPlayerMine(dbid)
	local mineId = self.players[dbid].mineId
	if not mineId then
		return false
	end
	return self.mineList[mineId]
end

function Mountain:GetMine(id)
	return self.mineList[id]
end

--参与活动检查
function Mountain:IsExistPlayer(dbid)
	if not self.players[dbid] then
		return false
	end
	return true
end

--攻击CD检查
function Mountain:CheckAttackCd(dbid)
	local info = self.players[dbid]
	if not info then
		return false
	end
	local nowtime = lua_app.now()
	return (nowtime > info.attackTime)
end

--重算排行
function Mountain:RecalcGuildRank()
	table.sort(self.guildRank, function(a, b)
		return a.score > b.score
	end)
	for rank, guildInfo in ipairs(self.guildRank) do
		guildInfo.rank = rank
	end
end

--更新玩家状态
function Mountain:UpdatePlayerStatus(dbid, data)
	local status = self.players[dbid]
	if not status then
		return
	end

	for k,v in pairs(data) do
		if status[k] then
			status[k] = v
		end
	end
	self:SendPlayerStatus(dbid)
end

function Mountain:GetGuildScore(guildid)
	local info = self.guildMine[guildid]
	return info and info.score
end

--添加参与记录
function Mountain:AddInvolvementRecord(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end

	local guildid = player.cache.guildid()
	self.guildRecord[guildid] = self.guildRecord[guildid] or {}
	self.guildRecord[guildid][dbid] = true
end

function Mountain:GetGuildRank(guildid)
	local guildInfo = self.guildMine[guildid]
	return guildInfo and guildInfo.rank
end

function Mountain:GetPlayerStatusData(dbid)
	local playerInfo = self.players[dbid]
	local data = {
		status = playerInfo.status,
		mineId = playerInfo.mineId,
		gatherTime = playerInfo.gatherTime,
		chainrate = self:GetChainRate(dbid),
		attackTime = playerInfo.attackTime,
		guildRank = self:GetGuildRank(playerInfo.guildId),
		guildScore = self:GetGuildScore(playerInfo.guildId),
	}
	return data
end

--添加帮会矿脉
function Mountain:AddGuildMine(guildid, mineId)
	self.guildMine[guildid].mineList[mineId] = true
	self:RecastGuildChain(guildid)
end

--移除帮会矿脉
function Mountain:RemoveGuildMine(guildid, mineId)
	local info = self.guildMine[guildid] 
	if not info then
		return
	end
	info.mineList[mineId] = false
	self:RecastGuildChain(guildid)
	self:BroadcastGuildPlayerStatus(guildid)
end

--更新帮会积分
function Mountain:UpdateGuildSorce(guildid, mineType)
	local GuildDiggingConfig = server.configCenter.GuildDiggingConfig
	local info = self.guildMine[guildid]
	local score = math.floor(GuildDiggingConfig[mineType].score * (info.rate + 100) / 100)
	self:RecalcGuildRank()
	info.score = info.score + score
	self:BroadcastGuildPlayerStatus(guildid)
end

--重算连锁加成
function Mountain:RecastGuildChain(guildid)
	local info = self.guildMine[guildid]
	if not info then return end 

	local function _CalcChain(src, index, addition, count, status)
		status = status or {}
		count = count or 0
		addition = addition or (math.ceil(index / 10) - 1) * 10
		for _, mineId in ipairs(_MineRelateMap[index - addition]) do
			if src[mineId + addition] and not status[mineId] then
				status[mineId] = true
				count = count + 1
				count = _CalcChain(src, (mineId + addition), addition, count, status)
			end
		end
		return count
	end

	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local maxChain = 0
	for id, v in pairs(info.mineList) do
		if v then
			maxChain = math.max(maxChain, _CalcChain(info.mineList, id))
		end
	end
	local addRate = GuildDiggingBaseConfig.chain[maxChain] or 0
	info.rate = addRate
	self:BroadcastGuildPlayerStatus(guildid)
end

--获取连锁加成
function Mountain:GetChainRate(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local guildid = player.cache.guildid()
	local info = self.guildMine[guildid]
	if not info then
		return 0
	end
	return info.rate
end

--玩家进入
function Mountain:Enter(dbid)
	if not self.players[dbid] then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		local baseinfo = player:BaseInfo()
		local playerdata = {
			status = _Status.free,
			mineId = 0,
			gatherTime = 0,
			chainrate = self:GetChainRate(dbid),
			attackTime = 0,
			guildId = baseinfo.guildid,
			serverId = player.nowserverid,
			playerinfo = baseinfo,
		}
		self.players[dbid] = playerdata
		local guildData = {
			guildid = baseinfo.guildid,
			guildName = baseinfo.guildname,
			serverId = player.nowserverid,
		}
		self:InitGuildMine(guildData)
	end
	self:SendMountainInfo(dbid)
	self:SendPlayerStatus(dbid)
end
--
function Mountain:LeaveMine(dbid, reserveTeam)
	local playerinfo = self.players[dbid]
	if not playerinfo then
		return
	end
	local mine = self.mineList[playerinfo.mineId]
	if mine then
		mine:LeaveGuard(dbid, reserveTeam)
	end
end

function Mountain:InitGuildMine(data)
	local info = self.guildMine[data.guildid]
	if not info then
		info = {
			guildId = data.guildid,
			guildName = data.guildName,
			rate = 0,
			mineList = {},
			score = 0,
			rank = 0,
			serverId = data.serverId,
		}
		table.insert(self.guildRank, info)
		self.guildMine[data.guildid] = info
		self:RecalcGuildRank()
	end
end

function Mountain:GetPlayerdata(dbid)
	local data = self.players[dbid]
	if not data then
		lua_app.log_error(">>Mountain GetPlayerdata dbid not exist.", dbid)
	end
	return data
end

function Mountain:GetAllMineData()
	local datas = {}
	for id, data in ipairs(self.mineList) do
		table.insert(datas, self:GetMineData(id))
	end
	return datas
end

function Mountain:GetRankData()
	return table.wcopy(self.guildRank)
end

function Mountain:GetMineData(mineId)
	return self.mineList[mineId]:GetMsgData()
end

--发放排名奖励
function Mountain:GiveRankReward()
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local RankRewardConfig = server.configCenter.RankRewardConfig
	for rank, data in ipairs(self.guildRank) do
		local players = self.guildRecord[data.guildId] or {}
		local rewards = table.wcopy(RankRewardConfig[_SingleRankReward][rank].reward)
		for dbid, _ in pairs(players) do
			local playerinfo = self.players[dbid]
			local title = GuildDiggingBaseConfig.dmailtitle
			local context = string.format(GuildDiggingBaseConfig.dmaildes, rank)
			server.serverCenter:SendOneMod("logic", playerinfo.serverId, "mailCenter", "SendMail", dbid, title, context, rewards, server.baseConfig.YuanbaoRecordType.GuildMine)
		end
		if rank == _RewardRank then break end
	end
end

--[[****************************消息接口****************************]]
--发送矿山信息
function Mountain:SendMountainInfo(dbid)
	server.sendReqByDBID(dbid, "sc_guildmine_mine_info", {
			mineinfos = self:GetAllMineData()
		})
end

--发送矿脉信息
function Mountain:SendMineInfo(dbid, mineId)
	server.sendReqByDBID(dbid, "sc_guildmine_mine_one_info", {
				mineinfo = self:GetMineData(mineId)
			})
end

--发送玩家状态
function Mountain:SendPlayerStatus(dbid)
	server.sendReqByDBID(dbid, "sc_guildmine_mine_mystatus", self:GetPlayerStatusData(dbid))
end

--广播矿脉信息
function Mountain:BroadcastMountainInfo(mineId)
	for dbid,_ in pairs(self.players) do
		server.sendReqByDBID(dbid, "sc_guildmine_mine_one_info", {
				mineinfo = self:GetMineData(mineId)
			})
	end
end

--广播帮派成员
function Mountain:BroadcastGuildPlayerStatus(guildId)
	for dbid,_ in pairs(self.players) do
		if self.players[dbid].guildId == guildId then
			server.sendReqByDBID(dbid, "sc_guildmine_mine_mystatus", self:GetPlayerStatusData(dbid))
		end
	end
end

return Mountain