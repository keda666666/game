local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local ClimbLayer = require "climb.ClimbLayer"
local ItemConfig = require "resource.ItemConfig"
local WarReport = require "warReport.WarReport"
local _FirstLayer = 1
local _LastLayer = 9

-- self.layerlist 九重天层数列表
-- self.playerlayer 玩家的层数
-- self.scorelist 玩家积分列表

-- 九重天一场小战区的主控文件
local ClimbMap = oo.class()

function ClimbMap:ctor(index, center)
	self.index = index
	self.center = center
end

function ClimbMap:Release()

end

function ClimbMap:Init()
	self.layerlist = {}
	self.playerlayer = {}
	self.scorelist = {}
	self.playerserver = {}
	self.ranklist = {}
	self.leavetime = {}
	self.warReport = WarReport.new("sc_climb_report")

	for i = _FirstLayer, _LastLayer do
		local layer = ClimbLayer.new(i, self)
		layer:Init()
		self.layerlist[i] = layer
	end

	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	self.kingrewards = server.dropCenter:DropGroup(ClimbTowerBaseConfig.kingreward)
	local config = server.configCenter.ClimbTowerBaseConfig
	self.kingrewardstr = string.format(config.chatkingreward, ItemConfig:ItemString(self.kingrewards))
	self.king = 0
end

function ClimbMap:End()
	-- 全踢出地图
	-- for _, layer in pairs(self.layerlist) do
	-- 	layer:End()
	-- end

	local king = server.playerCenter:GetPlayerByDBID(self.king)
	if king then
		self.warReport:AddShareData({
			shows = king.role:GetEntityShows(),
			serverid = king.nowserverid,
		})
		king.role.titleeffect:DoActivatePart(server.configCenter.ClimbTowerBaseConfig.titleid)
	end

	self.king = 0

	-- 未领积分奖励通过邮件发送
	local config = server.configCenter.ClimbTowerBaseConfig
	local title = config.scoretitle
	local content = config.scorecontent
	local serverreward = {}
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	for dbid, scoreinfo in pairs(self.scorelist) do
		for _, task in pairs(ClimbTowerBaseConfig.scoretask) do
			local rewards = {}
			if scoreinfo.score >= task.score and not scoreinfo.reward[task.score] then
				table.insert(rewards, {type = ItemConfig.AwardType.Item, id = task.item, count = task.num})
			end
			if #rewards > 0 then
				local serverid = self.playerserver[dbid]
				if serverid then
					serverreward[serverid] = serverreward[serverid] or {}
					serverreward[serverid][dbid] = {rewards = rewards, title = title, content = content}
				end
			end
		end
	end
	for serverid, playerlist in pairs(serverreward) do
		self.center:SendOne(serverid, "SendMailReward", playerlist)
	end

	--积分排名奖励
	local ClimbTowerRewardConfig = server.configCenter.ClimbTowerRewardConfig[1]
	local titlerank = config.climbranktitle
	local serverrewardrank = {}
	local order = {}
	for dbid, v in pairs(self.scorelist) do
		v.dbid = dbid
		table.insert(order, v)
	end
	table.sort(order, function(a, b)
			return a.score > b.score
		end)
	for i=1,20 do
		local playerscore = order[i]
		if playerscore then
			for _, rankreward in pairs(ClimbTowerRewardConfig) do
				if rankreward.min <= i and i <= rankreward.max then
					local dbid = playerscore.dbid
					local serverid = self.playerserver[dbid]
					if serverid then
						local contentrank = string.format(config.climbrankcontent, i)
						serverrewardrank[serverid] = serverrewardrank[serverid] or {}
						serverrewardrank[serverid][dbid] = {rewards = table.wcopy(rankreward.reward), title = titlerank, content = contentrank}
					end
				end
			end
		end
	end
	for serverid, playerlist in pairs(serverrewardrank) do
		for dbid, mailinfo in pairs(playerlist) do
			self.warReport:AddRewards(dbid, mailinfo.rewards)
		end
		self.center:SendOne(serverid, "SendMailReward", playerlist)
	end
	self.warReport:BroadcastReport()
end

function ClimbMap:LayerDo(dbid, funcname, ...)
	print("ClimbMap:LayerDo ", dbid, funcname)
	local layerid = self.playerlayer[dbid]
	if not layerid then
		print("ClimbMap:Do player not in the layer", dbid)
		return
	end

	local layer = self.layerlist[layerid]
	if layer[funcname] then
		return layer[funcname](layer, ...)
	end
