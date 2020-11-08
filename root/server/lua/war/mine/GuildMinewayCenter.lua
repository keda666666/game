local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local lua_util = require "lua_util"
local Mountain = require "mine.Mountain"

local tbname = server.GetSqlName("wardatas")
local tbcolumn = "guildmine"

--矿山争夺
local GuildMinewarCenter = {}

local _MaxServer = 4
local _MonthRankReward = 20

function GuildMinewarCenter:CallLogics(funcname, ...)
	return server.serverCenter:CallLogics("GuildMinewarLogicCall", funcname, ...)
end

function GuildMinewarCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "GuildMinewarLogicSend", funcname, ...)
end

function server.GuildMinewarWarCall(src, funcname, ...)
	return lua_app.ret(server.guildMinewarCenter[funcname](server.guildMinewarCenter, ...))
end

function server.GuildMinewarWarSend(src, funcname, ...)
	server.guildMinewarCenter[funcname](server.guildMinewarCenter, ...)
end

function GuildMinewarCenter:Init()
	if not server.serverCenter:IsCross() then return end

	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.monthRank = false
	local opentime = server.configCenter.GuildDiggingBaseConfig.opentime
	self.checkTimer = lua_timer.add_timer_day(opentime.starttime..":00", -1, self.Start, self)
end

function GuildMinewarCenter:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
	if self.checkTimer then
		lua_timer.del_timer_day(self.checkTimer)
		self.checkTimer = nil
	end
end

local _intervalTime = false
local function _GetIntervalTime()
	if not _intervalTime then
		local opentime = server.configCenter.GuildDiggingBaseConfig.opentime
		local starttime = lua_util.split(opentime.starttime,":")
		local endtime = lua_util.split(opentime.endtime,":")
		_intervalTime = ((tonumber(endtime[1]) - tonumber(starttime[1])) * 3600 + (tonumber(endtime[2]) - tonumber(starttime[2])) * 60)
	end
	return _intervalTime 
end

--活动开启
function GuildMinewarCenter:Start()
	if self.isOpen then return end 

	self.mapServer = {}
	self.serverMap = {}
	local serverList = self:CallLogics("ServerInfo")

	local serverIndex = 1
	--分配单服玩法
	for serverId, info in pairs(serverList) do
		if info.opencode == 1 then
			self.serverMap[serverId] = serverIndex
			self.mapServer[serverIndex] = self.mapServer[serverIndex] or {}
			table.insert(self.mapServer[serverIndex], serverId)
			serverIndex = serverIndex + 1
			lua_app.log_info("GuildMinewarCenter:Start--- single server mapindex and serverid:",serverIndex, serverId)
		end
	end

	--分配跨服玩法
	local acc = 1
	for serverId, info in pairs(serverList) do
		if info.opencode == 2 then
			local index = math.ceil(acc / _MaxServer) + serverIndex
			self.serverMap[serverId] = index
			self.mapServer[index] = self.mapServer[index] or {}
			table.insert(self.mapServer[index], serverId)
			acc = acc +1
			lua_app.log_info("GuildMinewarCenter:Start--- mapindex and serverid:", index, serverId)
		end
	end

	self.mountains = {}
	for index, servers in pairs(self.mapServer) do
		self.mountains[index] = Mountain.new(index)
		self.mountains[index]:Init(servers, serverIndex)
	end

	self.isOpen = true
    --通知开启活动的服器
	for serverid, __ in pairs(self.serverMap) do
		self:SendOne(serverid, "Start")
	end
	self.endtimer = lua_app.add_update_timer(_GetIntervalTime() * 1000, self, "Shut")
	print("GuildMinewarCenter:Start--------------------------------")
end

--活动关闭
function GuildMinewarCenter:Shut()
	if not self.isOpen then return end
	if self.endtimer then
		lua_app.del_timer(self.endtimer)
		self.endtimer = nil
	end
	--记录帮会积分
	for index, mountain in pairs(self.mountains) do
		local mountainRank = mountain:GetRankData()
		for _, rankdata in ipairs(mountainRank) do
			local data = self.cache.guildRecord[rankdata.guildId]
			if not data then
				data = {
					guildId = rankdata.guildId,
					guildName = rankdata.guildName,
					serverId = rankdata.serverId,
					score = 0,
					rank = 0,
				}
				self.cache.guildRecord[rankdata.guildId] = data
			end
			data.index = index
			data.score = data.score + rankdata.score
		end
		mountain:Release()
	end

	for serverid, __ in pairs(self.serverMap) do
		self:SendOne(serverid, "Shut")
	end

	self.isOpen = false
	self.monthRank = false
	print("GuildMinewarCenter:Shut---------------------------------")
end

function GuildMinewarCenter:IsOpen()
	return self.isOpen
end

--[[****************************功能接口****************************]]
--获取一个矿脉
function GuildMinewarCenter:GetMineById(dbid, mineId)
	local mountain = self:GetMountain(dbid)
	return mountain:GetMine(mineId)
