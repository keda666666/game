local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Buff = require "fight.skill.Buff"
local Skill = require "fight.skill.Skill"
local FightConfig = require "resource.FightConfig"

local _FightStatus = FightConfig.FightStatus
local _BuffStatus = FightConfig.BuffStatus

local SkillPlug = oo.class()

local RemoveType = {
	Normal 		= 1,	--正常移除
	Clean 		= 2,	--净化移除
}

function SkillPlug:ctor(entity)
	self.entity = entity
	self.bufflist = {}
	self.buffstatus = {}
	self.nextaddbuff = {}
end

function SkillPlug:Init(skilllist, skillsort, buffinit)
	self.skillsort = skillsort or {}
	self.skillsortindex = {}
	self.skills = {}
	self.skillindex = {}
	self.skillids = {}
	if buffinit then
		for buffid, args in pairs(buffinit) do
			self:AddBuffByID(buffid, self.entity, table.wcopy(args))
		end
	end
	for fightstatus, skillids in pairs(skilllist) do
		self.skills[fightstatus] = {}
		self.skillids[fightstatus] = {}
		self.skillindex[fightstatus] = nil
		for skillid, args in pairs(skillids) do
			local skill = Skill.new(self.entity, skillid, table.wcopy(args))
			skill:Init()
			self.skills[fightstatus][skillid] = skill
			table.insert(self.skillids[fightstatus], skillid)
		end
	end
end

function SkillPlug:RunStatus(round, fightstatus)
	local skills = self.skills[fightstatus]
	local skillids = self.skillids[fightstatus]
	local skillindex = self.skillindex[fightstatus]
	local skillsort = self.skillsort[fightstatus]
	if skills and skillids then
		if fightstatus == _FightStatus.Ready then
			for k, skill in pairs(skills) do
				skill:Use(round)
			end
			return
		end

		local index, skillid
		if skillindex then
			index, skillid = next(skillids, skillindex)
		else
			index, skillid = next(skillids)
		end

		if not skillid then
			index, skillid = next(skillids)
		end
		self.skillindex[fightstatus] = index
		local skill = skills[skillid]

		if skillsort then
			if not self.skillsortindex[fightstatus] or self.skillsortindex[fightstatus] >= #skillsort then
				self.skillsortindex[fightstatus] = 1
			else
				self.skillsortindex[fightstatus] = self.skillsortindex[fightstatus] + 1
			end

			local theskill
			local index = self.skillsortindex[fightstatus]
			for i = index, #skillsort do
				if skills[skillsort[i]] then
					theskill = skills[skillsort[i]]
					self.skillsortindex[fightstatus] = i
					break
				end
			end

			if not theskill then
				self.skillsortindex[fightstatus] = 1
				local index = self.skillsortindex[fightstatus]
				for i = index, #skillsort do
					if skills[skillsort[i]] then
						theskill = skills[skillsort[i]]
						self.skillsortindex[fightstatus] = i
						break
					end
				end
			end

			skill = theskill or skill
		end

		local targets
		-- 手动选择的对象
		if fightstatus == _FightStatus.Running and self.clientskill then
			skill = self.clientskill
			targets = self.clienttargets
		end

		self.entity.fight:AddActCount()

		if skill then
			skill:Use(round, targets)
			self.clientskill = nil
			self.clienttargets = nil
		end
	end
end

function SkillPlug:BuffTurnNext()
	-- 处理buff状态
	for bufftype, grouplist in pairs(self.buffstatus) do
		for groupid, args in pairs(grouplist) do
			if bufftype == FightConfig.BuffStatus.RESTORE then
				self.entity:DoRestore(groupid, args)
			elseif bufftype == FightConfig.BuffStatus.POISON then
				self.entity:DoPoison(groupid, args)
			elseif bufftype == FightConfig.BuffStatus.CLEAN then
				self.entity:DoClean(groupid, args)
			end
		end
	end

	local remove = {}
	for _, buff in pairs(self.bufflist) do
		if not buff:NextRound() then
			table.insert(remove, buff)
		end
	end
	for _, buff in ipairs(remove) do
		self.entity.fight:AddMsg(FightConfig.FightMsgType.RemoveBuff, buff.buffid, self.entity.handler, {args = {RemoveType.Normal}})
		self:RemoveBuff(buff)
	end

	if #self.nextaddbuff then
		for _, buffid in ipairs(self.nextaddbuff) do
			self:AddBuffByID(buffid)
		end
		self.entity.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, 0, self.handler, { target = self.handler, args = self.nextaddbuff })
	end
	self.nextaddbuff = {}
end

function SkillPlug:NextAddBuffByID(buffid)
	local BuffConfig = server.configCenter.EffectsConfig[buffid]
	if BuffConfig.next == 1 then
		self.nextaddbuff = self.nextaddbuff or {}
		table.insert(self.nextaddbuff, buffid)
		return true
	end
	return false
end

function SkillPlug:AddBuffByID(buffid, caster, args)
	local buff = Buff.new(buffid, caster or self.entity, args)
	return self:AddBuff(buff)
