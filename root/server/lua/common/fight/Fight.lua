local server = require "server"
local lua_app = require "lua_app"
local oo = require "class"
local EntityConfig = require "resource.EntityConfig"
local FightConfig = require "resource.FightConfig"
local Entity = require "fight.entity.Entity"
local AttackSort = require "fight.AttackSort"

local Fight = oo.class()
local _FightStatus = FightConfig.FightStatus
local _WaitSkillTime = 15
local _WaitAutoTime = 3

function Fight:ctor()
end

function Fight:InitData(fbid, raid)
	self.raid = raid
	self.fbid = fbid
	self.entitylist = {}
	self.sidelist = {
		[FightConfig.Side.Def]	= {},
		[FightConfig.Side.Attack]	= {},
	}
	self.waitlist = {}
	self.sidewaitlist = {
		[FightConfig.Side.Def]	= {},
		[FightConfig.Side.Attack]	= {},
	}
	self.tmpwaitinlist = {}
	self.tmpwaitorderlist = {}
	self.playerlist = {}
	self.posToEntity = {
		[FightConfig.Side.Def]	= {},
		[FightConfig.Side.Attack]	= {},
	}
	self.round = 0
	self.msglist = {}
	self.msginsert = self.msglist
	self.msglayer = {}
	self.record = {}

	local instancecfg = server.configCenter.InstanceConfig[self.fbid] or server.configCenter.Instance2SConfig[self.fbid]
	self.raidtype = instancecfg.type
	self.maxround = instancecfg.totalTime
	self.manuallymode = instancecfg.manuallymode
end

function Fight:InitPvP(fbid, raid)
	self:InitData(fbid, raid)
	self.pvp = true
end

function Fight:Init(fbid, raid, hps, initmonsters, attrscfg, resetattrs, initsattrs)
	self:InitData(fbid, raid)
	self:PrintDebug("Fight:InitFight:InitFight:InitFight:InitFight:InitFight:InitFight:Init")
	local instancecfg = server.configCenter.InstanceConfig[self.fbid] or server.configCenter.Instance2SConfig[self.fbid]
	if not initmonsters then
		initmonsters = instancecfg.initmonsters
	end
	hps = hps or {}
	attrscfg = attrscfg or {}
	resetattrs = resetattrs or {}
	initsattrs = initsattrs or {}
	for _, monsterinfo in pairs(initmonsters) do
		local pos = monsterinfo.pos
		local mondata = {
			side = FightConfig.Side.Def,
			pos = pos,
			monid = monsterinfo.monid,
			hp = hps[pos],
			attrscfg = attrscfg[pos] or attrscfg[0],
			resetattrs = resetattrs[pos] or resetattrs[0],
			initsattrs = initsattrs[pos] or initsattrs[0],
		}
		self:AddMonster(mondata)
	end
end

function Fight:AddMonster(mondata)
	local side = mondata.side
	local pos = mondata.pos
	local hp = mondata.hp
	if hp == 0 then return end
	local entity = Entity.new(self, EntityConfig.EntityType.Monster)
	entity:InitAsMonster(mondata)
	self.entitylist[entity.handler] = entity
	self.sidelist[side][entity.handler] = entity
	self.posToEntity[side][pos] = entity
	return entity
end

function Fight:AddEntity(etype, side, pos, attrs, sattrs, exdatas, iswait, hp)
	local entity = Entity.new(self, etype)
	entity:Init(side, pos, attrs, sattrs, exdatas, iswait)
	if hp and hp > 0 then
		entity:SetHP(hp)
	end
	if iswait then
		if not self.sidewaitlist[side][pos] then
			self.sidewaitlist[side][pos] = {}
		end
		table.insert(self.sidewaitlist[side][pos], entity)
		self.waitlist[entity.handler] = entity
	else
		self.sidelist[side][entity.handler] = entity
		self.posToEntity[side][pos] = entity
		self.entitylist[entity.handler] = entity
	end
	return entity
end

function Fight:AddPlayer(side, dbid, datas, index)
	local entitys = {}
	local waitentitys = {}
	local attrs = datas.playerinfo.attrs
	for _, edatas in ipairs(datas.entitydatas) do
		self:RefreshPos(index, edatas)
		local entity = self:AddEntity(edatas.etype, side, edatas.pos, table.wcopy(attrs), {}, edatas, edatas.iswait, datas.synchp and edatas.hp)
		entity:SetOwner(dbid)
		entity:SetSrcData(edatas)
		entity:SetSyncHp(datas.synchp)
		entity:SetIndex(index)
		entitys[entity.handler] = entity
		if edatas.iswait then
			waitentitys[entity.handler] = entity
		end
	end
	if dbid then
		self.playerlist[dbid] = {
			side = side,
			info = datas.playerinfo,
			entitydatas = datas.entitydatas,
			entitys = entitys,
			waitentitys = waitentitys,
		}
		server.fightCenter:SetFight(dbid, self)
	end
	self:SetAuto(dbid, 1, false)
	self:PrintDebug("Fight:AddFight:AddFight:AddFight:AddFight:AddFight:Add", dbid, datas)
