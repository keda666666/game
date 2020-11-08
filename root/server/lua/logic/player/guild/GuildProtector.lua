local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local GuildConfig = require "common.resource.GuildConfig"

local GuildProtector = oo.class()

local _EveryDayMark = 0xFFFFFFFF

function GuildProtector:ctor(player)
	self.player = player
	self.role = player.role
end

function GuildProtector:Init(datas)
	local protector = datas.protector
	if not protector then
		protector = {}
		protector.todayActive = 0
		protector.totalActive = 0
		protector.rewardMark = _EveryDayMark
		protector.level = 0
		datas.protector = protector
		protector.taskCount = {}
	end
	self.cache = protector
	self:Load()
end

function GuildProtector:Load()
	self:UpdateAttrs({})
end

function GuildProtector:UpdateActive(taskId)
	local GuildTaskConfig = server.configCenter.GuildTaskConfig
	local active = GuildTaskConfig[taskId]
	if not active then
		lua_app.log_info(">>>Protector UpdateActive taskId error. taskId:"..taskId)
		return
	end
	local count = self.cache.taskCount[taskId] or 0
	if count >= active.num then
		return
	end
	self.cache.taskCount[taskId] = count + 1
	self.cache.totalActive = self.cache.totalActive + active.exp
	self.cache.todayActive = self.cache.todayActive + active.exp
	self:SendTaskMsg()
	self:SendClient()
end

function GuildProtector:SendTaskMsg()
	local datas = {}
	for taskId, count in pairs(self.cache.taskCount) do
		table.insert(datas, {
				taskId = taskId,
				count = count,
			})
	end
	server.sendReq(self.player, "sc_guild_protector_task_info", {
			taskinfos = datas
		})
end

function GuildProtector:UpProtectorLevel()
	local GuildActiveConfig = server.configCenter.GuildActiveConfig
	local oldLv = self.cache.level
	local maxLv = #GuildActiveConfig
	if oldLv >= maxLv then
		lua_app.log_info("GuildProtector:UpProtectorLevel() Has reached the maximum level.")
		return
	end
	local needActive = GuildActiveConfig[oldLv + 1].exp
	if self.cache.totalActive < needActive then
		lua_app.log_info("upLevel fail. totalActive("..self.cache.totalActive..") < needActive("..needActive..").")
		return
	end
	self.cache.totalActive = self.cache.totalActive - needActive
	self.cache.level = self.cache.level + 1
	local rewards = GuildActiveConfig[self.cache.level].reward
	self.player:GiveRewardAsFullMailDefault(rewards, "帮派守护升级", server.baseConfig.YuanbaoRecordType.GuildProtector)
	self:SendClient()
	self:UpdateAttrs()
end

function GuildProtector:CheckEveryDayReward(rewardId)
	local GuildEverydayConfig = server.configCenter.GuildEverydayConfig
	local rewards = GuildEverydayConfig[rewardId].reward
	local exp = GuildEverydayConfig[rewardId].exp
	if not rewards then
		lua_app.log_info("GuildEverydayConfig not exist id:",rewardId)
		return false
	end
	if exp > self.cache.todayActive then
		lua_app.log_info("today active:"..self.cache.todayActive," < ".." needActive:"..exp)
		return false
	end
	if not self:GetRewardStatus(rewardId) then
		lua_app.log_info("Have received the award.")
		return false
	end
	return true
end

function GuildProtector:GetRewardStatus(rewardId)
	local mark = self.cache.rewardMark
	return lua_util.bit_status(mark, rewardId)
end

function GuildProtector:SetRewardReceive(rewardId)
	local mark = self.cache.rewardMark
	self.cache.rewardMark = lua_util.bit_shut(mark, rewardId)
end

function GuildProtector:EveryDayReward(rewardId)
	if not self:CheckEveryDayReward(rewardId) then
		return
	end
	local GuildEverydayConfig = server.configCenter.GuildEverydayConfig
	local rewards = GuildEverydayConfig[rewardId].reward
	self.player:GiveRewardAsFullMailDefault(rewards, "帮派每日奖励", server.baseConfig.YuanbaoRecordType.GuildProtector)
	self:SetRewardReceive(rewardId)
	self:SendClient()
end

function GuildProtector:SendClient()
	local msg = {
		todayActive = self.cache.todayActive,
		totalActive = self.cache.totalActive,
		protectorLv = self.cache.level,
		rewardMark = self.cache.rewardMark,
	}
	server.sendReq(self.player, "sc_guild_protector_info", msg)
end

function GuildProtector:UpdateAttrs(oldattr)
	local GuildActiveConfig = server.configCenter.GuildActiveConfig
	local level = self.cache.level
	local oldAttrs = oldattr or GuildActiveConfig[level - 1] and GuildActiveConfig[level - 1].attrpower or {}
	local newAttrs = GuildActiveConfig[level] and GuildActiveConfig[level].attrpower or {}
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.GuildProtector)
end

function GuildProtector:onLogin()
	self:SendTaskMsg()
	self:SendClient()
end

function GuildProtector:onDayTimer()
	self.cache.todayActive = 0
	self.cache.rewardMark = _EveryDayMark
	self.cache.taskCount = {}
	self:SendClient()
	self:SendTaskMsg()
end

function GuildProtector:Test()
	self.cache.todayActive = 10000
	self.cache.totalActive = 10000
	self:SendClient()
end

return GuildProtector