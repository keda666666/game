local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local TianNvPlug = oo.class(template)
--[[
天女
]]--
template:SetType(9, {type1="tiannv",type2="tianNvPlug",shownum=1})

function TianNvPlug:ctor(tiannv)
	self.typ = 9
	self.tiannv = tiannv
	-- self.equipType = 0
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.TianNv
end

function TianNvPlug:onCreate()
	self:Init(self.tiannv.cache.tiannv_data)
end

function TianNvPlug:onLoad()
	self:Init(self.tiannv.cache.tiannv_data)
end

--此模块没有装备和技能功能
function TianNvPlug:ChangeEquip()
end
function TianNvPlug:SkillUpLv()
end

-- function TianNvPlug:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function TianNvPlug:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.FemaleDevaBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function TianNvPlug:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.FemaleDevaAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function TianNvPlug:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.FemaleDevaProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function TianNvPlug:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.FemaleDevaLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function TianNvPlug:GetSkillConfig()
	-- if _skillConfig then return _skillConfig end
	-- _skillConfig = server.configCenter.FemaleDevaSkillConfig
	return _skillConfig
end

local _skinConfig = false
function TianNvPlug:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.FemaleDevaSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(TianNvPlug, "tiannv.tianNvPlug")
return TianNvPlug