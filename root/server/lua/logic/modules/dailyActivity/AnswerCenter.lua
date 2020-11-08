local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local AnswerCenter = {}

local optionList={
	{1,2,3,4},{1,2,4,3},{1,3,2,4},{1,3,4,2},{1,4,2,3},{1,4,3,2},
	{2,1,3,4},{2,1,4,3},{2,3,1,4},{2,3,4,1},{2,4,1,3},{2,4,3,1},
	{3,1,2,4},{3,1,4,2},{3,2,1,4},{3,2,4,1},{3,4,1,2},{3,4,2,1},
	{4,1,2,3},{4,1,3,2},{4,2,1,3},{4,2,3,1},{4,3,1,2},{4,3,2,1},
}

function AnswerCenter:Init()
	self.playerList = {} --玩家数据
	self.operationList = {} --每轮玩家答题数据
	self.answerList = {} --题目
	self.rankList = {} --排行榜
	self.rankListMin = {}
	self.rankListMin3 = {}
	self.champion = ""
	self.type = 0 -- 0活动没开 1开启答题状态 2答题结束等待下一题阶段
	self.answerNum = 1
	self.answerMax = 0
	self.now = 0
	self.time_rum = ""
end

function AnswerCenter:AnswerStart(firstAward)
	self.type = 1
	self.now = lua_app.now()
	local players = server.playerCenter:GetOnlinePlayers()
	local msg = {}

	local ti = self:TimeOut()
	if firstAward then
		for _,player in pairs(players) do
			local msg = self:packInfo(player.dbid, ti)
			server.sendReq(player, "sc_answer_info", msg)
		end
	else
		for _,player in pairs(players) do
			local msg = self:packUpInfo(player.dbid, "type","answerNum","answerNo","answerList","timeout","operation")
			server.sendReq(player, "sc_answer_update", msg)
		end
	end
	local baseConfig = server.configCenter.AnswerBaseConfig
	self.time_rum = lua_app.add_update_timer(baseConfig.answertime * 1000, self, "AnswerEnd")
end

function AnswerCenter:AnswerEnd()
	self.type = 2
	self.now = lua_app.now()
	local players = server.playerCenter:GetOnlinePlayers()
	local fractionConfig = server.configCenter.AnswerFractionConfig
	for _,player in pairs(players) do
		if self.minLv <= player.cache.level then
			if not self.operationList[player.dbid] then
				if not self.playerList[player.dbid] then
					self.playerList[player.dbid] = {
						dbid = player.dbid,
						name = player.cache.name,
						point = 0,
						rankNo = 0,
					}
				end
				local point = self.playerList[player.dbid].point
				self.playerList[player.dbid].point = point + fractionConfig[self.answerNum].errorscore
				player.answer:AddAnswer()
			end
		end
	end

	self.rankList = {}
	self.rankListMin = {}
	self.rankListMin3 = {}
	for k,v in pairs(self.playerList) do
		local data = table.wcopy(v)
		table.insert(self.rankList, data)
	end

	table.sort(self.rankList, function(a,b) return a.point > b.point end)

	for k,v in pairs(self.rankList) do
		self.playerList[v.dbid].rankNo = k
	end
	local baseConfig = server.configCenter.AnswerBaseConfig
	for k,v in ipairs(self.rankList)do
		table.insert(self.rankListMin, v)
		if k <= 3 then
			table.insert(self.rankListMin3, v)
		end
		if k > baseConfig.rankmax then
			break
		end
	end

	local ti = self:TimeOut()
	local players = server.playerCenter:GetOnlinePlayers()
	
	for _,player in pairs(players) do
		if self.minLv <= player.cache.level then
			local msg = self:packInfo(player.dbid, ti)
			server.sendReq(player, "sc_answer_info", msg)
		end
	end
	self.operationList = {}
	self.answerNum = self.answerNum + 1

	local baseConfig = server.configCenter.AnswerBaseConfig
	self.time_rum = lua_app.add_update_timer(baseConfig.nexttime * 1000, self, "NextAnswer")
end

function AnswerCenter:NextAnswer()
	if self.answerNum <= self.answerMax then
		self:AnswerStart()
	else
		-- 答题结束进入结算界面
		self:Settlement()
		server.dailyActivityCenter:SetAnswer(false)
	end
end

function AnswerCenter:Settlement()
	local data = self.rankList[1] or {}
	self.champion = data.name or "虚位以待"
	local baseConfig = server.configCenter.AnswerBaseConfig
	local awardConfig = server.configCenter.AnswerAwardConfig
	self.type = 0
	for k,v in pairs(self.rankList) do
		for _,vv in ipairs(awardConfig) do
			if vv.rank[1] <= k and (not vv.rank[2] or k <= vv.rank[2]) then
				local reward = vv.reward
				local mailtitle = baseConfig.mailtitle
				local maildes = string.format(baseConfig.maildes, k)
				server.mailCenter:SendMail(v.dbid, mailtitle, maildes, reward, self.YuanbaoRecordType, "答题活动")
				local msg = {
					point = v.point,
					rankNo = k,
					rewards = reward,
				}
				server.sendReqByDBID(v.dbid, "sc_answer_reward", msg)
				local msg = self:packUpInfo(v.dbid,"type")
				server.sendReqByDBID(v.dbid, "sc_answer_update", msg)
				break
			end
		end
	end
	
	server.dailyActivityCenter:updateData("answer", self.champion)
	server.serverCenter:SendLogicsMod("noticeCenter", "Notice", baseConfig.winnotice, self.champion)

	self.playerList = {} --玩家数据
	self.operationList = {} --每轮玩家答题数据
	self.answerList = {} --题目
	self.rankList = {} --排行榜

	self.answerNum = 1
