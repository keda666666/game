local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_timer = require "lua_timer"
local KingMap = require "king.KingMap"
local KingCamp = require "king.KingCamp"
local KingCity = require "king.KingCity"
local KingConfig = require "resource.KingConfig"
local _Camp = KingConfig.camp

-- 跨服争霸跨服主控文件
local KingCenter = {}

function KingCenter:CallLogics(funcname, ...)
	return server.serverCenter:CallLogics("KingLogicCall", funcname, ...)
end

function KingCenter:SendLogics(funcname, ...)
	server.serverCenter:SendLogics("KingLogicSend", funcname, ...)
end

function KingCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "KingLogicSend", funcname, ...)
end

function server.KingWarCall(src, funcname, ...)
	lua_app.ret(server.kingCenter[funcname](server.kingCenter, ...))
end

function server.KingWarSend(src, funcname, ...)
	server.kingCenter[funcname](server.kingCenter, ...)
end

-- self.servermap	服务器id到战场id的索引 self.servermap[serverid] = mapindex
-- self.mapserver 	战场id到服务器id的索引 self.mapserver[mapindex] = serverid
-- self.maplist		战场列表 self.maplist[mapindex] = KingMap
-- self.begintime 	活动正式开始的时间(倒计时完成)
-- self.begin 		活动是否正式开启

function KingCenter:Init()
	if not server.serverCenter:IsCross() then return end

	local KingBaseConfig = server.configCenter.KingBaseConfig
	local thetime = KingBaseConfig.opentime
	local opentime = lua_util.split(thetime[1],":")
	self.openhm = {hour = tonumber(opentime[1]), minute = tonumber(opentime[2])}

	local endtime = lua_util.split(thetime[2],":")
	self.endhm = {hour = tonumber(endtime[1]), minute = tonumber(endtime[2])}

	self.timer = lua_timer.add_timer_day(thetime[1], -1, self.CheckStart, self)
	lua_timer.add_timer_day(KingBaseConfig.tipstime[1], -1, self.CheckNotice, self)
	-- local function _Test()
	-- 	self:Start()
	-- end
	-- self.testtimer = lua_app.add_timer(10000, _Test)
end

function KingCenter:HotFix()
	print("KingCenter:HotFix-----------", self.timer)
end

function KingCenter:Release()
	if self.maplist then
		for _, kingmap in pairs(self.maplist) do
			kingmap:Release()
		end
	end
end

local _intervalTime = false
local function _GetIntervalTime()
	if not _intervalTime then
		local opentime = server.configCenter.KingBaseConfig.opentime
		local starttime = lua_util.split(opentime[1],":")
		local endtime = lua_util.split(opentime[2],":")
		_intervalTime = ((tonumber(endtime[1]) - tonumber(starttime[1])) * 3600 + (tonumber(endtime[2]) - tonumber(starttime[2])) * 60) * 1000
	end
	return _intervalTime 
end

function KingCenter:CheckDay()
	local week = lua_app.week()
	local config = server.configCenter.KingBaseConfig
	local isopen = false
	for _, w in pairs(config.openday) do
		if week == w then
			isopen = true
		end
	end
	return isopen
end

function KingCenter:CheckStart()
	print("KingCenter:CheckStart----------")
	if not server.serverCenter:IsCross() then return end
	if self.start then
		return
	end
	if self:CheckDay() then
		self:Start()
	end
end

function KingCenter:CheckNotice()
	if self:CheckDay() then
		local KingBaseConfig = server.configCenter.KingBaseConfig
		self:SendLogics("DoNotice", KingBaseConfig.readyNotice, KingBaseConfig.tipstime[2])
	end
end

-- function KingCenter:onHalfHour(hour, minute)
-- 	if not server.serverCenter:IsCross() then return end
-- 	local KingBaseConfig = server.configCenter.KingBaseConfig
-- 	local week = lua_app.week()
-- 	for _, w in pairs(KingBaseConfig.openday) do
-- 		if week ~= w then
-- 			return
-- 		end
-- 	end

-- 	if ((self.openhm.hour * 60 + self.openhm.minute) - (hour * 60 + minute)) == 30 then
-- 		local function _DoNotice()
-- 			self:SendLogics("DoNotice", KingBaseConfig.readyNotice, "2")
-- 		end
-- 		lua_app.add_timer(28 * 60 * 1000, _DoNotice)
-- 	end

-- 	if self.openhm.hour == hour and self.openhm.minute == minute then
-- 		self:Start()
-- 	end

-- 	if self.endhm.hour == hour and self.endhm.minute == minute then
-- 		self:End()
-- 	end
-- end

-- 活动开启
function KingCenter:Start()
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local now = lua_app.now()
	self.sectimer = nil
	self.servermap = {}
	self.serverinfo = {}
	self.mapserver = {}
	-- local serverlist = server.serverCenter:GetLogicServers("war")
	local serverlist = self:CallLogics("ServerInfo")
	local acc = 1
	for serverid, info in pairs(serverlist) do
		if info.serverday >= KingBaseConfig.serverday then
			local mapindex = math.ceil(acc/3)
			self.servermap[serverid] = mapindex
			self.serverinfo[serverid] = info
			self.mapserver[mapindex] = self.mapserver[mapindex] or {}
			table.insert(self.mapserver[mapindex], serverid)
			acc = acc + 1
			lua_app.log_info("KingCenter:Start--- mapindex and serverid:", mapindex, serverid)
		end
	end

	self.maplist = {}
	for mapindex, servers in pairs(self.mapserver) do
		self.maplist[mapindex] = KingMap.new(mapindex, self)
		self.maplist[mapindex]:Init(servers)
	end

	self.start = true
	self.begin = false
	
	self.begintime = now + KingBaseConfig.readytime
	self.activitytime = self:GetActivityTime()
	self.endtime = now + self.activitytime
	local function _Begin()
		self:Begin()
	end
	lua_app.add_timer(KingBaseConfig.readytime * 1000, _Begin)
	-- lua_app.add_timer(KingBaseConfig.readytime, _Begin)

	self:SendLogics("SetOpen", self.start)
	self:SendLogics("DoNotice", KingBaseConfig.startNotice)
	print("KingCenter:Start------------------------------")
	if self.endTimer then
		lua_app.del_local_timer(self.endTimer)
		self.endTimer = nil
	end
	self.endTimer = lua_app.add_update_timer(_GetIntervalTime(), self, "End")
