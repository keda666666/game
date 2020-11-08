local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_timer = require "lua_timer"
local ClimbMap = require "climb.ClimbMap"
local tbname = server.GetSqlName("wardatas")
local tbcolumn = "climb"

-- 九重天跨服主控文件
local ClimbCenter = {}

function ClimbCenter:CallLogics(funcname, ...)		
	return server.serverCenter:CallLogics("ClimbLogicCall", funcname, ...)
end

function ClimbCenter:SendLogics(funcname, ...)
	server.serverCenter:SendLogics("ClimbLogicSend", funcname, ...)
end

function ClimbCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "ClimbLogicSend", funcname, ...)
end

function server.ClimbWarCall(src, funcname, ...)
	lua_app.ret(server.climbCenter[funcname](server.climbCenter, ...))
end

function server.ClimbWarSend(src, funcname, ...)
	server.climbCenter[funcname](server.climbCenter, ...)
end

local _intervalTime = false
local function _GetIntervalTime()
	if not _intervalTime then
		local opentime = server.configCenter.ClimbTowerBaseConfig.opentime
		local starttime = lua_util.split(opentime.starttime,":")
		local endtime = lua_util.split(opentime.endtime,":")
		_intervalTime = ((tonumber(endtime[1]) - tonumber(starttime[1])) * 3600 + (tonumber(endtime[2]) - tonumber(starttime[2])) * 60) * 1000
	end
	return _intervalTime 
end

function ClimbCenter:CheckStart()
	print("ClimbCenter:CheckStart----------")
	if not server.serverCenter:IsCross() then return end
	if self.open then
		return
	end
	self:Start()
end

function ClimbCenter:Init()
	if not server.serverCenter:IsCross() then return end	

	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.scorelist = self.cache.scorelist
	self.champion = self.cache.champion
	self.recordlist = self.cache.recordlist
	self.cache.currrank = self.cache.currrank or {}
	self.currrank = self.cache.currrank
	self.playerbaseinfo = {}

	local config = server.configCenter.ClimbTowerBaseConfig
	local opentime = config.opentime
	local starttime = lua_util.split(opentime.starttime,":")
	self.starthm = {hour = tonumber(starttime[1]), minute = tonumber(starttime[2])}
	print("-----开启时间-------------:"..tonumber(starttime[1]) ..': :'..tonumber(starttime[2]))
	local endtime = lua_util.split(opentime.endtime,":")
	self.endhm = {hour = tonumber(endtime[1]), minute = tonumber(endtime[2])}

	self:SortScore()

	self.timer = lua_timer.add_timer_day(opentime.starttime .. ":00", -1, self.CheckStart, self)
	print("ClimbCenter:Init-----------")
       --	self.open = true
	--[[local function _Test()
		self:Start()
	end
	self.testtimer = lua_app.add_timer(10000, _Test)]]
end

function ClimbCenter:HotFix()
	print("ClimbCenter:HotFix-----------", self.timer)
end


function ClimbCenter:Release()
	if self.maplist then
		for _, climbmap in pairs(self.maplist) do
			climbmap:Release()
		end
	end

	if self.cache then
		self.cache(true)
	end
	if self.endTimer then
		lua_app.del_local_timer(self.endTimer)
		self.endTimer = nil
	end
end

-- function ClimbCenter:onHalfHour(hour, minute)
-- 	if not server.serverCenter:IsCross() then return end
-- 	-- local week = lua_app.week()
-- local config = server.configCenter.ClimbTowerBaseConfig
-- 	-- for _, w in pairs(config.openday) do
-- 	-- 	if week ~= w then
-- 	-- 		return
-- 	-- 	end
-- 	-- end

-- 	-- if self.starthm.hour == hour and self.starthm.minute == minute then
-- 	-- 	self:Start()
-- 	-- end

-- 	-- if self.endhm.hour == hour and self.endhm.minute == minute then
-- 	-- 	self:End()
-- 	-- end
-- end

function ClimbCenter:onDayTimer()
	if not server.serverCenter:IsCross() then return end
	-- 结算周榜
	local week = lua_app.week()
	if week == 1 then
		self:DealWeekRank()
	end
end

function ClimbCenter:Start()
	self.playerbaseinfo = {}
	self.cache.session = self.cache.session + 1
	self.servermap = {}
	self.mapserver = {}
	--local serverlist = server.serverCenter:GetLogicServers("war")
	local serverlist = self:CallLogics("ServerInfo")
	local isstart = false
	local acc = 1
	local localmapindex = 1001	
	for serverid, info in pairs(serverlist) do		
		if info.opencode == 2 then
			local mapindex = math.ceil(acc/4)
			self.servermap[serverid] = mapindex
			self.mapserver[mapindex] = self.mapserver[mapindex] or {}
			table.insert(self.mapserver[mapindex], serverid)
			acc = acc + 1
			isstart = true
			self:SendOne(serverid, "SetOpen", true)
		elseif info.opencode == 1 then
			self.servermap[serverid] = localmapindex
			self.mapserver[localmapindex] = {serverid}
			localmapindex = localmapindex + 1
			isstart = true			
			self:SendOne(serverid, "SetOpen", true)
		end
	end

	if not isstart then return end

	self.maplist = {}
	for mapindex, servers in pairs(self.mapserver) do
		self.maplist[mapindex] = ClimbMap.new(mapindex, self)
		self.maplist[mapindex]:Init(servers)
	end

	if self.minutetimer then
		lua_app.del_timer(self.minutetimer)
		self.minutetimer = nil
	end
	local function _MinuteDeal()
		self.minutetimer = lua_app.add_timer(60000, _MinuteDeal)
		self:MinuteDeal()
	end
	self.minutetimer = lua_app.add_timer(60000, _MinuteDeal)

	if self.sec5timer then
		lua_app.del_timer(self.sec5timer)
		self.sec5timer = nil
	end
	local function _Sec5Deal()
		self.sec5timer = lua_app.add_timer(5000, _Sec5Deal)
		self:Sec5Deal()
	end
	self.sec5timer = lua_app.add_timer(5000, _Sec5Deal)
	self.open = true

	if self.endTimer then
		lua_app.del_local_timer(self.endTimer)
		self.endTimer = nil
	end
	self.endTimer = lua_app.add_update_timer(_GetIntervalTime(), self, "End")
