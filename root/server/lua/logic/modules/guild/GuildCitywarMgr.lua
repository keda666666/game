local server = require "server"
local lua_app = require "lua_app"
local GuildConfig = require "common.resource.GuildConfig"
local Guild = require "modules.guild.Guild"
local lua_timer = require "lua_timer"

local GuildCitywarMgr = {}


function GuildCitywarMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "GuildCitywarWarCall", funcname, ...)
end

function GuildCitywarMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "GuildCitywarWarSend", funcname, ...)
end

function GuildCitywarMgr:Init()
	self.qualification = {}		-- 参赛资格列表 [guildid] = {dbid1, dbid2, ...}
	self.guildatas = {}			-- 帮会数据 [guildid] = {fighters = {packinfo...}, info = guild.summary}
	self.guildpowers = {}		-- 此次活动的帮会所有战斗员的战力总和 [guildid] = power

	self.guildmatchlist = {}	-- 本服帮会用到的配对数据 [guildid1] = {敌对帮会的guildata} 

end

-- 是否开放时间
function GuildCitywarMgr:IsOpen()
	if self:IsActivityDay() then
		local hour = lua_app.hour()
		if 8 <= hour and hour <= 21 then
			return true
		end
	end
	return false
end

-- 是否是活动日
function GuildCitywarMgr:IsActivityDay()
	if server.serverRunDay > 3 then
		local week = lua_app.week()
		if week == 0 then
			return true
		end
	end
	return false
end

-- 是否满足参赛条件
function GuildCitywarMgr:CanJoin(player)
	if not player then
		return false
	end

	if not self:IsOpen() then
		return false
	end

	local guildid = player.cache.guildid

	if not self.guildmatchlist[guildid] then
		return false
	end

	if not self.qualification[guildid] then
		return false
	end

	if self.qualification[guildid][player.dbid] then
		return true
	else
		return false
	end

end

-- 生成有参赛资格的帮会和成员
-- 生成攻城战战斗员数据
function GuildCitywarMgr:GenActivityData()
	local guildlist = server.guildCenter.guildList or {}
	self.qualification = {}
	self.guildatas = {}
	for guildid, guild in pairs(guildlist) do
		if guild:GetLevel() >= 2 and guild:GetPlayerCount() >= 20 then
			self.qualification[guildid] = {}
			self.guildatas[guildid] = {fighters = {}, info = guild.summary}
			for pos, playerinfo in pairs(guild:GetPlayers()) do
				if #self.guildatas[guildid].fighters < 40 then
					local jointime = playerinfo.jointime
					local joindays = os.intervalDays(jointime)
					local player = server.playerCenter:DoGetPlayerByDBID(playerinfo.dbid)
					if player then
						if pos <= 40 and joindays >= 4 and player.cache.level >= 90 then
							self.qualification[guildid][player.dbid] = true
						end
						if joindays >= 4 then
							local packinfo = server.dataPack:FightInfo(player)
							packinfo.exinfo = {
							    totalpower = player.cache.totalpower,
							}
							table.insert(self.guildatas[guildid].fighters, packinfo)
						end
					end
				end
			end
		end
	end

	-- 帮会战力总和
	self.guildpowers = {}
	for guildid, datas in pairs(self.guildatas) do
		local power = 0
		for _, packinfo in pairs(datas.fighters) do
			power = power + packinfo.exinfo.totalpower
		end
		self.guildpowers = power
	end

	return {datalist = self.guildatas, powerlist = self.guildpowers}
end

-- 战斗
function GuildCitywarMgr:Attack(player, targetid)
	if not self.CanJoin() then return false end

	local guildid = player.cache.guildid
	local targetguilddata = self.guildmatchlist[guildid]
end

-- 跨发发来的全部配对数据
function GuildCitywarMgr:SetMatchData(guildmatchlist)
	self.guildmatchlist = guildmatchlist
end


function GuildCitywarMgr:onDayTimer(day)
end



function server.GuildCitywarLogicCall(src, funcname, ...)
	lua_app.ret(server.guildCitywarMgr[funcname](server.guildCitywarMgr, ...))
end

function server.GuildCitywarLogicSend(src, funcname, ...)
	server.guildCitywarMgr[funcname](server.guildCitywarMgr, ...)
end

server.SetCenter(GuildCitywarMgr, "guildCitywarMgr")
return GuildCitywarMgr