end

-- 进入的都是从第一关开始
function ClimbMap:Enter(dbid)
	if not self.scorelist[dbid] then
		self.scorelist[dbid] = {score = 0, reward = {}}
	end

	self.playerlayer[dbid] = _FirstLayer

	local player = server.playerCenter:GetPlayerByDBID(dbid)
	self.playerserver[dbid] = player.nowserverid

	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local baseinfo = player:BaseInfo()
	baseinfo.serverid = player.nowserverid
	self.center.playerbaseinfo[dbid] = baseinfo

	self.layerlist[_FirstLayer]:Enter(dbid)
	self:GetScoreInfo(dbid)
	self.warReport:AddPlayer(dbid)
	print("ClimbMap:Enter--------- ", dbid)
	return true
end

function ClimbMap:Leave(dbid)
	self.leavetime[dbid] = lua_app.now()
	self:LayerDo(dbid, "Leave", dbid)
	self.playerlayer[dbid] = nil

	if dbid == self.king then
		print("ClimbMap:onLogout the king logout", self.king)
		self.king = 0
		local currpower = 0
		local currking = 0
		for playerid, climbplayer in pairs(self.layerlist[_LastLayer].playerlist) do
			if climbplayer.playerinfo.power > currpower then
				currpower = climbplayer.playerinfo.power
				currking = climbplayer.dbid
			end
		end
		if currpower ~= 0 and currking ~= 0 then
			server.mapCenter:SetTitle(currking, server.configCenter.ClimbTowerBaseConfig.titleid)
			self.king = currking
			self.layerlist[_LastLayer]:BroadcastKing()
		end
	end
end

-- 每分钟定时器
function ClimbMap:MinuteDeal()
	for _, layer in pairs(self.layerlist) do
		layer:MinuteDeal()
	end

	if self.king and self.king ~= 0 then
		local player = server.playerCenter:GetPlayerByDBID(self.king)
		if player then
			player:GiveRewardAsFullMailDefault(self.kingrewards, "九重天", server.baseConfig.YuanbaoRecordType.Climb)
			player.server.chatCenter:ChatSysInfo(self.king, self.kingrewardstr)
		end
	end
end

-- 每5秒
function ClimbMap:Sec5Deal()
	for _, layer in pairs(self.layerlist) do
		layer:Sec5Deal()
	end
end

-- 进入下一层
function ClimbMap:Next(dbid)
	local currlayer = self.playerlayer[dbid]
	if not currlayer then
		print("ClimbMap:Next no currlayer", dbid)
		return
	end

	if currlayer == _LastLayer then
		print("ClimbMap:Next in the last layer", dbid, currlayer)
		return
	end

	local nextlayer = currlayer + 1
	self.playerlayer[dbid] = nextlayer
	self.layerlist[currlayer]:Leave(dbid)
	self.layerlist[nextlayer]:Enter(dbid)
	
	if nextlayer == _LastLayer then
		if not self.king or self.king == 0 then
			server.mapCenter:SetTitle(dbid, server.configCenter.ClimbTowerBaseConfig.titleid)
			self.king = dbid
			self.layerlist[_LastLayer]:BroadcastKing()
			self.layerlist[_LastLayer]:BroadcastKingFirst()
		end
	end

	self:GetScoreInfo(dbid)
end

-- 退到上一层
function ClimbMap:Back(dbid)
	local currlayer = self.playerlayer[dbid]
	if not currlayer then
		print("ClimbMap:Back no currlayer", dbid)
		return
	end

	if currlayer == _FirstLayer then
		print("ClimbMap:Back in the last layer", dbid, currlayer)
		return
	end

	local backlayer = currlayer - 1
	self.playerlayer[dbid] = backlayer
	self.layerlist[currlayer]:Leave(dbid)
	self.layerlist[backlayer]:Enter(dbid)

	self:GetScoreInfo(dbid)
end

function ClimbMap:AddScore(dbid, score)
	self.scorelist[dbid].score = self.scorelist[dbid].score + score
	self:GetScoreInfo(dbid)
	self:ToRank()
	print("ClimbMap:AddScore----------", dbid, score)
end