end

function ClimbCenter:End()
	for serverid, mapid in pairs(self.servermap) do
		self.currrank[serverid] = self.maplist[mapid]:CurrRankMsg()
	end

	for _, map in pairs(self.maplist) do
		map:End()
	end

	if self.minutetimer then
		lua_app.del_timer(self.minutetimer)
		self.minutetimer = nil
	end
	if self.sec5timer then
		lua_app.del_timer(self.sec5timer)
		self.sec5timer = nil
	end

	self:DoScoreEnd()

	self.cache(true)
	self:SendLogics("SetOpen", false)
	self.open = false
	print("ClimbCenter:End----------------")
	if self.endTimer then
		lua_app.del_local_timer(self.endTimer)
		self.endTimer = nil
	end
end

-- 记录积分
function ClimbCenter:DoScoreEnd()
	self.recordlist[self.cache.session] = {}
	local thisrecord = self.recordlist[self.cache.session]
	for _, map in pairs(self.maplist) do
		for dbid, scoreinfo in pairs(map.scorelist) do
			thisrecord[dbid] = scoreinfo.score
			local glbscoreinfo = self.scorelist[dbid]
			if glbscoreinfo then
				glbscoreinfo.score = glbscoreinfo.score + scoreinfo.score
			else
				glbscoreinfo = {score = scoreinfo.score}
				self.scorelist[dbid] = glbscoreinfo
			end
			local baseinfo = self.playerbaseinfo[dbid]
			if baseinfo then
				glbscoreinfo.name = baseinfo.name
				glbscoreinfo.serverid = baseinfo.serverid
			end
		end
	end
	self:SortScore()
end

function ClimbCenter:SortScore()
	self.ranklist = {}
	for dbid, scoreinfo in pairs(self.scorelist) do
		table.insert(self.ranklist, {dbid = dbid, serverid = scoreinfo.serverid, score = scoreinfo.score, name = scoreinfo.name})
	end
	table.sort(self.ranklist, function(a, b)
			return a.score > b.score
		end)

	if #self.ranklist > 0 and self.playerbaseinfo[self.ranklist[1].dbid] then
		self.champion = self.playerbaseinfo[self.ranklist[1].dbid]
	end
end

function ClimbCenter:MinuteDeal()
	for _, map in pairs(self.maplist) do
		map:MinuteDeal()
	end
end

function ClimbCenter:Sec5Deal()
	for _, map in pairs(self.maplist) do
		map:Sec5Deal()
	end
end

function ClimbCenter:GetPlayerMap(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		if self.servermap[player.nowserverid] then
			return self.maplist[self.servermap[player.nowserverid]]
		else
			print("ClimbCenter:GetPlayerMap no server map", player.nowserverid)
		end
	else
		print("ClimbCenter:GetPlayerMap no player map", dbid)
	end
end

function ClimbCenter:GetAllRank(dbid)
	local msg = {}
	msg.ranklist = {}
	for rank, scoreinfo in pairs(self.ranklist) do
		table.insert(msg.ranklist, {dbid = scoreinfo.dbid, rank = rank, serverid = scoreinfo.serverid, name = scoreinfo.name, score = scoreinfo.score})
	end
	if self.champion then
		msg.job = self.champion.job
		msg.sex = self.champion.sex
		msg.shows = self.champion.shows
	end
	server.sendReqByDBID(dbid, "sc_climb_all_rank", msg)
end

function ClimbCenter:GetCurrRank(dbid)
	self.currrank = self.currrank or {}
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		local msg = self.currrank[player.nowserverid]
		if msg then
			server.sendReqByDBID(dbid, "sc_climb_curr_rank", msg)
		end
	end
end

function ClimbCenter:GetMapLine(dbid, mapid)
	local line = self:MapDo(dbid, "GetMapLine", dbid, mapid)
	if line then
		return line
	else
		return 1
	end
end

function ClimbCenter:DealWeekRank()
	local ClimbTowerRewardConfig = server.configCenter.ClimbTowerRewardConfig[2]
	local config = server.configCenter.ClimbTowerBaseConfig
	local titlerank = config.climballranktitle
	local serverrewards = {}
	for i, v in ipairs(ClimbTowerRewardConfig) do
		for rank = v.min, v.max do
			local rankinfo = self.ranklist[rank]
			if rankinfo then
				local contentrank = string.format(config.climballrankcontent, i)
				serverrewards[rankinfo.dbid] = {rewards = table.wcopy(v.reward), title = titlerank, content = contentrank}
			end
		end
	end
	self:SendLogics("SendMailReward", serverrewards)
	self.ranklist = {}
	self.cache(true)
end

function ClimbCenter:onLogout(player)
	if not server.serverCenter:IsCross() then return end
	if not player then return end
	local dbid = player.dbid
	self:MapDo(dbid, "Leave", dbid)
end

function ClimbCenter:MapDo(dbid, funcname, ...)
	if not self.open then return end
	print("ClimbCenter:MapDo ", dbid, funcname)
	local map = self:GetPlayerMap(dbid)
	if map and map[funcname] then
		return map[funcname](map, ...)
	else
		return false
	end
end

server.SetCenter(ClimbCenter, "climbCenter")
return ClimbCenter
