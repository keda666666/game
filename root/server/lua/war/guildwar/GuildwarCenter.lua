local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local lua_util = require "lua_util"
local GuildwarMap = require "guildwar.GuildwarMap"

-- 帮会战主控文件
local GuildwarCenter = {}

function GuildwarCenter:CallLogics(funcname, ...)
	return server.serverCenter:CallLogics("GuildwarLogicCall", funcname, ...)
end

function GuildwarCenter:SendLogics(funcname, ...)
	server.serverCenter:SendLogics("GuildwarLogicSend", funcname, ...)
end

function GuildwarCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "GuildwarLogicSend", funcname, ...)
end

function GuildwarCenter:CallOne(serverid, funcname, ...)
	return server.serverCenter:CallOne("logic", serverid, "GuildwarLogicCall", funcname, ...)
end

function server.GuildwarWarCall(src, funcname, ...)
	lua_app.ret(server.guildwarCenter[funcname](server.guildwarCenter, ...))
end

function server.GuildwarWarSend(src, funcname, ...)
	server.guildwarCenter[funcname](server.guildwarCenter, ...)
end

--[[****************************调度接口****************************]]
function GuildwarCenter:Init()
	if not server.serverCenter:IsCross() then return end
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local thetime = GuildBattleBaseConfig.opentime
	local opentime = lua_util.split(thetime[1],":")
	self.openhm = {hour = tonumber(opentime[1]), minute = tonumber(opentime[2])}

	local endtime = lua_util.split(thetime[2],":")
	self.endhm = {hour = tonumber(endtime[1]), minute = tonumber(endtime[2])}
end

function GuildwarCenter:Release()
end

function GuildwarCenter:onDayTimer(day)
end

function GuildwarCenter:onHalfHour(hour, minute)
	if not server.serverCenter:IsCross() then return end
	if self.openhm.hour == hour and self.openhm.minute == minute then
		self:Start()
	end
end

function GuildwarCenter:onLogout(player)
	if not server.serverCenter:IsCross() then return end
	if not self:CheckPlayer(player) then return end

	local guildwarMap = self:GetGuildwarMap(player.dbid)
	guildwarMap:Logout(player.dbid)
	server.teamCenter:Leave(player.dbid)
end

function GuildwarCenter:onLogin(player)
	if not server.serverCenter:IsCross() then return end
	if not self:CheckPlayer(player) then return end

	local guildwarMap = self:GetGuildwarMap(player.dbid)
	guildwarMap:Login(player.dbid)
end

function GuildwarCenter:CheckPlayer(player)
	if not self.servermap then return false end
	local mapindex = self.servermap[player.nowserverid]
	return self.maplist[mapindex]
end

local _intervalTime = false
local function _GetIntervalTime()
	if not _intervalTime then
		local opentime = server.configCenter.GuildBattleBaseConfig.opentime
		local starttime = lua_util.split(opentime[1],":")
		local endtime = lua_util.split(opentime[2],":")
		_intervalTime = ((tonumber(endtime[1]) - tonumber(starttime[1])) * 3600 + (tonumber(endtime[2]) - tonumber(starttime[2])) * 60)
	end
	return _intervalTime 
end


--[[****************************功能接口****************************]]
--活动开启
function GuildwarCenter:Start()
	if self.isOpen then return end
	--初始化活动数据
	self.servermap = {}
	self.mapserver = {}
	self.serverlevel = {}

	local serverlist = self:CallLogics("ServerInfo")
	local serverindex = 1
	--分配单服玩法
	for serverid, info in pairs(serverlist) do
		if info.opencode == 1 then
			self.servermap[serverid] = serverindex
			self.mapserver[serverindex] = self.mapserver[serverindex] or {}
			table.insert(self.mapserver[serverindex], serverid)
			self.serverlevel[serverindex] = math.max(self.serverlevel[serverindex] or 0, info.lv)
			serverindex = serverindex + 1
			lua_app.log_info("GuildwarCenter:Start--- single server mapindex and serverid:",serverindex, serverid)
		end
	end

	--分配跨服玩法
	local acc = 1
	for serverid, info in pairs(serverlist) do
		if info.opencode == 2 then
			local mapindex = math.ceil(acc / 4) + serverindex
			self.servermap[serverid] = mapindex
			self.mapserver[mapindex] = self.mapserver[mapindex] or {}
			table.insert(self.mapserver[mapindex], serverid)
			self.serverlevel[mapindex] = math.max(self.serverlevel[mapindex] or 0, info.lv)
			acc = acc + 1
			lua_app.log_info("GuildwarCenter:Start--- mapindex and serverid:", mapindex, serverid)
		end
	end

	self.maplist = {}
	for mapindex, servers in pairs(self.mapserver) do
		self.maplist[mapindex] = GuildwarMap.new(mapindex, self, servers)
	end

	local intervaltime = _GetIntervalTime()
	local endtime = lua_app.now() + intervaltime
	for mapindex, guildwarMap in pairs(self.maplist) do
		local worldlv = self.serverlevel[mapindex]
		guildwarMap:Init(endtime, worldlv)
	end
	for serverid, __ in pairs(self.servermap) do
		self:SendOne(serverid, "Start")
	end
	self.isOpen = true
	self.endtimer = lua_app.add_update_timer(intervaltime * 1000, self, "Shut")
	print("GuildwarCenter:Start--------------------------")