end

function KingCenter:Begin()
	self.begin = true
	for _, kingmap in pairs(self.maplist) do
		kingmap:Begin()
	end

	self:StartSecondTimer()

	print("KingCenter:Begin------------------------------")
end

-- 每秒的定时器
function KingCenter:StartSecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		if not self.begin then return end
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		for _, kingmap in pairs(self.maplist) do
			kingmap:DoSecond()
		end
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

-- 活动结束
function KingCenter:End()
	self.start = false
	self.begin = false
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end
	if self.maplist then
		for _, kingmap in pairs(self.maplist) do
			kingmap:End()
		end
	end
	self:SendLogics("SetOpen", self.start)
end

function KingCenter:onLogout(player)
	if not server.serverCenter:IsCross() then return end
	if not player then return end
	if not self.start then return end
	local kingmap = self:GetPlayerMap(player.dbid)
	if kingmap then
		kingmap:onLogout(player)
	end
end

-- 活动持续时间
function KingCenter:GetActivityTime()
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local thetime = KingBaseConfig.opentime
	local opentime = lua_util.split(thetime[1],":")
	local endtime = lua_util.split(thetime[2],":")
	return (tonumber(endtime[1]) - tonumber(opentime[1])) * 3600 + (tonumber(endtime[2]) - tonumber(opentime[2])) * 60
end

function KingCenter:GetPlayerMap(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player and self.servermap[player.nowserverid] then
		return self.maplist[self.servermap[player.nowserverid]]
	end
end

function KingCenter:GetMapLine(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		return kingmap.index
	else
		return 0
	end
end

--玩家加入
function KingCenter:Join(playerinfo, israndom)
	if not self.start then return false end
	local player = server.playerCenter:GetPlayerByDBID(playerinfo.dbid)
	local kingmap = self:GetPlayerMap(playerinfo.dbid)
	if kingmap then
		return kingmap:Join(playerinfo, player.nowserverid, israndom)
	else
		print("KingCenter:Join no player map", playerinfo.dbid)
		return false
	end
end

--攻城
function KingCenter:AttackCity(datas, targetcamp)
	if not self.begin then return false end
	local kingmap = self:GetPlayerMap(datas.playerinfo.dbid)
	if kingmap then
		return kingmap:AttackCity(datas, targetcamp)
	else
		return false
	end
end

--参与守卫
function KingCenter:Guard(datas, citycamp)
	if not self.begin then return false end
	local kingmap = self:GetPlayerMap(datas.playerinfo.dbid)
	if kingmap then
		return kingmap:Guard(datas, citycamp)
	else
		return false
	end
end

--自由pk
function KingCenter:PK(datas, targetid)
	if not self.begin then
		server.sendErrByDBID(datas.playerinfo.dbid, "准备状态不能PK")
		return
	end
	local kingmap = self:GetPlayerMap(datas.playerinfo.dbid)
	if kingmap then
		return kingmap:PK(datas, targetid)
	end
end

function KingCenter:MapDo(dbid, funcname, ...)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap and kingmap[funcname] then
		return kingmap[funcname](kingmap, dbid, ...)
	else
		return false
	end
end

-- 获取城池详细信息
function KingCenter:GetCityData(dbid, citycamp)
	if not self.begin then return end
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:GetCityData(dbid, citycamp)
	end
end

-- 花钱复活
function KingCenter:PayRevive(dbid)
	if not self.begin then return end
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:PayRevive(dbid)
	end
end

-- 离开游戏
function KingCenter:Leave(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:Leave(dbid)
	end
end

-- 领取积分奖励
function KingCenter:GetPointReward(dbid, ptype, index)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:GetPointReward(dbid, ptype, index)
	end
end

-- 积分数据
function KingCenter:GetPointData(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:SendPonitData(dbid)
	end
end

-- 玩家变身
function KingCenter:Transform(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:Transform(dbid)
	end
end

function KingCenter:GetMyGuard(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:GetMyGuard(dbid)
	end
end

function KingCenter:SetFighting(dbid, fighting)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:SetFighting(dbid, fighting)
		kingmap:BroadcastFightingChange()
	end
end

function KingCenter:CanTeam(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		return kingmap:CanTeam(dbid)
	end
end

function KingCenter:TeamRecruit(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:TeamRecruit(dbid)
	end
end

function KingCenter:onLeaveMap(dbid, mapid, ...)
	if not server.serverCenter:IsCross() then return end
	local map = server.configCenter.MapConfig[mapid]
	if not map then return end
	if map.type ~= server.raidConfig.type.KingCity then return end
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:onLeaveMap(dbid, mapid, ...)
	end
end

-- 快速死亡
function KingCenter:TestDead(dbid)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:TestDead(dbid)
	end
end

function KingCenter:TestPoint(dbid, point)
	local kingmap = self:GetPlayerMap(dbid)
	if kingmap then
		kingmap:TestPoint(dbid, point)
	end
end

server.SetCenter(KingCenter, "kingCenter")
return KingCenter
