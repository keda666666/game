local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local KingCamp = require "king.KingCamp"
local KingCity = require "king.KingCity"
local WarReport = require "warReport.WarReport"
local KingConfig = require "resource.KingConfig"
local ChatConfig = require "resource.ChatConfig"
local _MainCity = 0

-- 跨服争霸跨服一场地图主控文件
local KingMap = oo.class()

-- self.camplist 阵营列表  self.camplist[KingConfig.camp] = KingCamp
-- self.maincity 主城 KingCity
-- self.citylist 边城列表  self.citylist[KingConfig.camp] = KingCity
-- self.servercamp 服务器到阵营的索引 self.servercamp[serverid] = KingCamp
-- self.playerlist 玩家到阵营的索引	self.playerlist[dbid] = KingCamp
-- self.onlinelist 正在游戏中的玩家

function KingMap:ctor(index, center)
	self.index = index
	self.center = center

	self.camplist = {}
	for _, camp in pairs(KingConfig.camp) do
		self.camplist[camp] = KingCamp.new(camp, self)
	end

	self.maincity = KingCity.new(_MainCity, self)
	self.citylist = {}
	for _, camp in pairs(KingConfig.camp) do
		self.citylist[camp] = KingCity.new(camp, self)

	end
end

function KingMap:Release()
	if self.maincity then
		self.maincity:Release()
	end

	if self.citylist then
		for _, kingcity in pairs(self.citylist) do
			kingcity:Release()
		end
	end

	if self.camplist then
		for _, kingcamp in pairs(self.camplist) do
			kingcamp:Release()
		end
	end
end

-- 服务器
function KingMap:Init(servers)
	self.playerlist = {}
	self.onlinelist = {}
	self.fighting = {}
	self.servercamp = {}
	self.leavepos = {}
	self.serieskill = {}
	self.warReport = WarReport.new("sc_king_report")
	self.lv = nil
	local index = 1
	for _, serverid in pairs(servers) do
		local kingcamp = self.camplist[index]
		self.servercamp[serverid] = kingcamp
		kingcamp:SetServerid(serverid)
	
		index = index + 1
		local lv = self.center.serverinfo[serverid].lv
		self.lv = self.lv or lv
		if lv > self.lv then
			self.lv = lv
		end
	end

	for __,camp in pairs(self.camplist) do
		camp:SetWarReport(self.warReport)
	end

	self.maincity:Init()
	for _, kingcity in pairs(self.citylist) do
		kingcity:Init()
	end
end

-- 活动正式开始
function KingMap:Begin()
	for _, kingcamp in pairs(self.camplist) do
		kingcamp:Begin()
	end
	self:BroadcastBeginAct()
	for dbid, _ in pairs(self.playerlist) do
		self:SendKingInfo(dbid)
	end
end

-- 活动结束
function KingMap:End()
	self.maincity:End()
	for _, kingcity in pairs(self.citylist) do
		kingcity:End()
	end

	local order = {}
	for _, kingcamp in pairs(self.camplist) do
		table.insert(order, kingcamp)
	end

	table.sort(order, function(a, b)
			if a.citypoint == b.citypoint then
				return a.addpointtime < b.addpointtime
			else
				return a.citypoint > b.citypoint
			end
		end)

	local winner = order[1]
	local KingBaseConfig = server.configCenter.KingBaseConfig
	if winner.citypoint == 0 then
		self:BroadcastNotice(KingBaseConfig.noendNotice)
		lua_app.log_info("KingMap:End--- no winner")
	else
		winner:SendWinReward()
		order[2]:SendLostReward()
		order[3]:SendLostReward()
		self:BroadcastNotice(KingBaseConfig.endNotice, KingConfig.campname[winner.camp])
		self.warReport:AddShareData({
				rank = {winner.camp, order[2].camp, order[3].camp}
			})
		lua_app.log_info("KingMap:End--- 1, 2, 3:", winner.camp, order[2].camp, order[3].camp)
	end

	self:GiveCityPointRewards()

	for _, kingcamp in pairs(self.camplist) do
		kingcamp:End()
	end
	
	self.warReport:BroadcastReport()

	-- 全踢出地图
	-- for dbid, online in pairs(self.onlinelist) do
	-- 	if online then
	-- 		server.mapCenter:Leave(dbid)
	-- 	end
	-- end

	self.playerlist = {}
	self.onlinelist = {}
	self.fighting = {}
	self.servercamp = {}
	self.leavepos = {}
	self.serieskill = {}
