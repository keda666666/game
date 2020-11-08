local server = require "server"
local lua_app = require "lua_app"
local GuildConfig = require "common.resource.GuildConfig"
local Guild = require "modules.guild.Guild"
local lua_timer = require "lua_timer"

local GuildMinewarMgr = {}


function GuildMinewarMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "GuildMinewarWarCall", funcname, ...)
end

function GuildMinewarMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "GuildMinewarWarCall", funcname, ...)
end

function server.GuildMinewarLogicCall(src, funcname, ...)
	return lua_app.ret(server.guildMinewarMgr[funcname](server.guildMinewarMgr, ...))
end

function server.GuildMinewarLogicSend(src, funcname, ...)
	server.guildMinewarMgr[funcname](server.guildMinewarMgr, ...)
end

--[[****************************调度接口****************************]]
function GuildMinewarMgr:Init()

end

function GuildMinewarMgr:onDayTimer(day)
end

--消息入口
function GuildMinewarMgr:Portal(player, func, ...)
	print("GuildMinewarMgr:Portal--------------", self.isOpen, func, player.dbid, player.cache.name)
	if not self:EnterCheck(player) then return end
	if not self:IsOpen() then return end
	return GuildMinewarMgr[func](self, player.dbid, ...)
end

--[[****************************功能接口****************************]]
-- 是否开放时间
function GuildMinewarMgr:IsOpen()
	return self.isOpen
end

function GuildMinewarMgr:Start()
	print("GuildMinewarMgr:Start----------------------")
	self.isOpen = true
	server.noticeCenter:Notice(188)
end

function GuildMinewarMgr:Shut()
	print("GuildMinewarMgr:Shut----------------------")
	self.isOpen = false
end

--进入判断
function GuildMinewarMgr:EnterCheck(player)
	if player.cache.guildid == 0 then
		print(">>GuildMinewarMgr:PlayerEnterCheck player not join guild. dbid", dbid)
		return false
	end
	return true
end

--发送奖励
function GuildMinewarMgr:GiveMonthRankReward(guildid, rank)
	print("GuildMinewarMgr:GiveMonthRankReward", guildid, rank)
	local RankRewardConfig = server.configCenter.RankRewardConfig
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local guild = server.guildCenter:GetGuild(guildid)
	if not guild then return end
	local rewards = RankRewardConfig[2][rank].reward
	local title = GuildDiggingBaseConfig.mmailtitle
	local context = string.format(GuildDiggingBaseConfig.mmaildes, rank)
	guild:GiveMemberRewardByMail(title, context, rewards, server.baseConfig.YuanbaoRecordType.GuildMine)
end

function GuildMinewarMgr:ServerInfo()
	return {opencode = self:GetOpenCode()}
end

function GuildMinewarMgr:GetOpenCode()
	if self:IsActivityDay() then
		local crossgame = server.serverRunDay >= server.configCenter.GuildDiggingBaseConfig.opencross
		if crossgame then
			return 2
		else
			return 1
		end
	end
	return 0
end

-- 是否是活动日
function GuildMinewarMgr:IsActivityDay()
	local week = lua_app.week()
	for _, v in ipairs(server.configCenter.GuildDiggingBaseConfig.openday) do
		if v == week then
			return true
		end
	end
	return false
end

--[[****************************消息接口****************************]]
--加入守护
function GuildMinewarMgr:JoinMine(dbid, mineId)
	return self:CallWar("JoinMine", dbid, mineId)
end

--离开守护
function GuildMinewarMgr:LeaveMine(dbid)
	self:SendWar("LeaveMine", dbid)
end

--矿脉采集
function GuildMinewarMgr:MineCompleteGather(dbid)
	return true
end

function GuildMinewarMgr:ForceJoinMine(dbid, mineId)
	return self:CallWar("ForceJoinMine", dbid, mineId)
end

--获得一个矿脉信息
function GuildMinewarMgr:GetMineInfoById(dbid, mineId)
	self:SendWar("GetMineInfoById", dbid, mineId)
end

--进入矿山争夺
function GuildMinewarMgr:EnterMinewar(dbid)
	self:SendWar("EnterMinewar", dbid)
end

--查看排行榜
function GuildMinewarMgr:GetGuildScoreRank(dbid, rankType)
	self:SendWar("GetGuildScoreRank", dbid, rankType)
end

function GuildMinewarMgr:Test(func, ...)
	self:SendWar("Test", func, ...)
end

server.SetCenter(GuildMinewarMgr, "guildMinewarMgr")
return GuildMinewarMgr
