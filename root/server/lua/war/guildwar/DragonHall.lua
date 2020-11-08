local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local BaseBarrier = require "guildwar.BaseBarrier"
local GuildwarConfig = require "resource.GuildwarConfig"

local DragonHall = oo.class(BaseBarrier)

function DragonHall:ctor(barrierId, guildwarMap)
end

function DragonHall:Release()
end

function DragonHall:Init()
	self.guards = {}
	self.monsterhps = {}
	self.maxhp = 0
	self.currhp = 0
	self.resist = 0			--已经抵御的玩家数
	self.holdtime = 0 	--时长
	local GuildBattleSlongDingConfig = server.configCenter.GuildBattleSlongDingConfig
	self.fblv = self:GetFbLevel(GuildBattleSlongDingConfig)

	self.fbid = GuildBattleSlongDingConfig[self.fblv].fbid
	local instancecfg = server.configCenter.InstanceConfig[self.fbid]
	for _, monsterinfo in pairs(instancecfg.initmonsters) do
		local monconfig = server.configCenter.MonstersConfig[monsterinfo.monid]
		self.maxhp = self.maxhp + monconfig.hp
	end
	self.currhp = self.maxhp
	self:RegisteFunc(GuildwarConfig.Datakeys[self.barrierId])
end

function _WrapKey(srckey)
	return string.format("dragonhall_%s", srckey)
end

function DragonHall:EnterHook(dbid)
	local playerdata = self:GetPlayerData(dbid)
	local recordkey = _WrapKey(playerdata.guildid)
	self.playerCtrl:RegisteEffectKey(recordkey, 1)
	self:UpdateGuild(playerdata.guildid, {
			[recordkey] = 1
		})
end

--离开
function DragonHall:LeaveHook(dbid)
	local playerdata = self:GetPlayerData(dbid)
	self:UpdateGuild(playerdata.guildid, {
			[_WrapKey(playerdata.guildid)] = - 1
		})
end

function DragonHall:SendEnterMsg(dbid)
	self:SendGuildRankDataMsg(dbid, "scoreRank")
	self:SendPlayerRankDataMsg(dbid, "killRank")
	self:SendGuildDataMsg(dbid)
	self:SendGuardInfo(dbid)
	self:SendReqByInside(dbid, "sc_guildwar_ultimate_attack", {
			countdown = self.countdown,
		})
end

--产生空排行
function DragonHall:GendefaultData(dbid)
	self:UpdatePlayer(dbid, {
			dragonhall_holdtracks = 0
		})
end

--每秒定时器
function DragonHall:DoSecond(now)
	--关卡需是开启状态
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	if self.countdown and self.countdown == now then
		self.guildwarMap:Notice(GuildBattleBaseConfig.startime)
	end

	if not self.opening then return end
	for _, data in ipairs(self.guards) do
		local increasetime = now - data.begintime >= GuildBattleBaseConfig.l_occupytime
		if increasetime then
			self:UpdatePlayer(data.playerinfo.dbid, {
				score = GuildBattleBaseConfig.l_occupypoints,
			})
			data.begintime = now
		end
	end

	self.pointime = self.pointime or now + GuildBattleBaseConfig.l_pointime
	if now >= self.pointime then
		for dbid, inside in pairs(self.playerlist) do
			if inside then
				self:UpdatePlayer(dbid, {
						score = GuildBattleBaseConfig.l_points
					})
			end
		end
		self.pointime = now + GuildBattleBaseConfig.l_pointime 
	end

	if self.holdtracks then
		self.holdtracks = self.holdtracks + 1
		if self.holdtracks >= GuildBattleBaseConfig.adendtime then
			return self.guildwarMap:EarlyShut()
		end
	end
end

--设置战斗开启时间
function DragonHall:SetFightStarttime(time)
	self.countdown = time
end

--攻击检测
function DragonHall:CanAttack(dbid, bossid)
	if not BaseBarrier.CanAttack(self, dbid) then
		return false
	end

	local now = lua_app.now()
	local countdown = self.countdown or math.huge
	if countdown > now then
		return false
	end

	if next(self.guards) then
		local dbidlist = {dbid}
		for __, guard in ipairs(self.guards) do
			table.insert(dbidlist, guard.playerinfo.dbid)
		end

		if self.guildwarMap:CheckGuildmember(dbidlist) then
			return false
		end
	end

	return true
end

--战斗结果
function DragonHall:AttackResult(iswin, dbid, attackers, poshps)
	local lasthp = self.currhp
	if not next(self.guards) then
		-- 没有守卫
		self.currhp = 0
		for pos, hp in pairs(poshps) do
			self.monsterhps[pos] = hp
			self.currhp = self.currhp + hp
		end
	else
		-- 玩家守卫
		self.currhp = 0
		for _, guard in ipairs(self.guards) do
			local live = {}
			for _, data in ipairs(guard.entitydatas) do
				self.currhp = self.currhp + data.hp
				if data.hp > 0 then
					table.insert(live, data)
				end
			end
			guard.entitydatas = live
		end
	end

	if self.currhp <= 0 then
		self.holdtracks = 0
		self:Occupy(attackers)
	else
		for _, playerdata in ipairs(attackers) do
			self.guildwarMap:Reborn(playerdata.playerinfo.dbid)
		end
	end

	self:SendGuardInfo()
	print("DragonHall:AttackResult-----------", self.currhp.."/"..self.maxhp)
end

--补充帮会信息
function DragonHall:AppendGuildMsgData(data, guildinfo)
	data.rankData = {
		score = guildinfo.score,
		scoreRank = guildinfo.scoreRank,
	}
