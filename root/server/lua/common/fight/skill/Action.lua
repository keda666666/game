local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local FightConfig = require "resource.FightConfig"
local Target = require "fight.Target"

local Action = {}

local EntityAttr = EntityConfig.Attr
local ActionType = FightConfig.ActionType
local _FightStatus = FightConfig.FightStatus

local HitType = {
	Crit 		= 1,
	Evade 		= 2,
	Normal 		= 3,
}

local _UseFunc = {}
_UseFunc[ActionType.DAMAGE] = function(id, args, cargs, target, caster, targetcount)
	local DamageAdjustConfig = server.configCenter.DamageAdjustConfig
	local hittype, damage, evade
	local deskattr = math.random()
	local crit = math.min(math.max(DamageAdjustConfig.critAdjust + (caster:GetAttr(EntityAttr.atCrit) - target:GetAttr(EntityAttr.atTough))
					/ DamageAdjustConfig.critAdjustLv, DamageAdjustConfig.critAdjustMinimum), DamageAdjustConfig.critAdjustMaxlimit)
	if deskattr < crit then
		hittype = HitType.Crit
	else
		deskattr = deskattr - crit
		evade = 1 - math.max(DamageAdjustConfig.HitAdjust + (DamageAdjustConfig.HitAdjustAdd + caster:GetAttr(EntityAttr.atHitRate)
				- target:GetAttr(EntityAttr.atEvade))/DamageAdjustConfig.HitAdjustLv, DamageAdjustConfig.HitAdjustMinimum)
		if deskattr < evade then
			hittype = HitType.Evade
			damage = 0
		else
			hittype = HitType.Normal
		end
	end
	if hittype ~= HitType.Evade then
		-- 最终伤害 = 暴击伤害(buff伤害(技能伤害(基础伤害())))
		local ca, cb = cargs and cargs.a or args.a, cargs and cargs.b or args.b
		
		-- changevalue = changevalue + caster:GetAttr(EntityAttr.atBossEnhance) - target:GetAttr(EntityAttr.atBossReduction)
		-- 基础伤害
		damage = Action:BaseDamage(caster, target)
		
		-- 技能伤害
		damage = math.max(damage * ca + cb, 1)
		if hittype == HitType.Crit then
			damage = damage * (2 + math.max((caster:GetAttr(EntityAttr.atCritEnhance) - target:GetAttr(EntityAttr.atCritReduction))/10000, -1))
		end
	end

	local normaldamage = damage

	damage = caster:DoSpecialDamage(damage)
	
	-- 吸收伤害
	damage = target:DoAbsorb(damage)

	damage = -math.floor(damage)
	target.fight:AddMsg(FightConfig.FightMsgType.ActionHP, id, caster.handler, { target = target.handler, args = { hittype, damage} })
	target:ChangeHP(damage, caster)
	if damage < 0 then
		caster:onHit(-damage, target)
		target:onDamage(-damage, caster)
	end

	-- 连击
	caster:DoDouble(normaldamage, target, targetcount)

	Action:Debuff(caster, target, targetcount)
	Action:Break(caster, target, targetcount)
end

_UseFunc[ActionType.ADDBUFF] = function(id, args, cargs, target, caster)
	local buffids = {}
	for _, buffid in ipairs((cargs or args).id) do
		if not target.skill:NextAddBuffByID(buffid) then
			if target.skill:AddBuffByID(buffid, caster) then
				table.insert(buffids, buffid)
			end
		end
	end
	if #buffids > 0 then
		target.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, id, caster.handler, { target = target.handler, args = buffids })
	end
end

