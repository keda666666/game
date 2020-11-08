local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local GuildConfig = require "common.resource.GuildConfig"

local GuildSkill = oo.class()

function GuildSkill:ctor(player, guildctrl)
	self.player = player
	self.role = player.role
	self.guildctrl = guildctrl
end

function GuildSkill:Init(datas)
	local skills = datas.skills
	if not skills then
		skills = {}
		skills.skilldata = {}
		for posId = 0, 7 do 
			table.insert(skills.skilldata, {
				posId = posId,
				level = 0,
				})
		end
		datas.skills = skills
	end
	self.cache = skills
	self:Load()
end

function GuildSkill:Load()
	for _, skilldata in ipairs(self.cache.skilldata) do
		local skillCfg = self:GetLearnConfig(skilldata.level, skilldata.posId)
		if skillCfg then
			self.role:UpdateBaseAttr({}, skillCfg.attrpower, server.baseConfig.AttrRecord.GuildSkill)
		end
	end
end

function GuildSkill:GetSkillData()
	local data = self.cache.skilldata
	return data
end

function GuildSkill:LearnSkill()
	if self:CheckMaximumLevel() then
		lua_app.log_info("guild skill reach maximum level.")
		return
	end

	local nextLearnData = self:GetNextLearnData()
	local newlevel = nextLearnData.level + 1
	local newLevelCfg = self:GetLearnConfig(newlevel, nextLearnData.posId)
	if not self.player:PayRewards({newLevelCfg.cost}, server.baseConfig.YuanbaoRecordType.GuildSkill) then
		lua_app.log_info("PayRewards fail.")
		return 
	end

	local oldCfg = self:GetLearnConfig(nextLearnData.level, nextLearnData.posId)
	local oldAttrs = oldCfg and oldCfg.attrpower or {}
	self.role:UpdateBaseAttr(oldAttrs, newLevelCfg.attrpower, server.baseConfig.AttrRecord.GuildSkill)
	nextLearnData.level = newlevel
	self:SendClientLearn(nextLearnData)
end

function GuildSkill:CheckMaximumLevel()
	local GuildLevelConfig = server.configCenter.GuildLevelConfig
	local guildlevel = self.guildctrl:GetGuildLevel()
	local skillMaxLv = GuildLevelConfig[guildlevel].skilllv
	local nextskilldata = self:GetNextLearnData()
	return nextskilldata.level >= skillMaxLv
end

function GuildSkill:GetLearnConfig(level, posId)
	local GuildCommonSkillConfig = server.configCenter.GuildCommonSkillConfig
	return GuildCommonSkillConfig[level] and GuildCommonSkillConfig[level][posId]
end

function GuildSkill:SendClientLearn(learndata)
	local msg = {
		skillInfo = learndata,
		learnPos = self:GetNextLearnPos(),
	}
	server.sendReq(self.player, "sc_guild_skill_learn_ret", msg)
end

function GuildSkill:SendClientInfo()
	local msg = {
		skillInfos = self:GetSkillData(),
		learnPos = self:GetNextLearnPos(),
	}
	server.sendReq(self.player, "sc_guild_skill_info", msg)
end

function GuildSkill:GetNextLearnPos()
	local skilldata = self:GetNextLearnData()
	return skilldata.posId
end

function GuildSkill:GetNextLearnData()
	local learnskill
	for __, skilldata in ipairs(self.cache.skilldata) do
		learnskill = self:ChooseSkill(learnskill, skilldata)
	end
	return learnskill
end

function GuildSkill:ChooseSkill(firstskill, secondskill)
	if firstskill and firstskill.level <= secondskill.level then
		if firstskill.level < secondskill.level or firstskill.posId < secondskill.posId then
			return firstskill
		end
	end
	return secondskill
end

function GuildSkill:GetGuild()
	return server.guildCenter:GetGuild(self.player.cache.guildid)
end

return GuildSkill