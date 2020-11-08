local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local GuildFinancial = oo.class()

function GuildFinancial:ctor(guild)
	self.guild = guild
end

function GuildFinancial:Init()
	local data = self.guild.cache.variable
	local financial = data.financial
	if not financial then
		financial = {}
		data.financial = financial
	end
	self.cache = financial
	self:InitPeach()
end

function GuildFinancial:InitPeach()
	local peachdata = self.cache.peachdata
	if not peachdata then
		peachdata = {}
		peachdata.peachRecord = {}
		peachdata.peachValue = 0
		self.cache.peachdata = peachdata
	end
	self.peachdata = peachdata
end

function GuildFinancial:EatPeach(player, peachId)
	local GuildPeachConfig = server.configCenter.GuildPeachConfig
	local guildexp = GuildPeachConfig[peachId].exp
	local peach = self.peachdata
	local peachValue = GuildPeachConfig[peachId].peachvalue
	peach.peachValue = peach.peachValue + peachValue
	self.guild:UpdateFund(guildexp)
	self:AddPeachRecord(player, peachId)
end

function GuildFinancial:AddPeachRecord(player, peachId)
	local peach = self.peachdata
	if #peach.peachRecord >= 50 then
		table.remove(peach.peachRecord, 1)
	end
	local data = {
		playerName = player.cache.name,
		peachId = peachId,
		time = lua_app.now(),
		}
	table.insert(peach.peachRecord, data)
	self.guild:Broadcast("sc_guild_peach_record_add", {
		peachExp = peach.peachValue,
		eatRecord = data,
	})
end

function GuildFinancial:SendClientPeach(player)
	local peach = self.peachdata
	server.sendReq(player, "sc_guild_peach_record", {
		peachExp = peach.peachValue,
		eatRecord = peach.peachRecord,
		})
end

function GuildFinancial:CheckPeachReward(rewardIndex)
	local GuildPeachRewardConfig = server.configCenter.GuildPeachRewardConfig
	local peachItem = GuildPeachRewardConfig[rewardIndex]
	local peach = self.peachdata
	return peach.peachValue >= peachItem.exp
end

function GuildFinancial:DonateWood(player, woodid)
	local GuildDonateConfig = server.configCenter.GuildDonateConfig
	local guildexp = GuildDonateConfig[woodid] and GuildDonateConfig[woodid].exp or 0
	self.guild:UpdateFund(guildexp)
end

function GuildFinancial:onLogin(player)
	self:SendClientPeach(player)
end

function GuildFinancial:onDayTimer()
	self.cache.peachdata.peachValue = 0
	local peach = self.peachdata
	self.guild:Broadcast("sc_guild_peach_record", {
		peachExp = peach.peachValue,
		eatRecord = peach.peachRecord,
		})
end

return GuildFinancial