function ClimbMap:ToRank()
	if self.ranktimer then return end

	local function _RankScore()
		if self.ranktimer then
			lua_app.del_timer(self.ranktimer)
			self.ranktimer = nil
		end
		self.ranklist = {}
		for dbid, scoreinfo in pairs(self.scorelist) do
			table.insert(self.ranklist, {dbid = dbid, score = scoreinfo.score})
		end
		table.sort(self.ranklist, function(a, b)
			return a.score > b.score
		end)
	end

	self.ranktimer = lua_app.add_timer(1500, _RankScore)
end

function ClimbMap:GetCurrRank(dbid)
	local msg = self:CurrRankMsg()
	server.sendReqByDBID(dbid, "sc_climb_curr_rank", msg)
end

function ClimbMap:CurrRankMsg()
	local msg = {}
	msg.ranklist = {}
	for rank, scoreinfo in pairs(self.ranklist) do
		if rank >= 20 then
			break
		end
		local baseinfo = self.center.playerbaseinfo[scoreinfo.dbid]
		table.insert(msg.ranklist, {dbid = scoreinfo.dbid, rank = rank, serverid = baseinfo.serverid, name = baseinfo.name, score = scoreinfo.score})
	end
	msg.king = self.king
	return msg
end

function ClimbMap:GetClimbInfo(dbid)
	local msg = {}
	msg.score = self.scorelist[dbid].score
	msg.rewardsocre = self:GetCurrRewardScore(dbid)
	msg.fighting = self:LayerDo(dbid, "GetFighting")
	msg.monsters = self:LayerDo(dbid, "GetMonsterMsg")
	msg.king = self.king
	server.sendReqByDBID(dbid, "sc_climb_info", msg)
	print("ClimbMap:GetClimbInfo", dbid)
end

function ClimbMap:GetScoreInfo(dbid)
	local msg = {}
	msg.score = self.scorelist[dbid].score
	msg.rewardsocre = self:GetCurrRewardScore(dbid)
	server.sendReqByDBID(dbid, "sc_climb_score_info", msg)
end

function ClimbMap:GetCurrRewardScore(dbid)
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	local rewardscorelist = self.scorelist[dbid].reward
	local maxscore = 0
	for score, _ in pairs(rewardscorelist) do
		if score > maxscore then
			maxscore = score
		end
	end

	local currscore = maxscore
	for _, task in pairs(ClimbTowerBaseConfig.scoretask) do
		if task.score > maxscore then
			currscore = task.score
			break
		end
	end
	if currscore == maxscore then
		currscore = -1
	end

	print("ClimbMap:GetCurrRewardScore--------", currscore)
	return currscore
end

function ClimbMap:GetReward(dbid)
	local score = self:GetCurrRewardScore(dbid)
	if score < 0 then return end
	local scoreinfo = self.scorelist[dbid]
	if not scoreinfo then return end
	if scoreinfo.reward[score] then return end
	if scoreinfo.score < score then return end

	local rewardtask
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	for _, task in pairs(ClimbTowerBaseConfig.scoretask) do
		if task.score == score then
			rewardtask = task
		end
	end

	if not rewardtask then return end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return end
	scoreinfo.reward[score] = true
	local rewards = {{type = ItemConfig.AwardType.Item, id = rewardtask.item, count = rewardtask.num}}
	player:GiveRewardAsFullMailDefault(rewards, "九重天", server.baseConfig.YuanbaoRecordType.Climb)
	self:GetScoreInfo(dbid)
end

function ClimbMap:GetMapLine(dbid, mapid)
	local linebase = self.index * 1000
	local linedefault = linebase + 1
	local floor
	local ClimbTowerConfig = server.configCenter.ClimbTowerConfig
	for _, v in pairs(ClimbTowerConfig) do
		if v.sceneid == mapid then
			floor = v.floor
		end
	end

	if not floor then return linedefault end

	local limit
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	for _, v in pairs(ClimbTowerBaseConfig.branch) do
		if floor == v.floor then
			limit = v.limit
		end
	end

	if not limit then return linedefault end

	local count = self.layerlist[floor]:GetCount()
	return (linebase + math.ceil(count / limit))
end

function ClimbMap:BroadcastServerMod(...)
	local serverlist = self.center.mapserver[self.index]
	if not serverlist then return end
	for _, serverid in pairs(serverlist) do
		server.serverCenter:SendOneMod("logic", serverid, ...)
	end
end

return ClimbMap

