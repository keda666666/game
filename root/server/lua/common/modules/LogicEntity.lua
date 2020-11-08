local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local FightConfig = require "resource.FightConfig"

local LogicEntity = oo.class()

function LogicEntity:ctor(player)
	self.player = player
	self.attrs = EntityConfig:GetZeroAttr(EntityConfig.Attr.atCount)
	self.exattrs = EntityConfig:GetZeroAttr(EntityConfig.ExAttr.eatCount)
	self.skilllist = {}
	self.skillsort = {}
	self.buffinit = {}
	self.shows = {}
end

function LogicEntity:ChangeBaseAttr(baseAttrType, changeValue, recordtype)
	recordtype = recordtype or 0
	local baseAttr = self.attrs
	local playerAttr = self.player.attrs
	local attrRecord = self.player.attrRecord[recordtype] or EntityConfig:GetZeroAttr(EntityConfig.Attr.atCount)
	baseAttr[baseAttrType] = baseAttr[baseAttrType] + changeValue
	playerAttr[baseAttrType] = playerAttr[baseAttrType] + changeValue
	attrRecord[baseAttrType] = attrRecord[baseAttrType] + changeValue
	if baseAttrType == EntityConfig.Attr.atMaxHP then
		baseAttr[EntityConfig.Attr.atHP] = baseAttr[baseAttrType]
		playerAttr[EntityConfig.Attr.atHP] = playerAttr[baseAttrType]
		attrRecord[EntityConfig.Attr.atHP] = attrRecord[baseAttrType]
	end
	self.player.attrRecord[recordtype] = attrRecord
	self:ToReCalcPower()
end

function LogicEntity:ResetBaseAttr(baseAttrType, oldvalue, newvalue)
	self:ChangeBaseAttr(baseAttrType, newvalue - (oldvalue or 0))
	self:ToReCalcPower()
end

function LogicEntity:UpdateBaseAttr(oldattrs, newattrs, recordtype)
	for _, v in pairs(oldattrs) do
		self:ChangeBaseAttr(v.type, -v.value, recordtype)
	end
	for _, v in pairs(newattrs) do
		self:ChangeBaseAttr(v.type, v.value, recordtype)
	end
	self:ToReCalcPower()
end

function LogicEntity:ChangeExAttr(exAttrType, changeValue)
	local exAttr = self.exattrs
	local playerExAttr = self.player.exattrs
	exAttr[baseAttrType] = baseAttr[baseAttrType] + changeValue
	playerExAttr[baseAttrType] = playerExAttr[baseAttrType] + changeValue
end

function LogicEntity:ResetExAttr(exAttrType, oldvalue, newvalue)
	self:ChangeExAttr(exAttrType, newvalue - (oldvalue or 0))
end

function LogicEntity:UpdateExAttr(oldattrs, newattrs)
	for _, v in pairs(oldattrs) do
		self:ChangeExAttr(v.type, -v.value)
	end
	for _, v in pairs(newattrs) do
		self:ChangeExAttr(v.type, v.value)
	end
end

function LogicEntity:ChangeEquip(oldItem, newItem)
	local EquipConfig = server.configCenter.EquipConfig
	self:UpdateBaseAttr(oldItem and oldItem.attrs or {}, newItem.attrs, server.baseConfig.AttrRecord.EquipBase)
	self:UpdateBaseAttr(oldItem and EquipConfig[oldItem.id] and EquipConfig[oldItem.id].attrs or {}, EquipConfig[newItem.id] and EquipConfig[newItem.id].attrs or {}, server.baseConfig.AttrRecord.EquipBase)
end

function LogicEntity:AddSkill(skillid, args, num)
	local SkillsConfig = server.configCenter.SkillsConfig[skillid]
	if not SkillsConfig then return end
	local fightstatus = SkillsConfig.runStatus
	num = num or 1
	local skilllist = self.skilllist[num]
	if not skilllist then
		skilllist = {}
		self.skilllist[num] = skilllist
	end
	if not skilllist[fightstatus] then
		skilllist[fightstatus] = {}
	end
	skilllist[fightstatus][skillid] = args or true
