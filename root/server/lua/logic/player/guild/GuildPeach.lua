local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local GuildConfig = require "common.resource.GuildConfig"

local GuildPeach = oo.class()
local _PeachRewardMark = 0xFFFF

function GuildPeach:ctor(player)
	self.player = player
end

function GuildPeach:Init(datas)
	local peach = datas.peach
	if not peach then
		peach = {}
		peach.rewardMark = _PeachRewardMark
		peach.eatStatus = false
		datas.peach = peach
	end
	self.cache = peach
end

function GuildPeach:EatPeach(peachIndex)
	if self.cache.eatStatus then
		lua_app.log_error("GuildPeach:DonatePeach() today already DonatePeach.")
		return
	end
	local GuildPeachConfig = server.configCenter.GuildPeachConfig
	local cost = GuildPeachConfig[peachIndex].cost
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.EatPeach, "GuildPeach:offer:peach") then
		lua_app.log_info("GuildPeach:DonatePeach() PayRewards fail.",cost.type, cost.id, cost.count)
		return
	end
	local rewards = GuildPeachConfig[peachIndex].reward
	self.player:GiveRewardAsFullMailDefault({rewards}, "每日蟠桃", server.baseConfig.YuanbaoRecordType.EatPeach)
	local guild = self:GetGuild()
	guild.guildFinancial:EatPeach(self.player, peachIndex)
	self.cache.eatStatus = true
	self:SendClient()
	self.player.guild:UpdateActive(GuildConfig.Task.GuildPeach)
end

function GuildPeach:GetPeachReward(rewardIndex)
	local guild = self:GetGuild()
	if not guild.guildFinancial:CheckPeachReward(rewardIndex) then
		lua_app.log_info("not received reward. rewardIndex", rewardIndex)
		return
	end
	if not self:GetRewardStatus(rewardIndex) then
		lua_app.log_info(self.player.cache.name.." have received the award.")
		return
	end
	local GuildPeachRewardConfig = server.configCenter.GuildPeachRewardConfig
	local reward = GuildPeachRewardConfig[rewardIndex].reward
	self.player:GiveRewardAsFullMailDefault({reward}, "每日蟠桃", server.baseConfig.YuanbaoRecordType.EatPeach)
	self:SetRewardApply(rewardIndex)
	self:SendClient()
end

function GuildPeach:GetRewardStatus(rewardIndex)
	local mark = self.cache.rewardMark
	return lua_util.bit_status(mark, rewardIndex)
end

function GuildPeach:SetRewardApply(rewardIndex)
	local mark = self.cache.rewardMark
	self.cache.rewardMark = lua_util.bit_shut(mark, rewardIndex)
end

function GuildPeach:SendClient()
	local msg = {}
	msg.rewardMark = self.cache.rewardMark
	msg.eatStatus = self.cache.eatStatus
	server.sendReq(self.player, "sc_guild_peach_info", msg)
end

function GuildPeach:GetGuild()
	return server.guildCenter:GetGuild(self.player.cache.guildid)
end

function GuildPeach:onDayTimer()
	self.cache.rewardMark = _PeachRewardMark
	self.cache.eatStatus = false
	self:SendClient()
end

return GuildPeach