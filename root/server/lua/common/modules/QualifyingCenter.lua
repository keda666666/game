local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local lua_util = require "lua_util"
local tbname = server.GetSqlName("wardatas")
local tbpdata = server.GetSqlName("qualifying_player")
local tbrecord = server.GetSqlName("qualifying_record")
-- local tbcolumn = "qualifying"
local tbaudition = "qualifying_audition"
-- local tbrecord = "qualifying_record"
local tbauditionFight = "qualifying_auditionFight"
local tbrank = "qualifying_rank"
local tbkey = "qualifying_key"
local tblast = "qualifying_last"
local tbthe = "qualifying_the"
local tbbets = "qualifying_bets"

local cdTime = 60
local cdTime16 = 120
local cdTime8 = 120
local cdTime4 = 120
local cdTime2 = 120

local QualifyingCenter = {}

QualifyingCenter.The4Type = {}
QualifyingCenter.The4Type[4] = 16
QualifyingCenter.The4Type[6] = 8
QualifyingCenter.The4Type[8] = 4
QualifyingCenter.The4Type[10] = 2

QualifyingCenter.rank4Num = {1,2,3,4}

function QualifyingCenter:Load()
	self.playerList = {}
	local data = server.mysqlBlob:LoadDmg(tbpdata)
	for _,v in pairs(data) do
		self.playerList[v.dbid] = v
	end
end

function QualifyingCenter:Init()
	if not server.serverCenter:IsCross() then return end
	self.robotList = {}
	self:Load()
	self.Video = {}
	self.cache_audition = server.mysqlBlob:LoadUniqueDmg(tbname, tbaudition)
	self.cache_auditionfight = server.mysqlBlob:LoadUniqueDmg(tbname, tbauditionFight)
	self.cache_rank = server.mysqlBlob:LoadUniqueDmg(tbname, tbrank)
	self.cache_key = server.mysqlBlob:LoadUniqueDmg(tbname, tbkey)
	self.cache_last = server.mysqlBlob:LoadUniqueDmg(tbname, tblast)
	self.cache_the = server.mysqlBlob:LoadUniqueDmg(tbname, tbthe)
	self.cache_bets = server.mysqlBlob:LoadUniqueDmg(tbname, tbbets)
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.QualifyingCenter
end

function QualifyingCenter:Release()
	if not server.serverCenter:IsCross() then return end
	if self.cache_audition then
		self.cache_audition(true)
		self.cache_audition = nil
	end
	if self.cache_auditionfight then
		self.cache_auditionfight(true)
		self.cache_auditionfight = nil
	end
	if self.cache_rank then
		self.cache_rank(true)
		self.cache_rank = nil
	end
	if self.cache_key then
		self.cache_key(true)
		self.cache_key = nil
	end
	if self.cache_last then
		self.cache_last(true)
		self.cache_last = nil
	end
	if self.cache_the then
		self.cache_the(true)
		self.cache_the = nil
	end
	if self.cache_bets then
		self.cache_bets(true)
		self.cache_bets = nil
	end

	for _, cache in pairs(self.playerList) do
		cache(true)
	end
	self.playerList = {}
end

function QualifyingCenter:HotFix()
	if not server.serverCenter:IsCross() then return end
	print("QualifyingCenter:HotFix----------", self.cache_audition.typ, self.Round)
end

function QualifyingCenter:onHalfHour(hour, minute)
	if not server.serverCenter:IsCross() then return end
	local baseConfig = self:GetXianDuMatchBaseConfig()
	local wday = lua_app.week()
	print("QualifyingCenter:onHalfHour", self.cache_audition.typ)
	if wday == 1 then
		if self.cache_audition.typ == 12 then
			--重置所有数据
			self.cache_audition.typ = 0
			self:ClearKnockout()

			self:DoBroadcastMsg()
		end
		if self.cache_audition.typ == 0 then--报名
			local startTime = lua_util.split(baseConfig.enrolltime[1],":")
			local stopTime = lua_util.split(baseConfig.enrolltime[2],":")
			if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
			self:SignStart()
			self:DoBroadcastMsg()
			self.time_rum = lua_timer.add_timer_day(baseConfig.enrolltime[2], 1, self.SignStop, self)
		elseif self.cache_audition.typ == 2 then--海选
			local startTime = lua_util.split(baseConfig.preliminaries[1],":")
			local stopTime = lua_util.split(baseConfig.preliminaries[2],":")
			if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
			
			self.cache_audition.typ = 3
			self.Round = 1
			self.fightNum = 0
			self.residue = {0,0,0,0}
			-- self:CheckMan()--补齐人数
			self:FightStart()
			self:DoBroadcastMsg()
		end
	elseif wday == 2 then--16强
		if self.cache_audition.typ ~= 4 then return end
		local startTime = lua_util.split(baseConfig.knockouttime16[1],":")
		local stopTime = lua_util.split(baseConfig.knockouttime16[2],":")
		if hour == 20 and minute == 30 then
			self.time_rum = lua_app.add_update_timer(25 * 60 * 1000, self, "OpenMsg")
		end
		if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
		self.Round = 0
		self.fightNum = 1
		self.cache_audition.typ = 5
		self:Knockout16()
	elseif wday == 3 then
		if self.cache_audition.typ ~= 6 then return end
		local startTime = lua_util.split(baseConfig.knockouttime8[1],":")
		local stopTime = lua_util.split(baseConfig.knockouttime8[2],":")
		if hour == 20 and minute == 30 then
			self.time_rum = lua_app.add_update_timer(25 * 60 * 1000, self, "OpenMsg")
		end
		if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
		self.Round = 0
		self.fightNum = 2
		self.cache_audition.typ = 7
		self:Knockout8()
	elseif wday == 4 then
		if self.cache_audition.typ ~= 8 then return end
		local startTime = lua_util.split(baseConfig.knockouttime4[1],":")
		local stopTime = lua_util.split(baseConfig.knockouttime4[2],":")
		if hour == 20 and minute == 30 then
			self.time_rum = lua_app.add_update_timer(25 * 60 * 1000, self, "OpenMsg")
		end
		if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
		self.Round = 0
		self.fightNum = 3
		self.cache_audition.typ = 9
		self:Knockout4()
	elseif wday == 5 then
		if self.cache_audition.typ ~= 10 then return end
		local startTime = lua_util.split(baseConfig.knockouttime2[1],":")
		local stopTime = lua_util.split(baseConfig.knockouttime2[2],":")
		if hour == 20 and minute == 30 then
			self.time_rum = lua_app.add_update_timer(25 * 60 * 1000, self, "OpenMsg")
		end
		if hour < tonumber(startTime[1]) or hour >= tonumber(stopTime[1]) then return end
		self.Round = 0
		self.fightNum = 4
		self.cache_audition.typ = 11
		self:Knockout2()
	end

