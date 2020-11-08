local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Circle = oo.class(template)
--[[
仙侣法阵
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(8, {type1="xianlv",type2="circle",shownum=1})

function Circle:ctor(xianlv)
	self.typ = 8
	self.equipType = 5
	self.xianlv = xianlv
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Circle
end

function Circle:onCreate()
	self:Init(self.xianlv.cache.xianlv_circle_data)
end

function Circle:onLoad()
	self:Init(self.xianlv.cache.xianlv_circle_data)
end

-- function Circle:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Circle:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.CircleBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Circle:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.CircleAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Circle:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.CircleProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Circle:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.CircleLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Circle:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.CircleSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Circle:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.CircleSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Circle, "xianlv.circle")
return Circle