local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local tbname = server.GetSqlName("wardatas")
local tbcolumn = "fieldboss"

local FieldBoss = {}
local bosspos = 8

function FieldBoss:Init()
	if server.serverCenter:IsCross() then return end
	self.type = server.raidConfig.type.FieldBoss
	self.playerinfos = {}
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	local nexthifehour = (os.hifehourEndTime() + 1 - lua_app.now()) * 1000
	self.bosslist = self.cache.bosslist
	self.deflist = {}
	for index, bossinfo in pairs(self.bosslist) do
		local owner = bossinfo.owner
		if not bossinfo.iskill and owner ~= 0 then
			bossinfo.iskill = true
			bossinfo.bosshp = 0
			bossinfo.ownerlefttime = nil
			lua_app.run_after(0, function()
					self:SendKillReward(index, owner)
				end)
		end
	end
	if lua_app.now() > self.cache.borntime + server.configCenter.FieldBossCommonConfig.intervaltime * 60 then
		self:RefreshFieldBoss()
	end
	server.raidMgr:SetRaid(self.type, FieldBoss)
	local intervaltime = server.configCenter.FieldBossCommonConfig.intervaltime * 60 * 1000
	local function _RunRefresh()
		self.refurshtimer = lua_app.add_timer(intervaltime, _RunRefresh)
		self:RefreshFieldBoss()
	end
	self.refurshtimer = lua_app.add_timer(nexthifehour, _RunRefresh)
end

function FieldBoss:Release()
	if self.refurshtimer then
		lua_app.del_timer(self.refurshtimer)
		self.refurshtimer = nil
	end
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function FieldBoss:IsAct()
	local hour = os.date("*t").hour
	local refreshtime = server.configCenter.FieldBossCommonConfig.refreshtime
	if refreshtime[2] >= 24 then
		if hour < refreshtime[1] and hour >= refreshtime[2] - 24 then
			return false
		end
	else
		if hour < refreshtime[1] or hour >= refreshtime[2] then
			return false
		end
	end
	return true
end

function FieldBoss:RefreshFieldBoss()
	for _, info in pairs(self.playerinfos) do
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
	end
	self.playerinfos = {}
	for _, definfo in pairs(self.deflist) do
		if definfo.timer then
			lua_app.del_timer(definfo.timer)
		end
	end
	self.deflist = {}
	if not self:IsAct() then
		return
	end
	self.bosslist = {}
	for _, cfg in pairs(server.configCenter.FieldBossConfig) do
		local monsters = server.configCenter.InstanceConfig[cfg.fbid].initmonsters
		local bossid = 1
		for _, v in ipairs(monsters) do
			if v.pos == bosspos then
				bossid = v.monid
				break
			end
		end
		self.bosslist[cfg.id] = {
			bossid = bossid,
			bosshp = server.configCenter.MonstersConfig[bossid].hp,
			owner = 0,
			challengers = {},
		}
	end
	self.cache.bosslist = self.bosslist
	self.cache.borntime = os.hifehourEndTime() - server.configCenter.FieldBossCommonConfig.intervaltime * 60
	server.serverCenter:SendLocalMod("logic", "chatCenter", "NoticeFb", self.type)
end

function FieldBoss:IsEsp()
	return lua_app.now() >= self.cache.borntime + server.configCenter.FieldBossCommonConfig.escapetime * 60
end