end

function KingMap:GiveCityPointRewards()
	local pointlist = {}
	for dbid, camp in pairs(self.playerlist) do
		table.insert(pointlist, camp:GetCityPoint(dbid))
	end
	table.sort(pointlist, function(currdata, backdata)
		return currdata.citypoint > backdata.citypoint
	end)

	local KingBaseConfig = server.configCenter.KingBaseConfig
	local PlayerPointsRewardConfig = server.configCenter.PlayerPointsRewardConfig
	local match = table.matchValue
	local title = KingBaseConfig.mailtitle3
	for rank, data in ipairs(pointlist) do
		local rewardCfg = match(PlayerPointsRewardConfig, function(cfg)
			return rank - cfg.rank
		end)

		local rewards = server.dropCenter:DropGroup(rewardCfg.reward)
		local context = string.format(KingBaseConfig.maildes3, rank)
		server.serverCenter:SendOneMod("logic", data.serverid, "mailCenter", "SendMail", 
			data.dbid, title, context, rewards, server.baseConfig.YuanbaoRecordType.King)
		self.warReport:AddRewards(data.dbid, rewards)
	end
end

-- 每秒定时器处理
function KingMap:DoSecond()
	local now = lua_app.now()
	for _, kingcamp in pairs(self.camplist) do
		kingcamp:DoSecond(now)
	end
	for _, city in pairs(self.citylist) do
		city:DoSecond(now)
	end
	self.maincity:DoSecond(now)
end

-- 玩家的阵营
function KingMap:GetPlayerCamp(dbid)
	return self.playerlist[dbid]
end

