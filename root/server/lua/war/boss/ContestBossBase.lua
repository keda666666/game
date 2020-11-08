local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local WarReport = require "warReport.WarReport"
local FightConfig = require "resource.FightConfig"
local EntityConfig = require "resource.EntityConfig"

local ContestBossBase = {}

local _OpenLastTime = false
local function _GetOpenLastTime(self)
	if _OpenLastTime then return _OpenLastTime end
	local opentime = self.baseConfig.ContestBaseConfig.opentime
	local openHour, openMin, openSec = string.match(opentime[1], "(%d+):(%d+):(%d+)")
	local closeHour, closeMin, closeSec = string.match(opentime[2], "(%d+):(%d+):(%d+)")
	openHour, openMin, openSec, closeHour, closeMin, closeSec = tonumber(openHour), tonumber(openMin), tonumber(openSec), tonumber(closeHour), tonumber(closeMin), tonumber(closeSec)
	local _OpenLastTime = (closeHour - openHour)*3600 + (closeMin - openMin)*60 + closeSec - openSec
	return _OpenLastTime
end

local _sortPoints = {}
local function _GetSortPoint(points)
	if _sortPoints[points] then return _sortPoints[points] end
	local sortp = {{},{}}
	for i = 1, 2 do
		if points[1][i] <= points[2][i] then
			sortp[1][i] = points[1][i]
			sortp[2][i] = points[2][i]
		else
			sortp[1][i] = points[2][i]
			sortp[2][i] = points[1][i]
		end
	end
	_sortPoints[points] = sortp
	return sortp
end

function ContestBossBase:HotFix()
	print("ContestBossBase:HotFix-----")
	table.ptable(self.servers, 3)
end

function ContestBossBase:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ContestBossBase:Init()
	self.type = 0
	self:Load()
end

function ContestBossBase:Load()
	self.baseConfig = setmetatable({}, {__index = function(cfgname)
		return self:GetConfig(cfgname)
	end})
	self.playerinfos = {}
	self.relivetimers = {}
	self.servers = false
	self.status = 0
	server.raidMgr:SetRaid(self.type, self)
	local ContestBossConfig = self.baseConfig.ContestBaseConfig
	self.checkTimer = lua_timer.add_timer_day(ContestBossConfig.opentime[1], -1, self.CheckOpen, self)
	self.warReport = WarReport.new(self:DecorateSproto("sc_contestboss_report"))
end

function ContestBossBase:Release()
	if self.status ~= 0 then
		self:Close()
	end
	if self.checkTimer then
		lua_timer.del_timer_day(self.checkTimer)
		self.checkTimer = nil
	end
end

function ContestBossBase:onInitClient(player)
	if self.servers and self.servers[player.nowserverid] then
		player:sendReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })
	end
end

function ContestBossBase:onLeaveMap(playerid, mapid)
	if mapid == self.baseConfig.ContestBaseConfig.mapid then
		self:CollectCancel(playerid)
	end
end

function ContestBossBase:CheckOpen()
	print("ContestBossBase:CheckOpen-------------")
	self:BeforeOpen()
end

function ContestBossBase:BeforeOpen()
	self.servers = false
	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	self:SendLogicsMod("noticeCenter", "Notice", ContestBaseConfig.readynotice)
	if self.readyopentimer then
		lua_app.del_local_timer(self.readyopentimer)
		self.readyopentimer = nil
	end
	self.readyopentimer = lua_app.add_update_timer(ContestBaseConfig.starttime*1000, self, "Open")
end

function ContestBossBase:Open()
	if self.readyopentimer then
		lua_app.del_local_timer(self.readyopentimer)
		self.readyopentimer = nil
	end
	if self.status ~= 0 then return end
	lua_app.log_info("================ ContestBossBase:Open")
	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	self:SendLogicsMod("noticeCenter", "Notice", ContestBaseConfig.opennotice)
	self.status = 1
	self.statuschangetime = lua_app.now()
	self.uid = 0
	self.tmpplayerdatas = {}
	self.bossReadyTimer = lua_app.add_update_timer(ContestBaseConfig.readytime*1000, self, "BossEnter")
	self.closeTimer = lua_app.add_update_timer(_GetOpenLastTime(self)*1000, self, "Close")
	self:BroadcastReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })
	self.warReport:Reset(self:DecorateSproto("sc_contestboss_report"))
end

