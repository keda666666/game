local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local GuildwarMgr = {}
local tbname = server.GetSqlName("datalist")
local tbcolumn = "guildwar"

function GuildwarMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "GuildwarWarCall", funcname, ...)
end

function GuildwarMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "GuildwarWarSend", funcname, ...)
end

function server.GuildwarLogicCall(src, funcname, ...)
	lua_app.ret(server.guildwarMgr[funcname](server.guildwarMgr, ...))
end

function server.GuildwarLogicSend(src, funcname, ...)
	server.guildwarMgr[funcname](server.guildwarMgr, ...)
end

--[[****************************调度接口****************************]]
function GuildwarMgr:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)

	self.isOpen = false
	self:CollectGuildData()
end

function GuildwarMgr:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function GuildwarMgr:onDayTimer(day)
	if self:IsActivityDay() then
		self:CollectGuildData()
	end
	self.cache.openinterval = math.max(self.cache.openinterval - 1, 0)
end

function GuildwarMgr:onHalfHour(hour, minute)
end

function GuildwarMgr:ServerInfo()
	return {lv = server.dailyActivityCenter:AvgLv(), opencode = self:GetOpenCode()}
end

--[[****************************功能接口****************************]]
function GuildwarMgr:GetOpenCode()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local specifyOpen = server.serverRunDay == GuildBattleBaseConfig.appointime
	if specifyOpen then
		self.cache.openinterval = GuildBattleBaseConfig.intervaltime
		return 1
	elseif self:CheckNormalOpen() then 
		return 2
	end
	return 0
end

function GuildwarMgr:CheckNormalOpen()
	if self:IsActivityDay() and self.cache.openinterval == 0 and
	 server.serverRunDay >= server.configCenter.GuildBattleBaseConfig.serverday then
		return true
	end
	return false
end

function GuildwarMgr:IsActivityDay()
	local opendays = server.configCenter.GuildBattleBaseConfig.openday
	local week = lua_app.week()
	for _, v in ipairs(opendays) do
		if v == week then 
			return true 
		end
	end
	return false
end

function GuildwarMgr:IsOpen()
	return self.isOpen
end

--消息入口
function GuildwarMgr:Invoke(player, func, ...)
	if not self:EnterCheck(player) then
		lua_app.log_info("GuildwarMgr:Invoke not enter.", func, player.dbid, self.isOpen)
		return
	end
	return GuildwarMgr[func](self, player.dbid, ...)
end

function GuildwarMgr:onInitClient(player)
	server.sendReq(player, "sc_guildwar_enter_war_guild", {
		championGuild = self.cache.champions,
		guildinfos = self.contestantData,
	})
end

function GuildwarMgr:EnterCheck(player)
	if not self:IsOpen() then 
		return false 
	end
	local guildid = player.cache.guildid
	if guildid == 0 then 
		return false 
	end
	return true
end

function GuildwarMgr:Start()
	print(">>GuildwarMgr---------------------------Start")
	self.isOpen = true
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	server.noticeCenter:Notice(GuildBattleBaseConfig.endNotice)
	server.dailyActivityCenter:Brodcast()
end

function GuildwarMgr:Shut()
	print(">>GuildwarMgr---------------------------Shut")
	self.isOpen = false
	self.cache.open = 1
	server.dailyActivityCenter:Brodcast()
end

--收集帮会信息
function GuildwarMgr:CollectGuildData()
	local guildlist = server.guildCenter.guildList or {}
	local guildinfos = {}
	self.contestant = {}
	self.contestantData = {}
	for guildid, guild in pairs(guildlist) do
		table.insert(guildinfos, {
				guildid = guildid,
				guildName = guild:GetName(),
				level = guild:GetLevel(),
				power = guild.summary.totalpower,
			})
	end

	table.sort(guildinfos, function(data1, data2)
		if data1.level >= data2.level then
			return data1.level > data2.level or data1.power > data2.power
		end
		return false
	end)

	for i, data in ipairs(guildinfos) do
		table.insert(self.contestantData, {
				guildId = data.guildid,
				guildName = data.guildName,
			})
		self.contestant[data.guildid] = true
		if i == 2 then break end
	end
end

--获取世界等级
function GuildwarMgr:GetWorldAvageLeve()
	return server.dailyActivityCenter:AvgLv()
end

function GuildwarMgr:SetChampionGuildData(data)
	self.cache.champions = data
	self.contestant = {}
	self.contestantData = {}
	server.broadcastReq("sc_guildwar_enter_war_guild", {
		championGuild = self.cache.champions,
		guildinfos = self.contestantData,
	})
	self:Shut()
end

function GuildwarMgr:DressCouture(dbid, skinid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if player then
		player.role.skineffect:DoActivatePart(skinid)
	end
end

function GuildwarMgr:EnterGuildwar(dbid)
	server.dailyActivityCenter:SendJoinActivity("guildwar", dbid)
	return self:CallWar("EnterGuildwar", dbid)
end

function GuildwarMgr:Attack(dbid, ...)
	self:SendWar("Attack", dbid, ...)
end

function GuildwarMgr:EnterNextBarrier(dbid, ...)
	return self:CallWar("EnterNextBarrier", dbid, ...)
end

function GuildwarMgr:EnterLastBarrier(dbid, ...)
	return self:CallWar("EnterLastBarrier", dbid, ...)
end

function GuildwarMgr:ExitGuildwar(dbid)
	self:SendWar("ExitGuildwar", dbid)
end

function GuildwarMgr:Pk(dbid, ...)
	return self:CallWar("Pk", dbid, ...)
end

function GuildwarMgr:PayReborn(dbid)
	return self:CallWar("PayReborn", dbid)
end

function GuildwarMgr:ResetBarrier(...)
	self:SendWar("ResetBarrier", ...)
end

function GuildwarMgr:SendGuildRank(dbid)
	self:SendWar("SendGuildRank", dbid)
end

function GuildwarMgr:SendPersonRank(dbid)
	self:SendWar("SendPersonRank", dbid)
end

function GuildwarMgr:GetScoreReward(dbid, rewardid)
	self:SendWar("GetScoreReward", dbid, rewardid)
end

function GuildwarMgr:TeamRecruit(dbid)
	self:SendWar("TeamRecruit", dbid)
end

function GuildwarMgr:Debug(dbid)
	self:SendWar("Debug", dbid)
end

function GuildwarMgr:Test(func, ...)
	self:SendWar("Test", func, ...)
end

--[[****************************消息接口****************************]]

server.SetCenter(GuildwarMgr, "guildwarMgr")
return GuildwarMgr