function FieldBoss:Enter(dbid, datas)
	if self:IsEsp() then
		lua_app.log_error("FieldBoss:Enter boss escaped", dbid)
		return false
	end
	local index = datas.exinfo.index
	local FieldBossConfig = server.configCenter.FieldBossConfig[index]
	local bossinfo = self.bosslist[index]
	if bossinfo.iskill then
		lua_app.log_error("FieldBoss:Enter boss is killed", dbid)
		return false
	end
	local info = self.playerinfos[dbid]
	if not info then
		info = {}
		self.playerinfos[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("FieldBoss:Enter player is in fighting", dbid)
		return false
	end
	if self.deflist[dbid] and self.deflist[dbid].index ~= index then
		local cfg = server.configCenter.FieldBossConfig[self.deflist[dbid].index]
		if cfg then
			cfg = server.configCenter.MonstersConfig[cfg.bossid]
			server.sendErrByDBID(dbid, "您已经拥有[" .. cfg.name .. "(" .. cfg.level .. "级)]的归属权，不能再挑战")
		end
		-- lua_app.log_info("FieldBoss:Enter 已有占领", dbid, index, self.deflist[dbid].index)
		return false
	end
	if not bossinfo.challengers[dbid] then
		bossinfo.challengers[dbid] = true
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		local needbossprops = FieldBossConfig.needbossprops
		if needbossprops and not player:PayReward(needbossprops.type, needbossprops.id, needbossprops.count, server.baseConfig.YuanbaoRecordType.FieldBoss, "FieldBoss:PK") then
			bossinfo.challengers[dbid] = nil
			lua_app.log_error("FieldBoss:Enter::no enough 门票", dbid)
			return false
		end
	end
	if not self.deflist[bossinfo.owner] then
		bossinfo.owner = 0
	end
	local fighting
	if bossinfo.owner == 0 or bossinfo.owner == dbid then
		if bossinfo.isinbossfighting and lua_app.now() < bossinfo.isinbossfighting + 30 then
			lua_app.log_error("FieldBoss: boss is in fighting", dbid)
			return false
		end
		bossinfo.isinbossfighting = lua_app.now()
		fighting = server.NewFighting()
		fighting:Init(FieldBossConfig.fbid, self, { [bosspos] = bossinfo.bosshp })
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
		info.fighttype = 0
	else
		if bossinfo.isinpkfighting and lua_app.now() < bossinfo.isinpkfighting + 30 then
			lua_app.log_error("FieldBoss: boss is in pkfighting", dbid)
			return false
		end
		bossinfo.isinpkfighting = lua_app.now()
		-- if not self.deflist[bossinfo.owner] then
		-- 	lua_app.log_error("FieldBoss:Enter player not exit", dbid)
		-- 	local ownplayer = server.playerCenter:GetPlayerByDBID(bossinfo.owner)
		-- 	self.deflist[bossinfo.owner] = { datas = ownplayer.server.dataPack:FightInfoByDBID(bossinfo.owner) }
		-- end
		fighting = server.NewFighting()
		fighting:Init(FieldBossConfig.pkfbid, self)
		fighting:AddPlayer(FightConfig.Side.Def, nil, self.deflist[bossinfo.owner].datas)
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
		info.fighttype = 1
	end
	info.datas = datas
	info.index = index
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function FieldBoss:Exit(dbid)
	-- local info = self.playerinfos[dbid]
	-- if info then
	-- 	if info.fighting then
	-- 		info.fighting:Release()
	-- 		info.fighting = nil
	-- 	end
	-- end
	return true
end

function FieldBoss:SendBossList(dbid)
	local datas = {}
	for index, _ in ipairs(self.bosslist) do
		table.insert(datas, self:PackOneBoss(index, dbid))
	end
	server.sendReqByDBID(dbid, "sc_field_boss_base_list", { bossInfos = datas })
end

function FieldBoss:PackOneBoss(index, dbid)
	local bossinfo = self.bosslist[index]
	return {
		id = index,
		hp = bossinfo.bosshp,
		status = bossinfo.bosshp == 0 and 3 or not self:IsAct() and 4 or self:IsEsp() and 2 or 1,
		ownerId = bossinfo.owner,
		ownerName = bossinfo.ownername,
		ownerSex = bossinfo.sex,
		ownerJob = bossinfo.job,
		time = bossinfo.ownerlefttime and bossinfo.ownerlefttime - lua_app.now(),
		ischallenge = bossinfo.challengers[dbid] and true,
	}
end

function FieldBoss:SendKillReward(index, dbid, iskilling)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if player then
		local FieldBossConfig = server.configCenter.FieldBossConfig[index]
		local rewards = server.dropCenter:DropGroup(FieldBossConfig.dropId)
		if iskilling then
			player:GiveRewardAsFullMailDefault(rewards, "野外BOSS", server.baseConfig.YuanbaoRecordType.FieldBoss)
		else
			local cfg = server.configCenter.FieldBossCommonConfig
			local bosscfg = server.configCenter.MonstersConfig[FieldBossConfig.bossid]
			player:SendMail(cfg.mailtitle, string.format(cfg.maildes, bosscfg.name .. "(" .. bosscfg.level .. "级)"),
				rewards, server.baseConfig.YuanbaoRecordType.FieldBoss)
		end
		return rewards
	end
end

function FieldBoss:KillBoss(index, iskilling)
	if self:IsEsp() then return end
	local bossinfo = self.bosslist[index]
	if bossinfo.iskill then return end
	bossinfo.iskill = true
	bossinfo.bosshp = 0
	bossinfo.ownerlefttime = nil
	local definfo = self.deflist[bossinfo.owner]
	if definfo and definfo.timer then
		lua_app.del_timer(definfo.timer)
		definfo.timer = nil
	end
	self.deflist[bossinfo.owner] = nil
	server.sendReqByDBID(bossinfo.owner, "sc_field_boss_update_one", { bossInfo = self:PackOneBoss(index, bossinfo.owner) })
	return self:SendKillReward(index, bossinfo.owner, iskilling)
end

function FieldBoss:FightResult(retlist, round)
	for dbid, iswin in pairs(retlist) do
		local info = self.playerinfos[dbid]
		info.fighting:BroadcastFighting()
		local index = info.index
		local bossinfo = self.bosslist[index]
		local msg = {}
		if info.fighttype == 0 then
			bossinfo.bosshp = info.fighting:GetPosHP(FightConfig.Side.Def, bosspos)
			if bossinfo.owner == 0 then
				bossinfo.owner = dbid
				bossinfo.ownername = info.datas.playerinfo.name
				bossinfo.sex = info.datas.exinfo.sex
				bossinfo.job = info.datas.exinfo.job
				self.deflist[dbid] = { datas = info.datas, index = index }
				if bossinfo.bosshp > 0 then
					local lefttime = server.configCenter.FieldBossCommonConfig.gettime*60
					bossinfo.ownerlefttime = lua_app.now() + lefttime
					self.deflist[dbid].timer = lua_app.add_timer(lefttime*1000, function()
							self:KillBoss(index)
						end)
				end
			end
			if bossinfo.bosshp <= 0 then
				msg.result = 1
				msg.rewards = self:KillBoss(index, true)
			else
				msg.result = 2
			end
			bossinfo.isinbossfighting = nil
		elseif info.fighttype == 1 then
			if iswin then
				if self.deflist[bossinfo.owner] and self.deflist[bossinfo.owner].timer then
					lua_app.del_timer(self.deflist[bossinfo.owner].timer)
					self.deflist[bossinfo.owner] = nil
				end
				bossinfo.owner = dbid
				bossinfo.ownername = info.datas.playerinfo.name
				bossinfo.sex = info.datas.exinfo.sex
				bossinfo.job = info.datas.exinfo.job
				self.deflist[dbid] = { datas = info.datas, index = index }
				local lefttime = server.configCenter.FieldBossCommonConfig.gettime*60
				bossinfo.ownerlefttime = lua_app.now() + lefttime
				self.deflist[dbid].timer = lua_app.add_timer(lefttime*1000, function()
						self:KillBoss(index)
					end)
				msg.result = 1
			else
				msg.result = 0
			end
			bossinfo.isinpkfighting = nil
		end
		info.fighting:Release()
		info.fighting = nil
		info.fighttype = nil
		self.playerinfos[dbid] = nil
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function FieldBoss:GetReward(dbid)
end

server.SetCenter(FieldBoss, "fieldBoss")
return FieldBoss