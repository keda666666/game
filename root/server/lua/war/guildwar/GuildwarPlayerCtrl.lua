local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"


local GuildwarPlayerCtrl = oo.class()

---跨服帮战， 玩家数据主控文件
function GuildwarPlayerCtrl:ctor()
	self.playerlist = {}
	self.guildlist = {}
	self.playerCount = 0
	self.guildCount = 0
	self.playerRanks = {}
	self.guildRanks = {}
	self.playerMonitors = {}
	self.guildMonitors = {}
	self.effectKey = {
		addKey = {},
		syncKey = {},
		rankKey = {},
	}
end

function GuildwarPlayerCtrl:Release()
end

--初始化玩家
function GuildwarPlayerCtrl:InitPlayer(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local baseinfo = player:BaseInfo()
	local data = {
		dbid = dbid,
		guildid = baseinfo.guildid,
		serverid = player.nowserverid,
		playerinfo = baseinfo,
		online = false,
	}
	self.playerlist[dbid] = data

	--添加帮会信息
	if not self.guildlist[baseinfo.guildid] then
		self:InitGuild({
				guildid = baseinfo.guildid,
				guildname = baseinfo.guildname,
				serverid = player.nowserverid,
				leaderName = player.guild:GetLeaderName(),
			})
	end
end

--初始化帮会
function GuildwarPlayerCtrl:InitGuild(datas)
	local guilddata = {
		guildid = datas.guildid,
		guildname = datas.guildname,
		serverid = datas.serverid,
		leaderName = datas.leaderName,
		enternumber = 0, 	--进入人数
	}
	self.guildlist[datas.guildid] = guilddata
end

--更新函数
local function _UpdateDatas(srcdata, newdatas, addKey, olddatas)
	olddatas = olddatas or {}
	for k, v in pairs(newdatas) do
		if type(v) == "table" then
			olddatas[k] = {}
			srcdata[k] = srcdata[k] or {}
			_UpdateDatas(srcdata[k], v, addKey, olddatas[k])
		else
			olddatas[k] = srcdata[k]
			if addKey[k] then
				if v == math.huge then
					srcdata[k] = 0
				else
					srcdata[k] = (srcdata[k] or 0) + v
				end
			else
				srcdata[k] = v
			end
		end
	end
	return olddatas
end

--同步过滤器
local function _SyncFilte(data, synckey)
	for k, v in pairs(data) do
		if type(v) == "table" then
			_SyncFilte(v, synckey)
			if next(v) == nil then
				data[k] = nil
			end
		else
			if not synckey[k] then
				data[k] = nil
			end
		end
	end
end

--提取排行key
local function _ExtractRank(data, rankkey, keys)
	keys = keys or {}
	for k, v in pairs(data) do
		if type(v) == "table" then
			_ExtractRank(v, rankkey, keys)
		else
			if rankkey[k] then
				keys[k] = true
			end
		end
	end
	return keys
end

--通知监听
local function _NoticeMonitor(datas, monitorkey , instance, func, id, olddatas)
	for k, v in pairs(datas) do
		if type(v) == "table" then
			_NoticeMonitor(v, monitorkey , instance, func, id, olddatas)
		else
			if monitorkey[k] then
				instance[func](instance, id, k, olddatas)
			end
		end
	end
end 

--更新玩家数据
function GuildwarPlayerCtrl:UpdatePlayer(dbid, newdatas)
	local playerdata = self:GetPlayerData(dbid)
	local oldonline = playerdata.online
	local olddatas = _UpdateDatas(playerdata, newdatas, self.effectKey.addKey)
	--需要排行的key
	local rankkeys = _ExtractRank(newdatas, self.effectKey.rankKey)
	if next(rankkeys) ~= nil then
		for rankkey, __ in pairs(rankkeys) do
			local rankname = rankkey.."Rank"
			local rankdata = self.playerRanks[rankname]
			if not rankdata then 
				rankdata = {}
				self.playerRanks[rankname] = rankdata
			end
			local function _LargerFunc(currdata, secenddata)
				return currdata[rankkey] >= secenddata[rankkey]
			end
			local status = self:RecalculateRank(rankdata, playerdata, _LargerFunc, rankname)
			if status then
				self:NotifyPlayerMonitor(dbid, rankname, status)
			end
		end
	end

	--通知监听模块
	_NoticeMonitor(newdatas, self.playerMonitors, self, "NotifyPlayerMonitor", dbid, olddatas)

	--同步帮会数据
	_SyncFilte(newdatas, self.effectKey.syncKey)
	if oldonline ~= playerdata.online then
		newdatas.enternumber = playerdata.online and 1 or -1
		print(oldonline, playerdata.online, dbid, newdatas.enternumber, "================================")
	end
	if next(newdatas) ~= nil then
		self:UpdateGuild(playerdata.guildid, newdatas)
	end
end

--更新帮会数据
function GuildwarPlayerCtrl:UpdateGuild(guildid, newdatas)
	local guilddata = self:GetGuildData(guildid)
	local olddatas = _UpdateDatas(guilddata, newdatas, self.effectKey.addKey)

	--需要排行的key
	local rankkeys = _ExtractRank(newdatas, self.effectKey.rankKey)
	if next(rankkeys) ~= nil then
		for rankkey, __ in pairs(rankkeys) do
			local rankname = rankkey.."Rank"
			local rankdata = self.guildRanks[rankname]
			if not rankdata then 
				rankdata = {}
				self.guildRanks[rankname] = rankdata
			end
			local function _LargerFunc(currdata, secenddata)
				return currdata[rankkey] >= secenddata[rankkey]
			end
			local status = self:RecalculateRank(rankdata, guilddata, _LargerFunc, rankname)
			if status then
				self:NotifyGuildMonitor(guildid, rankname, status)
			end
		end
	end

	--通知监听模块
	_NoticeMonitor(newdatas, self.guildMonitors, self, "NotifyGuildMonitor", guildid,  olddatas)
end

local _RegisteKey = setmetatable({}, {__index = function() return function() end end})
_RegisteKey[1] = function(effectKey, key)
	effectKey.addKey[key] = true
end

_RegisteKey[2] = function(effectKey, key)
	effectKey.syncKey[key] = true
end

_RegisteKey[3] = function(effectKey, key)
	effectKey.rankKey[key] = true
end

--注册功能key
function GuildwarPlayerCtrl:RegisteEffectKey(key, keytype)
	for i = 1, 3 do
		if lua_util.bit_status(keytype, i) then
			_RegisteKey[i](self.effectKey, key)
		end
	end
end

--取玩家数据
function GuildwarPlayerCtrl:GetPlayerData(dbid)
	local playerdata = self.playerlist[dbid]
	if not playerdata then
		lua_app.log_error(">> GuildwarPlayerCtrl get playerdata not dbid", dbid)
		return
	end
	return playerdata
end

--获取玩家列表
function GuildwarPlayerCtrl:GetPlayerlist()
	return self.playerlist
end

--获取玩家排行数据
function GuildwarPlayerCtrl:GetPlayerRankdata(rankname)
	self.playerRanks[rankname] = self.playerRanks[rankname] or {}
	return self.playerRanks[rankname]
end

--取帮会数据
function GuildwarPlayerCtrl:GetGuildData(guildid)
	local guilddata = self.guildlist[guildid]
	if not guilddata then
		lua_app.log_error(">> GuildwarPlayerCtrl get guilddata not guildid", guildid)
		return
	end
	return guilddata
end

function GuildwarPlayerCtrl:GetGuildDataByDBID(dbid)
	local playerdata = self:GetPlayerData(dbid)
	return self:GetGuildData(playerdata.guildid)
end

--获取帮会排行数据
function GuildwarPlayerCtrl:GetGuildRankdata(rankname)
	self.guildRanks[rankname] = self.guildRanks[rankname] or {}
	return self.guildRanks[rankname]
end

--插入查找
local function _FindInsertIndex(datas, data, beginindex, endindex, largerFunc)
	if beginindex >= endindex then
		return beginindex
	end
	local checkindex = beginindex + math.floor((endindex - beginindex)/2)
	if largerFunc(datas[checkindex], data) then
		return _FindInsertIndex(datas, data, checkindex + 1, endindex, largerFunc)
	else
		return _FindInsertIndex(datas, data, beginindex, checkindex, largerFunc)
	end
end

--计算排行
function GuildwarPlayerCtrl:RecalculateRank(basicdata, newdata, largerfunc, rankkey)
	local originindex = #basicdata + 1
	for index, data in ipairs(basicdata) do
		if data.dbid then
			if data.dbid == newdata.dbid then
				originindex = index
				break
			end
		else 
			if data.guildid == newdata.guildid then
				originindex = index
				break
			end
		end
	end
	table.remove(basicdata, originindex)

	local newindex = _FindInsertIndex(basicdata, newdata, 1, #basicdata + 1, largerfunc)
	--这里新的排名大于原来的排名 说明更新数值为0  排名不做处理
	if newindex > originindex then
		table.insert(basicdata, originindex, newdata)
		return
	end

	table.insert(basicdata, newindex, newdata)

	for rank, data in ipairs(basicdata) do
		data[rankkey] = rank
	end
	--前三名变动标记
	local top3change = originindex <= 3 or newindex <= 3
	return {
		top3 = top3change, 
		endindex = originindex, 
		beginindex = newindex,
	}
end

--空的检测函数
local _EmptyVerifyFunc = function()
	return true
end

--注册玩家监听
function GuildwarPlayerCtrl:RegistePlayerMonitor(instance, monitorkey, noticefunc, verifyfunc)
	self.playerMonitors[monitorkey] = self.playerMonitors[monitorkey] or {}
	table.insert(self.playerMonitors[monitorkey], {
			instance = instance,
			noticefunc = noticefunc,
			verifyfunc = verifyfunc or _EmptyVerifyFunc,
		})
end

--通知监听模块
function GuildwarPlayerCtrl:NotifyPlayerMonitor(dbid, monitorkey, ...)
	local modules = self.playerMonitors[monitorkey] or {}
	for __, monitordata in ipairs(modules) do
		if monitordata.verifyfunc(dbid) then
			if monitordata.instance[monitordata.noticefunc] then
				monitordata.instance[monitordata.noticefunc](monitordata.instance, dbid, monitorkey, ...)
			else
				lua_app.log_error(">>NotifyPlayerMonitor noticefunc not exist.", monitordata.noticefunc)
			end
		end
	end
end

--注册监听
function GuildwarPlayerCtrl:RegisteGuildMonitor(instance, monitorkey, noticefunc, verifyfunc)
	self.guildMonitors[monitorkey] = self.guildMonitors[monitorkey] or {}
	table.insert(self.guildMonitors[monitorkey], {
			instance = instance,
			noticefunc = noticefunc,
			verifyfunc = verifyfunc or _EmptyVerifyFunc,
		})
end

--通知监听模块
function GuildwarPlayerCtrl:NotifyGuildMonitor(guildid, monitorkey, ...)
	local modules = self.guildMonitors[monitorkey] or {}
	for __, monitordata in ipairs(modules) do
		if monitordata.verifyfunc(guildid) then
			if monitordata.instance[monitordata.noticefunc] then
				monitordata.instance[monitordata.noticefunc](monitordata.instance, guildid, monitorkey, ...)
			else
				lua_app.log_error(">>NotifyGuildMonitor noticefunc not exist.", monitordata.noticefunc)
			end
		end
	end
end

function GuildwarPlayerCtrl:Debug(dbid)
	table.ptable(self.playerMonitors, 2)
end

return GuildwarPlayerCtrl

