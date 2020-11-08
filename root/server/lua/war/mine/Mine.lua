local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"

-- 跨服矿脉
local Mine = oo.class()
local _TypeByMineId = {1, 2, 2, 2, 2, 3, 3, 3, 3, 0}
local _MineStatus = {
		Monster = 1,
		Guard = 2,
		Monsterfighting = 3,
		Guardfighting = 4,
		Guardfighted = 5,	
	}
local _NewOccupy = function(dbid, name)
	return {
		guildid = dbid,
		guildname = name,
		increaseScoreTime = lua_app.now(),
		specialoccupy = {},
	}
end

function Mine:ctor(mountain, id)
	self.mountain = mountain
	self.mineId = id
	self.mineType = _TypeByMineId[(id - 1) % 10 + 1]
	self.guards = {}		--防守的玩家
	self.monsterhps = {}
	self.gathers = {}
	self.status = _MineStatus.Monster
	self.occupydata = _NewOccupy(0)

	local GuildDiggingConfig = server.configCenter.GuildDiggingConfig
	local fbId = GuildDiggingConfig[self.mineType].fbid
	local instancecfg = server.configCenter.InstanceConfig[fbId]
	self.maxhp = 0
	self.currhp = 0
	for _, monsterinfo in pairs(instancecfg.initmonsters) do
		local monconfig = server.configCenter.MonstersConfig[monsterinfo.monid]
		self.maxhp = self.maxhp + monconfig.hp
	end
	self.currhp = self.maxhp
	self.fbId = fbId
	self.limitGathernum = GuildDiggingConfig[self.mineType].limit
end

function Mine:Init()
end

function Mine:Release()
end

--攻击检测
function Mine:CanAttack(dbid)
	if not self.mountain:IsExistPlayer(dbid) then
		lua_app.log_info(">> mountain not exist dbid. ", dbid)
		return false
	end
	if not self.mountain:CheckAttackCd(dbid) then 
		lua_app.log_info(">> mountain attack cd. ", dbid)
		return false 
	end
	if self.status == _MineStatus.Monsterfighting or self.status == _MineStatus.Guardfighting then
		lua_app.log_info(">>This mine status is fighting.")
		return false
	end
	local playerdata = self.mountain:GetPlayerdata(dbid)
	return (playerdata.guildId ~= self.occupydata.guildid)
end

function Mine:SetAttackCd(dbids)
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	for __, playerId in ipairs(dbids) do
		 self.mountain:UpdatePlayerStatus(playerId, {
		 		attackTime = lua_app.now() + GuildDiggingBaseConfig.cd
		 	})
	end
end

--攻击
function Mine:Attack(dbid)
	local can, datas, idlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		lua_app.log_info("Mine Attack player not is teamleader.", dbid)
		return false
	end
	for __, id in ipairs(idlist) do
		if not self:CanAttack(id) then
			lua_app.log_info("Mine Attack have player attack wait cd.", id)
			return false
		end
	end

	local GuildDiggingConfig = server.configCenter.GuildDiggingConfig[self.mineType]
	if next(self.guards) then
		if GuildDiggingConfig.ispk == 0 then
			return false
		end
	end
	self:SetFightMark(true)
	datas.exinfo = {
		mine = self,
	}
	server.raidMgr:Enter(server.raidConfig.type.GuildMine, dbid, datas, idlist)
	return true
end

--战斗结果
function Mine:AttackResult(dbids, poshps)
	--添加参与记录
	for _, dbid in ipairs(dbids) do
		self.mountain:AddInvolvementRecord(dbid)
	end

	if self.limitGathernum == 0 then
		return self:AttackResultOfSpecial(dbids)
	end

	if not next(self.guards) then
		-- 没有守卫
		self.currhp = 0
		for pos, hp in pairs(poshps) do
			self.monsterhps[pos] = hp
			self.currhp = self.currhp + hp
		end
		if self.currhp <= 0 then
			-- 攻陷原始怪物守卫者 此玩家取而代之成为守卫
			self:Occupy(dbids)
		else
			self:SetAttackCd(dbids)
		end
	else
		-- 玩家守卫
		self.currhp = 0
		for _, guard in ipairs(self.guards) do
			local remove = {}
			for i, data in ipairs(guard.entitydatas) do
				self.currhp = self.currhp + data.hp
				if data.hp == 0 then
					table.insert(remove, i)
				end
			end

			table.sort(remove, function(a, b)
				return a > b
			end)

			for _, del in ipairs(remove) do
				table.remove(guard.entitydatas, del)
			end
		end
		if self.currhp <= 0 then
			self:Occupy(dbids)
		else
			self:SetAttackCd(dbids)
		end
	end
	print("Mine:AttackResult-----------", self.currhp.."/"..self.maxhp)
end

