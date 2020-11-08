local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local EntityConfig = require "resource.EntityConfig"
local FightConfig = require "resource.FightConfig"
local SkillPlug = require "fight.entity.SkillPlug"
local Action = require "fight.skill.Action"

local hpattrtype = EntityConfig.Attr.atHP
local maxhpattrtype = EntityConfig.Attr.atMaxHP
local speedattrtype = EntityConfig.Attr.atSpeed

local Entity = oo.class()

function Entity:ctor(fight, etype)
	self.handler = server.GetUID()
	self.etype = etype
	self.ownerid = 0
	self.fight = fight
	self.skill = SkillPlug.new(self)
end

function Entity:Init(side, pos, attrs, sattrs, exdatas, iswait)
	exdatas = exdatas or {}
	self.side = side
	self.pos = pos
	self.isinit = true
	self.attrs = attrs
	self.sattrs = sattrs or {}
	self.shows = exdatas.shows or {}
	self.skill:Init(exdatas.skilllist, exdatas.skillsort, exdatas.buffinit)
	self.iswait = iswait

	-- 速度处理
	local PosSpeedConfig = server.configCenter.PosSpeedConfig
	if self.etype == EntityConfig.EntityType.Monster then
		self.attrs[speedattrtype] = self.attrs[speedattrtype] + PosSpeedConfig[pos + 9].PosSpeed
	else
		self.attrs[speedattrtype] = self.attrs[speedattrtype] + PosSpeedConfig[pos].PosSpeed
	end
	self.fight:PrintDebug("Entity:Init", self.handler, side)
end

function Entity:InitAsMonster(mondata)
	local side = mondata.side
	local pos = mondata.pos
	local monid = mondata.monid
	local hp = mondata.hp
	local attrscfg = mondata.attrscfg or {}
	local resetattrs = mondata.resetattrs or {}
	local initsattrs = mondata.initsattrs or {}

	local MonConfig = server.configCenter.Monsters2SConfig
	if server.serverid and server.serverid <= 4 then
		MonConfig = server.configCenter.Monsters3SConfig
	end
	local config = server.configCenter.MonstersConfig[monid] or MonConfig[monid]
	local attrs = EntityConfig:GetZeroAttr(EntityConfig.Attr.atCount)
	for ttype, column in pairs(EntityConfig.EntityConfigAttr) do
		attrs[ttype] = attrscfg and attrscfg[column] or config[column]
	end
	attrs[EntityConfig.Attr.atHP] = hp or attrs[EntityConfig.Attr.atMaxHP]

	for ttype, value in pairs(resetattrs) do
		attrs[ttype] = value
	end

	local sattrs = {}
	for ttype, value in pairs(initsattrs) do
		sattrs[ttype] = value
	end

	local skilllist = {}
	for _, skillid in ipairs(config.skill) do
		skilllist[skillid] = true
	end
	self.monid = monid
	self:Init(side, pos, attrs, sattrs, { skilllist = {
			[FightConfig.FightStatus.Running] = skilllist,
		} })
end

function Entity:SetOwner(dbid)
	self.ownerid = dbid or 0
end

function Entity:SetSrcData(data)
	self.srcdata = data
end

function Entity:SetSyncHp(synchp)
	self.synchp = synchp
	if self.srcdata and self.synchp then
		self.srcdata.hp = self.attrs[hpattrtype]
	end
end

-- 组队排号 1 2 3 1是队长
function Entity:SetIndex(index)
	self.index = index
	if self.index ~= 1 and self.etype == EntityConfig.EntityType.Role then
		self.skill:RemoveFormationSkill()
	end
end

function Entity:GetAttr(attrtype)
	return self.attrs[attrtype]
end

function Entity:ChangeAttr(attrtype, value)
	self.fight:PrintDebug("Entity:ChangeAttr", attrtype, value, self.handler)
	self.attrs[attrtype] = math.floor(self.attrs[attrtype] + value)
end

function Entity:SetAttr(attrtype, value)
	self.attrs[attrtype] = math.floor(value)
end

function Entity:SetHP(value)
	self.attrs[hpattrtype] = math.floor(value)