function ContestBossBase:BossEnter()
	if self.status == 0 then return end
	lua_app.log_info("================ ContestBossBase:BossEnter")
	self.damagelist = {}
	self.status = 2
	self.statuschangetime = lua_app.now()
	if self.bossReadyTimer then
		lua_app.del_local_timer(self.bossReadyTimer)
		self.bossReadyTimer = nil
	end
	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	local thp = 0
	self:GenFbid()
	local fbid = self.fbid or ContestBaseConfig.fbid
	local InstanceConfig = server.configCenter.InstanceConfig[fbid]
	for _, v in pairs(InstanceConfig.initmonsters) do
		local MonstersConfig = server.configCenter.MonstersConfig[v.monid]
		thp = thp + MonstersConfig.hp
	end
	self.totalhp = thp
	self.bossinfo = {
		shieldvalue		= ContestBaseConfig.shieldvalue,
		hp				= thp,
		hpperc			= 100,
	}
	self.boxlist = {}
	self.collectlist = {}
	self:BroadcastReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })
	self.shielddecTimer = lua_app.add_update_timer(ContestBaseConfig.losstime*1000, self, "ShieldDecTime")
	self:BroadcastTime()
	self:BossEnterHook()
end

function ContestBossBase:BossEnterHook()
end

function ContestBossBase:Close()
	if self.closeTimer then
		lua_app.del_local_timer(self.closeTimer)
		self.closeTimer = nil
	end
	if self.readyopentimer then
		lua_app.del_local_timer(self.readyopentimer)
		self.readyopentimer = nil
	end
	if self.status == 0 then return end
	lua_app.log_info("================ ContestBossBase:Close")
	self.status = 0
	self.statuschangetime = lua_app.now()
	self:BroadcastReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })
	self.tmpplayerdatas = nil
	if self.bossReadyTimer then
		lua_app.del_local_timer(self.bossReadyTimer)
		self.bossReadyTimer = nil
	end
	if self.broadcastTimer then
		lua_app.del_local_timer(self.broadcastTimer)
		self.broadcastTimer = nil
	end
	if self.shielddecTimer then
		lua_app.del_local_timer(self.shielddecTimer)
		self.shielddecTimer = nil
	end
	if self.shieldrecoverTimer then
		lua_app.del_local_timer(self.shieldrecoverTimer)
		self.shieldrecoverTimer = nil
	end
	if self.endTimer then
		lua_app.del_local_timer(self.endTimer)
		self.endTimer = nil
	end
	for _, timer in pairs(self.relivetimers) do
		lua_app.del_local_timer(timer)
	end
	self.relivetimers = {}

	self.playerinfos = {}
	server.mapCenter:Clear(self.baseConfig.ContestBaseConfig.mapid)
	self:SendLogicsMod(self:GetBossCenterDescribe(), "Close")
	self.servers = false
	self:CloseHook()
end

function ContestBossBase:CloseHook()
	
end

function ContestBossBase:BossDead(killerid)
	if self.status == 0 then return end
	lua_app.log_info("================ ContestBossBase:BossDead", killerid)
	self.status = 3
	self.statuschangetime = lua_app.now()
	self:BroadcastReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })

	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	local leavetime = ContestBaseConfig.leavetime*1000
	if leavetime > 0 then
		self.endTimer = lua_app.add_update_timer(leavetime, self, "Close")
	end

	if self.broadcastTimer then
		lua_app.del_local_timer(self.broadcastTimer)
		self.broadcastTimer = nil
	end

	self.needbroadcast = true
	self:BroadcastBossInfo()
	self:BroadcastRanks()
	if self.shielddecTimer then
		lua_app.del_local_timer(self.shielddecTimer)
		self.shielddecTimer = nil
	end
	if self.shieldrecoverTimer then
		lua_app.del_local_timer(self.shieldrecoverTimer)
		self.shieldrecoverTimer = nil
	end
	-- 排行榜
	local maxdamage, first = 0, false
	local ranks = {}
	local sortranks = {}
	for dbid, v in pairs(self.damagelist) do
		local info = self.playerinfos[dbid]
		ranks[dbid] = {
			dbid = dbid,
			name = info.name,
			serverid = info.serverid,
			job = info.job,
			sex = info.sex,
			guildid = info.guildid,
			guildname = info.guildname,
			damage = v.damage,
		}
		if maxdamage < v.damage then
			maxdamage = v.damage
			first = dbid
		end
		table.insert(sortranks, {
				dbid = dbid,
				damage = v.damage,
			})
	end
	self:SendLogicsMod(self:GetBossCenterDescribe(), "SetRanks", ranks)
	self.first = self.playerinfos[first] or { name = "" }
	self.first.iswin = 2

	local killer = server.playerCenter:GetPlayerByDBID(killerid)
	local killrewards = server.dropCenter:DropGroup(ContestBaseConfig.killboss)
	killer.server.mailCenter:SendMail(killerid, ContestBaseConfig.mailtitle4, ContestBaseConfig.maildes4,
		killrewards, self:GetYunbaoRecordType())

	table.sort(sortranks, function(priordata, laterdate)
		return priordata.damage > laterdate.damage
	end)
	for rank, rankdata in ipairs(sortranks) do
		self.warReport:AddPersonData(rankdata.dbid, {
				rank = rank,
			})
	end
	self.warReport:AddRewards(killerid, killrewards)
	self.warReport:AddShareData({
			victory = self.first.guildname,
			first = self.first.name,
			sex = self.first.sex,
			job = self.first.job,
			serverid = self.first.serverid,
		})

	self:BossDeadHook()
	self:SendLogicsMod("noticeCenter", "Notice", ContestBaseConfig.skillnotice, killer.name)
	self:SendLogicsMod("chatCenter", "ChatLink", ContestBaseConfig.auctionotice)
	
	self:SendRankRewards()
	self:DoAuction()
