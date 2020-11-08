local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Wing = oo.class(template)
--[[
翅膀
目前需要补充项目20级才开启功能
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(2, {type1="role",type2="wing",shownum=2})

function Wing:ctor(role)
	self.typ = 2
	self.role = role
	self.equipType = 3
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Wing
end

function Wing:onCreate()
	self:Init(self.role.cache.wing_data)
end

function Wing:onLoad()
	self:Init(self.role.cache.wing_data)
end

-- function Wing:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Wing:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.WingBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Wing:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.WingAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Wing:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.WingProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Wing:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.WingLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Wing:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.WingSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Wing:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.WingSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Wing, "role.wing")
return Wing