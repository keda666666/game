local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local RankConfig = require "resource.RankConfig"
local tbname = server.GetSqlName("ranks")

local RankCenter = {}
local _SaveTime = 1800
local _RefreshTime = 600

local _IsUsefulData = {}
_IsUsefulData["power"] = function(data)
	return data.power > 0
end

_IsUsefulData["count"] = function(data)
	return data.count > 0
end

_IsUsefulData["level"] = function(data)
	return data.level > 0
end

_IsUsefulData["chapterlevel"] = function(data)
	return data.chapterlevel > 0
end

-- _IsUsefulData[RankConfig.RankType.LADDER] = function(data)
-- 	return data.challgeLevel > 1 or data.challgeId > 0
-- end

local _CompareData = {}
_CompareData["power"] = function(data1, data2)
	return data1.power > data2.power
end

_CompareData["count"] = function(data1, data2)
	return data1.count > data2.count
end

_CompareData["level"] = function(data1, data2)
	return data1.level > data2.level
end

_CompareData["chapterlevel"] = function(data1, data2)
	return data1.chapterlevel > data2.chapterlevel
end

-- _CompareData[RankConfig.RankType.LADDER] = function(data1, data2)
-- 	return data1.challgeLevel > data2.challgeLevel or data1.challgeLevel == data2.challgeLevel and
-- 		(data1.challgeId > data2.challgeId or data1.challgeId == data2.challgeId and data1.winNum > data2.winNum)
-- end

