local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local RankConfig = require "resource.RankConfig"
local tbname = server.GetSqlName("wardatas")
local tbcolumn = "maincity"

local MaincityCenter = {}

function MaincityCenter:Init()
	if server.serverCenter:IsCross() then return end
	self.playerlist = {}
	self.enterlist = {}
	self.channellist = {}
	self.OpenInit = false
	local CityBaseConfig = server.configCenter.CityBaseConfig
	local initialline = CityBaseConfig.wire
	for i = 1, initialline do
		table.insert(self.channellist, {
				channelid = i,
				mapline = i,
				playerCount = 0,
				players = {}
			})
	end
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.worships = self.cache.worships
	self.worshipRecord = self.cache.worshipRecord
end

function MaincityCenter:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

--进入主城
function MaincityCenter:Enter(dbid, channelId)
	local CityBaseConfig = server.configCenter.CityBaseConfig
	local bronposs = CityBaseConfig.bron
	local maxposnum = #bronposs
	local randompos = math.random(1, maxposnum)
	local x, y = bronposs[randompos][1], bronposs[randompos][2]
	local mapid = CityBaseConfig.mapid
	
	if not channelId then
		return server.mapCenter:EnterMain(dbid, mapid, x, y)
	end
	if not self:CheckLine(channelId) then
		lua_app.log_info(">>MaincityCenter:Enter current line has maximum Load.")
		return false
	end
	self:SetChanel(dbid, channelId)
	return server.mapCenter:EnterMain(dbid, mapid, x, y)
end

