local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local tbname = "datalist"
local tbcolumn = "escort"

local EscortCenter = {}

local _MaxRobListNum = 20

function EscortCenter:Init()
	self.playertimer = {}
	self.sortEscortList = {}
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.escortList = self.cache.escortList
end

local function _LargerFunc(data1, data2)
	if data1.quality >= data2.quality then
		if data1.quality > data2.quality then return true end
		if data1.power <= data2.power then
			if data1.power < data2.power then return true end
			return data1.playerid < data2.playerid
		end
	end
	return false
end

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

local function _InsertEscortList(datas, data)
	local index = _FindInsertIndex(datas, data, 1, #datas + 1, _LargerFunc)
	table.insert(datas, index, data)
end

local function _RemoveEscortList(datas, data)
	local index = _FindInsertIndex(datas, data, 1, #datas + 1, _LargerFunc)
	if datas[index].playerid ~= data.playerid then
		return
	end
	table.remove(datas, index)
end

--每秒定时器
function EscortCenter:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		self:MonitorComplete()
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

--检测任务完成
function EscortCenter:MonitorComplete()
	local nowtime = lua_app.now()
	local queueEmpty = true
	for dbid, escortdata in pairs(self.escortList) do
		if escortdata.finishTime < nowtime then
			self:CompleteEscort(dbid)
		end
		queueEmpty = false
	end

	if queueEmpty then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end
end

function EscortCenter:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function EscortCenter:AddEscort(data)
	if self.escortList[data.playerid] then
		lua_app.log_info(">>EscortCenter:AddEscort -- The mission's not finished.")
		return false
	end
	self.escortList[data.playerid] = data
	_InsertEscortList(self.sortEscortList, data)

	if not self.sectimer then
		self:SecondTimer()
	end
end

function EscortCenter:GetEscortInfo(robId, playerId)
	if not self.escortList[playerId] then
		lua_app.log_info(">>EscortCenter:AddEscort -- The mission's not finished.")
		return
	end
	local data = table.wcopy(self.escortList[playerId])
	if data.robPlayer[robId] then
		data.robMark = true
	end
	return data
end
--移除
function EscortCenter:RemoveEscort(playerid)
	if not self.escortList[playerid] then
		return
	end
	local data = self.escortList[playerid]
	self.escortList[playerid] = nil
	_RemoveEscortList(self.sortEscortList, data)
end

function EscortCenter:GetEscortList(playerid)
	local dataList = {}
	local addCount = 0
	local addRecord = {}
	local escortNum = #self.sortEscortList

	for i = 1, escortNum do
		local data = self.sortEscortList[i]
		if not data or addCount == _MaxRobListNum then break end 	--达到要求退出循环
		if self:CheckCatch(playerid, data.playerid) and data.playerid ~= playerid then
			table.insert(dataList, data)
			addRecord[i] = true
			addCount = addCount + 1
		end
	end

	if addCount < _MaxRobListNum then
		for i = 1, escortNum do
			local data = self.sortEscortList[i]
			if not addRecord[i] and data.playerid ~= playerid then
				table.insert(dataList, data)
			end
		end
	end
	return dataList
end

function EscortCenter:CheckEscort(playerid)
	if not self.escortList[playerid] then
		lua_app.log_info("EscortCenter: escort not exist. playerid:", playerid)
		return false
	end
	local data = self.escortList[playerid]
	local finishTime = data.finishTime
	local nowTime = lua_app.now() 
	return nowTime >= finishTime
end

--检测拦截
function EscortCenter:CheckCatch(robId, playerid)
	if not self.escortList[playerid] then
		lua_app.log_info("EscortCenter: escort not exist. playerid:"..playerid)
		return false
	end
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local data = self.escortList[playerid]
	local ret = false
	if data.catchCount < EscortBaseConfig.robnum and not data.robPlayer[robId] then
		ret = true
	end
	return ret, data.quality
end

--拦截
function EscortCenter:Catch(robId, playerid)
	if not self.escortList[playerid] then
		lua_app.log_info("EscortCenter: escort not exist. playerid:"..playerid)
		return false
	end
	local data = self.escortList[playerid]
	data.catchCount = data.catchCount + 1
	data.robPlayer[robId] = true
end

--护送完成
function EscortCenter:CompleteEscort(playerId)
	local player = server.playerCenter:DoGetPlayerByDBID(playerId)
	local data = self.escortList[playerId]
	self:RemoveEscort(playerId)
	player.escort:CompleteEscort(data)
end

--快速完成
function EscortCenter:QuickCompleteEscort(playerid)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	if not player:PayRewards({EscortBaseConfig.completecostb}, server.baseConfig.YuanbaoRecordType.Escort, "EscortCenter:QuickComplete") then
		lua_app.log_info("QuickCompleteEscort:PayRewards faild. playerid", playerid)
		return
	end
	self:CompleteEscort(playerid)
end

function EscortCenter:GetDoubleStatus()
	return self.doubletime
end

function EscortCenter:onHalfHour(hour, minute)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local nowtimestr = string.format("%.2d:%.2d", hour, minute)
	for __, tiemdata in ipairs(EscortBaseConfig.doubletime) do
		if string.find(tiemdata.star, nowtimestr) then
			self.doubletime = true
			server.chatCenter:ChatLink(33)
		end
	end
	for __, tiemdata in ipairs(EscortBaseConfig.doubletime) do
		if string.find(tiemdata.ends, nowtimestr) then
			self.doubletime = false
		end
	end
end

function EscortCenter:ServerOpen()
	for playerid, data in pairs(self.escortList) do
		_InsertEscortList(self.sortEscortList, data)
	end
	self:SecondTimer()
end

server.SetCenter(EscortCenter, "escortCenter")
return EscortCenter