--设置战斗
function Mine:SetFightMark(fight)
	if fight then
		if self.fighttimer then
			lua_app.del_timer(self.fighttimer)
		end
		self.fighttimer = lua_app.add_timer(50000, function()
			self.fighttimer = nil
			self:SetFightMark()
		end)
	else
		if self.fighttimer then
			lua_app.del_timer(self.fighttimer)
			self.fighttimer = nil
		end
	end

	if next(self.guards) == nil then
		self.status = fight and _MineStatus.Monsterfighting or _MineStatus.Monster
	elseif self.occupymark then
		self.occupymark = nil
		self.status = _MineStatus.Guard
	else
		self.status = fight and _MineStatus.Guardfighting or _MineStatus.Guardfighted
	end
	self.mountain:BroadcastMountainInfo(self.mineId)
end

--占领铁矿
function Mine:AttackResultOfSpecial(dbids)
	local playerdata = self.mountain:GetPlayerdata(dbids[1])
	local specialoccupy = self.occupydata.specialoccupy[playerdata.guildId]
	if not specialoccupy then
		specialoccupy = {
			referencecount = 0,
			increaseScoreTime = lua_app.now(),
		}
		self.occupydata.specialoccupy[playerdata.guildId] = specialoccupy
	end
	specialoccupy.referencecount = specialoccupy.referencecount + #dbids
	for __, dbid in ipairs(dbids) do
		self:JoinGather(dbid)
	end
end

--加入判断
function Mine:CanJoin(dbid)
	if not self.mountain:IsExistPlayer(dbid) then
		return false
	end

	local playerdata = self.mountain:GetPlayerdata(dbid)
	if playerdata.guildId ~= self.occupydata.guildid then
		return false
	end

	if self.status ~= _MineStatus.Guard then
		return false
	end

	if #self.guards >= self.limitGathernum then
		return false
	end
	return true
end