end

function LogicEntity:DelSkill(skillid, num)
	local SkillsConfig = server.configCenter.SkillsConfig[skillid]
	if not SkillsConfig then return end
	local fightstatus = SkillsConfig.runStatus
	num = num or 1
	self.skilllist[num] = self.skilllist[num] or {}
	self.skilllist[num][fightstatus] = self.skilllist[num][fightstatus] or {}
	self.skilllist[num][fightstatus][skillid] = nil
end

function LogicEntity:ClearSkill(num)
	self.skilllist[num or 1] = nil
end

function LogicEntity:GetSkill(num)
	return self.skilllist[num or 1]
end

function LogicEntity:GetRunSkill(num)
	local skilllist = self:GetSkill(num)
	return skilllist and skilllist[FightConfig.FightStatus.Running]
end

function LogicEntity:AddBuff(buffid, args, num)
	num = num or 1
	local buffinit = self.buffinit[num]
	if not buffinit then
		buffinit = {}
		self.buffinit[num] = buffinit
	end
	buffinit[buffid] = args or true
end

function LogicEntity:DelBuff(buffid, num)
	num = num or 1
	self.buffinit[num] = self.buffinit[num] or {}
	self.buffinit[num][buffid] = nil
end

function LogicEntity:GetBuff(num)
	return self.buffinit[num or 1]
end

function LogicEntity:ClearBuff(num)
	self.buffinit[num or 1] = {}
end

function LogicEntity:ClearEntity(num)
	num = num or 1
	self.skilllist[num] = nil
	self.skillsort[num] = nil
	self.buffinit[num] = nil
end

function LogicEntity:SetShow(typeid, value)
	for i = 1, typeid - 1 do
		if not self.shows[i] then
			self.shows[i] = 0
		end
	end
	self.shows[typeid] = value
	server.mapMgr:SetShow(self.player.dbid, self.player.role:GetShows())
end

function LogicEntity:GetShows()
	return self.shows
end

function LogicEntity:GetEntityShows()
	local msg = {
		job = self.player.cache.job,
		sex = self.player.cache.sex,
		name = self.player.cache.name,
		serverid = server.serverid,
		guildid = self.player.cache.guildid,
		guildname = self.player.guild:GetGuildName(),
		shows = self:GetShows(),
		level = self.player.cache.level,
	}
	return msg
end

function LogicEntity:GetSkillSort(num)
	return self.skillsort[num or 1]
end

function LogicEntity:SetSkillSort(fightstatus, skills, num)
	num = num or 1
	local skillsort = self.skillsort[num]
	if not skillsort then
		skillsort = {}
		self.skillsort[num] = skillsort
	end
	if not skillsort[fightstatus] then
		skillsort[fightstatus] = {}
	end
	skillsort[fightstatus] = skills
end

function LogicEntity:SetRunSkillSort(skills, num)
	self:SetSkillSort(FightConfig.FightStatus.Running, skills, num)
end

function LogicEntity:ToReCalcPower()
	if not self.powertimer and self.cache then
		local function _RunReCalcPower()
			if self.powertimer then
				lua_app.del_timer(self.powertimer)
				self.powertimer = nil
			end
			self:ReCalcPower()
		end
		self.powertimer = lua_app.add_timer(900, _RunReCalcPower)
	end
	self.player:ToReCalcPower()
end

function LogicEntity:ReCalcPower()
	local power = 0
	local attrs = EntityConfig:GetRealAttr(self.attrs, self.exattrs)
	local AttrPowerConfig = server.configCenter.AttrPowerConfig
	for k, v in pairs(attrs) do
		if AttrPowerConfig[k] then
			power = power + v * AttrPowerConfig[k].power
		end
	end
	self.cache.totalpower = math.floor(power / 100)
end

function LogicEntity:GetPower()
	return self.cache.totalpower or 0
end

return LogicEntity