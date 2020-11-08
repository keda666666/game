local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local tbname = server.GetSqlName("wardatas")
local tbcolumn = "publicboss"

local PublicBoss = {}
local bosspos = 8
local killuser = 1

function PublicBoss:Init()
	self.type = server.raidConfig.type.PublicBoss
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.playerinfos = {}
	self.bosslist = self.cache.bosslist
	local PublicBossConfig = server.configCenter.PublicBossConfig
	for index, item in ipairs(PublicBossConfig) do
		local bossinfo = self.bosslist[index]
		if not bossinfo then
			bossinfo = {}
			bossinfo.killrecord = {}
			bossinfo.iskill = true
			bossinfo.reborntime = 0
			self.bosslist[index] = bossinfo
		end
		if bossinfo.iskill then
			local nowtime = lua_app.now()
			if nowtime >= bossinfo.reborntime then
				bossinfo.timer = nil
				self:RebornPublicBoss(index)
			else
				local intervaltime = bossinfo.reborntime - nowtime
				bossinfo.timer = lua_app.add_timer(intervaltime * 1000, function()
				bossinfo.timer = nil
				self:RebornPublicBoss(index)
				end)
			end	
		end
	end
	server.raidMgr:SetRaid(self.type, PublicBoss)
end

function PublicBoss:Release()
	if self.refurshtimer then
		lua_app.del_timer(self.refurshtimer)
		self.refurshtimer = nil
	end
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function PublicBoss:onInitClient(player)
	self:SendClientList(player.dbid)
end

function PublicBoss:RebornPublicBoss(bossindex, dbid)
	local bossinfo = self:GetBossInfo(bossindex)
	if not bossinfo or bossinfo.iskill == false then
		lua_app.log_info("PublicBoss:RebornPublicBoss bossinfo not exist or die. bossindex: ", bossindex)
		return
	end
	if bossinfo.timer then
		lua_app.del_timer(bossinfo.timer)
		bossinfo.timer = nil
	end
	bossinfo.attackinfos = {}
	bossinfo.fightnum = 0
	bossinfo.iskill = false
	local bosscfg = server.configCenter.PublicBossConfig[bossindex]
	local monsters = server.configCenter.InstanceConfig[bosscfg.fbid].initmonsters
	local bossid = 1
	for _, v in ipairs(monsters) do
		if v.pos == bosspos then
			bossid = v.monid
			break
		end
	end
	local monsterscfg = server.configCenter.Monsters2SConfig[bossid] or server.configCenter.MonstersConfig[bossid]
	bossinfo.bosshp = monsterscfg.hp
	bossinfo.bosshp_cur = monsterscfg.hp
	bossinfo.bosshp_pre = monsterscfg.hp
	self:SendClient(bossindex, true)
	if dbid ~= nil then
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		local reborncount = player.cache.publicboss.reborncount()
		player.cache.publicboss.reborncount = reborncount + 1
	end
end

function PublicBoss:SendClient(bossindex, reborn)
	local data = self:GetBossData(bossindex, reborn)
	server.broadcastReq("sc_public_boss_update_one", { bossInfo = data })
end

function PublicBoss:SendAttackinfos(dbid, bossindex)
	local bossinfo = self:GetBossInfo(bossindex)
	table.sort(bossinfo.attackinfos, function(userA, userB)
		return userA.injure > userB.injure
	end)
	local rank = 0
	local datas = {}
	for i, v in ipairs(bossinfo.attackinfos) do
		if i <= server.raidConfig.PublicBoss.AttackRecord then
			table.insert(datas, {name = v.name, injure = v.injure})
		end
		if dbid == v.dbid then
			rank = i
		end
	end
	server.sendReqByDBID(dbid, "sc_public_boss_record_attack", {
		attackinfos = datas,
		rank = rank,
		})
end