end

function QualifyingCenter:ClearKnockout()
	server.mysqlBlob:DelDmgs(tbpdata, self.playerList)
	server.mysqlBlob:DelDmgs(tbrecord, self.Video)
	self.playerList = {}
	self.Video = {}

	self.robotList = {}
	self.cache_audition.memberList = {}
	self.cache_audition.audition = {{},{},{},{},}--海选
end

function QualifyingCenter:ClearPromotion()
	self.cache_key.keyList = {}
	self.cache_rank.auditionRank = {{},{},{},{},} --海选排行榜
	self.cache_auditionfight.auditionFight = {{},{},{},{},}
	self.cache_last.lastData = {{},{},{},{},}
	self.cache_audition.recordNo = 1--录像编号
	self.cache_the.the16 = {{},{},{},{},}--16强名单
	self.cache_the.the8 = {{},{},{},{},}
	self.cache_the.the4 = {{},{},{},{},}
	self.cache_the.the2 = {{},{},{},{},}
	self.cache_bets.bets16 = {{},{},{},{},}--下注
	self.cache_bets.bets8 = {{},{},{},{},}
	self.cache_bets.bets4 = {{},{},{},{},}
	self.cache_bets.bets2 = {{},{},{},{},}
end

function QualifyingCenter:OpenMsg()
	self.fightTime = lua_app.now() + 300
	-- local num = self.The4Type[self.cache_audition.typ]
	-- self:SendLogics("openMsg", num)
	local data = {}
	for rank,dbidList in pairs(self.cache_last.lastData) do
		for dbid,_ in pairs(dbidList) do
			local pData = self:GetpData(dbid)
			if not data[pData.serverid] then
				data[pData.serverid] = {}
			end
			table.insert(data[pData.serverid], {dbid = dbid, rank = rank})
		end
	end

	for serverid,v in pairs(data) do
		self:SendOne(serverid, "UpdataPlayer", v)
	end

	self:SendOne(rankNo.serverid, "UpdataPlayer", {rank = k, dbid = dbid})
end

function QualifyingCenter:SignStart()
	--开启活动允许报名
	self.cache_audition.typ = 1
	--要不要来一发广播？
end

function QualifyingCenter:SignStop()
	--关闭报名
	self.cache_audition.typ = 2
	self.fightTime = lua_app.now() + 300
	self:ClearPromotion()
	self:BroadcastRank()

	local function _CheckMan()
			self:CheckMan()--补齐人数
		end
	self:SendLogics("GetRankPlayer")
	local data = {}
	for rank,dbidList in pairs(self.cache_audition.audition) do
		for _,dbid in pairs(dbidList) do
			local pData = self:GetpData(dbid)
			if not data[pData.serverid] then
				data[pData.serverid] = {}
			end
			table.insert(data[pData.serverid], {dbid = dbid, rank = rank})
		end
	end

	for serverid,v in pairs(data) do
		self:SendOne(serverid, "UpdataPlayer", v)
	end

	lua_app.add_timer(10 * 1000, _CheckMan)
	self:DoBroadcastMsg()
end

function QualifyingCenter:UpdataPlayerData(data)
	for k,v in pairs(data) do
		local pData = self:GetpData(v.dbid)
		pData.lv = v.lv
		pData.name = v.name
		pData.power = v.power
		pData.shows = v.shows
		pData.fightData = v.fightData
	end
end