end

function Fight:AddTeam(side, team)
	local index = 1
	for playerid, member in pairs(team.playerlist) do
		self:AddPlayer(side, playerid, member.packinfo, index)
		index = index + 1
	end
	for _, member in pairs(team.robotlist) do
		self:AddPlayer(side, nil, member.packinfo, index)
		index = index + 1
	end
end

function Fight:CheckAndSetEntity(isaddmsg)
	local setposs = {}
	for side, poslist in pairs(self.sidewaitlist) do
		for pos, list in pairs(poslist) do
			if not self.posToEntity[side][pos] then
				table.insert(setposs, { side = side, pos = pos })
			end
		end
	end
	for _, v in pairs(setposs) do
		local list = self.sidewaitlist[v.side][v.pos]
		local entity = table.remove(list, 1)
		if not next(list) then
			self.sidewaitlist[v.side][v.pos] = nil
		end
		entity.iswait = nil
		self.sidelist[entity.side][entity.handler] = entity
		self.posToEntity[v.side][v.pos] = entity
		self.waitlist[entity.handler] = nil
		self.entitylist[entity.handler] = entity
		if isaddmsg then
			self:AddMsg(FightConfig.FightMsgType.OutBound, entity.pos, nil, { target = entity.handler })
		end
	end
end

function Fight:CheckReplaceEntity(entity)
	-- self.sidelist[entity.side][entity.handler] = nil
	local list = self.sidewaitlist[entity.side][entity.pos]
	if list then
		local nentity = table.remove(list, 1)
		if nentity then
			-- self.sidelist[nentity.side][nentity.handler] = nentity
			table.insert(self.tmpwaitinlist, { entity, nentity })
		end
		if not next(list) then
			self.sidewaitlist[entity.side][entity.pos] = nil
		end
	end
end

function Fight:SetReplaceEntity()
	for _, v in ipairs(self.tmpwaitinlist) do
		local entity, nentity = v[1], v[2]
		self.sidelist[entity.side][entity.handler] = nil
		nentity.iswait = nil
		self.sidelist[nentity.side][nentity.handler] = nentity
		self.posToEntity[nentity.side][nentity.pos] = nentity
		self.waitlist[nentity.handler] = nil
		self.entitylist[nentity.handler] = nentity
		table.insert(self.tmpwaitorderlist, nentity)
		self:AddMsg(FightConfig.FightMsgType.OutBound, nentity.pos, nil, { target = nentity.handler })
	end
	self.tmpwaitinlist = {}
end

function Fight:GetSideBeAttackList(side)
	local ar = {}
	for _, entity in pairs(self.sidelist[side]) do
		if entity:CanBeAttack() then
			table.insert(ar, entity)
		end
	end
	return ar
end

function Fight:SetCmds(cmds)
end

function Fight:RunEntitys(status)
	self.status = status
	for _, entity in ipairs(self.playerorder) do
		entity:RunStatus(self.round, status)
		self:SetReplaceEntity()
	end
end

function Fight:TurnRunning()
	for _, entity in ipairs(self.playerorder) do
		entity:NextTurn()
	end

	for _, entity in ipairs(self.playerorder) do
		entity:RunStatus(self.round, _FightStatus.Before)
		entity:RunStatus(self.round, _FightStatus.Running)
		entity:RunStatus(self.round, _FightStatus.After)
		self:SetReplaceEntity()
	end
end

function Fight:FightStart()
	self.round = 0
	self.starttime = lua_app.now()
	self.playerorder = {}
	local datamsg = {}
	for _, entity in pairs(self.entitylist) do
		table.insert(self.playerorder, entity)
		table.insert(datamsg, entity:ClientMsg())
	end
	for _, entity in pairs(self.waitlist) do
		table.insert(datamsg, entity:ClientMsg())
	end
	self:Broadcast("sc_battle_entitys", {
			raidType = self.raidtype,
			fbid = self.fbid,
			manual = self.manual,
			entitydatas = datamsg,
		})
	AttackSort.SortBySpeed(self.playerorder)
	self:RunEntitys(_FightStatus.Ready)