function RankCenter:Init()
	self.ranks = {}
	self.playersCache = {}		-- 玩家数据缓存，用来查看玩家数据的，服务器初始化时加载，玩家下线时更新
	self.needUpdateCache = {}	-- 需要更新的玩家缓存
	self.playersNewDatas = {}	-- 玩家下线后的最新数据，用来在玩家离线时更新排名，更新完就清空
	self.needUpdatePlayers = {}	-- 需要更新的玩家列表
	self.rankdataFunc = {}		-- 用于注册生成data的函数
	self.rankTypeList = {}		-- 储存已开启的排行榜类型

	for k, v in pairs(RankConfig.RankType) do
		if RankConfig.ActiveRankTypes[v] then
			self.rankTypeList[k] = v
		end
	end
	-- local playeridList = {}
	local function _InitRank(v)
		local values = server.mysqlCenter:query(tbname, { type = v })
		local datas = {}
		for _, i in pairs(values) do
			table.insert(datas, i.data)
		end
		table.sort(datas, _CompareData[RankConfig.CompareData[v]])
		local dt, ptr = {}, {}
		for i = 1, math.min(RankConfig.MaxRank[v], #datas) do
			dt[i] = datas[i]
			dt[i].pos = i
			ptr[dt[i].id] = i
		end
		-- for i = 1, math.min(RankConfig.MaxShowRank[v], #datas) do
		-- 	playeridList[datas[i].id] = true
		-- end
		return {
			type = v,
			callBackFuncs = {},
			realTimeFuncs = {},
			playeridToRank = ptr,
			datas = dt,
		}
	end
	for _, v in pairs(self.rankTypeList) do
		self.ranks[v] = _InitRank(v)
	end
	for _, v in pairs(RankConfig.DynRankType) do
		if RankConfig.ActiveRankTypes[v] and not self.ranks[v] then
			local rankData = _InitRank(v)
			if next(rankData.datas) then
				self.ranks[v] = rankData
			end
		end
	end
	-- if not self:InitPlayersCache(playeridList) then
	-- 	self:ReInitRanks()
	-- end
	local function _RunRefreshRank()
		self.refreshTimer = lua_app.add_timer(_RefreshTime * 1000, _RunRefreshRank)
		lua_app.waitlockrun(self, function()
				local ret, errmsg = pcall(self.RefreshRanks, self)
				if not ret then
					lua_app.log_error("Rank:RefreshRanks::", errmsg)
				end
			end, 5)
	end
	self.refreshTimer = lua_app.add_timer((_RefreshTime*2 - math.fmod(lua_app.now(), _RefreshTime)) * 1000, _RunRefreshRank)
	local function _RunSaveRank()
		self.saveTimer = lua_app.add_timer(_SaveTime * 1000, _RunSaveRank)
		lua_app.waitlockrun(self, function()
				local ret, errmsg = pcall(self.Save, self)
				if not ret then
					lua_app.log_error("Rank:Save::", errmsg)
				end
			end, 5)
	end
	self.saveTimer = lua_app.add_timer((_SaveTime + math.random(1, math.ceil(_SaveTime/3))) * 1000, _RunSaveRank)
end

function RankCenter:ReInitRanks(forceall)
	self:RefreshAllPlayerNewData(true)
	-- local playeridList = {}
	for t, v in pairs(self.ranks) do
		if forceall or not RankConfig.RealtimeUpdates[t] then
			v.datas = {}
			for playerid, datas in pairs(self.playersNewDatas) do
				if datas[t] then
					table.insert(v.datas, datas[t])
				end
			end
			table.sort(v.datas, _CompareData[RankConfig.CompareData[t]])
			local dt, ptr = {}, {}
			for i = 1, math.min(RankConfig.MaxRank[t], #v.datas) do
				dt[i] = v.datas[i]
				dt[i].pos = i
				ptr[dt[i].id] = i
			end
			v.datas = dt
			v.playeridToRank = ptr
		end
		-- for i = 1, math.min(RankConfig.MaxShowRank[t], #v.datas) do
		-- 	playeridList[v.datas[i].id] = true
		-- end
	end
	-- table.ptable(self.ranks, 5)
	-- self:InitPlayersCache(playeridList)
end

-- function RankCenter:InitPlayersCache(playeridList)
-- 	self.playersCache = {}
-- 	for dbid, _ in pairs(playeridList) do
-- 		local actor = server.playerCenter:GetPlayerCacheByDBID(dbid)
-- 		if actor then
-- 			self:UpdatePlayersCache(actor)
-- 		else
-- 			return false
-- 		end
-- 	end
-- 	return true
-- end

function RankCenter:Release()
	if self.refreshTimer then
		lua_app.del_timer(self.refreshTimer)
		self.refreshTimer = nil
	end
	if self.saveTimer then
		lua_app.del_timer(self.saveTimer)
		self.saveTimer = nil
	end
	lua_app.waitlockrun(self, function()
			self:RefreshRanks()
			self:Save()
		end, 3)
end

function RankCenter:Save()
	server.mysqlCenter:delete(tbname)
	for t, v in pairs(self.ranks) do
		local sqldata = {}
		for _, data in pairs(v.datas) do
			table.insert(sqldata, { type = t, rank = data.pos, data = data })
		end
		if #sqldata > 0 then
			server.mysqlCenter:insert_ms(tbname, sqldata)
		end
	end
end

function RankCenter:UpdatePlayersCache(player)
	local data = {}
	local cache = {
		playerData = {
			playerid      = player.dbid,
			name          = player.name,
			level         = player.cache.level(),
			vip           = player.cache.vip_level(),
			power         = player.cache.totalpower(),
		},
	}
	self.playersCache[player.dbid] = cache
	self.needUpdateCache[player.dbid] = nil
end

function RankCenter:GetPlayersCache(playerid, serverid)
	local info = self.playersCache[playerid]
	if not info or self.needUpdateCache[playerid] then
		local player = server.playerCenter:DoGetPlayerByDBID(playerid, serverid)
		self:UpdatePlayersCache(player)
		info = self.playersCache[playerid]
	end
	return info
end

local function _CommonGetPlayerData(rankType, dbDatas)
	local rankDatas = RankConfig.RankDatas[rankType]
	local ret = {}
	for i, dbName in pairs(rankDatas) do
		if dbDatas[dbName] ~= nil then
			ret[i] = dbDatas[dbName]
		else
			if dbName ~= "serverid" then
				lua_app.log_error("_CommonGetPlayerData:: no data:", rankType, dbName)
			end
		end
	end
	-- if ret.month then
	-- 	ret.month = ret.month > lua_app.now() and 1 or 0
	-- end
	if _IsUsefulData[RankConfig.CompareData[rankType]](ret) then
		return ret
	else
		return nil
	end
end

function RankCenter:GetPlayerNewData(dbDatas, getAll)
	local datas = {}
	for _, v in pairs(self.rankTypeList) do
		if self.rankdataFunc[v] then
			datas[v] = self.rankdataFunc[v](dbDatas)
		else
			datas[v] = _CommonGetPlayerData(v, dbDatas)
		end
	end
	if getAll then
		for _, v in pairs(RankConfig.DynRankType) do
			if RankConfig.ActiveRankTypes[v] and not datas[v] then
				if self.rankdataFunc[v] then
					datas[v] = self.rankdataFunc[v](dbDatas)
				else
					datas[v] = _CommonGetPlayerData(v, dbDatas)
				end
			end
		end
	end
	self.playersNewDatas[dbDatas.dbid] = datas
end

function RankCenter:RefreshLoginPlayerNewData(getAll)
	local conds = RankConfig.AllRankSqlDatas
	if conds.dbid then
		local players = server.playerCenter:GetOnlinePlayers()
		for _, player in pairs(players) do
			local dbDatas = player:GetPlayerCacheStr(conds)
			self:GetPlayerNewData(dbDatas, getAll)
		end
		for dbid, _ in pairs(self.needUpdatePlayers) do
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			local dbDatas = player:GetPlayerCacheStr(conds)
			self:GetPlayerNewData(dbDatas, getAll)
		end
	end
	self.needUpdatePlayers = {}
end

function RankCenter:RefreshAllPlayerNewData(getAll)
	self.playersNewDatas = {}
	local dataslist = server.serverCenter:CallLogics("GetAllPlayerCacheStr", RankConfig.AllRankSqlDatas)
	for _, datas in pairs(dataslist) do
		for _, data in ipairs(datas) do
			self:GetPlayerNewData(data, getAll)
		end
	end
	self.needUpdatePlayers = {}
	self.playersCache = {}
end

local function _RefreshRank(self, t)
	-- print("_RefreshRank:", t)
	local v = self.ranks[t]
	if not v then
		lua_app.log_error("_RefreshRank:: no type", t)
		return
	end
	if not RankConfig.RealtimeUpdates[t] then
		for playerid, datas in pairs(self.playersNewDatas) do
			if datas[t] then
				if v.playeridToRank[playerid] then
					v.datas[v.playeridToRank[playerid]] = datas[t]
				else
					table.insert(v.datas, datas[t])
				end
			end
		end
		-- table.ptable(v.datas, 2)
		table.sort(v.datas, _CompareData[RankConfig.CompareData[t]])
		local dt, ptr = {}, {}
		for i = 1, math.min(RankConfig.MaxRank[t], #v.datas) do
			dt[i] = v.datas[i]
			dt[i].pos = i
			ptr[dt[i].id] = i
		end
		v.datas = dt
		v.playeridToRank = ptr
		for _, value in pairs(v.callBackFuncs) do
			value.func(value.param, v.type, v.datas, v.playeridToRank)
		end
		-- table.ptable(dt, 3)
	else
		-- for playerid, datas in pairs(self.playersNewDatas) do
		-- 	if datas[t] then
		-- 		local pos = v.playeridToRank[playerid]
		-- 		if pos then
		-- 			datas[t].pos = pos
		-- 			v.datas[pos] = datas[t]
		-- 		end
		-- 	end
		-- end
	end
end

-- 正常刷新所有开启的排行榜
function RankCenter:RefreshRanks()
	self:RefreshLoginPlayerNewData()
	local cache = {}
	local unuseType = {}
	for t, _ in pairs(self.ranks) do
		unuseType[t] = true
	end
	for _, t in pairs(self.rankTypeList) do
		unuseType[t] = nil
		_RefreshRank(self, t)
		local datas = self.ranks[t].datas
		for i = 1, math.min(RankConfig.MaxShowRank[t], #datas) do
			cache[datas[i].id] = self.playersCache[datas[i].id]
		end
	end
	for t, _ in pairs(unuseType) do
		self.ranks[t] = nil
	end
	self.playersNewDatas = {}
	self.playersCache = cache
	-- print("---------------------------")
	-- table.ptable(self.ranks, 9)
	-- print("===========================")
end

-- 正常刷新一种排行榜
function RankCenter:RefreshRank(t)
	self:RefreshLoginPlayerNewData()
	_RefreshRank(self, t)
end

-- 重置所有数据 runRankFunc=true 为调用回调
function RankCenter:ReBuildAllRankDatas(runRankFunc)
	if runRankFunc then
		for t, _ in pairs(self.ranks) do
			self:ClearRank(t)
		end
	end
	self:ReInitRanks()
	if runRankFunc then
		for t, _ in pairs(self.ranks) do
			self:RunRankFunc(t)
		end
	end
end

-- 去掉 未开启的排名种类 并 ReBuildAllRankDatas
function RankCenter:ResetAll(runRankFunc)
	local unuseType = {}
	for t, _ in pairs(self.ranks) do
		unuseType[t] = true
	end
	for _, t in pairs(self.rankTypeList) do
		unuseType[t] = nil
	end
	for t, _ in pairs(unuseType) do
		if runRankFunc then
			self:ClearRank(t)
		end
		self.ranks[t] = nil
	end
	self:ReBuildAllRankDatas(runRankFunc)
end

function RankCenter:RunRankFunc(type)
	local rankValue = self.ranks[type]
	if RankConfig.RealtimeUpdates[rankValue] == true then
		for _, data in pairs(rankValue.datas) do
			for _, value in pairs(rankValue.realTimeFuncs) do
				value.func(value.param, rankValue.type, data.id, nil, data.pos)
			end
		end
	end
	for _, value in pairs(rankValue.callBackFuncs) do
		value.func(value.param, rankValue.type, rankValue.datas, rankValue.playeridToRank)
	end
end

function RankCenter:ClearRank(type)
	local rankValue = self.ranks[type]
	if RankConfig.RealtimeUpdates[rankValue] == true then
		for _, data in pairs(rankValue.datas) do
			for _, value in pairs(rankValue.realTimeFuncs) do
				value.func(value.param, rankValue.type, data.id, data.pos)
			end
		end
	end
	rankValue.playeridToRank = {}
	rankValue.datas = {}
	for _, value in pairs(rankValue.callBackFuncs) do
		value.func(value.param, rankValue.type, rankValue.datas, rankValue.playeridToRank)
	end
end

function RankCenter:OpenRank(type)
	if self.rankTypeList[type] then
		lua_app.log_error("RankCenter:OpenRank: reopen type:", type)
		return
	end
	lua_app.log_info("RankCenter:OpenRank", type)
	self.rankTypeList[type] = type
	self.ranks[type] = self.ranks[type] or {
			type = type,
			callBackFuncs = {},
			realTimeFuncs = {},
			playeridToRank = {},
			datas = {},
		}
end

function RankCenter:CloseRank(type)
	if not self.rankTypeList[type] then
		lua_app.log_error("RankCenter:CloseRank: no rank type:", type)
		return
	end
	lua_app.log_info("RankCenter:CloseRank", type)
	self.rankTypeList[type] = nil
	self.ranks[type] = nil
end

local function _ChangeRank(compareFunc, rankValue, rank, data, isup)
	local function _SetRank(rankValue, data, rank)
		for _, v in pairs(rankValue.realTimeFuncs) do
			v.func(v.param, rankValue.type, data.id, data.pos, rank)
		end
		data.pos = rank
		rankValue.playeridToRank[data.id] = rank
		rankValue.datas[rank] = data
	end
	local change = isup and -1 or 1
	local nextRank = rank + change
	local nextData = rankValue.datas[nextRank]
	while nextData and compareFunc(data, nextData) == isup do
		_SetRank(rankValue, nextData, rank)
		rank = nextRank
		nextRank = rank + change
		nextData = rankValue.datas[nextRank]
	end
	_SetRank(rankValue, data, rank)
	for _, value in pairs(rankValue.callBackFuncs) do
		value.func(value.param, rankValue.type, rankValue.datas, rankValue.playeridToRank)
	end
	return rank
end

function RankCenter:RealtimeUpdates(type, dbid, dbDatas)
	if not RankConfig.RealtimeUpdates[type] then
		lua_app.log_error("RankCenter:RealtimeUpdates: type:", type)
		return
	end
	local data
	if self.rankdataFunc[type] then
		data = self.rankdataFunc[type](dbDatas)
	else
		data = _CommonGetPlayerData(type, dbDatas)
	end
	if not data then
		-- table.ptable(dbDatas)
		-- lua_app.log_error("RankCenter:RealtimeUpdates: type:", type, dbid)
		return
	end
	local rankValue = self.ranks[type]
	local rank = rankValue.playeridToRank[dbid]
	local MaxRank = #rankValue.datas
	local compareFunc = _CompareData[RankConfig.CompareData[type]]
	if rank then
		rank = _ChangeRank(compareFunc, rankValue, rank, data, compareFunc(data, rankValue.datas[rank]))
	elseif MaxRank == RankConfig.MaxRank[type] then
		local maxRankData = rankValue.datas[MaxRank]
		if compareFunc(data, maxRankData) then
			for _, v in pairs(rankValue.realTimeFuncs) do
				v.func(v.param, rankValue.type, maxRankData.id, maxRankData.pos)
			end
			rank = _ChangeRank(compareFunc, rankValue, MaxRank, data, true)
		end
	else
		rank = _ChangeRank(compareFunc, rankValue, MaxRank + 1, data, true)
	end
	return rank
end

-- 实时排名更新回调  func(param, 排行榜类型, playerid, 旧排名, 新排名)  其中，没有排名就是nil
function RankCenter:RegRealtimeChangeCallBack(type, func, param)
	assert(RankConfig.RealtimeUpdates[type] == true)
	local rankValue = self.ranks[type]
	table.insert(rankValue.realTimeFuncs, { func = func, param = param })
end

-- 排名更新结果回调，全部更新完后回调一次  func(param, 排行榜类型, 排名数据, playerid对应的排名表)
function RankCenter:RegRankChangeCallBack(type, func, param)
	local rankValue = self.ranks[type]
	table.insert(rankValue.callBackFuncs, { func = func, param = param })
end

function RankCenter:RegRankdataFunc(type, func)
	self.rankdataFunc[type] = func
end

function RankCenter:SendRankDatas(dbid, type)
	local myrank = self:GetMyRank(type, dbid)
	local rankData = myrank and self.ranks[type].datas[myrank]
	server.sendReqByDBID(dbid, "sc_rank_data", {
			type = type,
			datas = self:GetRankDatas(type, 1, RankConfig.MaxSendRank[type]),
			selfRank = myrank or 0,
			value = rankData and rankData[RankConfig.KeyValue[type][1]] or nil,
		})
end

function RankCenter:GetRankFirstDatas(type, rank)
	local rankT = self.ranks[type]
	if not rankT then
		lua_app.log_error("RankCenter:GetRankFirstDatas: undefine ranktype:", type)
		return
	end
	local rankData = rankT.datas[rank or 1]
	local cache = { type = type }
	if not rankData then
		cache.playerData = { playerid = 0 }
		return cache
	end
	local info = self:GetPlayersCache(rankData.id, rankData.serverid)
	if not info then
        lua_app.log_error("RankCenter:GetRankFirstDatas: no first rankData type:", type)
		cache.playerData = { playerid = 0 }
		return cache
	end
	cache.playerData = info.playerData
	return cache
end

function RankCenter:GetMyRank(type, playerid)
	if not self.ranks[type] then
		lua_app.log_error("RankCenter:GetMyRank:: no type", type, playerid)
	end
	return self.ranks[type].playeridToRank[playerid] or false
end

function RankCenter:GetMyRankDatas(type, playerid, upRank, downRank)
	local rank = self.ranks[type].playeridToRank[playerid]
	if rank then
		return self:GetRankDatas(type, math.max(rank - (upRank or 0), 1), rank + (downRank or 0))
	end
end

function RankCenter:GetRankDatas(type, beginRank, endRank)
	if not self.ranks[type] then return {} end
	local datas = self.ranks[type].datas
	if not beginRank and not endRank then return datas end
	local results = {}
	for i = beginRank or 1, endRank or math.huge do
		if not datas[i] then break end
		table.insert(results, datas[i])
	end
	return results
end

function RankCenter:SendOtherPlayerDatas(player, otherid, otherserverid)
	local msg = self:GetPlayersCache(otherid, otherserverid)
	if not msg then
        lua_app.log_error("RankCenter:SendOtherPlayerDatas: player(", player.name , ") no otherid:", otherid)
		return
	end
	server.sendReq(player, "sc_show_rank_player", msg)
end

local _loginNotice = {
	[RankConfig.RankType.POWER] = 87,
}
local _OnlineNoticeTime = {
	[RankConfig.RankType.POWER] = 0,
}
local function _CheckNotice(self, rankType, player)
	if not RankConfig.ActiveRankTypes[rankType] then return false end
	local data = self.ranks[rankType].datas[1]
	if data and data.id == player.dbid then
		if _OnlineNoticeTime[rankType] < lua_app.now() - 300 then
			server.serverCenter:SendLogicsMod("noticeCenter", "Notice", _loginNotice[rankType], player.name)
			_OnlineNoticeTime[rankType] = lua_app.now()
		end
		return true
	end
	return false
end
function RankCenter:onInitClient(player)
	if _CheckNotice(self, RankConfig.RankType.POWER, player) then return end
end

function RankCenter:onLogout(player)
	self.needUpdatePlayers[player.dbid] = true
	self.needUpdateCache[player.dbid] = true
end

server.SetCenter(RankCenter, "rankCenter")
return RankCenter
