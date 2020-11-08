local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local RankConfig = require "resource.RankConfig"
local tbname = "datalist"
local tbcolumn = "kingarena"

local KingArenaMgr = {}
local KING_INDEX = 1

function KingArenaMgr:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.recoverlist = {}
	self.king = {}
	self.isopen = false
end

function KingArenaMgr:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function KingArenaMgr:ServerOpen()
	self:ReplaceKing()
end

function KingArenaMgr:onInitClient(player)
	if not self.cache.athletelist[player.dbid] then return end
	self:SendBuyPkcountMsg(player.dbid)
	self:EstimateRecover(player.dbid)
end

function KingArenaMgr:Open()
	if server.serverRunDay < server.configCenter.KingSportsBaseConfig.serverday then return end

	self.recoverlist = {}
	self.cache.openStatus = 1
	self:GenerateAthlete()
	self:SecondTimer()
	self.isopen = true

	if next(self.king) == nil then
		server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_4)
	else
		server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_1, self.king.playerinfo.name)
	end
	self:BroadcastClientMsg()
	print("KingArenaMgr----------------------------open")
end

function KingArenaMgr:IsOpen()
	return self.isopen
end

function KingArenaMgr:Resume()
	self.isopen = true
	self.recoverlist = {}
	self:SecondTimer()
	self:BroadcastClientMsg()
end

function KingArenaMgr:Close()
	if self.cache.openStatus == 0 then return end

	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end
	self:WeeklyRankReward()
	self.recoverlist = {}
	self.cache.priorathletelist = self.cache.athletelist
	self.cache.athletelist = {}
	self.cache.worshipRecord = {}
	self.cache.openStatus = 0
	self.isopen = false

	if next(self.king) == nil then
		server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_3)
	else
		server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_2, self.king.playerinfo.name)
	end
	self:BroadcastClientMsg()
	print("kingArena-------------------close")
end