end

function Entity:GetHP()
	return self.attrs[hpattrtype]
end

function Entity:ChangeHP(value, caster, isbuff)
	if self:IsDead() then return end
	self.fight:PrintDebug("Entity:ChangeHP", "blood:"..value, "caster_type:"..caster.etype, "caster_hander:"..caster.handler, 
		"target_type:"..self.etype, "target_hander:"..self.handler, "currhp:"..self.attrs[hpattrtype])
	self.attrs[hpattrtype] = math.floor(self.attrs[hpattrtype] + value)
	if self.attrs[hpattrtype] > self.attrs[maxhpattrtype] then
		self.attrs[hpattrtype] = math.floor(self.attrs[maxhpattrtype])
	elseif self.attrs[hpattrtype] < 0 then
		self.attrs[hpattrtype] = 0
		self:Dead(caster)
	end
	-- 上一个攻击自己的对象
	if not isbuff and value < 0 then
		self.lastcaster = caster
	end

	-- 同步血量
	if self.srcdata and self.synchp then
		self.srcdata.hp = self.attrs[hpattrtype]
	end
end

-- 伤害他人的时候
function Entity:onHit(value, target)
	-- 处理吸血
	local suckbloodlist = self.skill:HasStatus(FightConfig.BuffStatus.SUCKBLOOD)
	if suckbloodlist then
		for groupid, args in pairs(suckbloodlist) do
			local a = args.a or 1
			local b = args.b or 0
			local blood = math.floor(math.max(value * a + b, 0))
			self.fight:PrintDebug("Entity:Suck Blood", "blood:"..blood, "caster_type:"..self.etype, "caster_hander:"..self.handler, 
		"target_type:"..target.etype, "target_hander:"..target.handler)
			self.fight:AddMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, self.handler, { target = target.handler, args = { FightConfig.BuffStatus.SUCKBLOOD, blood} })
			self:ChangeHP(blood, target, true)
		end
	end

	if self.srcdata then
		self.srcdata.hit = self.srcdata.hit or 0
		self.srcdata.hit = self.srcdata.hit + value
	end
end

-- 被伤害的时候
function Entity:onDamage(value, caster)
	-- 处理反伤
	local thornslist = self.skill:HasStatus(FightConfig.BuffStatus.THORNS)
	if thornslist then
		for groupid, args in pairs(thornslist) do
			local a = args.a or 1
			local b = args.b or 0
			local hurt = -math.floor(math.max(value * a + b, 0))
			self.fight:PrintDebug("Entity:Thorns Blood", "hurt:"..hurt, "caster_type:"..self.etype, "caster_hander:"..self.handler, 
		"target_type:"..caster.etype, "target_hander:"..caster.handler)
			self.fight:AddMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, caster.handler, { target = self.handler, args = { FightConfig.BuffStatus.THORNS, hurt} })
			caster:ChangeHP(hurt, self, true)
		end
	end

	-- 处理复仇
	local revengelist = self.skill:HasStatus(FightConfig.BuffStatus.REVENGE)
	if revengelist then
		local buffids = {}
		for groupid, args in pairs(revengelist) do
			local p = args.p or 1
			local buffid = args.id
			local rand = math.random()
			if rand < p then
				self.skill:AddBuffByID(buffid, caster)
				if not self.skill:NextAddBuffByID(buffid) then
					if self.skill:AddBuffByID(buffid, caster) then
						table.insert(buffids, buffid)
					end
				end
				self.fight:AddMsg(FightConfig.FightMsgType.BuffStatusAct, groupid, self.handler, {target = caster.handler, args = {FightConfig.BuffStatus.REVENGE}})
			end
		end
		if #buffids > 0 then
			self.fight:AddMsg(FightConfig.FightMsgType.ActionBuff, 0, self.handler, { target = self.handler, args = buffids })
		end
	end
end

