local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local GuildDonate = oo.class()

function GuildDonate:ctor(player)
	self.player = player
end

function GuildDonate:Init(datas)
	local donate = datas.donate
	if not donate then
		donate = {}
		donate.donateCount = 0
		datas.donate = donate
	end
	self.cache = donate
end

function GuildDonate:onLogin()
	self:SendDonateMsg()
end

function GuildDonate:DonateWood(woodIndex)
	local GuildConfig = server.configCenter.GuildConfig
	if self.cache.donateCount >= GuildConfig.maxcount then
		self:SendClient(false, woodIndex)
		return
	end
	local GuildDonateConfig = server.configCenter.GuildDonateConfig
	local cost = GuildDonateConfig[woodIndex].cost
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.DonateWood) then
		lua_app.log_info("GuildDonate:DonateWood() PayRewards fail.",cost.type, cost.id, cost.count)
		return
	end
	local guild = self.player.guild:GetGuild()
	guild.guildFinancial:DonateWood(self.player, woodIndex)
	self.cache.donateCount = self.cache.donateCount + 1
	self:SendClient(true, woodIndex)
end

function GuildDonate:SendClient(result, woodId)
	server.sendReq(self.player, "sc_guild_donate_ret", {
		result = result,
		id = woodId,
		totalNum = self.cache.donateCount,
		})
end

function GuildDonate:SendDonateMsg()
	server.sendReq(self.player, "sc_guild_donate_info", {
			totalNum = self.cache.donateCount,
		})
end

function GuildDonate:onDayTimer()
	self.cache.donateCount = 0
	self:SendDonateMsg()
end

return GuildDonate