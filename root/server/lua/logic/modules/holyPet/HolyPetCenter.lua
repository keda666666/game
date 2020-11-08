local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "holyPetData"
local ItemConfig = require "resource.ItemConfig"
local HolyPetCenter = {}

function HolyPetCenter:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	if not self.cache.endTime or self.cache.endTime == 0 then
		self:UpConfig()
	end
	local lotteryConfig = server.configCenter.BeastLotteryConfig
	self.rewardSize = 0
	for _,_ in pairs(lotteryConfig.pet) do
		self.rewardSize = self.rewardSize + 1
	end
end

function HolyPetCenter:onDayTimer()
	local day = server.serverRunDay
	if day ~= (self.cache.endTime + 1) then return end
	local basisConfig = server.configCenter.BeastBasisConfig
	local awardConfig = server.configCenter.BeastAwardConfig
	local title = basisConfig.mail1
	local msg = basisConfig.mail2

	for dbid,data in pairs(self.cache.playerList) do
		for k,v in pairs(awardConfig) do
			if data.cash >= v.money and (data.reward & (1<<k)) == 0 then
				local tMsg = string.format(msg, v.money)
				server.mailCenter:SendMail(dbid, title, tMsg, table.wcopy(v.reward), server.baseConfig.YuanbaoRecordType.HolyPet, "神兽降临")
			end
		end
	end

	self.cache.playerList = {}
	self:SetNextTime()
	local players = server.playerCenter:GetOnlinePlayers()
	for _,player in pairs(players) do
		self:SendInfo(player.dbid)
	end
end

function HolyPetCenter:Release()
	if self.cache then
		self.cache(true)
		-- self.cache = nil
	end
end

local _basisConfig = false
function HolyPetCenter:GetBeastBasisConfig()
	if _basisConfig then return _basisConfig end
	return _basisConfig
end

function HolyPetCenter:UpConfig()
	if not self.cache then return end
	local basisConfig = server.configCenter.BeastBasisConfig

	self.cache.version = basisConfig.ID
	local day = server.serverRunDay
	

	local days = basisConfig.Days
	local days1 = basisConfig.Days1
	if days then
		self.cache.starTime = days
		self.cache.endTime = days + days1 - 1
	else
		-- local days2 = basisConfig.Days2 or 0
		self.cache.starTime = self:GetOpenDay(basisConfig.time)
		self.cache.endTime = self.cache.starTime + days1 - 1
	end
end

function HolyPetCenter:SetNextTime()
	local day = server.serverRunDay
	local basisConfig = server.configCenter.BeastBasisConfig
	self.cache.starTime = day + basisConfig.Days3
	self.cache.endTime = self.cache.starTime + basisConfig.Days1 - 1
end

function HolyPetCenter:GetOpenDay(time)
	local time1 = os.time({year =time[1], month = time[2], day =time[3], hour =0, min =0, sec = 0})
	local t = os.date("*t", lua_app.now())
	local time2 = os.time({year =t.year, month = t.month, day =t.day, hour =0, min =0, sec = 0})
	local day = math.floor((time2 - time1) / (60*60*24))
	return server.serverRunDay - day
end

function HolyPetCenter:ResetServer()
	self.cache.endTime = 0
	self:SetNextTime()
end

function HolyPetCenter:HotFix()
	local day = server.serverRunDay
	if self.cache.endTime and day > self.cache.endTime then
		self:SetNextTime()
		local players = server.playerCenter:GetOnlinePlayers()
		for _,player in pairs(players) do
			self:SendInfo(player.dbid)
		end
	end
	print("HolyPetCenter:HotFix----", self.cache.starTime, self.cache.endTime)
end

--增加玩家的消费记录
function HolyPetCenter:AddCash(dbid, num)
	local day = server.serverRunDay
	if day < self.cache.starTime or day > self.cache.endTime then return end
	local data = self.cache.playerList[dbid]
	if not data then
		data = {
			dbid = dbid,
			cash = 0,
			reward = 0,
		}
		self.cache.playerList[dbid] = data
	end
	data.cash = data.cash + num
	self:SendInfo(dbid)
end

function HolyPetCenter:GetReward(dbid, no)
	local day = server.serverRunDay
	if day < self.cache.starTime or day > self.cache.endTime then return end
	local data = self.cache.playerList[dbid]
	if not data then return end
	local awardConfig = server.configCenter.BeastAwardConfig
	local configData = awardConfig[no]
	if not configData then return end
	if data.cash < configData.money or (data.reward & (1<<no)) ~= 0 then return end
	data.reward = data.reward | (1<<no)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	player:GiveRewardAsFullMailDefault(configData.reward, "神兽降临", server.baseConfig.YuanbaoRecordType.HolyPet, "神兽降临")
	self:SendInfo(dbid)
end

function HolyPetCenter:SendInfo(dbid)
	local data = self.cache.playerList[dbid] or {}
	local msg = {
		cash = data.cash or 0,
		reward = data.reward or 0,
		sTime = self.cache.starTime,
		eTime = self.cache.endTime,
		day = server.serverRunDay,
	}
	server.sendReqByDBID(dbid, "sc_holy_pet_info", msg)
end

function HolyPetCenter:onInitClient(dbid)
	local day = server.serverRunDay
	-- if day < self.cache.starTime or day > self.cache.endTime then return end
	self:SendInfo(dbid)
end

