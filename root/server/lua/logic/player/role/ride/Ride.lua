local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local template = require "player.template.Template"
local Ride = oo.class(template)
--[[
坐骑
目前需要补充项目
等级才开启功能
达到等级开启后需要初始化属性发往客户端onLevelUp
]]--
template:SetType(1, {type1="role",type2="ride",shownum=1})

function Ride:ctor(role)
	self.typ = 1
	self.role = role
	self.equipType = 2
	self.YuanbaoRecordType=server.baseConfig.YuanbaoRecordType.Ride
end

function Ride:onCreate()
	self:Init(self.role.cache.ride_data)
end

function Ride:onLoad()
	self:Init(self.role.cache.ride_data)
end

-- function Ride:onInitClient()
-- 	-- if self.startUp == 0 then return end 
-- 	local msg = self:GetData()
-- 	msg.templateType = self.typ
-- 	server.sendReq(self.player, "sc_template_init_data", msg)
-- end

local _baseConfig = false
function Ride:GetBaseConfig()
	if _baseConfig then return _baseConfig end
	_baseConfig = server.configCenter.RideBaseConfig
	return _baseConfig
end

local _attrsConfig = false
function Ride:GetAttrsConfig()
	if _attrsConfig then return _attrsConfig end
	_attrsConfig = server.configCenter.RideAttrsConfig
	return _attrsConfig
end

local _progressConfig = false
function Ride:GetProgressConfig()
	if _progressConfig then return _progressConfig end
	_progressConfig = server.configCenter.RideProgressConfig
	return _progressConfig
end

local _lvproConfig = false
function Ride:GetLvproConfig()
	if _lvproConfig then return _lvproConfig end
	_lvproConfig = server.configCenter.RideLvproConfig
	return _lvproConfig
end

local _skillConfig = false
function Ride:GetSkillConfig()
	if _skillConfig then return _skillConfig end
	_skillConfig = server.configCenter.RideSkillConfig
	return _skillConfig
end

local _skinConfig = false
function Ride:GetSkinConfig()
	if _skinConfig then return _skinConfig end
	_skinConfig = server.configCenter.RideSkinConfig
	return _skinConfig
end

server.playerCenter:SetEvent(Ride, "role.ride")
return Ride