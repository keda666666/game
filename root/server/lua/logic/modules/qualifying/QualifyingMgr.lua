local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local RankConfig = require "resource.RankConfig"

local QualifyingMgr = {}


function QualifyingMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "QualifyingWarCall", funcname, ...)
end

function QualifyingMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "QualifyingWarSend", funcname, ...)
end

function QualifyingMgr:Init()
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.QualifyingMgr
end

function QualifyingMgr:Sign(dbid)
	local day = server.serverRunDay
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	if day < baseConfig.serverday then return {ret = false} end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return {ret = false} end
	local rank = self:GetRank(rankNo)
	if not rank then return {ret = false} end
	server.dailyActivityCenter:SendJoinActivity("qualifying", dbid)
	local msg = {
		ret = self:CallWar("Sign", dbid, server.serverid, rank, player.cache.totalpower, player.cache.name, player.cache.job, player.cache.sex, player.cache.level)
	}
	return msg
end

-- function QualifyingMgr:SignComplete(dbid, ret)
-- 	local msg = {ret = ret}

-- 	server.sendReqByDBID(dbid, "cs_qualifyingMgr_sign_up_res", msg)
-- end

function QualifyingMgr:GetRankPlayer()
	local data = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas", RankConfig.RankType.POWER, 1, 14)
	local dbList = {}
	for k,v in pairs(data) do
		local player = server.playerCenter:DoGetPlayerByDBID(v.id)
		if player then
			table.insert(dbList, {
				dbid = v.id,
				job = v.job,
				sex = v.sex,
				serverid = server.serverid,
				shows = player.role:GetShows(),
				-- fightData = server.dataPack:FightInfo(player),
				})
		end
	end
	self:SendWar("RobotSign", dbList)
end

function QualifyingMgr:UpdateMsg(msg)
	self.msg = msg
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	--广播给符合条件的玩家
	local players = server.playerCenter:GetOnlinePlayers()
	for _,player in pairs(players) do
		if player.cache.level >= openConfig[baseConfig.openlv].conditionnum then
			self:GetMsg(player.dbid)
		end
	end
end

function QualifyingMgr:UpdateRank(rank)
	self.rank = rank
	self:packRankInfo()
end

function QualifyingMgr:PreliminaryMail(dbid, rank, rankNo, iswin)
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	local primaryConfig = server.configCenter.XianDuMatchPrimaryConfig
	local title = baseConfig.mailtitle0
	local msg
	local reward
	if iswin then
		msg = string.format(baseConfig.mailwin0, rankNo)
	else
		msg = baseConfig.maillose0
	end
	for k,v in pairs(primaryConfig[rank]) do
		if v.rewardwin[1] <= rankNo and (not v.rewardwin[2] or rankNo <= v.rewardwin[2]) then
			reward = v.reward
			break
		end
	end
	server.mailCenter:SendMail(dbid, title, msg, reward, self.YuanbaoRecordType, "仙道会预选")
end

function QualifyingMgr:FightMail(dbid, fightNum, rank, iswin)
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	local outConfig = server.configCenter.XianDuMatchOutConfig
	local title = baseConfig["mailtitle"..fightNum]
	local msg
	local reward
	if iswin then
		msg = baseConfig["mailwin"..fightNum]
		reward = outConfig[fightNum][rank].rewardwin
	else
		msg = baseConfig["maillose"..fightNum]
		reward = outConfig[fightNum][rank].rewardlose
	end
	server.mailCenter:SendMail(dbid, title, msg, reward, self.YuanbaoRecordType, "仙道会淘汰")
end

function QualifyingMgr:GambleMail(dbid, typ, iswin)
	local stakeBaseConfig = server.configCenter.XianDuMatchStakeBaseConfig
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	local title = baseConfig.mailtitle5
	local reward
	local msg = ""
	if iswin then
		reward = stakeBaseConfig[typ].rewardwin
		msg = baseConfig.mailwin5
	else
		reward = stakeBaseConfig[typ].rewardlose
		msg = baseConfig.maillose5
	end
	server.mailCenter:SendMail(dbid, title, msg, reward, self.YuanbaoRecordType, "仙道会")

end

function QualifyingMgr:QualifyingInfoRes(dbid)
	self:GetMsg(dbid)
end

function QualifyingMgr:GetRank(rankNo)
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	for i=1,4 do
		local data = baseConfig["rank"..i]
		if data[1] <= rankNo and rankNo <= data[2] then 
			return i
		end
	end
end

