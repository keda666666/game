local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Psychic = oo.class(template)
--[[
宠物通灵
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(6, {type1="pet",type2="psychic",shownum=1})

function Psychic:ctor(pet)
	self.typ = 6
	self.equipType = 7
	self.pet = pet
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Psychic
end

function Psychic:onCreate()
	self:Init(self.pet.cache.pet_psychic_data)
end

function Psychic:onLoad()
	self:Init(self.pet.cache.pet_psychic_data)
end

-- function Psychic:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Psychic:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.PsychicBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Psychic:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.PsychicAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Psychic:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.PsychicProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Psychic:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.PsychicLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Psychic:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.PsychicSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Psychic:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.PsychicSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Psychic, "pet.psychic")
return Psychic