end

function Fight:FightEnd(loseside)
	self:RunEntitys(_FightStatus.Over)
	self:Over(loseside)
end

function Fight:CheckOver()
	local remove = {}
	local side = {
		[FightConfig.Side.Def]		= true,
		[FightConfig.Side.Attack]	= true,
	}
	for _, entity in ipairs(self.tmpwaitorderlist) do
		table.insert(self.playerorder, entity)
	end
	self.tmpwaitorderlist = {}
	for i = #self.playerorder, 1, -1 do
		local entity = self.playerorder[i]
		if entity:IsDead() then
			table.insert(remove, i)
		else
			side[entity.side] = nil
		end
	end
	for _, i in ipairs(remove) do
		table.remove(self.playerorder, i)
	end
	local loseside = next(side)
 	if not loseside then
 		if self.maxround then
 			if self.round < self.maxround then
 				return
 			else
 				if self.pvp then
	 				loseside = self:PvPLostSide()
	 			end
 			end
 		else
			return
		end
	end
	if not loseside then
		loseside = FightConfig.Side.Attack
	end
	self:FightEnd(loseside)
end

-- pvp的胜负判断
-- （1）30个回合过后，存活单位较多的一方获胜；
-- （2）存活单位一致时，剩余血量较多的一方获胜；
-- （3）存活单位与剩余血量均一致时，ID靠前的一方获胜；
function Fight:PvPLostSide()
	local side = {
		[FightConfig.Side.Def]		= {},
		[FightConfig.Side.Attack]	= {},
	}

	local hp = {
		[FightConfig.Side.Def]		= 0,
		[FightConfig.Side.Attack]	= 0,
	}

	local id = {
		[FightConfig.Side.Def]		= 0,
		[FightConfig.Side.Attack]	= 0,
	}

	for i, entity in ipairs(self.playerorder) do
		table.insert(side[entity.side], entity)
		hp[entity.side] = hp[entity.side] + entity:GetHP()
		id[entity.side] = entity.ownerid
	end

	if #side[FightConfig.Side.Def] > #side[FightConfig.Side.Attack] then
		return FightConfig.Side.Attack
	elseif #side[FightConfig.Side.Def] < #side[FightConfig.Side.Attack] then
		return FightConfig.Side.Def
	end

	if hp[FightConfig.Side.Def] > hp[FightConfig.Side.Attack] then
		return FightConfig.Side.Attack
	elseif hp[FightConfig.Side.Def] < hp[FightConfig.Side.Attack] then
		return FightConfig.Side.Def
	end

	if id[FightConfig.Side.Def] > id[FightConfig.Side.Attack] then
		return FightConfig.Side.Def
	else
		return FightConfig.Side.Attack
	end
end

function Fight:OneTurn()
	if self.status == _FightStatus.Over then
		self:PrintDebug("self.status == _FightStatus.Over")
		return
	end
	self:SetMsgRound(self.round + 1)
	self:PrintDebug("Fight:OneTurn---------------------", self.round)
	AttackSort.SortBySpeed(self.playerorder)
	self:RunEntitys(_FightStatus.Start)
	self:TurnRunning()
	self:RunEntitys(_FightStatus.End)
	self:CheckOver()
end

function Fight:FightRunOver()
	while self.status ~= _FightStatus.Over do
		self:OneTurn()
	end
end

-- 全自动
function Fight:RunAll()
	self:PrintDebug("Fight:RunFight:RunFight:RunFight:RunFight:RunFight:Run")
	self:FightStart()
	self:FightRunOver()
end

function Fight:FightRunStep()
	if self.status == _FightStatus.Over then
		return
	end
	if self.manualtimer then
		lua_app.del_timer(self.manualtimer)
		self.manualtimer = nil
	end

	for _,v in pairs(self.playerlist) do
		v.waitmanual = false
	end
	self.actcount = 0
	self.msglist = {}
	self.msginsert = self.msglist
	self:SetMsgRound(self.round + 1)
	self:PrintDebug("Fight:FightRunStep", self.round)
	AttackSort.SortBySpeed(self.playerorder)
	self:RunEntitys(_FightStatus.Start)
	self:TurnRunning()
	self:RunEntitys(_FightStatus.End)
	self:CheckOver()

	self:BroadcastFighting()
	self:WaitClient()
end

-- 手动操作
function Fight:RunManually()
	self.manual = 1
	self.actcount = 0
	self:FightStart()
	self:DoManual()
end