end

function SkillPlug:DelBuffByID(buffid)
	local buffconfig = server.configCenter.EffectsConfig[buffid]
	self:DelBuffByGroup(buffconfig.group)
end

function SkillPlug:DelBuffByGroup(buffgroup)
	if not self.bufflist[buffgroup] then
		lua_app.log_info("SkillPlug:DelBuffByGroup not exist buff", self.entity.etype, buff.buffid, buff.config.group)
		return
	end
	self:RemoveBuff(self.bufflist[buffgroup])
end

function SkillPlug:AddBuff(buff)
	if not buff.config then
		lua_app.log_info("SkillPlug:AddBuff not buff config", self.entity.etype, buff.buffid)
		return
	end
	local buffgroup = buff.config.group
	if self.bufflist[buffgroup] then
		self.bufflist[buffgroup]:Release()
	end
	self.bufflist[buffgroup] = buff
	self.entity.fight:PrintDebug("SkillPlug:AddBuff", "buffid:"..buff.buffid, "buffgroup:"..buffgroup, "bufftype:"..buff.config.type,
		"etype:"..self.entity.etype, "hander:"..self.entity.handler)
	return buff:Init(self.entity)
end

function SkillPlug:RemoveBuff(buff)
	local buffgroup = buff.config.group
	if not self.bufflist[buffgroup] then
		lua_app.log_error("SkillPlug:RemoveBuff not exist buff", buff.buffid, buff.config.group)
		return
	end
	self.bufflist[buffgroup] = nil
	buff:Release()
	self.entity.fight:PrintDebug("SkillPlug:RemoveBuff", buff.buffid, buffgroup, self.entity.handler)
end

function SkillPlug:AddBuffStatus(bufftype, buffgroup, args)
	if not self.buffstatus[bufftype] then
		self.buffstatus[bufftype] = {}
	end
	self.buffstatus[bufftype][buffgroup] = (args or true)
end

function SkillPlug:RemoveBuffStatus(bufftype, buffgroup)
	if not self.buffstatus[bufftype] then return end
	self.buffstatus[bufftype][buffgroup] = nil
	if not next(self.buffstatus[bufftype]) then
		self.buffstatus[bufftype] = nil
	end
end

function SkillPlug:HasStatus(bufftype)
	return self.buffstatus[bufftype]
end

function SkillPlug:CannotAct()
	if self:HasStatus(FightConfig.BuffStatus.COMA) then
		return FightConfig.BuffStatus.COMA
	end
	if self:HasStatus(FightConfig.BuffStatus.SEAL) then
		return FightConfig.BuffStatus.SEAL
	end
	if self:HasStatus(FightConfig.BuffStatus.FROZEN) then
		return FightConfig.BuffStatus.FROZEN
	end
	if self:HasStatus(FightConfig.BuffStatus.SLEEP) then
		return FightConfig.BuffStatus.SLEEP
	end
	return 0
end

function SkillPlug:ReleaseBuffs()
	for _, buff in pairs(self.bufflist) do
		buff:Release()
	end
	self.bufflist = {}
end

function SkillPlug:Release()
	self:ReleaseBuffs()
end

function SkillPlug:GetSkillList()
	local skills = {}
	local runskills = self.skills[_FightStatus.Running]
	if not runskills then
		return skills
	end
	for skillid, _ in pairs(self.skills[_FightStatus.Running]) do
		table.insert(skills, skillid)
	end
	return skills
end

function SkillPlug:ClientUseSkill(skillid, targets)
	local runskills = self.skills[_FightStatus.Running]
	if runskills and runskills[skillid] then
		self.clientskill = self.skills[_FightStatus.Running][skillid]
		self.clienttargets = {}
		for _,v in ipairs(targets) do
			local entity = self.entity.fight.entitylist[v]
			if entity then
				self.clienttargets[v] = entity
				break
			end
		end
	end
	self.entity.fight:PrintDebug(">> SkillPlug:ClientUseSkill", skillid)

end

-- 净化，清除负面buff
function SkillPlug:CleanDebuff()
	local remove = {}
	for _, buff in pairs(self.bufflist) do
		if not buff:IsHelpful() then
			table.insert(remove, buff)
		end
	end

	for _, buff in ipairs(remove) do
		self.entity.fight:AddMsg(FightConfig.FightMsgType.RemoveBuff, buff.buffid, self.entity.handler, {args = {RemoveType.Clean}})
		self:RemoveBuff(buff)
	end
end

function SkillPlug:GetCanUseSkills()
	local list = {}
	for skillid, skill in pairs(self.skills[_FightStatus.Running]) do
		if skill:CheckCD(self.entity.fight.round + 1) then
			table.insert(list, skillid)
		end
	end
	return list
end

function SkillPlug:RemoveFormationSkill()
	for _, sskill in pairs(self.skills) do
		for skillid, skill in pairs(self.skills[_FightStatus.Running]) do
			if server.configCenter.FormationSkillConfig[skillid] then
				self.skills[_FightStatus.Running][skillid] = nil
			end
		end
	end
end

return SkillPlug