end

--设置冠军
function GuildwarCenter:Shut()
	if not self.isOpen then return end

	--清除定时器
	if self.endtimer then
		lua_app.del_timer(self.endtimer)
		self.endtimer = nil
	end
	
	for __, guildwarMap in pairs(self.maplist) do
		guildwarMap:Shut()
	end

	self.isOpen = false
	print("GuildwarCenter:Shut--------------------------------")
end

--活动日
function GuildwarCenter:IsActivityDay()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local opendays = GuildBattleBaseConfig.openday
	local week = lua_app.week()
	for _, v in ipairs(opendays) do
		if v == week then 
			return true 
		end
	end
	return false
end

function GuildwarCenter:GetServerIndex(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	return self.servermap[player.nowserverid]
end

function GuildwarCenter:GetGuildwarMap(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local index = self.servermap[player.nowserverid]
	return self.maplist[index]
end

function GuildwarCenter:GetWorldAvageLeve(servers)
	local level = 0
	for _, serverId in ipairs(servers) do
		local levleltmp = self:CallOne(serverId, "GetWorldAvageLeve")
		level = math.max(level, levleltmp)
	end
	return level
end

function GuildwarCenter:GetMapLine(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	if guildwarMap then
		return guildwarMap.index
	else
		return 0
	end
end

--[[****************************消息接口****************************]]

function GuildwarCenter:EnterGuildwar(dbid)
	print(">GuildwarCenter:EnterGuildwar", dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	return guildwarMap:Enter(dbid)
end

function GuildwarCenter:Attack(dbid, ...)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:Attack(dbid, ...)
end

function GuildwarCenter:EnterNextBarrier(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	if guildwarMap then
		local barrier = guildwarMap:GetBarrier(dbid)
		return barrier:NextBarrier(dbid)
	end
end

function GuildwarCenter:EnterLastBarrier(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	if guildwarMap then
		local barrier = guildwarMap:GetBarrier(dbid)
		return barrier:LastBarrier(dbid)
	end
end

function GuildwarCenter:ExitGuildwar(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:Logout(dbid)
	server.teamCenter:Leave(dbid)
end

function GuildwarCenter:Pk(dbid, targetid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	return guildwarMap:Pk(dbid, targetid)
end

function GuildwarCenter:PayReborn(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	return guildwarMap:PayReborn(dbid)
end

function GuildwarCenter:ResetBarrier(dbid, barrierId)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:ResetBarrier(barrierId)
end

function GuildwarCenter:SendGuildRank(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:SendGuildRank(dbid)
end

function GuildwarCenter:SendPersonRank(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:SendPersonRank(dbid)
end

function GuildwarCenter:GetScoreReward(dbid, rewardid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	if guildwarMap then
		guildwarMap:GetWarScoreReward(dbid, rewardid)
	end
end

function GuildwarCenter:TeamRecruit(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:TeamRecruit(dbid)
end

function GuildwarCenter:CanJoinTeam(dbid, leaderid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	if guildwarMap then
		return guildwarMap:CanJoinTeam(dbid, leaderid)
	else
		server.sendErrByDBID(dbid, "活动已结束")
	end
end

function GuildwarCenter:Test(func, ...)
	if GuildwarCenter[func] then
		GuildwarCenter[func](self, ...)
	end
end

function GuildwarCenter:Debug(dbid)
	local guildwarMap = self:GetGuildwarMap(dbid)
	guildwarMap:Debug(dbid)
end

server.SetCenter(GuildwarCenter, "guildwarCenter")
return GuildwarCenter
