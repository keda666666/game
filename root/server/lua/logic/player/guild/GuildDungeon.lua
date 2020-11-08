local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local GuildConfig = require "common.resource.GuildConfig"

local GuildDungeon = oo.class()

function GuildDungeon:ctor(player)
	self.player = player
end

function GuildDungeon:Init(datas)
	local dungeon = datas.dungeon
	if not dungeon then
		dungeon = {}
		dungeon.profitCount = 0
		dungeon.assistCount = 0
		dungeon.firstReach = {}
		datas.dungeon = dungeon
	end
	self.cache = dungeon
end

function GuildDungeon:CheckEnter(fbId)
	local guild = self.player.guild:GetGuild()
	if not guild then
		lua_app.log_info("GuildDungeon:CheckEnter player not have join guild")
		return false
	end
	local GuildFubenConfig = server.configCenter.GuildFubenConfig
	local fbNeedGuildLv = GuildFubenConfig[fbId].needlv
	local guildLv = guild:GetLevel()
	return guildLv >= fbNeedGuildLv
end

function GuildDungeon:UpdateProfitCount(fbId, leaderid)
	if not self.cache.firstReach[fbId] then
		self.cache.firstReach[fbId] = true
	end
	self.cache.profitCount = self.cache.profitCount + 1
	local ismember = (self.player.dbid ~= leaderid)
	if ismember then
		self.cache.assistCount = self.cache.assistCount + 1
	end
end

--[[fbinfo = {fbId=0, leaderid = 0, membercount = 0 }--]]
function GuildDungeon:DoResult(iswin, fbinfo)
	self.fightresult = {
		fbId = fbinfo.fbId,
		membercount = fbinfo.membercount,
		leaderid = fbinfo.leaderid,
	}
	local msg = {}
	if iswin then
		msg.result = 1
	else
		msg.result = 0
	end
	self.rewards = iswin and self:GenRewards() or {}
	msg.rewards = self.rewards
	self.player:sendReq("sc_raid_chapter_boss_result", msg)
end

function GuildDungeon:GenRewards()
	local fbId = self.fightresult.fbId
	local membercount = self.fightresult.membercount
	local leaderid = self.fightresult.leaderid

	local totalrewards = table.GetTbPlus("count")
	local fbCfg = server.configCenter.GuildFubenConfig[fbId]
	--首通奖励
	if not self.cache.firstReach[fbId] then
		totalrewards = totalrewards + server.dropCenter:DropGroup(fbCfg.firstdropid)
	end

	--协助奖励
	local GuildFubenBaseConfig = server.configCenter.GuildFubenBaseConfig
	local assistReceive = self.player.dbid ~= leaderid and self.cache.assistCount < GuildFubenBaseConfig.assistcount
	if assistReceive then
		totalrewards = totalrewards + server.dropCenter:DropGroup(fbCfg.helpdrop)
	end

	--通关奖励
	if self.cache.profitCount < GuildFubenBaseConfig.profitCount then
		local fullteam = membercount == 3
		local rate = fullteam and GuildFubenBaseConfig.teamreward or 1
		local normalrewards = server.dropCenter:DropGroup(fbCfg.dropId)
		for i = 1, rate do
			totalrewards = totalrewards + normalrewards
		end

		totalrewards = totalrewards + server.dropCenter:DropGroup(fbCfg.chancedrop)
	end
	return totalrewards
end

function GuildDungeon:GetReward()
	if not self.rewards then return end
	self.player:GiveRewardAsFullMailDefault(self.rewards, "帮会副本", server.baseConfig.YuanbaoRecordType.GuildFb)
	self.rewards = nil
	self:UpdateProfitCount(self.fightresult.fbId, self.fightresult.leaderid)
	self.player.guild:UpdateActive(GuildConfig.Task.GuildFuBen)
	self.player.enhance:AddPoint(24, 1)
end

function GuildDungeon:GetMsgData()
	local data = {
		profitCount = self.cache.profitCount,
		assistCount = self.cache.assistCount,
	}
	local firstReach = {}
	for k,_ in pairs(self.cache.firstReach) do
		table.insert(firstReach, k)
	end
	data.firstReach = firstReach
	return data
end

function GuildDungeon:onDayTimer()
	self.cache.profitCount = 0
	self.cache.assistCount = 0
end

return GuildDungeon