local function _CalcRewards(grade, rank)
	local rewards = table.GetTbPlus("count")
	local rankCfg = server.configCenter.KingSportsRankConfig[rank]
	local receiveRewards = rankCfg and rankCfg.type >= grade
	if receiveRewards then
		rewards = rewards + rankCfg.rankreward
	end

	local DWKingSportsConfig = server.configCenter.DWKingSportsConfig
	local gradeCfg = table.matchValue(DWKingSportsConfig, function(cfg)
		return grade - cfg.typelv[1]
	end, #DWKingSportsConfig)
	rewards = rewards + gradeCfg.rankreward

	return rewards
end

function KingArenaMgr:WeeklyRankReward()
	local nowRanks = self:CallKingArenaCenter("GetRankDatas")

	local KingSportsConfig = server.configCenter.KingSportsConfig
	local title = server.configCenter.KingSportsBaseConfig.mailtitle
	self.cache.rewardslist = {}
	for rank, rankdata in ipairs(nowRanks) do
		-- self.cache.rewardslist[rankdata.dbid] = _CalcRewards(rankdata.grade, rank)
		local rewards = _CalcRewards(rankdata.grade, rank)
		-- 直接发了
		local gradeCfg = KingSportsConfig[rankdata.grade]
		if gradeCfg then
			local content = string.format(server.configCenter.KingSportsBaseConfig.maildes, gradeCfg.name, rank)
			server.mailCenter:SendMail(rankdata.dbid, title, content, rewards, server.baseConfig.YuanbaoRecordType.KingArena)
		end
	end
	self.cache.priorranks = nowRanks
	self:AddKingRecord()
	for dbid, __ in pairs(self.cache.athletelist) do
		self:SendClientMsg(dbid)
	end
end

function KingArenaMgr:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end
	local function _DoSecond()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		self:ScheduleRecover()
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

function KingArenaMgr:ScheduleRecover()
	local nowtime = lua_app.now()
	for dbid, recovertime in pairs(table.wcopy(self.recoverlist)) do
		if recovertime <= nowtime then
			self.recoverlist[dbid] = nil
			self:RecoverPkCount(dbid)
		end
	end
end

local function _NewAthlete(dbid, oldgrade)
	local KingSportsBaseConfig = server.configCenter.KingSportsBaseConfig
	local KingSportsConfig = server.configCenter.KingSportsConfig
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local info = {
		pkcount = KingSportsBaseConfig.sportstime,
		recovertime = -1,
		grade = KingSportsConfig[oldgrade].defaulttype,
		star = 0,
		lastwincount = 0,
		wincount = 0,
		dbid = dbid,
		playerinfo = player:BaseInfo(),
		buycount = 0,
		noticerecord = {},
	}
	return info
end

function KingArenaMgr:GenerateAthlete()
	local rankdatas = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas",RankConfig.RankType.POWER, 1, server.configCenter.KingSportsBaseConfig.inum)

	self.cache.athletelist = {}
	for __, data in ipairs(rankdatas) do
		self.cache.athletelist[data.id] = _NewAthlete(data.id, self:GetLastGrade(data.id))
	end
end

function KingArenaMgr:GetLastGrade(dbid)
	local athlete = self.cache.priorathletelist[dbid]
	local grade = athlete and athlete.grade or 1
	return grade
end

function KingArenaMgr:LastFightData()
	local athleteinfos = {}
	for dbid, __ in pairs(self.cache.athletelist) do
		athleteinfos[dbid] = self:PackPlayerInfo(dbid)
	end
	return athleteinfos
end

function KingArenaMgr:Match(dbid)
	if not self.cache.athletelist[dbid] then return end
	self:SendKingArenaCenter("Match", self:PackPlayerInfo(dbid))
end

function KingArenaMgr:Enter(dbid)
	local athlete = self.cache.athletelist[dbid]
	if athlete.pkcount <= 0 then 
		lua_app.log_info("athlete pkcount not enough", dbid, athlete.pkcount)
		return
	end
	self:SendKingArenaCenter("Enter", self:PackPlayerInfo(dbid))
end

function KingArenaMgr:FightResult(dbid, iswin, rewardData)
	local athlete = self.cache.athletelist[dbid]
	athlete.pkcount = athlete.pkcount - 1
	self:EstimateRecover(dbid)
	self:SendKingArenaCenter("UpdateAthlete", self:PackPlayerInfo(dbid))
	local increasestar = self:UpdateStar(dbid, iswin)
	server.sendReqByDBID(dbid, "sc_ladder_result", {
			isWin = iswin,
			rewardData = rewardData,
			grade = athlete.grade,
			star = athlete.star,
			increasestar = increasestar,
			ladderType = 1
		})
end

local _NoticeGrade = setmetatable({}, {__index = function() return function() end end})
_NoticeGrade[8] = function(record, grade, name)
	if record[grade] then return end
	server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_6, name)
	record[grade] = true
end

_NoticeGrade[13] = function(record, grade, name)
	if record[grade] then return end
	server.noticeCenter:Notice(server.configCenter.KingSportsBaseConfig.notice_5, name)
	record[grade] = true
end

function KingArenaMgr:UpdateStar(dbid, iswin)
	local athlete = self.cache.athletelist[dbid]
	local gradeCfg = server.configCenter.KingSportsConfig[athlete.grade]
	local increasestar = 0
	if iswin then
		athlete.lastwincount = athlete.lastwincount + 1
		increasestar = increasestar + gradeCfg.winstar
		if athlete.lastwincount >=  5 then
			increasestar = increasestar + gradeCfg.nstar
		end
		athlete.wincount = athlete.wincount + 1
	else
		increasestar = increasestar + gradeCfg.lossstar
		athlete.lastwincount = 0
		athlete.wincount = math.max(athlete.wincount - 1, 0)
	end
	athlete.star = athlete.star + increasestar
	self:UpdateGrade(athlete)
	_NoticeGrade[athlete.grade](athlete.noticerecord, athlete.grade, athlete.playerinfo.name)
	return increasestar
end