end

--得到自己所在的矿山
function GuildMinewarCenter:GetMineInfoById(dbid, mineId)
	local mountain = self:GetMountain(dbid)
	return mountain:SendMineInfo(dbid, mineId)
end

--获得自己所在矿山
function GuildMinewarCenter:GetMountain(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local index = self.serverMap[player.nowserverid]
	return self.mountains[index]
end

function GuildMinewarCenter:GetMonthRankByDBID(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local monthRank = self:GetMonthRank()
	local rankindex = monthRank.servermap[player.nowserverid]
	return monthRank[rankindex] or {}
end

function GuildMinewarCenter:GetMonthRank()
	if not self.monthRank then
		self.monthRank = self:CalcMonthRank()
	end 
	return self.monthRank
end

function GuildMinewarCenter:CalcMonthRank()
	local ranks = {}
	local servermap = {}
	for __, rankdata in pairs(self.cache.guildRecord) do
		servermap[rankdata.serverId] = rankdata.index
		ranks[rankdata.index] = ranks[rankdata.index] or {}
		table.insert(ranks[rankdata.index], rankdata)
	end

	for __, rankdata in pairs(ranks) do
		table.sort(rankdata, function(priordata, laterdata)
			return priordata.score > laterdata.score
		end)
		for rank, data in ipairs(rankdata) do
			data.rank = rank
		end
	end

	ranks.servermap = servermap
	return ranks
end

function GuildMinewarCenter:IsActivityDay()
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local week = lua_app.week()
	for _,day in ipairs(GuildDiggingBaseConfig.openday) do
		if day == week then
			return true
		end
	end
	return false
end

--[[****************************消息接口****************************]]

--强占矿脉
function GuildMinewarCenter:ForceJoinMine(dbid, mineId)
	local mine = self:GetMineById(dbid, mineId)
	return mine:Attack(dbid)
end

--矿脉采集
function GuildMinewarCenter:MineCompleteGather(dbid)
	local mountain = self:GetMountain(dbid)
	local mine = mountain:GetPlayerMine(dbid)
	if not mine then
		return false
	end
	return mine:CompleteGather(dbid)
end

--加入守护
function GuildMinewarCenter:JoinMine(dbid, mineId)
	local mine = self:GetMineById(dbid, mineId)
	return mine:JoinGuard(dbid)
end

--离开守护
function GuildMinewarCenter:LeaveMine(dbid)
	local mountain = self:GetMountain(dbid)
	local mine = mountain:GetPlayerMine(dbid)
	if not mine then
		return
	end
	return mine:LeaveGuard(dbid)
end

--进入矿山争夺
function GuildMinewarCenter:EnterMinewar(dbid)
	print("GuildMinewarCenter:EnterMinewar-----------------------",dbid)

	local team, info = server.teamCenter:GetPlayerTeam(dbid)
	if info then
		if info.raidtype ~= server.raidConfig.type.GuildMine then
			server.teamCenter:Leave(dbid)
		end
	end
	local mountain = self:GetMountain(dbid)
	return mountain:Enter(dbid)
end

--离开矿山争夺
function GuildMinewarCenter:onLogout(player)
	if not server.serverCenter:IsCross() then return end
	if not self:IsOpen() then return end

	local mountain = self:GetMountain(player.dbid)
	if not mountain then
		return false
	end
	mountain:Logout(player.dbid)
	print(">>GuildMinewarCenter: LeaveMinewar dbid", player.dbid)
end

--排行榜
function GuildMinewarCenter:GetGuildScoreRank(dbid, rankType)
	if rankType == 1 then
		local mountain = self:GetMountain(dbid)
		server.sendReqByDBID(dbid, "sc_guildmine_score_rank_day", {
				rankType = rankType,
				rankdatas = mountain:GetRankData(),
			})
	elseif rankType == 2 then
		server.sendReqByDBID(dbid, "sc_guildmine_score_rank_day", {
				rankType = rankType,
				rankdatas = self:GetMonthRankByDBID(dbid),
			})
	end
end

function GuildMinewarCenter:onDayTimer()
	if not server.serverCenter:IsCross() then return end

	if lua_app.day() == 1 then
		self:GiveMonthRankReward()
	end
end

--发放月度排名奖励
function GuildMinewarCenter:GiveMonthRankReward()
	local monthRank = self:GetMonthRank()
	for __, index in pairs(monthRank.servermap) do
		for rank, data in ipairs(monthRank[index]) do
			self:SendOne(data.serverId, "GiveMonthRankReward", data.guildId, rank)
			if rank == _MonthRankReward then break end
		end
	end
	self.monthRank = false
	self.cache.guildRecord = {}
end

function GuildMinewarCenter:Test(func, ...)
	if GuildMinewarCenter[func] then
		GuildMinewarCenter[func](self, ...)
	end
end

server.SetCenter(GuildMinewarCenter, "guildMinewarCenter")
return GuildMinewarCenter
