local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Weapon = oo.class(template)
--[[
神兵
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(4, {type1="role",type2="weapon",shownum=4})

function Weapon:ctor(role)
	self.typ = 4
	self.role = role
	self.equipType = 9
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Weapon
end

function Weapon:onCreate()
	self:Init(self.role.cache.weapon_data)
end

function Weapon:onLoad()
	self:Init(self.role.cache.weapon_data)
end

-- function Weapon:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Weapon:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.WeaponBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Weapon:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.WeaponAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Weapon:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.WeaponProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Weapon:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.WeaponLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Weapon:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.WeaponSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Weapon:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.WeaponSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Weapon, "role.weapon")
return Weapon