end

--替换守护
function DragonHall:Occupy(attackers)
	-- 守城者踢回出生点
	for __, guarddata in ipairs(self.guards) do
		self.guildwarMap:Reborn(guarddata.playerinfo.dbid)
	end

	self.maxhp = 0
	self.currhp = 0
	self.resist = 0	
	self.holdtime = lua_app.now() 
	--更新守护者
	self.guards = {}
	local attackername = {}
	for __, attacker in pairs(attackers) do
		local attackerid = attacker.playerinfo.dbid
		local player = server.playerCenter:GetPlayerByDBID(attackerid)
		if player then
			local datas = player.server.dataPack:SimpleFightInfoByDBID(attackerid)
			self:AddGuard(datas)
		end
		table.insert(attackername, attacker.playerinfo.name)
	end
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.guildwarMap:Notice(GuildBattleBaseConfig.occupyNotice, string.format("[%s]", table.concat(attackername, "],[")))
end

--添加守护
function DragonHall:AddGuard(datas)
	local dbid = datas.playerinfo.dbid
	if #self.guards == 0 then
		self.maxhp = 0
		self.currhp = 0
	end

	if #self.guards >= 3 then
		print("KingCity:Guard guards has enough")
		return
	end

	for __, guarddata in ipairs(self.guards) do
		if guarddata.playerinfo.dbid == dbid then
			print("KingCity:Guard you has been in the guards")
			return
		end
	end

	-- 设置同步血量
	datas.synchp = true
	datas.begintime = lua_app.now()
	table.insert(self.guards, datas)
	local entityhp = datas.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
	local addhp = #datas.entitydatas * entityhp

	self.maxhp = self.maxhp + addhp
	self.currhp = self.currhp + addhp

	server.teamCenter:Leave(dbid)
	print("DragonHall:AddGuard.......",dbid)
end

--发送守护信息
function DragonHall:SendGuardInfo(dbid)
	local data = {
		guardtype = 0,
		holdtime = self.holdtime,
		resistNum = self.resist,
		hp = math.ceil(self.currhp / self.maxhp * 100),
	}
	if next(self.guards) then
		data.guardtype = 1
		data.guardinfos = {}
		for __, guarddata in ipairs(self.guards) do
			local playerdata = self:GetPlayerData(guarddata.playerinfo.dbid)
			table.insert(data.guardinfos, {
					name = playerdata.playerinfo.name,
					job = playerdata.playerinfo.job,
					sex = playerdata.playerinfo.sex,
					serverId = playerdata.serverid,
					guildName = playerdata.playerinfo.guildName,
				})
			data.ownerGuildId = data.ownerGuildId or playerdata.guildid
		end
	end
	if not dbid then
		self:Broadcast("sc_guildwar_guard_info", data)
	else
		self:SendReqByInside(dbid, "sc_guildwar_guard_info", data)
	end
end

function DragonHall:Shut()
	BaseBarrier.Shut(self)
	self:SetTriumph()
end

function DragonHall:SetTriumph()
	local rankdatas = table.wcopy(self:GetGuildRankdata("scoreRank"))
	local triumphGuild = rankdatas[1]
	local triumphGuildid = false
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	if triumphGuild then
		for __, serverid in ipairs(self.guildwarMap.servers) do
			server.serverCenter:SendOneMod("logic", serverid, "noticeCenter", "Notice",GuildBattleBaseConfig.openNotice, triumphGuild.guildname)
		end
		triumphGuildid = triumphGuild.guildid
		self.warReport:AddShareData({
				victory = triumphGuild.guildname,
				serverid = triumphGuild.serverid,
			})
	else
		for __, serverid in ipairs(self.guildwarMap.servers) do
			server.serverCenter:SendOneMod("logic", serverid, "noticeCenter", "Notice", GuildBattleBaseConfig.noOccupationNotice)
		end
	end

	for rank, guilddata in ipairs(rankdatas) do
		self.warReport:AddGuildData(guilddata.guildid, {
				rank = rank,
			})
	end
	self.guildwarMap:SetWinerGuild(triumphGuildid)
	self:DropAuction(rankdatas)
end

function DragonHall:DropAuction(rankdatas)
	local GuildBattleAuctionConfig = server.configCenter.GuildBattleAuctionConfig
	for rank, guilddata in ipairs(rankdatas) do
		local GuildAuctionCfg = GuildBattleAuctionConfig[rank]
		if not GuildAuctionCfg then break end

		local guildmembers = guilddata[_WrapKey(guilddata.guildid)] or 0
		local rewardCfg = table.matchValue(GuildAuctionCfg, function(data)
			return guildmembers - data.num[1]
		end)
		if rewardCfg then
			local rewardtime = math.random(rewardCfg.rewardtime[1], (rewardCfg.rewardtime[2] or rewardCfg.rewardtime[1]))
			for i = 1, rewardtime do
				local rewards = server.dropCenter:DropGroup(rewardCfg.reward)
				local __, aucitem = next(rewards)
				if aucitem then
					server.serverCenter:SendOneMod("logic", guilddata.serverid, "auctionMgr", "ShelfLocal", 0, aucitem.id, aucitem.count, guilddata.guildid)
					self.warReport:AddAuctionRewards(guilddata.guildid, aucitem)
				end
			end
		end
		server.serverCenter:SendOneMod("logic", guilddata.serverid, "chatCenter", "ChatLink", 39)
	end
end

return DragonHall