function Action:BaseDamage(caster, target)
	local changevalue = 0
	if caster.fight.pvp then
		changevalue = caster:GetAttr(EntityAttr.atPVPEnhance) - target:GetAttr(EntityAttr.atPVPReduction)
	else
		changevalue = caster:GetAttr(EntityAttr.atPVEEnhance) - target:GetAttr(EntityAttr.atPVEReduction)
	end
	local DamageAdjustConfig = server.configCenter.DamageAdjustConfig
	local damage = math.max(DamageAdjustConfig.DamageAdjustAll
				* (math.max(caster:GetAttr(EntityAttr.atAttack) - math.max(target:GetAttr(EntityAttr.atDef)
				- math.max(caster:GetAttr(EntityAttr.atDefy) - target:GetAttr(EntityAttr.atDefyReduction), 0), 0), 0)) 
				* math.max(1 + (caster:GetAttr(EntityAttr.atDamageEnhancePerc) - target:GetAttr(EntityAttr.atDamageReductionPerc) + changevalue)/10000, 0)
				+ caster:GetAttr(EntityAttr.atDamageEnhance) - target:GetAttr(EntityAttr.atDamageReduction)
				+ caster:GetAttr(EntityAttr.atSoulAttack) - target:GetAttr(EntityAttr.atSoulDef), 1)
	return damage
end

function Action:Use(id, type, args, cargs, target, caster, targetcount)
	_UseFunc[type](id, args, cargs, target, caster, targetcount)
end

function Action:Run(id, cargs, targets, caster, last)
	local config = server.configCenter.SkillsExeConfig[id]
	local newtargets, newlast
	if not caster.skill.clienttargets then
		newtargets, newlast = Target:GetByConfig(caster, config.ttype, config.targetType, targets, last)
	else
		newtargets = targets
	end
	local prob = cargs.args and cargs.args.p or config.args and config.args.p
	if prob and math.random() >= prob then
		return
	end
	caster.fight:PrintDebug("     Action:Run", caster.handler, id)
	caster.fight:EnterMsg(FightConfig.FightMsgType.UseAction, id, caster.handler, nil, newtargets)
	local targetcount = 0
	for _ in pairs(newtargets) do
		targetcount = targetcount + 1
	end
	for _, target in ipairs(newtargets) do
		Action:Use(id, cargs.type or config.type, config.args, cargs.args, target, caster, targetcount)

		-- 反击
		if config.canbeatback == 1 and target.skill:CannotAct() == 0 then
			target:DoBeatback(caster)
			target:RunStatus(target.fight.round, _FightStatus.Damage)
		end
	end

	caster.fight:ExitMsg()
	
	return newlast or last
end

-- 处理debuff
function Action:Debuff(caster, target, targetcount)
	local debufflist = caster.skill:HasStatus(FightConfig.BuffStatus.DEBUFF)
	if debufflist then
		local buffids = {}
		for groupid, args in pairs(debufflist) do
			local t = args.t
			local p = args.p or 1
			local buffid = args.id
			if not t or targetcount == 1 then
				local rand = math.random()
				if rand < p then
					if not target.skill:NextAddBuffByID(buffid) then
						if target.skill:AddBuffByID(buffid, caster) then
							table.insert(buffids, buffid)
						end
					end
				end
			end
		end
		if #buffids > 0 then
			target.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, 0, caster.handler, { target = target.handler, args = buffids })
		end
	end
end

-- 破防
function Action:Break(caster, target, targetcount)
	local breaklist = caster.skill:HasStatus(FightConfig.BuffStatus.BREAK)
	if breaklist then
		local buffids = {}
		for groupid, args in pairs(breaklist) do
			local t = args.t
			local p = args.p or 1
			local a = args.a or 1
			local b = args.b or 0
			local buffid = args.id
			if not t or targetcount == 1 then
				local rand = math.random()
				if rand < p then
					local breakdamage = caster:GetAttr(EntityAttr.atAttack)
					local breakdamage = target:DoAbsorb(breakdamage)
					breakdamage = -math.floor(breakdamage)
					target.fight:AddMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, target.handler, { target = caster.handler, args = { FightConfig.BuffStatus.BREAK, breakdamage} })
					target:ChangeHP(breakdamage, caster, true)
					if not target.skill:NextAddBuffByID(buffid) then
						if target.skill:AddBuffByID(buffid, caster) then
							table.insert(buffids, buffid)
						end
					end
				end
			end
		end
		if #buffids > 0 then
			target.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, 0, caster.handler, { target = target.handler, args = buffids })
		end
	end
end

return Action