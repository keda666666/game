local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local BabyPlug = oo.class(template)
--[[
灵童
]]--
template:SetType(12, {type1="baby",type2="babyPlug",shownum=1})

function BabyPlug:ctor(baby)
	self.typ = 12
	self.baby = baby
	-- self.equipType = 0
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Baby
end

function BabyPlug:onCreate()
	self:onLoad()
end

function BabyPlug:onLoad()
	self:Init(self.baby.cache.baby_data)
end

local _baseConfig = false
function BabyPlug:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.BabyBasisConfig
	return _baseConfig
end

local _attrsConfig = false
function BabyPlug:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.BabyAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function BabyPlug:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.BabyProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function BabyPlug:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.BabyLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function BabyPlug:GetSkillConfig()
	return _skillConfig
end

local _skinConfig = false
function BabyPlug:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.BabySkinConfig
	return _skinConfig
end

function BabyPlug:OnUpLv()
	self.baby:OnUpLv()
	self.baby.babyStar:Open(true)--升级了开启新命格
end

function BabyPlug:OnOpenTemplate()
	self.baby.babyStar:Open(true) --判断能否开启新命格
end

server.playerCenter:SetEvent(BabyPlug, "baby.babyPlug")
return BabyPlug