function PublicBoss:SendKillInfos(dbid, bossindex)
	local bossinfo = self.bosslist[bossindex]
	local datas = {}
	for i, v in ipairs(bossinfo.killrecord) do
		if i <= server.raidConfig.PublicBoss.KillRecord then
			table.insert(datas, { 
				name = v.name, 
				killtime = v.killtime,
				power = v.power})
		end
	end
	server.sendReqByDBID(dbid, "sc_public_boss_record_kill", {killinfos = datas})
end

function PublicBoss:GetBossInfo(bossindex)
	if not self.bosslist[bossindex] then
		lua_app.log_error("bossinfo not exist. bossindex:",bossindex)
		return false
	end
	return self.bosslist[bossindex]
end

function PublicBoss:UpdateAttackinfos(dbid, bossindex)
	local bossinfo = self:GetBossInfo(bossindex)
	table.sort(bossinfo.attackinfos, function(userA, userB)
		return userA.injure > userB.injure
	end)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local playerattack = {}
	playerattack.name = player.cache.name()
	playerattack.injure = 0
	local datas = {}
	for i, v in ipairs(bossinfo.attackinfos) do
		if i <= server.raidConfig.PublicBoss.AttackRecord then
			table.insert(datas, {name = v.name, injure = v.injure})
		end
		if dbid == v.dbid then
			playerattack.injure = v.injure
		end
	end
	server.sendReqByDBID(dbid, "sc_public_boss_update_attack", {
		attackinfos = datas,
		myattackinfo = playerattack,
		})
end

function PublicBoss:SendClientList(dbid)
	local datas = {}
	for index, item in ipairs(self.bosslist) do
		local bossdata = self:GetBossData(index)
		table.insert(datas, bossdata)
	end
	server.sendReqByDBID(dbid, "sc_public_boss_base_list", { bossInfos = datas})
end

function PublicBoss:GetBossData(bossindex, reborn)
	local data = {}
	local bossinfo = self:GetBossInfo(bossindex)
	data.id = bossindex
	data.hp = math.ceil(bossinfo.bosshp_cur / bossinfo.bosshp * 100)
	data.iskill = bossinfo.iskill
	data.reborntime = bossinfo.reborntime
	data.fightnum = bossinfo.fightnum
	data.reborn = reborn
	return data
end