end

function ContestBossBase:BossDeadHook()
end

function ContestBossBase:SendRankRewards()
	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	local winrewards = server.dropCenter:DropGroup(ContestBaseConfig.winreward)
	local inrewards = server.dropCenter:DropGroup(ContestBaseConfig.inreward)
	local firstguildid = self.first.guildid
	local sendplayers = {}
	for dbid, info in pairs(self.playerinfos) do
		info.iswin = info.guildid == firstguildid and 1 or 0
		if info.iswin == 1 then
			info.rewards = winrewards
		else
			info.rewards = inrewards
		end
		sendplayers[dbid] = { serverid = info.serverid, iswin = info.iswin, }
	end
	self:SendLogicsMod(self:GetBossCenterDescribe(), "SendShowRewards", winrewards, inrewards, sendplayers)

	local cfg = self.baseConfig.ContestBaseConfig
	for dbid, info in pairs(self.playerinfos) do
		if info.rewards then
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			if info.iswin == 2 then
				player.server.mailCenter:SendMail(dbid, cfg.mailtitle, cfg.maildes, info.rewards, self:GetYunbaoRecordType())
			elseif info.iswin == 1 then
				local maildes = string.format(cfg.maildes1, self.first.name, self.first.name)
				player.server.mailCenter:SendMail(dbid, cfg.mailtitle1, maildes, info.rewards, self:GetYunbaoRecordType())
			else
				player.server.mailCenter:SendMail(dbid, cfg.mailtitle2, cfg.maildes2, info.rewards, self:GetYunbaoRecordType())
			end
			self.warReport:AddRewards(dbid, info.rewards)
			info.rewards = nil
		end
	end
end

-- 拍卖行掉落
function ContestBossBase:DoAuction()
	local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
	self:SendLogicsMod(self:GetBossCenterDescribe(), "DoAuction", self.first.guildid, map:Players())
end

function ContestBossBase:ShieldDecTime()
	self:ShieldDec(self.baseConfig.ContestBaseConfig.autoloss)
	if not self.bossinfo or self.bossinfo.shieldvalue <= 0 then
		self.shielddecTimer = nil
		return
	end
	self.shielddecTimer = lua_app.add_update_timer(self.baseConfig.ContestBaseConfig.losstime*1000, self, "ShieldDecTime")
end