function QualifyingMgr:GetMsg(dbid)	
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return end

	local rank = self:GetRank(rankNo)
	if not rank then return end

	if not self.msg then
		self.msg = self:CallWar("GetMsg")
	end
	if not self.msg then return end

	local gamble, signTyp, rank = self:CallWar("GetGambleMsg", dbid, server.serverid, rank)
	
	local msg = table.wcopy(self.msg[rank])
	msg.sign = signTyp
	msg.gamble = gamble
	server.sendReqByDBID(dbid, "sc_qualifyingMgr_info_res", msg)
end

function QualifyingMgr:GetMiniMsg(dbid)
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return end
	if not self:GetRank(rankNo) then return end
	if not self.rank then
		self.rank = self:CallWar("GetRank")
	end
	if not self.rank then return end
	if not self.miniRank then
		self:packRankInfo()
	end
	local typ, ret, rank, timeout, rankNo, point = self:CallWar("GetMiniMsg", dbid, server.serverid)
	if not typ then return end
	local msg = {
		ret = ret,
		rank_data = self.miniRank[rank],
		timeout = timeout,
		rankNo = rankNo,
		point = point,
	}
	server.sendReqByDBID(dbid, "sc_qualifyingMgr_map_info_res", msg)
	-- local fightRecordList, rankNo, point = self:CallWar("GetFightRecord", dbid, server.serverid, rank)
	-- local msg = {}

end

function QualifyingMgr:packRankInfo()
	self.miniRank = {}
	for k,v in pairs(self.rank) do
		self.miniRank[k] = {}
		for kk,vv in ipairs(v) do
			if kk > 3 then break end
			table.insert(self.miniRank[k], vv)
		end
	end
end

function QualifyingMgr:GetTimeOut(dbid)
	local ret, timeout = self:CallWar("GetTimeOut", dbid)
	return {ret = ret, timeout = timeout}
end

function QualifyingMgr:Gamble(dbid, field, no, typ)
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return {ret = false} end
	local rank = self:GetRank(rankNo)
	if not rank then return {ret = false} end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	--需要弄一个模块去存玩家在哪个场rank
	local stakeBaseConfig = server.configCenter.XianDuMatchStakeBaseConfig

	if not player:CheckRewards({stakeBaseConfig[typ].cost}) then return {ret = false} end
	server.dailyActivityCenter:SendJoinActivity("qualifying", dbid)
	local ret = self:CallWar("Gamble", dbid, server.serverid, rank, field, no, typ)
	if ret then
		player:PayRewards({stakeBaseConfig[typ].cost}, self.YuanbaoRecordType)
	end
	local msg = {
		ret = ret,
	}
	return msg
end

function QualifyingMgr:Rank(dbid)
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return {} end
	local rank = self:GetRank(rankNo)
	if not rank then return {} end
	if not self.rank then
		self.rank = self:CallWar("GetRank")
	end
	if not self.rank then return end
	local fightRecordList, rankNo, point, rank = self:CallWar("GetFightRecord", dbid, server.serverid, rank)
	local msg = {}
	msg.rank_data = table.wcopy(self.rank[rank])
	msg.fightRecord = fightRecordList
	msg.rankNo = rankNo
	msg.point = point

	return msg
end

function QualifyingMgr:Video(dbid,the,field,round)
	local rankNo = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", RankConfig.RankType.POWER, dbid)
	if not rankNo then return end
	local rank = self:GetRank(rankNo)
	if not rank then return end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self:CallWar("GetVideo", dbid, the, rank, field, round)
end

function QualifyingMgr:UpdataPlayer(dataList)
	local data = {}
	for _,v in pairs(dataList) do
		local player = server.playerCenter:DoGetPlayerByDBID(v.dbid)
		if player then
			table.insert(data,{
				dbid = v.dbid,
				rank = v.rank,
				lv = player.cache.level,
				name = player.cache.name,
				power = player.cache.totalpower,
				shows = player.role:GetShows(),
				-- fightData = server.dataPack:FightInfo(player),
			})
		end
	end
	if next(data) then
		self:CallWar("UpdataPlayerData", data)
	end
end

function QualifyingMgr:GetFightData(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	return server.dataPack:FightInfo(player)
end

function server.QualifyingLogicCall(src, funcname, ...)
	lua_app.ret(server.qualifyingMgr[funcname](server.qualifyingMgr, ...))
end

function server.QualifyingLogicSend(src, funcname, ...)
	server.qualifyingMgr[funcname](server.qualifyingMgr, ...)
end

server.SetCenter(QualifyingMgr, "qualifyingMgr")
return QualifyingMgr
