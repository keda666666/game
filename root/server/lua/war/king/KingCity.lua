local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local KingConfig = require "resource.KingConfig"
local _MainCity = 0

-- 跨服争霸边城和主城
local KingCity = oo.class()

function KingCity:ctor(camp, map)
	self.map = map
	self.camp = camp 		--初始阵营 0是主城
	self.occupycamp = camp 	--占领的阵营
end

function KingCity:Init()
	local now = lua_app.now()
	self.guards = {}		--防守的玩家
	self.monsterhps = {}
	self.maxhp = 0
	self.currhp = 0
	self.attackrecord = {}	--攻城记录
	self.resist = 0			--已经抵御的玩家数
	self.camppointtimer = nil	--积分定时器
	self.guardpointtimer = {}	--守卫者积分定时器
	self.occupytime = now
	self.dropbloodtime = now
	self.config = nil

	local KingCityConfig = server.configCenter.KingCityConfig[self.camp + 1]
	for lv, v in pairs(KingCityConfig) do
		self.config = self.config or v
		if self.map.lv <= lv then
			self.config = v
			break
		end
	end
	self.fbid = self.config.fbid
	local instancecfg = server.configCenter.InstanceConfig[self.fbid]
	for _, monsterinfo in pairs(instancecfg.initmonsters) do
		local monconfig = server.configCenter.MonstersConfig[monsterinfo.monid]
		self.maxhp = math.max(self.maxhp + monconfig.hp, 0)
	end
	self.currhp = self.maxhp
	self:StartCampPointTimer()

	self.dropbloodtime = lua_app.now()
end

function KingCity:Release()
	self:End()
end

function KingCity:End()
	local now = lua_app.now()
	self:StopGuardPointTimer()
	if self.camppointtimer then
		lua_app.del_timer(self.camppointtimer)
		self.camppointtimer = nil
	end
	self.guards = {}		--防守的玩家
	self.monsterhps = {}
	self.maxhp = 0
	self.currhp = 0
	self.attackrecord = {}	--攻城记录
	self.resist = 0			--已经抵御的玩家数
	self.camppointtimer = nil	--积分定时器
	self.guardpointtimer = {}	--守卫者积分定时器
	self.occupytime = now
	self.dropbloodtime = now
	self.config = nil
end

function KingCity:Attack(dbid, datas, ids)
	if self.occupycamp == datas.exinfo.attackercamp then 
		print("KingCity:Attack same occupy camp")
		return false
	end

	datas.exinfo.kingcity = self
	datas.exinfo.fbid = self.fbid
	local retraid = server.raidMgr:Enter(server.raidConfig.type.KingCity, dbid, datas, ids)
	if retraid == server.raidConfig.type.KingCity then
		self.map:BroadcastFightingChange()
		return true
	end
end