function ContestBossBase:ShieldDec(value, attackerid)
	self.needbroadcast = true
	if not self.bossinfo or self.bossinfo.shieldvalue <= 0 then return end
	self.bossinfo.shieldvalue = self.bossinfo.shieldvalue - value
	if self.bossinfo.shieldvalue <= 0 then
		lua_app.log_info("================ ContestBossBase:ShieldDec <= 0")
		self.bossinfo.shieldvalue = 0
		if self.shielddecTimer then
			lua_app.del_local_timer(self.shielddecTimer)
			self.shielddecTimer = nil
		end
		self:BroadcastBossInfo()
		local ContestBaseConfig = self.baseConfig.ContestBaseConfig
		local map = server.mapCenter:GetMap(ContestBaseConfig.mapid)
		local boxbron = _GetSortPoint(ContestBaseConfig.boxbron)
		self.boxlist = {}
		for i = 1, map:Count() + math.random(ContestBaseConfig.boxvalue[1], ContestBaseConfig.boxvalue[2]) do
			self.uid = self.uid + 1
			self.boxlist[self.uid] = {
					id = self.uid,
					x = math.random(boxbron[1][1], boxbron[2][1]),
					y = math.random(boxbron[1][2], boxbron[2][2]),
				}
		end
		self:SendBoxList()
		self.shieldrecoverTimer = lua_app.add_update_timer(ContestBaseConfig.shieldtime*1000, self, "ShieldRecover")
		if attackerid then
			local attacker = server.playerCenter:GetPlayerByDBID(attackerid)
			local shieldrewards = server.dropCenter:DropGroup(ContestBaseConfig.killshield)
			attacker.server.mailCenter:SendMail(attackerid, ContestBaseConfig.mailtitle3, ContestBaseConfig.maildes3,
				shieldrewards, self:GetYunbaoRecordType())
			self.warReport:AddRewards(attackerid, shieldrewards)
			self:SendLogicsMod("noticeCenter", "Notice", ContestBaseConfig.hudunnotice, attacker.name)
		else
			self:SendLogicsMod("noticeCenter", "Notice", ContestBaseConfig.hudunnotice_2)
		end
	end
end

function ContestBossBase:ShieldRecover()
	self.shieldrecoverTimer = nil
	self.bossinfo.shieldvalue = self.baseConfig.ContestBaseConfig.shieldvalue
	if self.shielddecTimer then
		lua_app.del_local_timer(self.shielddecTimer)
	end
	self.shielddecTimer = lua_app.add_update_timer(self.baseConfig.ContestBaseConfig.losstime*1000, self, "ShieldDecTime")
end

function ContestBossBase:BroadcastTime()
	self.broadcastTimer = lua_app.add_update_timer(2000, self, "BroadcastTime")
	self:BroadcastBossInfo()
	self:BroadcastRanks()
end

function ContestBossBase:BroadcastBossInfo()
	if self.needbroadcast and self.bossinfo then
		self.needbroadcast = nil
		local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
		server.broadcastList(self:DecorateSproto("sc_contestboss_update_info"), self.bossinfo, map.playerlist)
	end
end

function ContestBossBase:BroadcastRanks()
	local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
	local sendlist = {}
	for dbid, _ in pairs(map.playerlist) do
		sendlist[dbid] = self.playerinfos[dbid].serverid
	end
	self:SendLogicsMod(self:GetBossCenterDescribe(), "SendRanks", self.damagelist, sendlist)
end

function ContestBossBase:SendBoxList(dbid)
	if not self.boxlist or not next(self.boxlist) then return end
	local boxinfos = {}
	for _, box in pairs(self.boxlist) do
		table.insert(boxinfos, box)
	end
	if dbid then
		server.sendReqByDBID(dbid, self:DecorateSproto("sc_contestboss_box_all"), { boxinfos = boxinfos })
	else
		local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
		server.broadcastList(self:DecorateSproto("sc_contestboss_box_all"), { boxinfos = boxinfos }, map.playerlist)
	end
end

function ContestBossBase:SendCollectList(dbid)
	if not self.collectlist or not next(self.collectlist) then return end
	local collectlists = {}
	for _, collectinfo in pairs(self.collectlist) do
		table.insert(collectlists, collectinfo)
	end
	local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
	server.broadcastList(self:DecorateSproto("sc_contestboss_collect_all"), { infos = collectlists }, map.playerlist)
end

function ContestBossBase:Join(dbid, playerinfo)
	if self.status == 0 then return false end
	local cfg = self.baseConfig.ContestBaseConfig
	self.playerinfos[dbid] = self.playerinfos[dbid] or playerinfo
	playerinfo = self.playerinfos[dbid]
	local playbron = _GetSortPoint(cfg.playbron)
	server.mapCenter:Enter(dbid, cfg.mapid, math.random(playbron[1][1], playbron[2][1]),
		math.random(playbron[1][2], playbron[2][2]), self:IsDead(dbid) and server.mapConfig.status.Dead or server.mapConfig.status.Act)
	if self.bossinfo then
		server.sendReqByDBID(dbid, self:DecorateSproto("sc_contestboss_update_info"), self.bossinfo)
	end
	self:SendBoxList(dbid)
	self:SendCollectList(dbid)
	if playerinfo.deadtime then
		server.sendReqByDBID(dbid, self:DecorateSproto("sc_contestboss_player_dead"), { deadtime = playerinfo.deadtime })
	end
	self.warReport:AddPlayer(dbid)