function PublicBoss:Enter(dbid, datas)
	local index = datas.exinfo.index
	local PublicBossConfig = server.configCenter.PublicBossConfig[index]
	local bossinfo = self:GetBossInfo(index)
	local info = self.playerinfos[dbid]
	if not info then
		info = {}
		self.playerinfos[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("PublicBoss:Enter player is in fighting", dbid)
		return false
	end
	if bossinfo.iskill then
		lua_app.log_info("PublicBoss:Boss have been killed", bossinfo.iskill)
		return false
	end
	self:UpdateAttackinfos(dbid, index)
	local fighting = server.NewFighting()
	fighting:Init(PublicBossConfig.fbid, self, {[bosspos] = bossinfo.bosshp_cur})
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.eachrewards = info.eachrewards or server.dropCenter:DropGroup(PublicBossConfig.eachrewards)
	info.index = index
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function PublicBoss:IsSurvive(index)
	local boss = self:GetBossInfo(index)
	return boss and boss.iskill == false
end

function PublicBoss:Exit(dbid)
	return true
end

function PublicBoss:KillBoss(index)
	local bossinfo = self:GetBossInfo(index)
	bossinfo.iskill = true
end

function PublicBoss:FightResult(retlist, round)
	local PublicBossConfig = server.configCenter.PublicBossConfig
	for dbid, iswin in pairs(retlist) do
		local info = self.playerinfos[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		local bossinfo = self.bosslist[info.index]
		local bosscfg = PublicBossConfig[info.index]
		bossinfo.bosshp_cur = info.fighting:GetPosHP(FightConfig.Side.Def, bosspos)
		self:RecordAttacks(info.index, dbid)
		if iswin or bossinfo.bosshp_cur == 0 then
			print("fight is win. regist refresh and record info")
			self:RecordKill(info.index, dbid)
			self:GrantReward(info.index)
			local nowtime = lua_app.now()
			local intervaltime = bosscfg.resurrectiontime
			local reborntime = nowtime + intervaltime
			bossinfo.iskill = true
			bossinfo.reborntime = reborntime
			bossinfo.timer = lua_app.add_timer(intervaltime * 1000, function(__, index)
				self:RebornPublicBoss(index)
			end, info.index)
		end
		info.fighting = nil
		self:SendClient(info.index)
		local msg = {}
		msg.result = 1
		msg.rewards = info.eachrewards
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

--记录伤害
function PublicBoss:RecordAttacks(bossindex, dbid)
	local bossinfo = self:GetBossInfo(bossindex)
	local recordExist = false
	local recordIndex = 0
	for i, v in ipairs(bossinfo.attackinfos) do
		if v.dbid == dbid then
			recordExist = true
			recordIndex = i
			break
		end
	end
	if not recordExist then
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		local name = player.cache.name()
		table.insert(bossinfo.attackinfos, { dbid = dbid, name = name, injure = 0})
		bossinfo.fightnum = bossinfo.fightnum + 1
		recordIndex = #bossinfo.attackinfos
	end
	bossinfo.attackinfos[recordIndex].injure = bossinfo.attackinfos[recordIndex].injure + bossinfo.bosshp_pre - bossinfo.bosshp_cur
	bossinfo.bosshp_pre = bossinfo.bosshp_cur
end

--记录击杀
function PublicBoss:RecordKill(bossindex)
	local bossinfo = self:GetBossInfo(bossindex)
	local nowtime = lua_app.now()
	table.sort(bossinfo.attackinfos, function(userA, userB)
		return userA.injure > userB.injure
	end)
	local killdbid = bossinfo.attackinfos[killuser].dbid
	local player = server.playerCenter:DoGetPlayerByDBID(killdbid)
	local totalpower = player.cache.totalpower()
	local name = player.cache.name()
	table.insert(bossinfo.killrecord, 1, {dbid = killdbid, killtime = nowtime, name = name, power = totalpower})
	local killcount = #bossinfo.killrecord - server.raidConfig.PublicBoss.KillRecord
	if killcount > server.raidConfig.PublicBoss.KillMaxRecord then
		for i = 1, killcount do
			table.remove(bossinfo.killrecord)
		end
	end
end

--Boss挑战成功奖励
function PublicBoss:GrantReward(bossindex)
	local PublicBossItem = server.configCenter.PublicBossConfig[bossindex]
	local killrewards = server.dropCenter:DropGroup(PublicBossItem.dropId)
	local otherrewards = server.dropCenter:DropGroup(PublicBossItem.rewards)
	local bossinfo = self.bosslist[bossindex]
	for i, playerdata in ipairs(bossinfo.attackinfos) do
		if i == killuser then
			server.serverCenter:SendLocalMod("logic", "mailCenter", "SendMail", playerdata.dbid, PublicBossItem.mailTitle, PublicBossItem.mailContent, killrewards, server.baseConfig.YuanbaoRecordType.PublicBoss)
		else
			server.serverCenter:SendLocalMod("logic", "mailCenter", "SendMail", playerdata.dbid, PublicBossItem.mailTitle, PublicBossItem.othermailContent, otherrewards, server.baseConfig.YuanbaoRecordType.PublicBoss)
		end
	end
end

--Boss挑战奖励
function PublicBoss:GetReward(dbid)
	local info = self.playerinfos[dbid]
	local eachrewards = info.eachrewards
	if eachrewards then
		info.eachrewards = nil
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		player:GiveRewardAsFullMailDefault(eachrewards, "全民BOSS", server.baseConfig.YuanbaoRecordType.PublicBoss)
	end
end



server.SetCenter(PublicBoss, "PublicBossCenter")
return PublicBoss