function QualifyingCenter:FightStart()
	local fightData = self.cache_auditionfight.auditionFight
	local baseConfig = self:GetXianDuMatchBaseConfig()
	self.warNumList = {}
	if #fightData > 2 then
		for k,v in pairs(fightData) do
			self.warNumList[k] = 0
			for kk,dbid in pairs(v) do
				local data = self:GetpData(dbid)
				if data.fail < 3 then 
					local rand = self:GetEnemy(kk, data.enemyList, #v)
					table.insert(data.enemyList, rand)

					if server.playerCenter:IsOnline(dbid) and server.mapCenter:InMap(dbid, baseConfig.mapid) then

						local datas = {}
						datas.enemy = v[rand]
						datas.rank = k
						datas.atkDbid = dbid
						datas.fightType = 1
						if server.mapCenter:InMap(dbid, baseConfig.mapid) then
							datas.atkDbid = dbid
						end
						server.raidMgr:Enter(server.raidConfig.type.Qualifying, dbid, datas)
					else
						local enemy = self:GetpData(v[rand])
						local iswin = data.power >= enemy.power
						self:SetPreliminaryRes(k, dbid, v[rand], iswin, false)
					end
				end
			end
		end
	end
	local function NextFight()
		local tag = true
		self.Round = self.Round + 1
		for k,v in pairs(fightData) do
			if self.Round <= 3 or (#v - self.residue[k]) > 32 then
				tag = false
			end
		end

		local function _PreliminaryEnd()
				self:PreliminaryEnd()
			end
		if tag or self.Round >=30 then
			self.fightTime = nil
			lua_app.add_timer(2 * 1000, _PreliminaryEnd)
			return
		end
		
		self.fightTime = lua_app.now() + cdTime
		self.time_rum = lua_app.add_update_timer(cdTime * 1000, self, "FightStart")
	end
	self.time_rum = lua_app.add_timer(2 * 1000, NextFight)

end

function QualifyingCenter:SetPreliminaryRes(rank, dbid, enemy, iswin, msg)
	local baseConfig = self:GetXianDuMatchBaseConfig()
	local fightRecordList = {}
	local aData = self:GetpData(dbid)
	local bData = self:GetpData(enemy)
	fightRecordList.name1 = aData.name
	fightRecordList.server1 = aData.serverid
	fightRecordList.name2 = bData.name
	fightRecordList.server2 = bData.serverid

	local winPoint = baseConfig.winpoints
	local losePoint = baseConfig.losepoints
	if iswin then
		-- win
		fightRecordList.win = true
		aData.point = aData.point + winPoint
		
	else
		-- fail
		fightRecordList.win = false
		aData.fail = aData.fail + 1
		aData.point = aData.point + losePoint
		if aData.fail >= 3 then 
			self.residue[rank] = self.residue[rank] + 1
		end
	end

	if server.mapCenter:InMap(dbid, baseConfig.mapid) then
		self:WarMgs(dbid, iswin, {aData, bData}, {iswin, not iswin}, winPoint, losePoint)
	end

	self.warNumList[rank] = self.warNumList[rank] + 1
	if self.warNumList[rank] == #self.cache_auditionfight.auditionFight[rank] then
		local rankData = {}
		for _,dbid in pairs(self.cache_audition.audition[rank]) do
			local pData = self:GetpData(dbid)
			table.insert(rankData, table.wcopy(pData))
		end
		table.sort(rankData, function(a, b)
				return a.point > b.point
			end)
		--精简数据
		self.cache_rank.auditionRank[rank] = {}
		for _,v in ipairs(rankData) do
			table.insert(self.cache_rank.auditionRank[rank], {
				name = v.name,
				server = v.serverid,
				point = v.point,
				dbid = v.dbid,
			})
		end
		--------------
		-- self.cache_rank.auditionRank[rank] = rankData
		self:BroadcastRank()
		for k,v in pairs(self.cache_rank.auditionRank[rank]) do
			local data = self:GetpData(v.dbid)
			data.prank = k
		end
	end
	table.insert(aData.fightRecordList, fightRecordList)
end

function QualifyingCenter:WarMgs(dbid, iswin, pData, win, winPoint, losePoint)
	local msg = {roleData = {}}
	msg.win = iswin
	for k,v in pairs(pData) do
		local data = {
			win = win[k],
			name = v.name,
			serverid = v.serverid,
			level = v.lv,
			power = v.power,
		}
		if win[k] then
			data.addpoint = winPoint
		else
			data.addpoint = losePoint
		end
		table.insert(msg.roleData, data)
	end
	server.sendReqByDBID(dbid, "sc_qualifyingMgr_war_info", msg)
end

function QualifyingCenter:GetpData(dbid)
	return self.playerList[dbid] and self.playerList[dbid].data or nil
	-- return self.cache_audition.audition[rank][dbid]
end

function QualifyingCenter:GetEnemy(no, enemyList, num)
	while true do
		if num <= #enemyList then return 1 end
		local rand = math.random(num)
		if no ~= rand then
			local tag = true
			for k,v in pairs(enemyList) do
				if rand == v then
					tag = false
				end
			end
			if tag then
				return rand
			end
		end
	end
end

function QualifyingCenter:CheckMan()
	-- local robotList = {}
	local robotConfig = server.configCenter.XianDuMatchRobotConfig
	for rank,dbidList in pairs(self.cache_audition.audition) do
		local auditionFight = {}
		local small
		for _,dbid in pairs(dbidList) do
			local pData = self:GetpData(dbid)
			if not small then
				small = pData
			elseif small.power > pData.power then
				small = pData
			end
			table.insert(auditionFight, dbid)
		end
		local num = #auditionFight
		-- local fightData = self:CallOne(pData.serverid, "GetFightData", v)
		if num >= 2 and num < 16 then

			-- local robot = table.wcopy(small)
			for i = 1, (16 - num) do
				-- for k1,v1 in pairs(robot.fightData.playerinfo.attrs) do
				-- 	robot.fightData.playerinfo.attrs[k1] = math.ceil(v1 * 0.95)
				-- end
				--补充机器人
				-- 这里要调整机器人外观和技能职业性别
				local robotData = table.wcopy(self.robotList[math.random(#self.robotList)])
				robotData.name = robotConfig[i].name--名字
				robotData.rankNo = rank--场次
				-- robotData.fightData.playerinfo.attrs = table.wcopy(robot.fightData.playerinfo.attrs)
				-- robotData.fightData.playerinfo.name = robotConfig[i].name
				-- robotData.fightData.entitydatas[1].shows.name = robotConfig[i].name
				robotData.power = math.ceil(small.power * (0.7 - (i/100)))--战力
				robotData.lv = math.max((small.lv - math.random(10)), 10)
				robotData.fightNo = small.dbid
				robotData.smallServerid = small.serverid
				robotData.dbid = i + (self.rank4Num[rank] * 100)
				table.insert(auditionFight, robotData.dbid)
				local rData = {
					dbid = robotData.dbid,
					rank = rank,
					data = robotData,
				}
				local cache = server.mysqlBlob:CreateDmg(tbpdata, rData)
				self.playerList[robotData.dbid] = cache
				table.insert(self.cache_audition.audition[rank], robotData.dbid)
			end
		end
		if num >= 2 then
			self.cache_auditionfight.auditionFight[rank] = table.wcopy(auditionFight)
		end
	end
end

function QualifyingCenter:GetFightData(dbid)
	local pData = self:GetpData(dbid)
	if dbid > 9999 then
		local player = server.playerCenter:DoGetPlayerByDBID(dbid, pData.serverid)
		return player.server.dataPack:FightInfoByDBID(dbid)
	end
	
	local player1 = server.playerCenter:DoGetPlayerByDBID(pData.fightShow, pData.serverid)
	local fightData = player1.server.dataPack:FightInfoByDBID(pData.fightShow)

	if not self.RobotFight then
		local player2 = server.playerCenter:DoGetPlayerByDBID(pData.fightNo, pData.smallServerid)
		self.RobotFight = player2.server.dataPack:FightInfoByDBID(pData.fightNo)
	end
	for k1,v1 in pairs(self.RobotFight.playerinfo.attrs) do
		fightData.playerinfo.attrs[k1] = math.ceil(v1 * (0.7 - (0.03/100)))
	end

	fightData.playerinfo.name = pData.name
	fightData.entitydatas[1].shows.name = pData.name
	return fightData
end

function QualifyingCenter:PreliminaryEnd()
	--预选结束
	self.cache_audition.typ = 4
	self.cache_audition.memberList = {}
	for k,_ in pairs(self.cache_auditionfight.auditionFight) do
		table.sort(self.cache_auditionfight.auditionFight[k], function(a, b)
				local aData = self:GetpData(a)
				local bData = self:GetpData(b)
				return aData.point > bData.point 
			end)
	end
	--放入16强
	for k,v in pairs(self.cache_auditionfight.auditionFight) do
		local promotionList = {}
		for kk,vv in ipairs(v) do
			if kk <= 16 then
				--加入16强
				table.insert(promotionList, vv)
				self.cache_audition.memberList[vv] = 1
				self.cache_last.lastData[k][vv] = self:GetpData(vv)
				self:PreliminaryMail(vv, k, kk, true)
			else
				self:PreliminaryMail(vv, k, kk, false)
				--发奖励
			end
		end
		--打乱,不然按战力赢的话每次都是前面的赢了
		local dbid = 0
		local the16List = {}
		for k,v in pairs(lua_util.randArray2(promotionList)) do
			if dbid == 0 then
				dbid = v
			else
				table.insert(the16List, {
						noA = dbid,
						noB = v,
						record = {},
						winA = 0,
						winB = 0,
						fightRecord = {},
					})
				dbid = 0
			end
		end
		self.cache_the.the16[k] = the16List
	end
	local baseConfig = self:GetXianDuMatchBaseConfig()
	server.serverCenter:SendLogicsMod("noticeCenter", "Notice", baseConfig.liminariesnotice)

	self:DoBroadcastMsg()
end

function QualifyingCenter:Knockout16()
	local baseConfig = self:GetXianDuMatchBaseConfig()
	for k,v in pairs(self.cache_the.the16) do
		for kk,vv in pairs(v) do
			local datas = {}
			datas.rank = k
			datas.field = kk
			datas.enemy = vv.noB
			datas.the = "the16"
			datas.fightType = 2
			if server.playerCenter:IsOnline(vv.noA) and server.mapCenter:InMap(vv.noA, baseConfig.mapid) then
				datas.atkDbid = vv.noA
			end
			if server.playerCenter:IsOnline(vv.noB) and server.mapCenter:InMap(vv.noB, baseConfig.mapid) then
				datas.defDbid = vv.noB
			end
			server.qualifying:Enter(vv.noA, datas)
		end
	end
	local function _Knockout16End()
			self:Knockout16End()
		end

	self.Round = self.Round + 1
	if self.Round >=3 then
		self.fightTime = nil
		lua_app.add_timer(2 * 1000, _Knockout16End)
		return
	else
		self.fightTime = lua_app.now() + cdTime16
		self:DoBroadcastMsg()
	end
	self.time_rum = lua_app.add_update_timer(cdTime16 * 1000, self, "Knockout16")
end

function QualifyingCenter:SetKnockoutRes(the, rank, field, record, iswin)
	local data = self.cache_the[the][rank][field]
	if iswin then
		data.winA = data.winA + 1
		table.insert(data.fightRecord, 1)
	else
		data.winB = data.winB + 1
		table.insert(data.fightRecord, 2)
	end
	local no = self:SetVideo(record)
	table.insert(data.record, no)

	-- table.insert(data.record, table.wcopy(record))
	local aData = self:GetpData(data.noA)
	local bData = self:GetpData(data.noB)
	local baseConfig = self:GetXianDuMatchBaseConfig()
		if server.playerCenter:IsOnline(data.noA) and server.mapCenter:InMap(data.noA, baseConfig.mapid) then
		self:WarMgs(data.noA, iswin, {aData, bData}, {iswin, not iswin}, winPoint, losePoint)
	end
	if server.playerCenter:IsOnline(data.noB) and server.mapCenter:InMap(data.noB, baseConfig.mapid) then
		self:WarMgs(data.noB, not iswin, {aData, bData}, {not iswin, iswin}, winPoint, losePoint)
	end
end

function QualifyingCenter:Knockout16End()
	self.cache_audition.typ = 6
	self.cache_audition.memberList = {}
	for k,v in pairs(self.cache_the.the16) do
		local no = 0
		local the8List = {}
		for kk,vv in pairs(v) do
			local win = 0
			if vv.winA >= vv.winB then
				win = vv.noA
				vv.winNo = 1
			else
				win = vv.noB
				vv.winNo = 2
			end
			self.cache_audition.memberList[win] = 1
			if no == 0 then
				no = win
			else
				table.insert(the8List, {
					noA = no,
					noB = win,
					record = {},
					winA = 0,
					winB = 0,
					fightRecord = {},
				})
				no = 0
			end
			self:FightMail(vv.noA, k, vv.noA == win)
			self:FightMail(vv.noB, k, vv.noB == win)
			self:GambleCheck(16, k, kk, vv.winNo)
		end
		self.cache_the.the8[k] = the8List
	end
	self:DoBroadcastMsg()
end

function QualifyingCenter:Knockout8()
	local baseConfig = self:GetXianDuMatchBaseConfig()
	for k,v in pairs(self.cache_the.the8) do
		for kk,vv in pairs(v) do
			local noA = vv.noA
			local noB = vv.noB

			local datas = {}
			datas.rank = k
			datas.field = kk
			datas.enemy = vv.noB
			datas.the = "the8"
			datas.fightType = 2

			if server.playerCenter:IsOnline(vv.noA) and server.mapCenter:InMap(vv.noA, baseConfig.mapid) then
				datas.atkDbid = vv.noA
			end
			if server.playerCenter:IsOnline(vv.noB) and server.mapCenter:InMap(vv.noB, baseConfig.mapid) then
				datas.defDbid = vv.noB
			end
			server.qualifying:Enter(vv.noA, datas)
		end
	end
	local function _Knockout8End()
			self:Knockout8End()
		end

	self.Round = self.Round + 1
	if self.Round >=3 then
		self.fightTime = nil
		lua_app.add_timer(2 * 1000, _Knockout8End)
		return
	else
		self.fightTime = lua_app.now() + cdTime8
		self:DoBroadcastMsg()
	end
	
	self.time_rum = lua_app.add_update_timer(cdTime8 * 1000, self, "Knockout8")
end

function QualifyingCenter:Knockout8End()
	self.cache_audition.typ = 8
	self.cache_audition.memberList = {}
	for k,v in pairs(self.cache_the.the8) do
		local no = 0
		local the4List = {}
		for kk,vv in pairs(v) do
			local win = 0
			if vv.winA >= vv.winB then
				win = vv.noA
				vv.winNo = 1
			else
				win = vv.noB
				vv.winNo = 2
			end
			self.cache_audition.memberList[win] = 1
			if no == 0 then
				no = win
			else
				table.insert(the4List, {
					noA = no,
					noB = win,
					record = {},
					winA = 0,
					winB = 0,
					fightRecord = {},
				})
				no = 0
			end
			self:FightMail(vv.noA, k, vv.noA == win)
			self:FightMail(vv.noB, k, vv.noB == win)
			self:GambleCheck(8, k, kk, vv.winNo)
		end
		self.cache_the.the4[k] = the4List
	end
	self:DoBroadcastMsg()
end

function QualifyingCenter:Knockout4()
	local baseConfig = self:GetXianDuMatchBaseConfig()
	for k,v in pairs(self.cache_the.the4) do
		for kk,vv in pairs(v) do
			local noA = vv.noA
			local noB = vv.noB
			local datas = {}
			datas.rank = k
			datas.field = kk
			datas.enemy = vv.noB
			datas.the = "the4"
			datas.fightType = 2
			if server.playerCenter:IsOnline(vv.noA) and server.mapCenter:InMap(vv.noA, baseConfig.mapid) then
				datas.atkDbid = vv.noA
			end
			if server.playerCenter:IsOnline(vv.noB) and server.mapCenter:InMap(vv.noB, baseConfig.mapid) then
				datas.defDbid = vv.noB
			end
			server.qualifying:Enter(vv.noA, datas)
		end
	end
	local function _Knockout4End()
			self:Knockout4End()
		end

	self.Round = self.Round + 1
	if self.Round >=3 then
		self.fightTime = nil
		lua_app.add_timer(2 * 1000, _Knockout4End)
		return
	else
		self.fightTime = lua_app.now() + cdTime4
		self:DoBroadcastMsg()
	end
	
	self.time_rum = lua_app.add_update_timer(cdTime4 * 1000, self, "Knockout4")
end

function QualifyingCenter:Knockout4End()
	self.cache_audition.typ = 10
	self.cache_audition.memberList = {}
	for k,v in pairs(self.cache_the.the4) do
		local no = 0
		local the2List = {}
		for kk,vv in pairs(v) do
			local win = 0
			if vv.winA >= vv.winB then
				win = vv.noA
				vv.winNo = 1 
			else
				win = vv.noB
				vv.winNo = 2
			end
			self.cache_audition.memberList[win] = 1
			if no == 0 then
				no = win
			else
				table.insert(the2List, {
					noA = no,
					noB = win,
					record = {},
					winA = 0,
					winB = 0,
					fightRecord = {},
				})
				no = 0
			end
			self:FightMail(vv.noA, k, vv.noA == win)
			self:FightMail(vv.noB, k, vv.noB == win)
			self:GambleCheck(4, k, kk, vv.winNo)
		end
		self.cache_the.the2[k] = the2List
	end
	self:DoBroadcastMsg()
end

function QualifyingCenter:Knockout2()
	local baseConfig = self:GetXianDuMatchBaseConfig()
	for k,v in pairs(self.cache_the.the2) do
		for kk,vv in pairs(v) do
			local noA = vv.noA
			local noB = vv.noB
			local datas = {}
			datas.rank = k
			datas.field = kk
			datas.enemy = vv.noB
			datas.the = "the2"
			datas.fightType = 2
			if server.playerCenter:IsOnline(vv.noA) and server.mapCenter:InMap(vv.noA, baseConfig.mapid) then
				datas.atkDbid = vv.noA
			end
			if server.playerCenter:IsOnline(vv.noB) and server.mapCenter:InMap(vv.noB, baseConfig.mapid) then
				datas.defDbid = vv.noB
			end
			server.qualifying:Enter(vv.noA, datas)
		end
	end
	local function _Knockout2End()
			self:Knockout2End()
		end

	self.Round = self.Round + 1
	if self.Round >=3 then
		self.fightTime = nil
		lua_app.add_timer(2 * 1000, _Knockout2End)
		return
	else
		self.fightTime = lua_app.now() + cdTime2
		self:DoBroadcastMsg()
	end--最多3轮
	
	self.time_rum = lua_app.add_update_timer(cdTime2 * 1000, self, "Knockout2")
end

function QualifyingCenter:Knockout2End()
	self.cache_audition.typ = 12
	local nameList = {}
	for k,v in pairs(self.cache_the.the2) do
		nameList[k] = "无"
		for kk,vv in pairs(v) do
			if vv.winA >= vv.winB then
				vv.win = vv.noA
				vv.fail = vv.noB
				vv.winNo = 1
			else
				vv.win = vv.noB
				vv.fail = vv.noA
				vv.winNo = 2
			end
			self:FightMail(vv.noA, k, vv.noA == vv.win)
			self:FightMail(vv.noB, k, vv.noB == vv.win)
			self:GambleCheck(2, k, kk, vv.winNo)
			local pData = self:GetpData(vv.win)
			nameList[k] = pData.name
		end

	end
	local baseConfig = self:GetXianDuMatchBaseConfig()
	table.ptable(nameList,3)
	server.serverCenter:SendLogicsMod("noticeCenter", "Notice", baseConfig.winnotice, nameList[1], nameList[2], nameList[3], nameList[3])
	self:DoBroadcastMsg()
end

function QualifyingCenter:PreliminaryMail(dbid, rank, rankNo, iswin)
	if dbid < 999 then return end
	local serverid = self:GetpData(dbid).serverid
	self:SendOne(serverid, "PreliminaryMail", dbid, self.rank4Num[rank], rankNo, iswin)
end

function QualifyingCenter:FightMail(dbid, rank, iswin)
	if dbid < 999 then return end
	local serverid = self:GetpData(dbid).serverid
	self:SendOne(serverid, "FightMail", dbid, self.fightNum, self.rank4Num[rank], iswin)
end

function QualifyingCenter:GambleCheck(bets, rank, field, victory)
	local bets = "bets"..bets
	local data = self.cache_bets[bets][rank][field]
	if not data then return end
	for dbid,gamble in pairs(data) do
		local serverid = gamble.serverid

		self:SendOne(serverid, "GambleMail", dbid, gamble.typ, gamble.no == victory)
	end
end

local _xianDuMatchBaseConfig = false
function QualifyingCenter:GetXianDuMatchBaseConfig()
	if _xianDuMatchBaseConfig then return _xianDuMatchBaseConfig end
	_xianDuMatchBaseConfig = server.configCenter.XianDuMatchBaseConfig
	return _xianDuMatchBaseConfig
end

local _xianDuMatchStakeBaseConfig = false
function QualifyingCenter:GetXianDuMatchStakeBaseConfig()
	if _xianDuMatchStakeBaseConfig then return _xianDuMatchStakeBaseConfig end
	_xianDuMatchStakeBaseConfig = server.configCenter.XianDuMatchStakeBaseConfig
	return _xianDuMatchStakeBaseConfig
end

local _xianDuMatchOutConfig = false
function QualifyingCenter:GetXianDuMatchOutConfig()
	if _xianDuMatchOutConfig then return _xianDuMatchOutConfig end
	_xianDuMatchOutConfig = server.configCenter.XianDuMatchOutConfig
	return _xianDuMatchOutConfig
end

function QualifyingCenter:Sign(dbid, serverid, rankNo, power, name, job, sex, lv)
	if self.cache_audition.typ ~= 1 then return false end
	if self.cache_audition.audition[rankNo][dbid] then return false end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local pData = {
		dbid = dbid,
		rank = rankNo,
	 	data = {
			name = name,
			prank = 0,
			rankNo = rankNo,
			dbid = dbid,
			serverid = serverid,
			point = 0,
			power = power,--战力
			shows = player.role:GetShows(),
			-- fightData = player.server.dataPack:FightInfoByDBID(dbid),--战斗数据
			fail = 0,
			enemyList = {},
			fightRecordList = {},
			job = job,
			sex = sex,
			lv = lv,
		},
	}
	local cache = server.mysqlBlob:CreateDmg(tbpdata, pData)
	self.playerList[dbid] = cache
	table.insert(self.cache_audition.audition[rankNo], dbid)
	return true
end

function QualifyingCenter:RobotSign(dbList)
	for k,v in pairs(dbList) do
		local data = {
			name = "",--名字
			prank = 0,
			rankNo = "",--场次
			dbid = 0,--dbid
			serverid = v.serverid,
			point = 0,
			power = 0,--战力
			shows = v.shows,
			-- fightData = v.fightData,--战斗数据
			fail = 0,
			enemyList = {},
			fightRecordList = {},
			job = v.job,
			sex = v.sex,
			fightShow = v.dbid,
			lv = 0,
		}
		table.insert(self.robotList, data)
	end
end

function QualifyingCenter:Gamble(dbid, serverid, rank, field, no, typ)
	local rank = self.cache_key.keyList[dbid] or rank
	if not self.cache_key.keyList[dbid] then self.cache_key.keyList[dbid] = rank end
	if not self.The4Type[self.cache_audition.typ] then return end
	local knockout = self.The4Type[self.cache_audition.typ]
	local the = "the"..knockout
	if not self.cache_the[the] or not self.cache_the[the][rank] or #self.cache_the[the][rank] == 0 then return false end
	if not self.cache_the[the][rank][field] then return false end
	
	local bets = "bets"..self.The4Type[self.cache_audition.typ]
	local fieldData = self.cache_bets[bets][rank][field] or {}
	
	if fieldData[dbid] then return false end
	
	fieldData[dbid] = {no = no, typ = typ, serverid = serverid}
	self.cache_bets[bets][rank][field] = fieldData
	return true
end

function QualifyingCenter:onLogin(player)
	if not server.serverCenter:IsCross() then return end
	self:SendOne(player.nowserverid, "QualifyingInfoRes", player.dbid)
end

function QualifyingCenter:GetGambleMsg(dbid, serverid, rank)
	local num = self.The4Type[self.cache_audition.typ]
	local rank = self.cache_key.keyList[dbid] or rank
	local data = self:GetpData(dbid)
	
	if not num then return {}, self:GetpData(dbid) ~= nil, rank end
	
	local msg = {}
	local bets = "bets"..num
	for k,v in pairs(self.cache_bets[bets][rank]) do
		local data = v[dbid]
		if data then
			table.insert(msg, {
				field = k,
				no = data.no,
				typ = data.typ,
			})
		end
	end
	return msg, self:GetpData(dbid) ~= nil, rank
end

function QualifyingCenter:BroadcastMsg()
	local msg = self:packInfo()
	self:SendLogics("UpdateMsg", msg)
end

function QualifyingCenter:DoBroadcastMsg()
	local function _BroadcastMsg()
			self:BroadcastMsg()
		end
	lua_app.add_timer(2 * 1000, _BroadcastMsg)
end

function QualifyingCenter:BroadcastRank()
	local msg = self:packRankInfo()
	self:SendLogics("UpdateRank", msg)
end

function QualifyingCenter:GetMsg()
	local msg = self:packInfo()
	return msg
end

function QualifyingCenter:GetRank()
	local msg = self:packRankInfo()
	return msg
end

function QualifyingCenter:SetVideo(record)
	local no = self.cache_audition.recordNo
	local VData = {
		no = no,
		data = table.wcopy(record),
	}
	print("QualifyingCenter:SetVideo---",no)
	self.cache_audition.recordNo = no + 1
	local cache = server.mysqlBlob:CreateDmg(tbrecord, VData)
	self.Video[no] = cache
	return no
end

function QualifyingCenter:GetVideo(dbid, num, rank, field, round)
	local rank = self.cache_key.keyList[dbid] or rank
	local the = "the"..num
	local data = self.cache_the[the][rank][field]
	if not data then return end
	local no = data.record[round]
	if not self.Video[no] then
		local vData = server.mysqlBlob:LoadDmg(tbrecord, {no = no})
		if not vData[1] then return {} end
		self.Video[no] = vData[1]
	end
	local record = self.Video[no] and self.Video[no].data or {}
	server.fightCenter:SendRecord(dbid, record)
end

function QualifyingCenter:packInfo()
	local msgs = {}

	for i = 1, 4 do
		local msg = {}
		msg.type = self.cache_audition.typ
		msg.rank = i
		if self.cache_audition.typ >= 2 then
			if #self.cache_auditionfight.auditionFight[i] < 2 then
				msg.ret = false
			else
				msg.ret = true
				if self.cache_audition.typ >= 4 then
					msg.knockouttime16 = self:packKnockoutInfo(i, 16)
				end
				if self.cache_audition.typ >= 6 then
					msg.knockouttime8 = self:packKnockoutInfo(i, 8)
				end
				if self.cache_audition.typ >= 8 then
					msg.knockouttime4 = self:packKnockoutInfo(i, 4)
				end
			end
		end
		msg.player_data = self:packPlayerInfo(i)
		msg.knockouttime2 = self:packKnockoutInfo(i, 2)
		local champion = 0
		if self.cache_the.the2[i][1] then
			champion = self.cache_the.the2[i][1].win or 0
		end
		msg.champion = champion
		msgs[i] = msg
	end
	return msgs
end

function QualifyingCenter:packPlayerInfo(rank)
	local msg = {}
	for k,v in pairs(self.cache_auditionfight.auditionFight[rank]) do
		local data = self.cache_last.lastData[rank][v]
		if data then 
			table.insert(msg, {
					no = data.dbid,
					name = data.name,
					server = data.serverid,
					lv = data.lv,
					power = data.power,
					shows = data.shows,
					job = data.job,
					sex = data.sex,
				})
		end
	end
	return msg
end

function QualifyingCenter:packKnockoutInfo(rank, the)
	local msg = {}
	local the = "the"..the
	for k,v in pairs(self.cache_the[the][rank]) do
		table.insert(msg, {
				field = k,
				noA = v.noA,
				noB = v.noB,
				winNo = (v.winNo or 0),
				fightRecord = (v.fightRecord or {})
			})
	end
	return msg
end

function QualifyingCenter:packRankInfo()
	local msg = {}
	for k,v in pairs(self.cache_rank.auditionRank) do
		msg[k]={}
		for _,vv in ipairs(v) do
		table.insert(msg[k],{
				name = vv.name,
				server = vv.serverid,
				point = vv.point,
			})
		end
	end
	return msg
end

function QualifyingCenter:GetFightRecord(dbid, serverid, rank)
	
	local data = self:GetpData(dbid)
	if not data then
		return {}, 0, 0, rank
	end
	return data.fightRecordList, data.prank, data.point, data.rank
end

function QualifyingCenter:GetMiniMsg(dbid, serverid)
	local data = self:GetpData(dbid)
	if not data then return false end
	local ret = 3	
	if self.cache_audition.typ > 3 then
		ret = 2
	elseif data.fail < 3 then
		ret = 1
	end

	local timeout = math.max((self.fightTime or 0) - lua_app.now(), 20)
	return true, ret, data.rankNo, timeout, data.prank, data.point
end

function QualifyingCenter:GetTimeOut(dbid)
	if not self.fightTime then
		return false
	end
	if not self.cache_audition.memberList[dbid] then
		return false
	end
	return true, math.max(self.fightTime - lua_app.now(),1)
end



function QualifyingCenter:test(dbid, j, k, l)
	print("QualifyingCenter-test=====================",self.cache_audition.typ)
	if j == "clear" then
		self.cache_audition.typ = 0
		self:ClearKnockout()
		lua_app.del_local_timer(self.time_rum)
		self.fightTime=nil	
	elseif j == "start" then
		self.cache_audition.typ = 1
		self:SignStart()
		self:DoBroadcastMsg()
		-- self.cache_audition.typ = k
		-- self:DoBroadcastMsg()
		-- print("修改状态==11==",self.cache_audition.typ)
	elseif j == "next" then
		if self.cache_audition.typ == 1 then 
			self:SignStop()
			local function _Next()
				self.cache_audition.typ = 3
				self.Round = 1
				self.fightNum = 0
				self.residue = {0,0,0,0}
				-- self:CheckMan()--补齐人数
				self:FightStart()
				self:DoBroadcastMsg()
			end
			self.time_rum = lua_app.add_timer(30 * 1000, _Next)
		-- elseif self.cache_audition.typ == 2 then
		-- 	lua_app.del_local_timer(self.time_rum)
		-- 	self.cache_audition.typ = 3
		-- 	self.Round = 0
		-- 	self.fightNum = 0
		-- 	self.residue = {rank1=0,rank2=0,rank3=0,rank4=0}
		-- 	-- self:CheckMan()--补齐人数
		-- 	self:FightStart()
		-- 	self:DoBroadcastMsg()
		elseif self.cache_audition.typ == 4 then
			self.Round = 0
			self.fightNum = 1
			self.cache_audition.typ = 5
			self:Knockout16()
		elseif self.cache_audition.typ == 6 then
			self.Round = 0
			self.fightNum = 2
			self.cache_audition.typ = 7
			self:Knockout8()
		elseif self.cache_audition.typ == 8 then
			self.Round = 0
			self.fightNum = 3
			self.cache_audition.typ = 9
			self:Knockout4()
		elseif self.cache_audition.typ == 10 then
			self.Round = 0
			self.fightNum = 4
			self.cache_audition.typ = 11
			self:Knockout2()
		elseif self.cache_audition.typ == 0 or
			self.cache_audition.typ == 3 or
			self.cache_audition.typ == 5 or
			self.cache_audition.typ == 7 or
			self.cache_audition.typ == 9 or
			self.cache_audition.typ == 11 or 
			self.cache_audition.typ == 12 then
			local data = {}
			if self.cache_audition.typ == 0 then
				data.msg = "仙道会目前状态为["..self.cache_audition.typ.."]start开始活动"
			elseif self.cache_audition.typ == 12 then
				data.msg = "仙道会目前状态为["..self.cache_audition.typ.."]活动已结束请重置"
			else
				data.msg = "仙道会目前状态为["..self.cache_audition.typ.."]请等待下一个状态"
			end
			data.code = 0
			server.sendReqByDBID(dbid, "sc_error_code", data)
		end
	elseif j == "xf" then
		local newList = {}
		local dataList = {}
		for k,v in ipairs(self.cache_auditionfight.auditionFight[1]) do
			if not dataList[v] then
				dataList[v] = 1
				table.insert(newList,v)
			end
		end
		self.cache_auditionfight.auditionFight[1] = newList
		self:PreliminaryEnd()

	else
		print("self.playerList-------")
		for k,v in pairs(self.playerList) do
			print(k,"->",v)
		end
		print("self.cache_audition.audition-------")
		for k,v in pairs(self.cache_audition.audition) do
		-- 	for kk,vv in pairs(v) do
				print (k,"->",v)
		-- 	end
		end
		local vData = server.mysqlBlob:LoadDmg(tbrecord, {no = 1})
		print("-===",type(vData))
		print("-===",type(vData[1]))
		print("-===",type(vData[1].data))

	end
	self:DoBroadcastMsg()
	print("QualifyingCenter-test=====================",self.cache_audition.typ)
end

function QualifyingCenter:CallLogics(funcname, ...)
	return server.serverCenter:CallLogics("QualifyingLogicCall", funcname, ...)
end

function QualifyingCenter:CallOne(serverid, funcname, ...)
	return server.serverCenter:CallOne("logic", serverid, "QualifyingLogicCall", funcname, ...)
end

function QualifyingCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "QualifyingLogicSend", funcname, ...)
end

function QualifyingCenter:SendLogics(funcname, ...)
	server.serverCenter:SendLogics("QualifyingLogicSend", funcname, ...)
end

function server.QualifyingWarCall(src, funcname, ...)
	lua_app.ret(server.qualifyingCenter[funcname](server.qualifyingCenter, ...))
end

function server.QualifyingWarSend(src, funcname, ...)
	server.qualifyingCenter[funcname](server.qualifyingCenter, ...)
end

server.SetCenter(QualifyingCenter, "qualifyingCenter")
return QualifyingCenter