function Fight:StartRunAll()
	self:CheckAndSetEntity()
	lua_app.run_after(0, function()
			if self.manuallymode then
				self:RunManually()
			else
				self:RunAll()
			end
		end)
end

function Fight:Over(loseside)
	self:PrintDebug("Fight:OverFight:OverFight:OverFight:OverFight:OverFight:Over", FightConfig.OtherSide[loseside])
	local retlist = {}
	for dbid, playerinfo in pairs(self.playerlist) do
		retlist[dbid] = playerinfo.side ~= loseside
		server.fightCenter:SetFight(dbid, nil)
	end
	self.raid:FightResult(retlist, self.round, self)
end

function Fight:GetPosHP(side, pos)
	local entity = self.posToEntity[side][pos]
	if entity then
		return entity:GetHP()
	end
	return 0
end

function Fight:GetHPs(side)
	local poshps = {}
	local entitys = self.posToEntity[side]
	for pos, entity in pairs(entitys) do
		poshps[pos] = entity:GetHP()
	end
	return poshps
end

function Fight:GetTotalHit(playerid)
	local playerinfo = self.playerlist[playerid]
	local hit = 0
	for _, edatas in pairs(playerinfo.entitydatas) do
		hit = hit + (edatas.hit or 0)
	end
	return hit
end

function Fight:SetMsgRound(round)
	self.round = round
	table.insert(self.msginsert, {
			type		= FightConfig.FightMsgType.Round,
			id 			= round,
		})
end

function Fight:AddMsg(type, id, src, msg, targets)
	msg = msg or {}
	msg.type = type
	msg.id = id
	msg.src = src
	if targets then
		local ar = {}
		for _, target in pairs(targets) do
			table.insert(ar, target.handler)
		end
		msg.targets = ar
	end
	table.insert(self.msginsert, msg)
end

function Fight:EnterMsg(type, id, src, msg, targets)
	msg = msg or {}
	self:AddMsg(type, id, src, msg, targets)
	msg.actions = {}
	table.insert(self.msglayer, self.msginsert)
	self.msginsert = msg.actions