function KingArenaMgr:UpdateGrade(athlete)
	--降阶
	local degrade = athlete.star < 0
	if degrade then
		athlete.grade = athlete.grade - 1
		local newdradeCfg = server.configCenter.KingSportsConfig[athlete.grade]
		athlete.star = athlete.star + newdradeCfg.needstar
		return
	end

	print(athlete.grade, self:GetGradeMax())
	if athlete.grade >= self:GetGradeMax() then
		return 
	end
	--升阶
	local gradeCfg = server.configCenter.KingSportsConfig[athlete.grade]
	local upgrade = athlete.star > gradeCfg.needstar
	if upgrade then
		athlete.grade = athlete.grade + 1
		athlete.star = athlete.star - gradeCfg.needstar
	end
end

function KingArenaMgr:PackPlayerInfo(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local athlete = self.cache.athletelist[dbid]
	local playerinfo = {
		grade = athlete.grade,
		star = athlete.star,
		wincount = athlete.wincount,
		dbid = dbid,
		serverid = server.serverid,
		fightdata = server.dataPack:FightInfoByDBID(dbid),
		playerinfo = player:BaseInfo(),
	}
	return playerinfo
end

function KingArenaMgr:GetGradeMax()
	if not self.grademax then
		local KingSportsConfig = server.configCenter.KingSportsConfig
		self.grademax = #KingSportsConfig
	end
	return self.grademax
end

function KingArenaMgr:Worship(player)
	local dbid = player.dbid
	if self.cache.worshipRecord[dbid] then
		lua_app.log_info("already worshiped.")
		return
	end

	local rewards = server.configCenter.KingSportsBaseConfig.worshipreward
	player:GiveRewardAsFullMailDefault(rewards, "跨服王者争霸膜拜", server.baseConfig.YuanbaoRecordType.KingArena)
	self.cache.worshipRecord[dbid] = true
	self:SendKinginfoMsg(dbid)
end

function KingArenaMgr:EstimateRecover(dbid)
	if self.recoverlist[dbid] then return end

	local nowtime = lua_app.now()
	local athlete = self.cache.athletelist[dbid]
	local KingSportsBaseConfig = server.configCenter.KingSportsBaseConfig
	local retime = KingSportsBaseConfig.retime
	local recovertime = athlete.recovertime

	local recovercount = math.ceil((nowtime - recovertime) / retime)
	if recovercount > 0 and recovertime > 0 then
		athlete.pkcount = math.min(athlete.pkcount + recovercount, server.configCenter.KingSportsBaseConfig.sportstime)
		athlete.recovertime = recovertime + recovercount*retime
	end

	if athlete.pkcount < KingSportsBaseConfig.sportstime then
		athlete.recovertime = (recovertime-nowtime) > 0 and recovertime or (nowtime + retime)
		self.recoverlist[dbid] =  athlete.recovertime 
	else
		athlete.recovertime = -1
	end
end

function KingArenaMgr:BuyPkCount(player)
	local athlete = self.cache.athletelist[player.dbid]
	local KingSportsBaseConfig = server.configCenter.KingSportsBaseConfig
	if KingSportsBaseConfig.time <= athlete.buycount then
		lua_app.log_info("buy pkcount reach maximum.", athlete.buycount)
		return false
	end

	if athlete.pkcount >= KingSportsBaseConfig.sportstime then
		lua_app.log_info("pkcount reach maximum.", athlete.pkcount)
		return
	end

	if not player:PayRewards({KingSportsBaseConfig.cost}, server.baseConfig.YuanbaoRecordType.KingArena, "KingArenaMgr:BuyPkCount") then
		lua_app.log_info("wealth not enough.")
		return false
	end
	athlete.buycount = athlete.buycount + 1
	athlete.pkcount = athlete.pkcount + 1

	self:SendBuyPkcountMsg(player.dbid)
	self:SendClientMsg(player.dbid)
	return true
end

function KingArenaMgr:RecoverPkCount(dbid)
	local athlete = self.cache.athletelist[dbid]
	athlete.pkcount = math.min(athlete.pkcount + 1, server.configCenter.KingSportsBaseConfig.sportstime)
	self:EstimateRecover(dbid)
	self:SendClientMsg(dbid)
end

function KingArenaMgr:BroadcastClientMsg()
	local onlinelist = server.playerCenter:GetOnlinePlayers()
	for __, player in pairs(onlinelist) do
		self:SendClientMsg(player.dbid)
	end
end

function KingArenaMgr:SendClientMsg(dbid)
	local athlete = self.cache.athletelist[dbid]
	if not athlete then
		athlete = _NewAthlete(dbid, self:GetLastGrade(dbid))
	end
	local msg = {
		isOpen = self:IsOpen(),
		grade = athlete.grade,
		star = athlete.star,
		challgeNum = athlete.pkcount,
		challgeCd = athlete.recovertime,
		winNum = athlete.wincount,
		lianWin = athlete.lastwincount >= server.configCenter.KingSportsBaseConfig.nwin,
		canJoin = self.cache.athletelist[dbid] and true or false,
	}

	--上周的数据
	local lastinfo = self.cache.priorathletelist[dbid]
	if lastinfo then
		msg.playUpTime 	= true
		msg.isCanReward = self.cache.rewardslist[dbid] and true or false
		msg.upgrade = lastinfo.grade
		msg.upstar = lastinfo.star
		msg.upWin = lastinfo.wincount
		msg.rank = lastinfo.rank
	else
		msg.playUpTime = false
	end

	if next(self.king) ~= nil then
		msg.csName = self.king.playerinfo.name
		msg.csjob = self.king.playerinfo.job
		msg.cssex = self.king.playerinfo.sex
		msg.csServerId = self.king.serverid
	end
	server.sendReqByDBID(dbid, "sc_ladder_info", msg)
end

function KingArenaMgr:SendBuyPkcountMsg(dbid)
	local athlete = self.cache.athletelist[dbid]
	server.sendReqByDBID(dbid, "sc_ladder_buy_count", {
			todayBuyTime = athlete and athlete.buycount or 0,
			ladderType = 1,
		})
end

function KingArenaMgr:SendKinginfoMsg(dbid)
	server.sendReqByDBID(dbid, "sc_ladder_winner_info", {
			shows = self.king.shows,
			worship = self.cache.worshipRecord[dbid] or false,
		})
end

function KingArenaMgr:SendKingRecordMsg(dbid)
	local kingrecord = self:GetKingRecord()
	local data = {}
	for i = 1, #kingrecord do
		local winer = kingrecord[i]
		table.insert(data, {
				time = 	winer.time,
				serverid = winer.serverid,
				guildname = winer.playerinfo.guildname,
				leadername = winer.playerinfo.name,
				job = winer.playerinfo.job,
				sex = winer.playerinfo.sex,
				vip = winer.playerinfo.vip,
				power = winer.playerinfo.power,
				win = winer.wincount,
			})
	end
	server.sendReqByDBID(dbid, "sc_ladder_winner_records", data)
end

function KingArenaMgr:AddKingRecord()
	self:ReplaceKing()

	if not next(self.king) then return end
	table.insert(self.cache.kingrecord, {
			time = lua_app.now(),
			serverid = self.king.serverid,
			guildname = self.king.playerinfo.guildname,
			leadername = self.king.playerinfo.name,
			job = self.king.playerinfo.job,
			sex = self.king.playerinfo.sex,
			vip = self.king.playerinfo.vip,
			power = self.king.playerinfo.power,
			win = self.king.wincount,
		})
	if #self.cache.kingrecord > 50 then
		table.remove(self.cache.kingrecord, 1)
	end
	local king = server.playerCenter:DoGetPlayerByDBID(self.king.dbid)
	king.head:ActiveFrame(1, server.configCenter.KingSportsBaseConfig.icontime)
end

function KingArenaMgr:ReplaceKing()
	self.king = {}
	local kinginfo = self.cache.priorranks[1]
	if not kinginfo or kinginfo.grade < server.configCenter.KingSportsBaseConfig.typelv then return end

	kinginfo.shows = table.wcopy(kinginfo.playerinfo)
	kinginfo.shows.serverid = kinginfo.serverid
	self.king = kinginfo
end

function KingArenaMgr:GetKingRecord()
	return self.cache.kingrecord
end

function KingArenaMgr:SendRankMsg(dbid)
	local function _DressData(rankdata)
		local data = {
			id = rankdata.dbid,
			player = rankdata.playerinfo.name,
			grade = rankdata.grade,
			star = rankdata.star,
			winNum = rankdata.wincount,
			job = rankdata.playerinfo.job,
			sex = rankdata.playerinfo.sex,
			serverid = rankdata.serverid,
		}
		return data
	end

	local msg = {}
	msg.rankData = {}
	local nowRanks = self:CallKingArenaCenter("GetRankDatas")
	for rank, rankdata in ipairs(nowRanks) do
		if rankdata.dbid == dbid then
			msg.rank = rank
		end
		table.insert(msg.rankData, _DressData(rankdata))
	end

	msg.upWeekRankList = {}
	local preRanks = self.cache.priorranks
	local KingSportsRankConfig = server.configCenter.KingSportsRankConfig
	for rank, cfg in ipairs(KingSportsRankConfig) do
		local rankdata = preRanks[rank]
		if rankdata and cfg.type <= rankdata.grade then
			table.insert(msg.upWeekRankList, _DressData(rankdata))
			if rankdata.dbid == dbid then
				msg.upWeekRank = rank
			end
		end
	end
	
	msg.ladderType = 1
	server.sendReqByDBID(dbid, "sc_ladder_rank_list", msg)
end

function KingArenaMgr:ReceiveReward(dbid)
	local rewards = self.cache.rewardslist[dbid]
	if not rewards then 
		lua_app.log_info("not receive rewards.", dbid)
		return
	end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	player:GiveRewardAsFullMailDefault(rewards, "跨服王者争霸", server.baseConfig.YuanbaoRecordType.KingArena)
	self.cache.rewardslist[dbid] = nil
end

function KingArenaMgr:onDayTimer()
	for dbid, athlete in pairs(self.cache.athletelist) do
		athlete.buycount = 0
		self:SendBuyPkcountMsg(dbid)
	end
end

function KingArenaMgr:CallKingArenaCenter(funcname, ...)
	return server.serverCenter:CallDtbMod("war", "kingArenaCenter", funcname, ...)
end

function KingArenaMgr:SendKingArenaCenter(funcname, ...)
	server.serverCenter:SendDtbMod("war", "kingArenaCenter", funcname, ...)
end

function KingArenaMgr:Test(funcname, ...)
	server.serverCenter:SendDtbMod("war", "kingArenaCenter", funcname, ...)
end

function KingArenaMgr:TestPrint()
	print("----------rewardslist------------")
	table.ptable(self.cache.rewardslist, 3)
	print("----------priorathletelist------------")
	table.ptable(self.cache.priorathletelist, 1)
	print("-----------kingrecord---------------")
	table.ptable(self.cache.kingrecord, 1)
	print("-----------priorranks---------------")
	table.ptable(self.cache.priorranks, 1)
	print("-----------athletelist---------------")
	table.ptable(self.cache.athletelist, 1)
	print("++++++++++++++self.recoverlist")
	table.ptable(self.recoverlist, 3)
end

function KingArenaMgr:TestClear()
	self.cache.athletelist = {}
	self.cache.priorranks = {}
	self.cache.kingrecord = {}
	self.cache.priorathletelist = {}
	self.cache.rewardslist = {}
end

function KingArenaMgr:TestFight()
	self:SendKingArenaCenter("UpdateAthlete", self:PackPlayerInfo(17179869198))
	--self:FightResult(17179869185, true, {})
end

server.SetCenter(KingArenaMgr, "kingArenaMgr")
return KingArenaMgr