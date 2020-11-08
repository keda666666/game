local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Position = oo.class(template)
--[[
仙侣仙位
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(7, {type1="xianlv",type2="position",shownum=2})

function Position:ctor(xianlv)
	self.typ = 7
	self.equipType = 4
	self.xianlv = xianlv
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Position
end

function Position:onCreate()
	self:Init(self.xianlv.cache.xianlv_position_data)
end

function Position:onLoad()
	self:Init(self.xianlv.cache.xianlv_position_data)
end

-- function Position:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Position:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.PositionBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Position:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.PositionAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Position:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.PositionProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Position:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.PositionLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Position:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.PositionSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Position:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.PositionSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Position, "xianlv.position")
return Position