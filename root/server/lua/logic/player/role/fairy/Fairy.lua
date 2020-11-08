local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Fairy = oo.class(template)
--[[
天仙
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(3, {type1="role",type2="fairy",shownum=3})

function Fairy:ctor(role)
	self.typ = 3
	self.role = role
	self.equipType = 8
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Fairy
end

function Fairy:onCreate()
	self:Init(self.role.cache.fairy_data)
end

function Fairy:onLoad()
	self:Init(self.role.cache.fairy_data)
end

-- function Fairy:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Fairy:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.FairyBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Fairy:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.FairyAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Fairy:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.FairyProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Fairy:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.FairyLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Fairy:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.FairySkillConfig
	return _skillConfig
end

local _skinConfig = false
function Fairy:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.FairySkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Fairy, "role.fairy")
return Fairy