end

function ContestBossBase:CollectStart(dbid, boxid)
	local info = self.playerinfos[dbid]
	if info and self.boxlist[boxid] then
		local ContestBaseConfig = self.baseConfig.ContestBaseConfig
		info.collectid = boxid
		info.collecttime = lua_app.now() + ContestBaseConfig.coltime
		if info.collecttimer then
			lua_app.del_timer(info.collecttimer)
		end
		info.collecttimer = lua_app.add_timer(ContestBaseConfig.coltime*1000, function(id)
				if not self.playerinfos[dbid] or id ~= self.playerinfos[dbid].collecttimer then return end
				self:CollectEnd(dbid)
			end)
		self.collectlist[dbid] = {
			playerid 		= dbid,
			boxid			= boxid,
			time 			= info.collecttime,
		}
		local map = server.mapCenter:GetMap(ContestBaseConfig.mapid)
		server.broadcastList(self:DecorateSproto("sc_contestboss_collect_now"), { info = self.collectlist[dbid] }, map.playerlist)
	end
end

function ContestBossBase:CollectCancel(dbid)
	if not self.collectlist then return end
	local info = self.playerinfos[dbid]
	if info and info.collectid then
		if info.collecttimer then
			lua_app.del_timer(info.collecttimer)
			info.collecttimer = nil
		end
		info.collectid = nil
		info.collecttime = nil
	end
	local collectinfo = self.collectlist[dbid]
	if collectinfo then
		collectinfo.time = nil
		local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
		server.broadcastList(self:DecorateSproto("sc_contestboss_collect_now"), { info = collectinfo }, map.playerlist)
		self.collectlist[dbid] = nil
	end
end