function HolyPetCenter:LuckDraw(dbid)
	local day = server.serverRunDay
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local lotteryConfig = server.configCenter.BeastLotteryConfig
	if day < lotteryConfig.Days then return {ret = false} end
	if not player:PayRewards(lotteryConfig.deplete, server.baseConfig.YuanbaoRecordType.HolyPet, "holyPet") then
		return {ret = false}
	end
	local rewards = server.dropCenter:DropGroup(lotteryConfig.flop)

	if not self.cache.luckLog[dbid] then
		self.cache.luckLog[dbid] = {}
	end
	local luckLog = self.cache.luckLog[dbid]
	if luckLog[rewards[1].id] then
		local newReward
		for k,_ in pairs(lotteryConfig.pet) do
			if k ~= rewards[1].id and not luckLog[k] then
				newReward = k
				break
			end
		end
		if not newReward then
			self.cache.luckLog[dbid] = {}
		else
			rewards = table.wcopy(rewards)
			rewards[1].id = newReward
		end
	else
		local num = 0
		for _,_ in pairs(luckLog) do
			num = num + 1
		end
		if num == self.rewardSize then
			self.cache.luckLog[dbid] = {}
		end
	end

	luckLog[rewards[1].id] = 1

	local msgReward = lotteryConfig.notice
	for _,reward in pairs(rewards) do
		for _,v in pairs(msgReward) do
			if v == reward.id then
				self:SetData({name = player.cache.name, id = reward.id})	
				server.chatCenter:ChatLink(26, player, nil, player.cache.name, ItemConfig:ConverLinkText(reward))
				break
			end
		end
	end
	player:GiveRewardAsFullMailDefault(rewards, "降服神兽", server.baseConfig.YuanbaoRecordType.HolyPet, "降服神兽")
	local msg = {
		ret = true,
		no = rewards[1].id,
		data = self:GetData(),
		luckLog = self:GetLuckLog(dbid),
	}
	return msg
end

function HolyPetCenter:SetData(data)
	table.insert(self.cache.data, data)
	if #self.cache.data > 20 then
		table.remove(self.cache.data, 1)
	end
end

function HolyPetCenter:GetData()
	return self.cache.data
end

function HolyPetCenter:CountTB(tbData)
	local count = 0;
	if tbData then
		for i, val in pairs(tbData) do
			count = count + 1
		end
	end
	return count
end
      
function HolyPetCenter:XinJunLuckDraw(dbid)
	local day = server.serverRunDay
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local lotteryConfig = server.configCenter.XinJunLotteryConfig
	if day < lotteryConfig.Days then return {ret = false} end        
	if not player:PayRewards(lotteryConfig.deplete[1].cost, server.baseConfig.YuanbaoRecordType.HolyXinJun, "holyXinJun") then
        server.sendErr(self.player, "元宝不足")
		return {ret = false}
	end
	local rewards = server.dropCenter:DropGroup(lotteryConfig.flop)

	if not self.cache.luckXinLog[dbid] then
		self.cache.luckXinLog[dbid] = {}
	end
	local luckXinLog = self.cache.luckXinLog[dbid]
  	--print("server.UpdateCenter", luckXinLog,rewards[1].id)
	if luckXinLog[rewards[1].id] then
		local newReward
		for k,_ in pairs(lotteryConfig.xinjun) do
			if k ~= rewards[1].id and not luckXinLog[k] then
				newReward = k
				break
			end
		end
		if not newReward then
			self.cache.luckXinLog[dbid] = {}
		else
			rewards = table.wcopy(rewards)
			rewards[1].id = newReward
		end
	else
		local num = 0
		for _,_ in pairs(luckXinLog) do
			num = num + 1
		end
		if num == self.rewardSize then
			self.cache.luckXinLog[dbid] = {}
		end
	end
    
	luckXinLog[rewards[1].id] = 1

	local msgReward = lotteryConfig.notice
	for _,reward in pairs(rewards) do
		for _,v in pairs(msgReward) do
			if v == reward.id then
				self:SetXinJunData({name = player.cache.name, id = reward.id})	
				server.chatCenter:ChatLink(47, player, nil, player.cache.name, ItemConfig:ConverLinkText(reward))
				break
			end
		end
	end
	player:GiveRewardAsFullMailDefault(rewards, "星君降临", server.baseConfig.YuanbaoRecordType.HolyXinJun, "星君降临",0)
	local msg = {
		ret = true,
		no = rewards[1].id,
		data = self:GetXinJunData(),
		luckLog = self:GetXinJunLuckLog(dbid),
	}
	return msg
end

function HolyPetCenter:GetLuckLog(dbid)
	local data = self.cache.luckLog[dbid]
	if not data then
		return {}
	end
	local msg = {}
	for k,_ in pairs(data) do
		table.insert(msg, k)
	end
	return msg
end

function HolyPetCenter:GetXinJunLuckLog(dbid)
	local xindata = self.cache.luckXinLog[dbid]
	if not xindata then
		return {}
	end
	local msg = {}
	for k,_ in pairs(xindata) do
		table.insert(msg, k)
	end
	return msg
end

function HolyPetCenter:SetXinJunData(data)
	table.insert(self.cache.xindata, data)
	if #self.cache.xindata > 20 then
		table.remove(self.cache.xindata, 1)
	end
end

function HolyPetCenter:GetXinJunData()
	return self.cache.xindata
end

server.SetCenter(HolyPetCenter, "holyPetCenter")
return HolyPetCenter
