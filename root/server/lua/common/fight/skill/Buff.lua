local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local BuffArgs = require "fight.skill.BuffArgs"

local Buff = oo.class()

Buff.type = {
	CHANGE_HP			= 1,	-- 改变HP
	CHANGE_ATTR			= 2,	-- 改变属性
	SET_STATUS			= 3,	-- 状态
}

function Buff:ctor(id, caster, args)
	self.buffid = id
	self.caster = caster
	self.config = server.configCenter.EffectsConfig[id]
	if args and args ~= true then
		self.args = BuffArgs.InitArgs(args, self.config)
	end
end

local _InitBuff = {}
_InitBuff[Buff.type.CHANGE_HP] = function(self, args)
	local entity = self.entity
	self.value = math.floor(entity:GetAttr(args.t)*args.a + args.b)
	return true
end
_InitBuff[Buff.type.CHANGE_ATTR] = function(self, args)
	if not args then
		lua_app.log_error("no args --------- ", self.buffid)
		return true
	end
	local entity = self.entity
	local a = args.a or 1
	local b = args.b or 0
	if not args.t then
		lua_app.log_error("no args.t --------- ", self.buffid)
		return true
	end
	self.value = math.floor(entity:GetAttr(args.t)*a + b)
	self.arg = args.t
	self.entity:ChangeAttr(self.arg, self.value)
	return true
end
_InitBuff[Buff.type.SET_STATUS] = function(self, args)
	self.value = table.wcopy(args)
	self.arg = args.i
	self.args = args
	self.entity.skill:AddBuffStatus(self.arg, self.config.group, self.value)
	return true
end
function Buff:Init(entity)
	if self.round then
		lua_app.log_error("Buff:Init: re init buff", self.buffid)
		return
	end
	self.entity = entity
	self.round = 0
	return _InitBuff[self.config.type](self, self.args or self.config.args)
end

local _NextBuff = {}
_NextBuff[Buff.type.CHANGE_HP] = function(self)
	self.entity.fight:AddMsg(FightConfig.FightMsgType.BuffHP, self.buffid, self.caster.handler, { target = self.entity.handler, arg = self.value })
	self.entity:ChangeHP(self.value, self.caster, true)
end
_NextBuff[Buff.type.SET_STATUS] = function(self)
	if self.arg == FightConfig.BuffStatus.GAINBUFF then
		self.roundadd = self.roundadd or 0
		if self.roundadd == 0 then
			if not self.args then
				return
			end
			local p = self.args.p or 1
			local buffid = self.args.id
			local rand = math.random()
			if rand < p then
				local targetlist = self.entity:GetSelfTargetList()
				for k, v in pairs(targetlist) do
					local buffids = {}
					if not v.skill:NextAddBuffByID(buffid) then
						if v.skill:AddBuffByID(buffid, self.entity) then
							table.insert(buffids, buffid)
						end
					end
					if #buffids > 0 then
						self.entity.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, 0, v.handler, { target = self.entity.handler, args = buffids })
					end
				end
			end
		end
		self.roundadd = self.roundadd + 1
		if self.roundadd >= self.config.interval then
			self.roundadd = 0
		end
	end
end
function Buff:NextRound()
	self.round = self.round + 1
	local nextfunc = _NextBuff[self.config.type]
	if nextfunc then
		nextfunc(self)
	end
	return self.round < self.config.duration
end

local _ReleaseBuff = {}
_ReleaseBuff[Buff.type.CHANGE_ATTR] = function(self)
	self.entity:ChangeAttr(self.arg, -self.value)
end
_ReleaseBuff[Buff.type.SET_STATUS] = function(self)
	self.entity.skill:RemoveBuffStatus(self.arg, self.config.group)
end
function Buff:Release()
	if not self.round then
		lua_app.log_warning("Buff:Release: not init buff", self.buffid)
		return
	end
	self.round = nil
	local releasefunc = _ReleaseBuff[self.config.type]
	if releasefunc then
		releasefunc(self)
	end
end

-- 是否增益的buff
function Buff:IsHelpful()
	return self.config.isBuff == 1
end

return Buff