function ContestBossBase:CollectEnd(dbid)
	local info = self.playerinfos[dbid]
	if info and info.collectid then
		if info.collecttimer then
			lua_app.del_timer(info.collecttimer)
			info.collecttimer = nil
		end
		local cfg = self.baseConfig.ContestBaseConfig
		if lua_app.now() >= info.collecttime then
			if self.boxlist[info.collectid] and not self:IsDead(dbid) then
				self.boxlist[info.collectid] = nil
				local player = server.playerCenter:GetPlayerByDBID(dbid)
				local rewards = server.dropCenter:DropGroup(cfg.boxreward[math.random(1, #cfg.boxreward)])
				player:GiveRewardAsFullMailDefault(rewards, "跨服Boss", self:GetYunbaoRecordType())
				local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
				server.broadcastList(self:DecorateSproto("sc_contestboss_box_one"), { boxinfo = { id = info.collectid } }, map.playerlist)
			end
			info.collectid = nil
			info.collecttime = nil
		else
			return
		end
	end
	local collectinfo = self.collectlist[dbid]
	if collectinfo then
		collectinfo.time = nil
		local map = server.mapCenter:GetMap(self.baseConfig.ContestBaseConfig.mapid)
		server.broadcastList(self:DecorateSproto("sc_contestboss_collect_now"), { info = collectinfo }, map.playerlist)
		self.collectlist[dbid] = nil
	end
end

function ContestBossBase:IsDead(dbid)
	local info = self.playerinfos[dbid]
	return info.deadtime and lua_app.now() < info.deadtime + self.baseConfig.ContestBaseConfig.revivecd
end

function ContestBossBase:BuyRelive(dbid)
	if not self:IsDead(dbid) then return end
	local info = self.playerinfos[dbid]
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local revivecost = self.baseConfig.ContestBaseConfig.revivecost
	if not player:PayReward(revivecost.type, revivecost.id, revivecost.count, self:GetYunbaoRecordType(), "ContestBossBase:BuyRelive") then
		server.sendErr(player, "元宝不足，无法复活")
		return
	end
	if self.relivetimers[dbid] then
		lua_app.del_local_timer(self.relivetimers[dbid])
		self.relivetimers[dbid] = nil
	end
	self:Relive(nil, dbid)
end

function ContestBossBase:Relive(id, dbid)
	local info = self.playerinfos[dbid]
	if not info then return end
	info.deadtime = nil
	server.sendReqByDBID(dbid, self:DecorateSproto("sc_contestboss_player_dead"))
	server.mapCenter:SetStatus(dbid, server.mapConfig.status.Act)
end

function ContestBossBase:GetReward(dbid)
	local info = self.playerinfos[dbid]
	if not info or not info.rewards then return false end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	player:GiveRewardAsFullMailDefault(info.rewards, "跨服Boss", self:GetYunbaoRecordType())
	return true
end

function ContestBossBase:GetPlayerDatas(dbid)
	local datas = self.tmpplayerdatas[dbid]
	if datas then return datas end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	datas = player.server.dataPack:FightInfoByDBID(dbid)
	datas.synchp = true
	if not datas then
		lua_app.log_error("ContestBossBase:GetPlayerDatas no player id", dbid)
		return false
	end
	self.tmpplayerdatas[dbid] = datas
	return datas
end

function ContestBossBase:Enter(dbid, datas)
	local info = self.playerinfos[dbid]
	if not info or self:IsDead(dbid) then
		lua_app.log_error("boss dead.", dbid, info)
		return false
	end
	if info.infighting then
		lua_app.log_error("player infighting.", dbid)
		return
	end
	local challengeid = datas.exinfo.challengeid
	-- local player = server.playerCenter:GetPlayerByDBID(dbid)
	local ContestBaseConfig = self.baseConfig.ContestBaseConfig
	if challengeid then
		local mdatas = self:GetPlayerDatas(dbid)
		if not mdatas then return false end
		local cinfo = self.playerinfos[challengeid]
		if not cinfo or self:IsDead(challengeid) or not server.mapCenter:InMap(challengeid, ContestBaseConfig.mapid) then
			lua_app.log_error("challengeid error", challengeid)
			return false
		end
		if info.guildid == 0 or info.guildid == cinfo.guildid then
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			server.sendErr(player, "不能挑战同帮会玩家")
			return false
		end
		local targetdatas = self:GetPlayerDatas(challengeid)
		if not targetdatas then return false end
		local fighting = server.NewFighting()
		fighting:InitPvP(ContestBaseConfig.pkfbid, self)
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, mdatas)
		fighting:AddPlayer(FightConfig.Side.Def, challengeid, targetdatas)
		info.fighting = fighting
		cinfo.infighting = true
		info.fighttype = 1
		cinfo.fighttype = 1
		server.mapCenter:SetStatus(challengeid, server.mapConfig.status.Fighting)
		fighting:StartRunAll()
	else
		if not self.bossinfo or self.bossinfo.hp <= 0 or self.bossinfighting and lua_app.now() <= self.bossinfighting + 10 then
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			server.sendErr(player, "Boss已死亡")
			return false
		end
		self.bossinfighting = lua_app.now()
		local fighting = server.NewFighting()
		local fbid = self.fbid or ContestBaseConfig.fbid
		fighting:Init(fbid, self, self.bossinfo.hps, nil, nil, self.bossinfo.shieldvalue > 0 and {
			[0] = { [EntityConfig.Attr.atDamageReductionPerc] = ContestBaseConfig.reductionvalue * 100},
		})
		self.tmpplayerdatas[dbid] = datas
		datas.synchp = true
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
		info.fighting = fighting
		info.fighttype = 0
		fighting:StartRunAll()
	end
	server.mapCenter:SetStatus(dbid, server.mapConfig.status.Fighting)
	return true
end

function ContestBossBase:Exit(dbid)
	return true
end

function ContestBossBase:GenFbid()

end

function ContestBossBase:FightResult(retlist, round, fighting)
	local cfg = self.baseConfig.ContestBaseConfig
	fighting:BroadcastFighting()
	for dbid, iswin in pairs(retlist) do
		local info = self.playerinfos[dbid]
		if info.fighting then
			if info.fighttype == 0 then
				self.bossinfighting = nil
				self:ShieldDec(cfg.attackloss, dbid)
				local hps = info.fighting:GetHPs(FightConfig.Side.Def)
				local thp = 0
				for i = 1, 10 do
					hps[i] = hps[i] or 0
					thp = thp + hps[i]
				end
				self.bossinfo.hps = hps
				self.bossinfo.hp = thp
				local oldhpperc = self.bossinfo.hpperc or 1
				self.bossinfo.hpperc = math.ceil(thp/self.totalhp*100)
				if thp <= 0 then
					lua_app.log_info("ContestBossBase:FightResult:: boss hp <= 0", dbid, iswin)
				elseif oldhpperc > 10 and self.bossinfo.hpperc <= 10 then
					local killer = server.playerCenter:GetPlayerByDBID(dbid)
					self:SendLogicsMod("noticeCenter", "Notice", cfg.powernotice_10)
				end
				if not self.damagelist[dbid] then
					self.damagelist[dbid] = {
						dbid 			= dbid,
						name			= info.name,
						serverid		= info.serverid,
						job				= info.job,
						sex				= info.sex,
						damage			= 0,
					}
				end
				self.damagelist[dbid].damage = self.damagelist[dbid].damage + info.fighting:GetTotalHit(dbid)
			end
		end
		info.infighting = nil
		info.fighting = nil
		local msg = {}
		if iswin then
			server.mapCenter:SetStatus(dbid, server.mapConfig.status.Act)
			if info.fighttype == 0 then
				self:BossDead(dbid)
			end
			msg.result = 1
		else
			info.deadtime = lua_app.now()
			server.sendReqByDBID(dbid, self:DecorateSproto("sc_contestboss_player_dead"), { deadtime = info.deadtime })
			if self.relivetimers[dbid] then
				lua_app.del_local_timer(self.relivetimers[dbid])
				self.relivetimers[dbid] = nil
			end
			local playbron = _GetSortPoint(cfg.playbron)
			server.mapCenter:Fly(cfg.mapid, dbid, math.random(playbron[1][1],
				playbron[2][1]), math.random(playbron[1][2], playbron[2][2]), true)
			server.mapCenter:SetStatus(dbid, server.mapConfig.status.Dead)
			self.relivetimers[dbid] = lua_app.add_update_timer(cfg.revivecd*1000, self, "Relive", dbid)
			self.tmpplayerdatas[dbid] = nil
			msg.result = 0
		end
		server.sendReqByDBID(dbid, self:DecorateSproto("sc_raid_chapter_boss_result"), msg)
		info.fighttype = nil
	end
	fighting:Release()
end

function ContestBossBase:DecorateSproto(name)
	return (string.gsub(name, "contestboss", self:GetSprotoDescribe()))
end

function ContestBossBase:SendLogicsMod(...)
	for __, serverid in pairs(self:GetServer()) do
		server.serverCenter:SendOneMod("logic", serverid, ...)
	end
end

function ContestBossBase:BroadcastReq(name, param)
	for __, serverid in pairs(self:GetServer()) do
		server.serverCenter:SendOne("logic", serverid, "rbc_online", name, param)
	end
end

function ContestBossBase:GetServer()
	if not self.servers then
		self.servers = {}
		local serverlist = server.serverCenter:CallLogicsMod(self:GetBossCenterDescribe(), "ServerInfo")
		for serverid, serverinfo in pairs(serverlist) do
			if server.serverCenter:IsCross() then
				if serverinfo.opencode == 2 then 
					self.servers[serverid] = serverid
				end
			else
				if serverinfo.opencode == 1 then
					self.servers[0] = 0
				end
			end
		end
	end
	return self.servers
end

--------------------------override--------------------------------------
function ContestBossBase:GetYunbaoRecordType()
	assert(false, "ContestBossBase:GetYunbaoRecordType() necessary override.")
end

function ContestBossBase:GetConfig(cfgname)
	assert(false, "ContestBossBase:GetConfig() necessary override.")
end

function ContestBossBase:GetSprotoDescribe()
	assert(false, "ContestBossBase:GetSprotoDescribe() necessary override.")
end

function ContestBossBase:GetBossCenterDescribe()
	assert(false, "ContestBossBase:GetBossCenterDescribe() necessary override.")
end

---------------------------test-----------------------------------------------
function ContestBossBase:TestOpen()
	if not self.servers then
		self.servers = {[0] = 0}
		local serverlist = server.serverCenter:CallLogicsMod(self:GetBossCenterDescribe(), "ServerInfo")
		for serverid, serverinfo in pairs(serverlist) do
			if server.serverCenter:IsCross() then
				self.servers[serverid] = serverid
			end
		end
		table.ptable(serverlist, 3)
	end
	self:Open()
end

function ContestBossBase:TestPrint()
	print("----------------------------------------------------")
	table.ptable(self.warReport, 3)
	print(self.status)
end


return ContestBossBase