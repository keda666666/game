local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Nimbus = oo.class(template)
--[[
天女灵气
]]--
template:SetType(10, {type1="tiannv",type2="nimbus",shownum=2})

function Nimbus:ctor(tiannv)
	self.typ = 10
	self.equipType = 13
	self.tiannv = tiannv
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Nimbus
end

function Nimbus:onCreate()
	self:Init(self.tiannv.cache.tiannv_nimbus_data)
end

function Nimbus:onLoad()
	self:Init(self.tiannv.cache.tiannv_nimbus_data)
end

-- function Nimbus:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Nimbus:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.NimbusBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Nimbus:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.NimbusAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Nimbus:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.NimbusProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Nimbus:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.NimbusLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Nimbus:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.NimbusSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Nimbus:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.NimbusSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Nimbus, "tiannv.nimbus")
return Nimbus