function Entity:ClientMsg()
	local msg = {
		ownerid = self.ownerid,
		handler = self.handler,
		type = self.etype,
		side = self.side,
		pos = self.iswait and -1 or self.pos,
		attrs = lua_util.ConverToArray(self.attrs, 0, EntityConfig.Attr.atCount),
		sattrs = {},
		shows = self.shows,
		skills = self.skill:GetSkillList(),
	}
	for i,v in ipairs(self.sattrs) do
		table.insert(msg.sattrs, {atttype = i, value = v})
	end
	if self.etype == EntityConfig.EntityType.Monster then
		msg.monid = self.monid
	end
	return msg
end

function Entity:Dead(killer)
	self.killer = killer or true
	self.fight:PrintDebug("Entity:Dead .......", "type:"..self.etype, "hander:"..self.handler)
	self.fight:EnterMsgAdd(FightConfig.FightMsgType.Dead, nil, self.handler, { target = killer and killer.handler })
	self.fight:ExitMsg()
	local isrelive = self:DoRelive()
	
	if not isrelive then
		self.skill:ReleaseBuffs()
		self.fight:CheckReplaceEntity(self)
	end
end

function Entity:DoRelive()
	local isrelive = false
	local relivebufflist = self.skill:HasStatus(FightConfig.BuffStatus.RELIVE)
	if relivebufflist then
		for groupid, args in pairs(relivebufflist) do
			local p = args.p or 1
			local a = args.a or 1
			local b = args.b or 0
			local rand = math.random()
			if rand < p then
				-- 复活
				isrelive = true
				self.killer = false
				self.attrs[hpattrtype] = math.floor(self.attrs[maxhpattrtype] * a + b)
				if self.attrs[hpattrtype] > self.attrs[maxhpattrtype] then
					self.attrs[hpattrtype] = math.floor(self.attrs[maxhpattrtype])
				end
				self.fight:PrintDebug("Entity:Relive !!!!!!", "type:"..self.etype, "hander:"..self.handler)
				self.fight:EnterMsgAdd(FightConfig.FightMsgType.Relive, nil, self.handler, { target = self.handler, arg = self.attrs[hpattrtype]})
				self.fight:ExitMsg()
				break
			end
		end
	end
	return isrelive
end

function Entity:IsDead()
	return self.killer
end

function Entity:CanBeAttack()
	return not self:IsDead()
end

function Entity:GetAttackList()
	return self.fight:GetSideBeAttackList(FightConfig.OtherSide[self.side])
end

function Entity:GetSelfTargetList()
	return self.fight:GetSideBeAttackList(self.side)
end

function Entity:GetLastCasterList()
	if self.lastcaster then
		return {self.lastcaster}
	else
		return {}
	end
end

function Entity:RunStatus(round, fightstatus)
	if self:IsDead() then return end
	local cannot = self.skill:CannotAct()
	if cannot > 0 then
		if fightstatus == FightConfig.FightStatus.Running then
			self.fight:EnterMsg(FightConfig.FightMsgType.BuffStatusAct, 0, self.handler, {target = self.handler, args = {cannot}})
			self.fight:ExitMsg()
		end
		return 
	end

	self.skill:RunStatus(round, fightstatus)
end

function Entity:NextTurn()
	if self:IsDead() then return end
	self.skill:BuffTurnNext()
end

function Entity:Release()
	if not self.isinit then
		lua_app.log_error("Entity:Release re release", self.handler)
		return
	end
	self.fight:PrintDebug("Entity:Release", self.handler)
	self.isinit = nil
	self.skill:Release()
end

function Entity:ClientUseSkill(skillid, targets)
	self.skill:ClientUseSkill(skillid, targets)
end

-- 处理回血
function Entity:DoRestore(groupid, args)
	local a = args.a or 1
	local b = args.b or 0
	local blood = math.floor(self.attrs[maxhpattrtype] * a + b)
	self.fight:PrintDebug("Entity:Restore Blood", "blood:"..blood, "type:"..self.etype, "hander:"..self.handler)
	self.fight:EnterMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, self.handler, {target = self.handler, args = {FightConfig.BuffStatus.RESTORE, blood}})
	self.fight:ExitMsg()
	self:ChangeHP(blood, self, true)
end

