local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Flower = oo.class(template)
--[[
天女花辇
]]--
template:SetType(11, {type1="tiannv",type2="flower",shownum=3})

function Flower:ctor(tiannv)
	self.typ = 11
	self.equipType = 12
	self.tiannv = tiannv
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Flower
end

function Flower:onCreate()
	self:Init(self.tiannv.cache.tiannv_flower_data)
end

function Flower:onLoad()
	self:Init(self.tiannv.cache.tiannv_flower_data)
end

-- function Flower:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Flower:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.FlowerBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Flower:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.FlowerAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Flower:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.FlowerProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Flower:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.FlowerLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Flower:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.FlowerSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Flower:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.FlowerSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Flower, "tiannv.flower")
return Flower