function KingMap:GetKingPlayer(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		return kingcamp.playerlist[dbid]
	end
end

function KingMap:GetKingCamp(camp)
	return self.camplist[camp]
end

function KingMap:onLogout(player)
	self:SetOffline(player.dbid)
end

function KingMap:SetOnline(dbid)
	self.onlinelist[dbid] = true
	self:SendKingInfo(dbid)
end

function KingMap:SetOffline(dbid)
	self.onlinelist[dbid] = nil
	self:BroadcastPlayerLeave(dbid)
end

-- 玩家加入
function KingMap:Join(playerinfo, serverid, israndom)
	local dbid = playerinfo.dbid
	self.warReport:AddPlayer(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		print("KingMap:Join has been join", dbid)
		self:Enter(playerinfo, kingcamp)
		return true
	end

	if israndom then
		local tmpcamp = nil
		for _, kingcamp in pairs(self.camplist) do
			if not tmpcamp then
				tmpcamp = kingcamp
			else
				if kingcamp.totalpower < tmpcamp.totalpower then
					tmpcamp = kingcamp
				end
			end
		end
		self.playerlist[dbid] = tmpcamp
		tmpcamp:Join(playerinfo)
		self:Enter(playerinfo, tmpcamp)
		print("KingMap:Join to camp random", tmpcamp.camp)
		return true
	end

	local kingcamp = self.servercamp[serverid]
	if kingcamp then
		self.playerlist[dbid] = kingcamp
		kingcamp:Join(playerinfo)
		self:Enter(playerinfo, kingcamp)
		print("KingMap:Join to camp", kingcamp.camp)
		return true
	else
		print("KingMap:Join no this camp", camp, serverid)
		return false
	end
end

function KingMap:Enter(playerinfo, kingcamp)
	local dbid = playerinfo.dbid
	server.teamCenter:Leave(dbid)
	kingcamp:EnterMap(dbid, self.leavepos[dbid])
	kingcamp:SetFighting(dbid, false)
	kingcamp:SetTransform(dbid, false)
	self:SetOnline(dbid)
	self:BroadcastPlayerEnter(dbid, kingcamp.camp, kingcamp:GetStatus(dbid))
	self:SendAllTeam(dbid)
end

function KingMap:SendAllTeam(dbid)
	server.teamCenter:SendTeamList(dbid, server.raidConfig.type.KingCity, KingConfig.camp.Human)
	server.teamCenter:SendTeamList(dbid, server.raidConfig.type.KingCity, KingConfig.camp.God)
	server.teamCenter:SendTeamList(dbid, server.raidConfig.type.KingCity, KingConfig.camp.Devil)
end

-- 判断是否可以战斗
function KingMap:CanFight(idlist)
	for _, id in pairs(idlist) do
		local kingcamp = self:GetPlayerCamp(id)
		if not kingcamp then return false end
		if not kingcamp:CanFight(id) then return false end
	end
	return true
end
	

-- 攻城
function KingMap:AttackCity(datas, targetcamp)
	local dbid = datas.playerinfo.dbid
	local kingcamp = self:GetPlayerCamp(dbid)
	if not kingcamp then
		print("KingMap:AttackCity no player's camp", dbid)
		return false 
	end

	-- 判断组队
	local can, newdatas, idlist = server.teamCenter:GetTeamData(datas, true)
	if not can then
		return false
	end

	-- 判断是否可以战斗
	if not self:CanFight(idlist) then
		print("KingMap:AttackCity can not fight")
		return false
	end

	--变身加成
	newdatas.exinfo.attackercamp = kingcamp.camp
	if kingcamp:IsTransform(dbid) then
		local KingBaseConfig = server.configCenter.KingBaseConfig
		for _, playerdata in pairs(newdatas.playerlist) do
			for _, data in pairs(playerdata.entitydatas) do
				data.deepen = KingBaseConfig.bsbuff
			end
		end
	end

	local city
	if targetcamp == _MainCity then
		-- 打主城
		city = self.maincity
	else
		city = self.citylist[targetcamp]
		if not city then return end
	end
	return city:Attack(dbid, newdatas, idlist)
end

-- 参与守卫
function KingMap:Guard(datas, citycamp)
	local dbid = datas.playerinfo.dbid
	local kingcamp = self:GetPlayerCamp(dbid)
	if not kingcamp then
		print("KingMap:Guard no player's camp", dbid)
		return
	end

	local kingcity = self.citylist[citycamp]
	if citycamp == _MainCity then
		kingcity = self.maincity
	end
	if not kingcity then
		print("KingMap:Guard no kingcity", citycamp)
		return
	end

	if kingcamp.camp ~= kingcity.occupycamp then
		print("KingMap:Guard must guard your occupy camp city", citycamp)
		return
	end

	kingcity:Guard(datas)
end

-- 自由pk
function KingMap:PK(datas, targetid)
	local dbid = datas.playerinfo.dbid
	local mykingcamp = self:GetPlayerCamp(dbid)
	if not mykingcamp then
		print("KingMap:PK no player's camp", dbid)
		return false
	end

	local targetkingcamp = self.playerlist[targetid]
	if not targetkingcamp then
		print("KingMap:PK no target's camp", targetid)
		return false
	end

	if mykingcamp.camp == targetkingcamp.camp then
		print("KingMap:PK you are the same camp", mykingcamp.camp)
		server.sendErrByDBID(dbid, "相同阵营不能PK")
		return false
	end

	-- 攻方组队
	local can, newdatas, playeridlist = server.teamCenter:GetTeamData(datas, true)
	if not can then
		return false
	end

	-- 守方组队
	local can2, targetdatas, targetidlist = server.teamCenter:GetTeamDataByDBID(targetid)
	if not can2 then
		print("KingMap:PK no target ", targetid)
		return false
	end

	for _, id in ipairs(targetidlist) do
		table.insert(playeridlist, id)
	end

	-- 判断能否战斗
	-- if not self:CanFight(playeridlist) then
	-- 	return
	-- end

	-- 种族加成
	local deepen = self:GetCampDeepen(dbid, targetid)
	for _, playerdata in pairs(newdatas.playerlist) do
		for _, data in ipairs(playerdata.entitydatas) do
			data.deepen = deepen
		end
	end

	newdatas.exinfo.target = targetdatas
	newdatas.exinfo.kingmap = self
	newdatas.exinfo.target = targetdatas
	table.print(playeridlist)
	server.raidMgr:Enter(server.raidConfig.type.KingPK, dbid, newdatas, playeridlist)
	self:BroadcastFightingChange()
	return true
end

-- pk结果
function KingMap:PKResult(iswin, players, targets)
	local winlist = {}
	local lostlist = {}
	if iswin then
		winlist = players
		lostlist = targets
	else
		winlist = targets
		lostlist = players
	end

	-- 算积分
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local winpoint = KingBaseConfig.winpoints
	local lostpoint = KingBaseConfig.losepoints
	local winmsg = {iswin = true, commonpoint = winpoint}
	local lostmsg = {iswin = false, commonpoint = lostpoint}

	for _, dbid in pairs(winlist) do
		local kingcamp = self:GetPlayerCamp(dbid)
		if kingcamp then
			kingcamp:AddCityPoint(dbid, winpoint)
		end
		server.sendReqByDBID(dbid, "sc_king_pk_result", winmsg)
		self:AddSeriesKill(dbid, #lostlist)
	end
	-- 失败者踢回出生点
	for _, dbid in pairs(lostlist) do
		local kingcamp = self:GetPlayerCamp(dbid)
		if kingcamp then
			kingcamp:AddCityPoint(dbid, lostpoint)
			kingcamp:DeadKick(dbid)
		end
		server.sendReqByDBID(dbid, "sc_king_pk_result", lostmsg)
		self:StopSeriesKill(dbid)
	end
end

function KingMap:AddSeriesKill(dbid, count)
	self.serieskill[dbid] = self.serieskill[dbid] or {count = 0, lastbro = 0, wait = 0}
	local serieskill = self.serieskill[dbid]
	serieskill.count = serieskill.count + count
	local notice
	local KingBattleMultiKill = server.configCenter.KingBattleMultiKill
	for _, v in pairs(KingBattleMultiKill) do
		if v.notice ~= 0 then
			if serieskill.count >= v.count and serieskill.lastbro < v.count then
				serieskill.lastbro = v.count
				notice = v.notice
			end
		end
	end
	if notice then
		self:BroadcastNotice(notice, self:CampDo(dbid, "GetPlayerName"), tostring(serieskill.count))
	end
end

function KingMap:StopSeriesKill(dbid)
	if self.serieskill[dbid] then
		self.serieskill[dbid].count = 0
	end
end

function KingMap:CampDo(dbid, funcname, ...)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp and kingcamp[funcname] then
		return kingcamp[funcname](kingcamp, dbid, ...)
	end
end

function KingMap:SetFighting(dbid, fighting)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:SetFighting(dbid, fighting)
	end
end

-- 花钱复活
function KingMap:PayRevive(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:PayRevive(dbid)
	end
end

-- 离开游戏
function KingMap:Leave(dbid)
	self:SetOffline(dbid)
	server.teamCenter:Leave(dbid)
	-- local guardcity = self:GetGuardCity(dbid)
	-- if guardcity then
	-- 	guardcity:LeaveGuard(dbid)
	-- end
end

function KingMap:onLeaveMap(dbid, mapid, line, x, y)
	self.leavepos[dbid] = {x = x, y = y}
end

function KingMap:GetGuardCity(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		local guardcamp = kingcamp:GetMyGuardCamp(dbid)
		if guardcamp == _MainCity then
			return self.maincity
		else
			return self.citylist[guardcamp]
		end
	end
end

-- 获得王城积分最高的阵营
function KingMap:GetMaxCityPoint()
	local camp
	local point
	for c, kingcamp in pairs(self.camplist) do
		if not camp then
			camp = c
			point = kingcamp.citypoint
		end
		if kingcamp.citypoint > point then
			camp = c
			point = kingcamp.citypoint
		end
	end
	return camp, point
end

-- 领取积分奖励
function KingMap:GetPointReward(dbid, ptype, index)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:GetPointReward(dbid, ptype, index)
	end
end

-- 玩家列表数据
function KingMap:GetPlayerInfoMsg()
	local list = {}
	for dbid, kingcamp in pairs(self.playerlist) do
		local info = {
			dbid = dbid,
			camp = kingcamp.camp,
			status = kingcamp:GetStatus(dbid)
		}
		table.insert(list, info)
	end
	return list
end

-- 玩家变身
function KingMap:Transform(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp and kingcamp:CanTransfrom(dbid) then
		kingcamp:SetTransform(dbid, true)
	end
end

function KingMap:GetMyGuard(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:GetMyGuard(dbid)
	end
end

function KingMap:CanTeam(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		return kingcamp:CanTeam(dbid)
	end
end

function KingMap:TeamRecruit(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:BroadcastOnline("sc_chat_new_msg", {
				chatData = ChatConfig:PackLinkData(37, dbid, kingcamp:GetPlayerName(dbid), {ChatConfig.CollectType.Fb, kingcamp.camp, server.raidConfig.type.KingCity}),
			})
	end
end

-- 快速死亡
function KingMap:TestDead(dbid)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:DeadKick(dbid, true)
	end
end

function KingMap:TestPoint(dbid, point)
	local kingcamp = self:GetPlayerCamp(dbid)
	if kingcamp then
		kingcamp:AddCityPoint(dbid, point)
		kingcamp:AddCommonPoint(dbid, point)
	end
end

-- 获得城市数据
function KingMap:GetCityInfoMsg()
	local list = {}
	local maincity = {
			camp = _MainCity, 
			currcamp = self.maincity.occupycamp,
			currhp = math.ceil(self.maincity.currhp),
			maxhp = math.ceil(self.maincity.maxhp),
			guards = self.maincity:GetGuardInfoMsg(),
		}
	table.insert(list, maincity)

	for camp, kingcity in pairs(self.citylist) do
		local city = {
			camp = camp, 
			currcamp = kingcity.occupycamp,
			currhp = math.ceil(kingcity.currhp),
			maxhp = math.ceil(kingcity.maxhp),
			guards = kingcity:GetGuardInfoMsg(),
		}
		table.insert(list, city)
	end
	return list
end

-- 获得城市详细数据
function KingMap:GetCityData(dbid, citycamp)
	local city
	if citycamp == _MainCity then
		city = self.maincity
	else
		city = self.citylist[citycamp]
	end
	if city then
		city:SendCityDataMsg(dbid)
	end
end

-- 获得战斗中的玩家
function KingMap:GetFightingPlayerMsg()
	local list = {}
	for _, kingcamp in pairs(self.camplist) do
		for dbid, kingplayer in pairs(kingcamp.playerlist) do
			if kingplayer.fighting then
				table.insert(list, dbid)
			end
		end
	end
	return list
end

-- 获得变身中的玩家
function KingMap:GetTransformPlayerMsg()
	local list = {}
	for _, kingcamp in pairs(self.camplist) do
		for dbid, kingplayer in pairs(kingcamp.playerlist) do
			if kingplayer.transform then
				table.insert(list, dbid)
			end
		end
	end
	return list
end

-- 攻收双方是否有种族碾压(己方种族占领了敌方的边城)
function KingMap:GetCampDeepen(dbid, targetid)
	local mykingcamp = self:GetPlayerCamp(dbid)
	local targetkingcamp = self:GetPlayerCamp(targetid)
	if mykingcamp and targetkingcamp then
		if self.citylist[targetkingcamp.camp].occupycamp == mykingcamp.camp then
			local KingBaseConfig = server.configCenter.KingBaseConfig
			return KingBaseConfig.citybuff
		end
	end
	return 0
end

-- 战场基础基础数据
function KingMap:SendKingInfo(dbid)
	local now = lua_app.now()
	local msg = {}
	local kingcamp = self:GetPlayerCamp(dbid)
	local kingplayer = self:GetKingPlayer(dbid)
	if kingcamp and kingplayer then
		msg.camp = kingcamp.camp
		msg.status = kingcamp:GetStatus(dbid)
		msg.reborncout = kingcamp:GetRebonCount(dbid)
		msg.citypoint = kingplayer.citypoint
		msg.commonpoint = kingplayer.commonpoint
	end
	msg.players = self:GetPlayerInfoMsg()
	msg.citys = self:GetCityInfoMsg()
	msg.fighting = self:GetFightingPlayerMsg()
	msg.transform = self:GetTransformPlayerMsg()
	msg.camppoint = self:GetCampPoint()
	if not self.center.begin then
		msg.actcountdown = self.center.begintime - now
	else
		msg.actcountdown = self.center.endtime - now
	end
	server.sendReqByDBID(dbid, "sc_king_info", msg)
end

function KingMap:Broadcast(name, msg)
	for playerid, online in pairs(self.onlinelist) do
		if online then
			server.sendReqByDBID(playerid, name, msg)
		end
	end
end

-- 广播玩家状态变更
function KingMap:BroadcastStatusChange(dbid, status)
	local msg = {dbid = dbid, status = status}
	self:Broadcast("sc_king_status_change", msg)
end

-- 广播玩家战斗状态变化
function KingMap:BroadcastFightingChange(dbid, fighting)
	local msg = {fighting =  self:GetFightingPlayerMsg()}
	self:Broadcast("sc_king_fighting_change", msg)
end

-- 广播玩家变身状态变化
function KingMap:BroadcastTransformChange(dbid, istransform)
	local msg = {dbid = dbid, istransform = istransform}
	self:Broadcast("sc_king_transform_change", msg)
end

-- 广播游戏开始，可以行动
function KingMap:BroadcastBeginAct()
	self:Broadcast("sc_king_begin_act", {})
end

-- 广播玩家进入游戏
function KingMap:BroadcastPlayerEnter(dbid, camp, status)
	local msg = {}
	msg.player = {dbid = dbid, camp = camp, status = status}
	self:Broadcast("sc_king_player_enter", msg)
end

-- 广播玩家离开游戏
function KingMap:BroadcastPlayerLeave(dbid)
	local msg = {dbid = dbid}
	self:Broadcast("sc_king_player_leave", msg)
end

-- 各阵营积分
function KingMap:GetCampPoint()
	local list = {}
	for camp, kingcamp in ipairs(self.camplist) do
		table.insert(list, {camp = camp, point = kingcamp.citypoint})
	end
	return list
end

-- 广播阵营积分数据变化
function KingMap:BroadcastPointInfo()
	local msg = {}
	msg.camppoint = self:GetCampPoint()
	self:Broadcast("sc_king_point_info", msg)
end

function KingMap:BroadcastCityUpdate()
	local msg = {}
	msg.citys = self:GetCityInfoMsg()
	self:Broadcast("sc_king_update_city", msg)
end

-- 积分数据
function KingMap:SendPonitData(dbid)
	local msg = {}
	local kingplayer = self:GetKingPlayer(dbid)
	if kingplayer then
		msg.citypoint = kingplayer.citypoint
		msg.commonpoint = kingplayer.commonpoint
		msg.cityreward = {}
		for index, _ in pairs(kingplayer.cityreward) do
			table.insert(msg.cityreward, index)
		end
		msg.commonreward = {}
		for index, _ in pairs(kingplayer.commonreward) do
			table.insert(msg.commonreward, index)
		end
		server.sendReqByDBID(dbid, "sc_king_point_data", msg)
	end
end

function KingMap:BroadcastNotice(id, ...)
	for serverid, _ in pairs(self.servercamp) do
		server.serverCenter:SendOneMod("logic", serverid, "noticeCenter", "Notice", id, ...)
	end
end

return KingMap