-- 处理掉血
function Entity:DoPoison(groupid, args)
	local a = args.a or 1
	local b = args.b or 0
	local blood = -math.floor(self.attrs[maxhpattrtype] * a + b)
	self.fight:PrintDebug("Entity:Poison Blood", "blood:"..blood, "type:"..self.etype, "hander:"..self.handler)
	self.fight:EnterMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, self.handler, {target = self.handler, args = {FightConfig.BuffStatus.POISON, blood}})
	self.fight:ExitMsg()
	self:ChangeHP(blood, self, true)
end

-- 处理净化
function Entity:DoClean(groupid, args)
	local p = args.p or 1
	local rand = math.random()
	if rand < p then
		self.fight:PrintDebug("Entity:Clean", "type:"..self.etype, "hander:"..self.handler)
		self.fight:EnterMsg(FightConfig.FightMsgType.BuffStatusAct, groupid, self.handler, {target = self.handler, args = {FightConfig.BuffStatus.CLEAN}})
		for _, entity in pairs(self.fight.sidelist[self.side]) do
		 	entity:CleanDebuff()
		end
		self.fight:ExitMsg()
		return
	end
end

-- 净化，清除负面buff
function Entity:CleanDebuff()
	self.skill:CleanDebuff()
end

-- 处理伤害吸收
function Entity:DoAbsorb(damage)
	local absorblist = self.skill:HasStatus(FightConfig.BuffStatus.ABSORB)
	if absorblist then
		for groupid, args in pairs(absorblist) do
			local a = args.a or 1
			local b = args.b or 0
			local blood = math.floor(math.max(damage * a + b, 0))
			self.fight:PrintDebug("Entity:Absorb Blood", "blood:"..blood, "type:"..target.etype, "hander:"..target.handler)
			self.fight:AddMsg(FightConfig.FightMsgType.BuffStatusAct, groupid, target.handler, {target = caster.handler, args = {FightConfig.BuffStatus.ABSORB, blood}})
			damage = math.max(damage - blood, 0)
		end
		return damage
	end
	return damage
end

-- 处理连击
function Entity:DoDouble(damage, target, targetcount)
	local doublelist = self.skill:HasStatus(FightConfig.BuffStatus.DOUBLE)
	if doublelist then
		for groupid, args in pairs(doublelist) do
			local t = args.t
			local p = args.p or 1
			local a = args.a or 1
			local b = args.b or 0
			if not t or targetcount == 1 then
				local rand = math.random()
				if rand < p then
					local doubledamage = math.floor(damage * a + b, 0)
					local doubledamage = target:DoAbsorb(doubledamage)
					doubledamage = -math.floor(doubledamage)
					target.fight:PrintDebug("Entity:Double Blood", "blood:"..doubledamage, "type:"..self.etype, "hander:"..self.handler)
					target.fight:AddMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, self.handler, { target = target.handler, args = { FightConfig.BuffStatus.DOUBLE, doubledamage} })
					target:ChangeHP(doubledamage, self, true)
					if doubledamage < 0 then
						self:onHit(-doubledamage, target)
						target:onDamage(-doubledamage, self)
					end
				end
			end
		end
	end
end

-- 处理反击
function Entity:DoBeatback(target)
	local beatbacklist = self.skill:HasStatus(FightConfig.BuffStatus.BEATBACK)
	if beatbacklist then
		for groupid, args in pairs(beatbacklist) do
			local p = args.p or 1
			local a = args.a or 1
			local b = args.b or 0
			local rand = math.random()
			if rand < p then
				local damage = Action:BaseDamage(self, target)
				local hurt = -math.floor(math.max(damage * a + b, 0))
				self.fight:AddMsg(FightConfig.FightMsgType.BuffStatusHP, groupid, self.handler, { target = target.handler, args = { FightConfig.BuffStatus.BEATBACK, hurt} })
				target:ChangeHP(hurt, self, true)
			end
		end
	end
end


-- 一些特殊的活动玩法需要处理的伤害
function Entity:DoSpecialDamage(damage)
	if self.srcdata and self.srcdata.deepen then
		damage = damage * (1 + self.srcdata.deepen / 100)
		damage = math.floor(math.max(damage, 0))
	end
	return damage
end

return Entity