--获取玩家优先线路
function MaincityCenter:GetProiorityline(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end
	local targetid = player.marry.cache.partnerid()
	if not self.playerlist[targetid] then
		return 1
	else
		local channel = self.playerlist[targetid].channelid
		if not self:CheckLine(channel) then
			return 1
		end
		return channel
	end
end

function MaincityCenter:CheckLine(channelId)
	local CityBaseConfig = server.configCenter.CityBaseConfig
	local data = self.channellist[channelId]
	if not data or data.playerCount >= CityBaseConfig.playnum then
		return false
	end
	return true
end

function MaincityCenter:SetChanel(dbid, channelId)
	local proiorityline = self:GetProiorityline(dbid)
	local line = channelId or proiorityline or 1
	for i, data in ipairs(self.channellist) do
		if i >= line and self:CheckLine(i) then
			line = i
			break
		end
	end
	self.enterlist[dbid] = line
	--扩线
	self:ExpandLine()
end

local function _CreateMapLine(channellist, mapline)
	mapline = mapline or 1
	local exist = false
	for _, data in ipairs(channellist) do
		if data.mapline == mapline then
			exist = true
			break
		end
	end
	if not exist then
		return mapline
	else
		return _CreateMapLine(channellist, mapline + 1)
	end
end

function MaincityCenter:ExpandLine()
	local saturation = true
	for _, data in ipairs(self.channellist) do
		if data.playerCount < 40 then
			saturation = false
		end 
	end
	if saturation then
		local mapline = _CreateMapLine(self.channellist)
		table.insert(self.channellist, {
				channelid = #self.channellist + 1,
				mapline = mapline,
				playerCount = 0,
				players = {},
				reserve = true,
			})
	end
	return saturation
end

--获取设置的路线
function MaincityCenter:GetChannel(dbid)
	local line = self.enterlist[dbid]
	if not line then
		self:SetChanel(dbid)
		line = self.enterlist[dbid]
	end
	--记录进入信息
	self.enterlist[dbid] = nil
	 
	local channeldata = self.channellist[line]
	channeldata.playerCount = channeldata.playerCount + 1
	channeldata.players[dbid] = true
	channeldata.reserve = nil
	self.playerlist[dbid] = channeldata
	return channeldata.mapline
end

function MaincityCenter:onLeaveMap(dbid, mapid, line, x, y)
	if server.serverCenter:IsCross() then return end

	local CityBaseConfig = server.configCenter.CityBaseConfig
	if mapid ~= CityBaseConfig.mapid then return end
	print(mapid, CityBaseConfig.mapid,"----------MaincityCenter:onLeaveMap--------------")
	if not self.cache then return end

	self:CleanChannel(dbid)
	self.playerlist[dbid] = nil
	self:BroadcastLine(line)
end

local _WorshipPay = {}
_WorshipPay[1] = function(player, cityconf)
	local rewards = {
			cityconf.worshipreward
		}
	return true, rewards, math.random(cityconf.worshipcharm[1], cityconf.worshipcharm[2])
end

_WorshipPay[2] = function(player, cityconf)
	local cost = {
		cityconf.goldworship
	}
	if not player:PayRewards(table.wcopy(cost), server.baseConfig.YuanbaoRecordType.Maincity, "Worship") then
		return false
	end
	local rewards = {
		cityconf.goldworshipreward
	}
	return true, rewards, math.random(cityconf.goldworshipcharm[1], cityconf.goldworshipcharm[2])
end

function MaincityCenter:WorshipOnce(dbid, type)
	local CityBaseConfig = server.configCenter.CityBaseConfig
	if self.worshipRecord[dbid] then return false end

	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local ret , rewards, charm = _WorshipPay[type](player, CityBaseConfig)
	if not ret then
		return false
	end
	player:GiveRewardAsFullMailDefault(table.wcopy(rewards), "膜拜奖励", server.baseConfig.YuanbaoRecordType.Maincity)
	self.worships[self.cache.champion] = self.worships[self.cache.champion] + charm
	self.worshipRecord[dbid] = type
	self:BroadcastMap()
	return true
end

function MaincityCenter:onEnterMap(dbid, mapid, line, x, y)
	if server.serverCenter:IsCross() then return end

	local CityBaseConfig = server.configCenter.CityBaseConfig
	if mapid ~= CityBaseConfig.mapid then return end
	self:BroadcastLine(line)
	--self:SendChannelInfo(dbid)
end

function MaincityCenter:CleanChannel(dbid)
	local channeldata = self.playerlist[dbid]
	if channeldata then
		channeldata.playerCount = channeldata.playerCount - 1
		channeldata.players[dbid] = nil
	end
	
	local CityBaseConfig = server.configCenter.CityBaseConfig
	local initialline = CityBaseConfig.wire
	if #self.channellist <= initialline then return end

	local remove = #self.channellist + 1
	for i = remove - 1, 1, -1 do
		if self.channellist[i].playerCount <= 0 and not self.channellist[i].reserve then
			remove = i
		end
	end
	table.remove(self.channellist, remove)
	for i, data in ipairs(self.channellist) do
		data.channelid = i
	end
	self:ExpandLine()
	--通知id变化的路线
	for i = remove, #self.channellist do
		self:BroadcastChannel(self.channellist[i].channelid)
	end
end

--重设天下第一
function MaincityCenter:ResetChampion()
	local rankdatas = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas",RankConfig.RankType.POWER, 1, 1)
	local __, championdata = next(rankdatas)
	if not championdata then return end
	local dbid = championdata.id
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if player then 
		self.cache.champion = dbid
		self.worships[dbid] = self.worships[dbid] or 0
		self.championShows = player.role:GetEntityShows()
	end
end

function MaincityCenter:GetChannelMsg()
	local data = {}
	for id, channel in ipairs(self.channellist) do
		table.insert(data, {
				id = id,
				count = channel.playerCount,
			})
	end
	return data
end

function MaincityCenter:BroadcastMap()
	for dbid, _ in pairs(self.playerlist) do
		self:SendChannelInfo(dbid)
	end
end

function MaincityCenter:BroadcastChannel(channelid)
	local channeldata = self.channellist[channelid]
	for dbid,_ in pairs(channeldata.players) do
		self:SendChannelInfo(dbid)
	end
end

function MaincityCenter:BroadcastLine(line)
	for channelid, channel in ipairs(self.channellist) do
		if channel.mapline == line then
			self:BroadcastChannel(channelid)
			break
		end
	end
end

function MaincityCenter:SendChannelInfo(dbid)
	if not self.playerlist[dbid] then return end
	if not self.OpenInit then
		self.OpenInit = true
		self:ResetChampion()
	end
	server.sendReqByDBID(dbid, "sc_map_maincity_info", {
		championid = self.cache.champion,
		charismaNum = self.cache.worships[self.cache.champion],
		channelid = self.playerlist[dbid].channelid,
		worship = self.worshipRecord[dbid] or 0,
		shows = self.championShows,
		people = self.playerlist[dbid].playerCount,
	})
end

function MaincityCenter:onDayTimer()
	if server.serverCenter:IsCross() then return end
	self:ResetChampion()
	self.worshipRecord = {}
	self.cache.worshipRecord = self.worshipRecord
	self:BroadcastMap()
end

function MaincityCenter:ResetServer()
	self.cache.champion = 0
	self.championShows = nil
end

function MaincityCenter:Debug()
	print("-----------MaincityCenter-------------")
	for i,v in ipairs(self.channellist) do
		v.playerCount = 45
	end
	table.ptable(self.channellist, 3)
end

function server.MaincityCall(src, funcname, ...)
	return lua_app.ret(server.maincityCenter[funcname](server.maincityCenter, ...))
end

function server.MaincitySend(src, funcname, ...)
	server.maincityCenter[funcname](server.maincityCenter, ...)
end

server.SetCenter(MaincityCenter, "maincityCenter")
return MaincityCenter