function KingCity:AttackResult(iswin, dbid, attackercamp, attackers, poshps)
	local kill = 0
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
			if #live == 0 then
				if not guard.dead then
					guard.dead = true
					kill = kill + 1
				end
			end
		end
	end
	self.currhp = math.max(self.currhp, 0)

	self.resist = self.resist + #attackers
	self:RecordAttack(attackers, attackercamp, math.max(lasthp - self.currhp, 0))

	local KingBaseConfig = server.configCenter.KingBaseConfig
	local winpoint = KingBaseConfig.winpoints
	local lostpoint = KingBaseConfig.losepoints
	if self.currhp <= 0 then
		-- 攻陷 此队伍取而代之成为守卫
		self:Occupy(attackercamp, attackers)

		local msg = {iswin = true, commonpoint = winpoint, camp = self.camp}
		for _, attacker in pairs(attackers) do
			local dbid = attacker.playerinfo.dbid
			local kingcamp = self.map:GetPlayerCamp(dbid)
			if kingcamp then
				kingcamp:AddCommonPoint(dbid, winpoint)
			end
			server.sendReqByDBID(dbid, "sc_king_attack_result", msg)
			self.map:AddSeriesKill(dbid, kill)
		end
	end

	-- 打输了踢回出生点
	if not iswin then
		local msg = {iswin = false, commonpoint = lostpoint, camp = self.camp}
		for _, attacker in pairs(attackers) do
			local dbid = attacker.playerinfo.dbid
			local kingcamp = self.map:GetPlayerCamp(dbid)
			if kingcamp then
				kingcamp:DeadKick(dbid)
				kingcamp:AddCommonPoint(dbid, lostpoint)
			end
			server.sendReqByDBID(dbid, "sc_king_attack_result", msg)
		end

		for _, guard in ipairs(self.guards) do
			self.map:AddSeriesKill(guard.playerinfo.dbid, #attackers)
		end
	end
	self.map:BroadcastCityUpdate()
	print("KingCity:AttackResult-----------", self.camp, self.occupycamp, self.currhp.."/"..self.maxhp)
end

function KingCity:RecordAttack(attackers, attackercamp, changhp)
	local names = {}
	for _, attacker in pairs(attackers) do
		table.insert(names, attacker.playerinfo.name)
	end
	table.insert(self.attackrecord, {camp = attackercamp, changhp = changhp, names = names, time = lua_app.now()})
end

function KingCity:Occupy(attackercamp, attackers)
	-- 守城者踢回出生点
	for _, guarddata in ipairs(self.guards) do
		local guardid = guarddata.playerinfo.dbid
		self:StopOneGuardPointTimer(guardid)
		local kingcamp = self.map:GetPlayerCamp(guardid)
		if kingcamp then
			kingcamp:DeadKick(guardid)
		end
	end
	self:StopGuardPointTimer()

	local now = lua_app.now()
	self.attackrecord = {}
	self.occupycamp = attackercamp
	self.guards = {}
	self.maxhp = 0
	self.currhp = 0
	self.resist = 0
	self.occupytime = now
	self.dropbloodtime = now
	local attackername
	for _, attacker in pairs(attackers) do
		local attackerid = attacker.playerinfo.dbid
		if not attackername then 
			attackername = attacker.playerinfo.name
		else
			attackername = attackername .. " " .. attacker.playerinfo.name
		end
		local player = server.playerCenter:GetPlayerByDBID(attackerid)
		if player then
			local datas = player.server.dataPack:SimpleFightInfoByDBID(attackerid)
			self:AddOneGuard(datas)
		end
	end
	self:StartCampPointTimer()

	local KingBaseConfig = server.configCenter.KingBaseConfig
	if _MainCity == self.camp then
		self.map:BroadcastNotice(KingBaseConfig.z_cityNotice, attackername)
	elseif KingConfig.camp.Human == self.camp then
		self.map:BroadcastNotice(KingBaseConfig.z_rcityNotice, attackername)
	elseif KingConfig.camp.God == self.camp then
		self.map:BroadcastNotice(KingBaseConfig.z_xcityNotice, attackername)
	elseif KingConfig.camp.Devil == self.camp then
		self.map:BroadcastNotice(KingBaseConfig.z_mcityNotice, attackername)
	end
	print("KingCity:Occupy-----------", self.camp, self.occupycamp, self.currhp.."/"..self.maxhp)
end

function KingCity:LeaveGuard(dbid)
	local remove = #self.guards + 1
	for index, guard in pairs(self.guards) do
		if dbid == guard.playerinfo.dbid then
			remove = index
		end
	end
	
	local kingcamp = self.map:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:LeaveGuard(dbid)
		table.remove(self.guards, remove)
	end
end

function KingCity:Guard(datas)
	-- 判断组队
	local can, newdatas, idlist = server.teamCenter:GetTeamData(datas, true)
	if not can then
		return
	end

	if #newdatas.playerlist + #self.guards > 3 then
		print("KingCity:Guard too much people")
		return
	end

	for _, playerdatas in ipairs(newdatas.playerlist) do
		self:AddOneGuard(playerdatas)
	end
	self:BroadcastCity()
	-- for _, playerdatas in ipairs(newdatas.playerlist) do
	-- 	self:SendCityDataMsg(playerdatas.playerinfo.dbid)
	-- end
end

function KingCity:AddOneGuard(datas)
	local dbid = datas.playerinfo.dbid
	if #self.guards == 0 then
		self.maxhp = 0
		self.currhp = 0
	end

	if #self.guards >= 3 then
		print("KingCity:Guard guards has enough")
		return
	end

	for _, guarddata in ipairs(self.guards) do
		if guarddata.playerinfo.dbid == dbid then
			print("KingCity:Guard you has been in the guards")
			return
		end
	end

	--设置守城状态
	local kingcamp = self.map:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:Guard(dbid, self.camp)
	end
	self:StartGuardPointTimer(dbid)

	local now = lua_app.now()
	-- 设置同步血量
	datas.synchp = true
	datas.begintime = now
	datas.citypoint = 0
	datas.pointtime = now
	table.insert(self.guards, datas)

	local entityhp = datas.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
	local addhp = #datas.entitydatas * entityhp
	for _, data in ipairs(datas.entitydatas) do
		data.hp = entityhp
	end

	self.maxhp = math.max(self.maxhp + addhp, 0)
	self.currhp = math.max(self.currhp + addhp, 0)

	server.teamCenter:Leave(dbid)
	print("KingCity:Guard new guard in", dbid, self.currhp.."/"..self.maxhp)
end

-- 阵营全体积分定时器
function KingCity:StartCampPointTimer()
	if self.camppointtimer then
		lua_app.del_timer(self.camppointtimer)
		self.camppointtimer = nil
	end

	local function _DoPoint()
		self.camppointtimer = lua_app.add_timer(self.config.partnerpoints_time * 60000, _DoPoint)
		local exclude = {}
		for _, guard in ipairs(self.guards) do
			exclude[guard.playerinfo.dbid] = true
		end

		-- 全体积分
		local kingcamp = self.map:GetKingCamp(self.occupycamp)
		if kingcamp then
			kingcamp:AddAllCommonPoint(self.config.partnerpoints, exclude)
		end
	end

	-- 分钟->毫秒
	if self.config.partnerpoints_time > 0 then
		self.camppointtimer = lua_app.add_timer(self.config.partnerpoints_time * 60000, _DoPoint)
	end
end

-- 王城积分定时器
function KingCity:StartGuardPointTimer(dbid)
	local function _DoPoint(_, playerid)
		if not self.map.center.begin then return end
		self.guardpointtimer[playerid] = lua_app.add_timer(self.config.citypoints_time * 60000, _DoPoint, playerid)
		-- 占领者积分
		local now = lua_app.now()
		for _, guard in ipairs(self.guards) do
			if playerid == guard.playerinfo.dbid then
				local kingcamp = self.map:GetPlayerCamp(playerid)
				if kingcamp then
					local mul = 1
					if self.camp == _MainCity then
						-- 占领主城有差距保护加成
						local maxcamp, maxpoint = self.map:GetMaxCityPoint()
						if maxcamp ~= self.occupycamp then
							local KingGainPointsConfig = server.configCenter.KingGainPointsConfig
							local gap = maxpoint - kingcamp.citypoint
							local lastgap = 0
							for _, v in ipairs(KingGainPointsConfig) do
								if gap >= v.dvalue and v.dvalue > lastgap then
									lastgap = v.dvalue
									mul = v.multiplepoints
								end
							end
						end
					end
					
					local addcitypoint = self.config.citypoints * mul
					guard.citypoint = guard.citypoint + addcitypoint
					kingcamp:AddCityPoint(playerid, addcitypoint)
					kingcamp:AddCommonPoint(playerid, self.config.guardpoints)
					guard.pointtime = now
				end
			end
		end
	end

	-- 分钟->毫秒
	if self.config.citypoints_time > 0 then
		self.guardpointtimer[dbid] = lua_app.add_timer(self.config.citypoints_time * 60000, _DoPoint, dbid)
	end
end

function KingCity:StopGuardPointTimer()
	for _, t in ipairs(self.guardpointtimer) do
		lua_app.del_timer(t)
	end
	self.guardpointtimer = {}
end

function KingCity:StopOneGuardPointTimer(dbid)
	if self.guardpointtimer[dbid] then
		lua_app.del_timer(self.guardpointtimer[dbid])
		self.guardpointtimer[dbid] = nil
	end
end

-- 每秒
function KingCity:DoSecond(now)
	local KingBaseConfig = server.configCenter.KingBaseConfig
	if now - self.dropbloodtime > KingBaseConfig.bloodtime then
		self.dropbloodtime = now
		if self:IsDropBlood() then
			self:GuardDropBlood()
		end
	end
end

-- 如果一个阵营占领了主城但他的边城被占领了，此时主城的守卫会次序掉血
function KingCity:IsDropBlood()
	if self.camp ~= _MainCity then return false end
	if next(self.guards) == nil then return false end
	return true
end

-- 守卫掉血
function KingCity:GuardDropBlood()
	local lasthp = self.currhp
	self.currhp = 0
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local percent = KingBaseConfig.bloodpercent / 100
	for _, guard in pairs(self.guards) do
		local maxhp = guard.playerinfo.attrs[EntityConfig.Attr.atMaxHP]
		local dropblood = maxhp * percent
		local live = {}
		for _, data in ipairs(guard.entitydatas) do
			data.hp = math.max(data.hp - dropblood, 1)
			if data.hp > 0 then
				self.currhp = math.max(self.currhp + data.hp, 0)
				table.insert(live, data)				
			end
		end
		guard.entitydatas = live
	end
	local changhp = math.max(lasthp - self.currhp, 0)
	if changhp ~= 0 then
		table.insert(self.attackrecord, {camp = _MainCity, changhp = changhp, names = {}, time = lua_app.now()})
	end
	-- -- 掉血掉死了
	-- if self.currhp <= 0 then
	-- 	self.Occupy(_MainCity, {})
	-- end
end

-- 守城者信息
function KingCity:GetGuardInfoMsg()
	local list = {}
	for _, guarddata in pairs(self.guards) do
		local guard = {
			dbid = guarddata.playerinfo.dbid,
			name = guarddata.playerinfo.name,
			level = guarddata.playerinfo.level,
			job = guarddata.playerinfo.job,
			sex = guarddata.playerinfo.sex,
			power = guarddata.playerinfo.power,
			isdead = (#guarddata.entitydatas == 0)
		}
		table.insert(list, guard)
	end
	return list
end

-- 守城记录
function KingCity:GetGuardRecordMsg()
	local list = {}
	for _, r in pairs(self.attackrecord) do
		local record = {
			camp = r.camp,
			changhp = math.ceil(r.changhp),
			names = r.names,
			time = r.time
		}
		table.insert(list, record)
	end
	return list
end

function KingCity:IsGuard(dbid)
	for _, guarddata in pairs(self.guards) do
		if guarddata.playerinfo.dbid == dbid then
			return true, guarddata
		end
	end
	return false
end

-- 城市详细数据
function KingCity:SendCityDataMsg(dbid)
	local msg = {}
	msg.camp = self.camp
	msg.currcamp = self.occupycamp
	msg.currhp = math.ceil(self.currhp)
	msg.maxhp = math.ceil(self.maxhp)
	msg.guards = self:GetGuardInfoMsg()
	local isguard, data = self:IsGuard(dbid)
	if isguard then
		local now = lua_app.now()
		msg.guardtime = now - data.begintime
		msg.point = data.citypoint
		if self.camp == _MainCity then
			msg.pointtime = data.pointtime + self.config.citypoints_time * 60 - now
		end
		msg.record = self:GetGuardRecordMsg()
	end
	server.sendReqByDBID(dbid, "sc_king_city_data", msg)
end

-- 广播城市被占领消息
function KingCity:BroadcastOccupy(names)
	local msg = {}
	msg.camp = self.camp
	msg.occupycamp = self.occupycamp
	msg.names = names
	self.map:Broadcast("sc_king_city_occupy", msg)
end

function KingCity:BroadcastCity()
	local msg = {}
	msg.citys = {
		camp = self.camp,
		currcamp = self.occupycamp,
		currhp = math.ceil(self.currhp),
		maxhp = math.ceil(self.maxhp),
		guards = self:GetGuardInfoMsg(),
	}
	self.map:Broadcast("sc_king_info_update", msg)
end

return KingCity