end

function AnswerCenter:AStart()
	self.playerList = {} --玩家数据
	self.operationList = {} --每轮玩家答题数据
	self.answerList = {} --题目
	self.rankList = {} --排行榜
	self.type = 0
	self.answerNum = 1
	lua_app.del_local_timer(self.time_rum)
	self.time_rum = ""
	self:Start()
end

function AnswerCenter:PlayerLogin(dbid)
	if self.type == 0 then return end
	local ti = self:TimeOut()
	local msg = self:packInfo(dbid,ti)
	server.sendReqByDBID(dbid, "sc_answer_info", msg)
end


function AnswerCenter:Start()
	if self.type ~= 0 then return end
	local baseConfig = server.configCenter.AnswerBaseConfig
	self.answerMax = baseConfig.answermax --读配置
	local questionConfig = server.configCenter.AnswerQuestionConfig
	local allanswer = #questionConfig
	if self.answerMax > allanswer then 
		lua_app.log_error("answerMax is greater than #questionConfig！")
		return
	end
	local answerList = {}
	local answerNum = 0
	local option = #optionList
	while answerNum <= self.answerMax do
		local no = math.random(1, allanswer)
		if not answerList[no] then
			answerList[no] = optionList[math.random(1, option)]
			answerNum = answerNum + 1
		end
	end

	for k,v in pairs(answerList) do
		table.insert(self.answerList, {no = k, optionList = v})
	end
	local baseConfig = server.configCenter.AnswerBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	self.minLv = openConfig[baseConfig.open].conditionnum
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Answer
	self:AnswerStart(true)
	server.dailyActivityCenter:SetAnswer(true)
end

function AnswerCenter:Answer(dbid, name, answerNo, answer)
	if self.type ~= 1 then return end
	if self.operationList[dbid] then return end
	if self.answerNum ~= answerNo then return end
	server.dailyActivityCenter:SendJoinActivity("answer", dbid)
	local res = self.answerList[answerNo].optionList[answer] == 1
	local baseConfig = server.configCenter.AnswerBaseConfig
	local ti = lua_app.now() - self.now
	local fractionConfig = server.configCenter.AnswerFractionConfig
	local data = fractionConfig[answerNo]
	self.operationList[dbid] = answer
	local point = 0
	if res then
		point = data.yesscore + data.addscore * ti
	else
		point = data.errorscore + data.addscore * ti
	end
	if not self.playerList[dbid] then
		self.playerList[dbid] = {
			dbid = dbid,
			name = name,
			point = 0,
			rankNo = 0,
		}
	end
	self.playerList[dbid].point = self.playerList[dbid].point + point
	
	local ti = self:TimeOut()
	local msg = self:packUpInfo(dbid, "point","operation","timeout")
	server.sendReqByDBID(dbid, "sc_answer_update", msg)
end

function AnswerCenter:Ui(dbid)
	if self.type == 0 then return {ret = false} end
	
	local ti = self:TimeOut()
	local msg = self:packInfo(dbid,ti)
	server.sendReqByDBID(dbid, "sc_answer_info", msg)
	return {ret = true}
end

function AnswerCenter:Rank(dbid)
	if self.type == 0 then return end
	local msg ={
		rank = self.rankListMin,
	}
	server.sendReqByDBID(dbid, "sc_answer_rank_res", msg)
end

function AnswerCenter:TimeOut()
	local ti = 0
	local baseConfig = server.configCenter.AnswerBaseConfig
	if self.type == 1 then
		ti = baseConfig.answertime
	else
		ti = baseConfig.nexttime
	end
	return math.max(ti - (lua_app.now() - self.now), 0)
end

function AnswerCenter:packInfo(dbid, ti)
	local data = self.playerList[dbid] or {}
	print("answerNum=1===",self.answerNum)
	local msg = {
		type = self.type,
		rank = self.rankListMin3,
		answerNum = self.answerNum,
		answerNo = self.answerList[self.answerNum].no,
		answerList = self.answerList[self.answerNum].optionList,
		point = (data.point or 0),
		rankNo = (data.rankNo or 0),
		operation = (self.operationList[dbid] or 0),
		timeout = ti,
	}
	return msg
end

function AnswerCenter:packUpInfo(dbid, ...)
	local args = {...}
	local msg = {}
	print("answerNum=2===",self.answerNum)
	for _,v in pairs(args) do
		if v == "answerNo" then
			msg.answerNo = self.answerList[self.answerNum].no
		elseif v == "answerList" then
			msg.answerList = self.answerList[self.answerNum].optionList
		elseif v == "point" then
			local data = self.playerList[dbid] or {}
			msg.point = data.point or 0
		elseif v == "operation" then
			msg.operation = (self.operationList[dbid] or 0)
		elseif v == "timeout" then
			msg.timeout = self:TimeOut()
		else
			msg[v]=self[v]
		end
	end
	return msg
end

server.SetCenter(AnswerCenter, "answerCenter")
return AnswerCenter