end
function Fight:EnterMsgAdd(type, id, src, msg, targets)
	local upmsg = self.msginsert[#self.msginsert]
	upmsg.actions = {}
	table.insert(self.msglayer, self.msginsert)
	self.msginsert = upmsg.actions
	self:AddMsg(type, id, src, msg, targets)
end
function Fight:ExitMsg()
	self.msginsert = table.remove(self.msglayer)
end

function Fight:BroadcastFighting()
	-- table.ptable(self.msglist, 20)
	-- self:PrintDebug("++++++++++++++++++++++++++++++")
	self:Broadcast("sc_battle_action", { events = self.msglist })
end

function Fight:BroadcastManual()
	for dbid, player in pairs(self.playerlist) do
		local msg = {time = _WaitSkillTime, useskills = {}}
		for k,v in pairs(self.entitylist) do
			if (v.etype == EntityConfig.EntityType.Role or
				v.etype == EntityConfig.EntityType.Pet) and
			 	v.ownerid == dbid then
			 	local skills = v.skill:GetCanUseSkills()
				table.insert(msg.useskills, {handler = v.handler, skills = skills})
			end
		end
		server.sendReqByDBID(dbid, "sc_battle_manual", msg)
	end
end

function Fight:DoManual()
	for _, player in pairs(self.playerlist) do
		player.waitmanual = true
	end

	self:BroadcastManual()

	-- 设置定时器
	if self.manualtimer then
		lua_app.del_timer(self.manualtimer)
		self.manualtimer = nil
	end

	local function _RunStep()
		for dbid, player in pairs(self.playerlist) do
			if player.waitmanual then
				player.isauto = 1
				server.sendReqByDBID(dbid, "sc_battle_set_auto", {isauto = player.isauto})
			end
		end
		self:FightRunStep()
	end

	self.manualtimer = lua_app.add_timer(_WaitSkillTime * 1000, _RunStep)

	-- 如果有玩家未才操作则给他3秒时间
	local isundo = false
	for dbid, player in pairs(self.playerlist) do
		if not player.isclient then
			isundo = true
		else
			if player.isauto == 1 then
				self:FinishManual(dbid)
			end
		end
	end

	local function _WaitUndoPlayer()
		if self.waitautotimer then
			lua_app.del_timer(self.waitautotimer)
			self.waitautotimer = nil
		end
		for dbid, player in pairs(self.playerlist) do
			if not player.isclient and player.isauto == 1 then
				self:FinishManual(dbid)
			end
		end
	end

	if isundo then
		self.waitautotimer = lua_app.add_timer(_WaitAutoTime * 1000, _WaitUndoPlayer)
	end	
end

-- 等待客户端播放动画的时间
function Fight:WaitClient()
	for _, player in pairs(self.playerlist) do
		player.waitclient = true
	end

	if self.waittimer then
		lua_app.del_timer(self.waittimer)
		self.waittimer = nil
	end

	local function _WaitClientFinish()
		if self.waittimer then
			lua_app.del_timer(self.waittimer)
			self.waittimer = nil
		end

		local iswaiting = false
		for _,v in pairs(self.playerlist) do
			if v.waitclient then
				iswaiting = true
			end
			v.waitclient = false
		end

		if iswaiting then
			self:DoManual()
		end
	end

	self.waittimer = lua_app.add_timer(self.actcount * 1700, _WaitClientFinish)
end

function Fight:AddActCount()
	if self.actcount then
		self.actcount = self.actcount + 1
	end
end

function Fight:Broadcast(name, msg)
	table.insert(self.record, {name = name, msg = msg})
	if self.silence then return end
	for dbid, _ in pairs(self.playerlist) do
		server.sendReqByDBID(dbid, name, msg)
	end
end

function Fight:Release()
	self:PrintDebug("Fight:ReleaseFight:ReleaseFight:ReleaseFight:ReleaseFight:Release")
	for _, entity in pairs(self.entitylist) do
		entity:Release()
	end
	for _, entity in pairs(self.waitlist) do
		entity:Release()
	end
	self.entitylist = {}
	self.sidelist = {
		[FightConfig.Side.Def]	= {},
		[FightConfig.Side.Attack]	= {},
	}
	self.waitlist = {}
	self.sidewaitlist = {
		[FightConfig.Side.Def]	= {},
		[FightConfig.Side.Attack]	= {},
	}
	self.playerlist = {}
end

-- 刷新站位
function Fight:RefreshPos(index, edatas)
	if index then
		if edatas.etype == EntityConfig.EntityType.Role then
			if index == 1 then
				edatas.pos = 8
			elseif index == 2 then
				edatas.pos = 6
			elseif index == 3 then
				edatas.pos = 10
			elseif index == 4 then
				edatas.pos = 7
			elseif index == 5 then
				edatas.pos = 9
			end
		elseif edatas.etype == EntityConfig.EntityType.Pet then
			if index == 1 then
				edatas.pos = 3
			elseif index == 2 then
				edatas.pos = 1
			elseif index == 3 then
				edatas.pos = 5
			elseif index == 4 then
				edatas.pos = 2
			elseif index == 5 then
				edatas.pos = 4
			end
		end
	end
end

-- 手动释放技能
function Fight:ClientUseSkill(dbid, msg)
	if msg.use_skill_list then
		for _, v in ipairs(msg.use_skill_list) do
			local entity = self.entitylist[v.handler]
			if entity and entity.ownerid == dbid then
				entity:ClientUseSkill(v.skillid, v.targets or {})
				self:PrintDebug("Fight:ClientUseSkill >>>>>", v.handler, v.skillid)
			end
		end
		local player = self.playerlist[dbid]
		if player then
			player.isclient = true
		end
		self:FinishManual(dbid)
	end
end

function Fight:FinishManual(dbid)
	local player = self.playerlist[dbid]
	if player then
		player.waitmanual = false
	end

	local isstep = true
	for _,v in pairs(self.playerlist) do
		if v.waitmanual then
			isstep = false
		end
	end
	
	if isstep then
		self:FightRunStep()
	end
end

-- 客户端播放结束
function Fight:PlayFinish(dbid)
	local player = self.playerlist[dbid]

	if not player then return end
	if not player.waitclient then return end

	player.waitclient = false

	local isallfinish = true
	for _,v in pairs(self.playerlist) do
		if v.waitclient then
			isallfinish = false
		end
	end

	if isallfinish then
		self:DoManual()
	end
end

-- 设置自动或手动
function Fight:SetAuto(dbid, isauto, isclient)
	local player = self.playerlist[dbid]
	if not player then return end
	player.isauto = isauto
	player.isclient = isclient
	if isauto == 1 and self.manualtimer and isclient then
		self:FinishManual(dbid)
	end
end

-- 设置不广播数据
function Fight:SetSilence()
	self.silence = true
end

function Fight:PrintDebug( ... )
	return
	-- print(...)
end

server.NewFighting = server.NewFighting or function()
	return Fight.new()
end

return Fight