--加入
function Mine:JoinGuard(dbid)
	--只有队长才能申请加入
	local can , datas, idlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		return false
	end
	if (#idlist + #self.guards) > self.limitGathernum then
		return false
	end
	for _, playerId in ipairs(idlist) do
		if not self:CanJoin(playerId) then
			return false
		end
	end
	--加入
	for __, playerId in ipairs(idlist) do
		local player = server.playerCenter:GetPlayerByDBID(playerId)
		local datas = player.server.dataPack:SimpleFightInfoByDBID(playerId)
		self:Guard(datas)
	end
	self.mountain:BroadcastMountainInfo(self.mineId)
	return true
end

--退出守护
function Mine:LeaveGuard(dbid, reserveTeam)
	local remove = #self.guards + 1
	for i, guarddata in pairs(self.guards) do
		if guarddata.playerinfo.dbid == dbid then
			remove = i
			break
		end
	end
	table.remove(self.guards, remove)
	--如果守护为空，还原
	if next(self.guards) == nil and self.limitGathernum ~= 0 then
		self.mountain:RemoveGuildMine(self.occupydata.guildid, self.mineId)
		self.monsterhps = {}
		self.status = _MineStatus.Monster
		self.occupydata = _NewOccupy(0)
	end

	self:LeaveGather(dbid)
	if not reserveTeam then
		server.teamCenter:Leave(dbid)
	end
	self.mountain:BroadcastMountainInfo(self.mineId)
end

--占据通知
local _NoticeMine = setmetatable({}, {__index = function() return function() end end })

_NoticeMine[1] = function(self, names)
	for __,serverid in ipairs(self.mountain.servers) do
		server.serverCenter:SendOneMod("logic", serverid, "noticeCenter", "Notice", 26, names, "金矿")
	end
end

_NoticeMine[2] = function(self, names)
	for __, serverid in ipairs(self.mountain.servers) do
		server.serverCenter:SendOneMod("logic", serverid, "noticeCenter", "Notice", 26, names, "银矿")
	end
end

--清除之前玩家记录
function Mine:ClearLastoccupy(dbids)
	local playerdata = self.mountain:GetPlayerdata(dbids[1])
	local attackerinfo = {
		name = playerdata.playerinfo.name,
		level = playerdata.playerinfo.level,
		serverId = playerdata.serverId,
	}
	self.mountain:RemoveGuildMine(self.occupydata.guildid, self.mineId)
	for __, data in ipairs(self.guards) do
		self:LeaveGather(data.playerinfo.dbid)
		server.sendReqByDBID(data.playerinfo.dbid, "sc_guildmine_rob_info", attackerinfo)
	end
end

--占据
function Mine:Occupy(dbids)
	self:ClearLastoccupy(dbids)

	self.guards = {}
	self.gathers = {}
	self.occupymark = true
	local occupynames = {}
	local firstplayer = true
	for _, dbid in ipairs(dbids) do
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if firstplayer then
			local playerdata = self.mountain:GetPlayerdata(dbid)
			self.occupydata = _NewOccupy(playerdata.guildId, playerdata.playerinfo.guildname)
			self.mountain:AddGuildMine(playerdata.guildId, self.mineId)
			firstplayer = false
		end
		local datas = player.server.dataPack:SimpleFightInfoByDBID(dbid)
		self:Guard(datas)
		table.insert(occupynames, datas.playerinfo.name)
		print("Mine:Occupy-----------", dbid, self.currhp.."/"..self.maxhp)
	end
	--广播更新矿脉信息
	_NoticeMine[self.mineType](self, string.format("[%s]", table.concat(occupynames, "] [")))
	self.mountain:BroadcastMountainInfo(self.mineId)
end

--替换守护数据
function Mine:Guard(datas)
	if #self.guards == 0 then
		self.maxhp = 0
		self.currhp = 0
	end

	if #self.guards >= 3 then
		print("Mine:Guard guards has enough")
		return
	end

	for _, guarddata in ipairs(self.guards) do
		if guarddata.playerinfo.dbid == datas.playerinfo.dbid then
			print("Mine:Guard you has been in the guards")
			return
		end
	end

	-- 设置同步血量
	datas.synchp = true
	table.insert(self.guards, datas)

	local entityhp = datas.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
	local addhp = #datas.entitydatas * entityhp

	self.maxhp = self.maxhp + addhp
	self.currhp = self.currhp + addhp
	--离开处理
	self.mountain:LeaveMine(datas.playerinfo.dbid, true)
	self:JoinGather(datas.playerinfo.dbid)
end

--积分增加
function Mine:IncreaseSorce(now)
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local obtainTime = now - GuildDiggingBaseConfig.needtime
	if self.limitGathernum ~= 0 then
		if self.occupydata.guildid ~= 0 and self.occupydata.increaseScoreTime < obtainTime then
			self.occupydata.increaseScoreTime = now
			self.mountain:UpdateGuildSorce(self.occupydata.guildid, self.mineType)
		end
	else
		for guildid, data in pairs(self.occupydata.specialoccupy) do
			if data.increaseScoreTime < obtainTime then
				data.increaseScoreTime = now
				self.mountain:UpdateGuildSorce(guildid, self.mineType)
			end
		end
	end
end

--定时给开采奖励
function Mine:GiveGatherRewards(now)
	local GuildDiggingConfig = server.configCenter.GuildDiggingConfig
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	
	for dbid, gatherdata in pairs(self.gathers) do
		if gatherdata.obtainTime < now then
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			local rewards = {
				 	table.wcopy(GuildDiggingConfig[self.mineType].reward),
				}
			player:GiveRewardAsFullMailDefault(rewards, "矿山争夺", server.baseConfig.YuanbaoRecordType.GuildMine)
			gatherdata.obtainTime = now + GuildDiggingBaseConfig.needtime
			self.mountain:UpdatePlayerStatus(dbid, {
					gatherTime = gatherdata.obtainTime,
				})
		end
	end
end

--加入开采
function Mine:JoinGather(dbid)
	local GuildDiggingBaseConfig = server.configCenter.GuildDiggingBaseConfig
	local interval = GuildDiggingBaseConfig.needtime
	local nowtime = lua_app.now()
	local playerdata = self.mountain:GetPlayerdata(dbid)
	local data = {
		obtainTime = nowtime + interval,
		name = playerdata.playerinfo.name,
		dbid = dbid,
	}
	self.gathers[dbid] = data
	self.mountain:UpdatePlayerStatus(dbid, {
			gatherTime = data.obtainTime,
			status = 1,
			mineId = self.mineId,
		})
	self.mountain:AddInvolvementRecord(dbid)
end

--离开开采
function Mine:LeaveGather(dbid)
	if self.gathers[dbid] then
		self.gathers[dbid] = nil
		self.mountain:UpdatePlayerStatus(dbid, {
			gatherTime = 0,
			status = 2,
			mineId = 0,
		})
	end
	--铁矿处理
	if self.mineType == 0 then
		local playerdata = self.mountain:GetPlayerdata(dbid)
		local specialoccupy = self.occupydata[playerdata.guildId]
		if specialoccupy then
			specialoccupy.referencecount = specialoccupy.referencecount - 1
			if specialoccupy.referencecount <= 0 then
				self.occupydata[playerdata.guildId] = nil
			end
		end
	end
end

function Mine:GetMsgData()
	local datas = {
		mineId = self.mineId,
		status = self.status,
	}
	datas.guard = {}
	datas.guildName = self.occupydata.guildname
	for _, data in ipairs(self.guards) do
		local maxhp = data.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
		local currhp = 0
		for _, v in ipairs(data.entitydatas) do
			if v.pos == 8 then
				currhp = v.hp or data.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
				break
			end
		end
		table.insert(datas.guard, {
				name = data.playerinfo.name,
				level = data.playerinfo.level,
				power = data.playerinfo.power,
				job = data.playerinfo.job,
				sex = data.playerinfo.sex,
				hp = math.floor(currhp / maxhp * 100),
			})
	end
	return datas
end

return Mine