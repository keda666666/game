local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local Target = require "fight.Target"
local Action = require "fight.skill.Action"
local SkillArgs = require "fight.skill.SkillArgs"

local Skill = oo.class()

function Skill:ctor(entity, id, args)
	self.entity = entity
	self.fight = entity.fight
	self.skillid = id
	self.config = table.wcopy(server.configCenter.SkillsConfig[id])
	if args and args ~= true then
		SkillArgs.InitArgs(args, self.config)
		self.args = args
	else
		self.args = {}
	end
end

-- function Skill:ResetEntity(entity)
-- 	self.entity = entity
-- end

-- function Skill:ResetConfig(config)
-- 	self.config = config
-- end

function Skill:Init(round)
	self.round = round or 0
end

function Skill:CheckCD(round)
	return self.round == 0 or self.round + self.config.cd <= round
end

function Skill:Use(round, targets)
	if not self:CheckCD(round) then return end
	
	self.round = round
	if targets then
		targets = Target:CheckTargets(self.entity, self.config.ttype, self.config.targetType, targets)
	end
	if not targets then
		targets = Target:GetByConfig(self.entity, self.config.ttype, self.config.targetType)
	end
	local last = 0
	self.fight:PrintDebug(">> Skill:Use", "type:"..self.entity.etype, "owner:"..self.entity.ownerid, 
		"hander:"..self.entity.handler, "skillid:"..self.skillid)
	self.fight:EnterMsg(FightConfig.FightMsgType.UseSkill, self.skillid, self.entity.handler, nil, targets)
	local retList = {}
	for i, actionid in ipairs(self.config.actions) do
		last = Action:Run(actionid, self.args[i] or {}, targets, self.entity, last)
	end
	self.fight:ExitMsg()
end

return Skill