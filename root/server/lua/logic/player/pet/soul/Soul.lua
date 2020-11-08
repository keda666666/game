local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Soul = oo.class(template)
--[[
宠物兽魂
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(5, {type1="pet",type2="soul",shownum=2})

function Soul:ctor(pet)
	self.typ = 5
	self.equipType = 6
	self.pet = pet
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Soul
end

function Soul:onCreate()
	self:Init(self.pet.cache.pet_soul_data)
end

function Soul:onLoad()
	self:Init(self.pet.cache.pet_soul_data)
end

-- function Soul:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Soul:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.SoulBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Soul:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.SoulAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Soul:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.SoulProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Soul:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.SoulLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Soul:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.SoulSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Soul:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.SoulSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Soul, "pet.soul")
return Soul