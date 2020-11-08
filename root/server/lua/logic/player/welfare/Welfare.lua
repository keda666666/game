local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local Welfare = oo.class()

function Welfare:ctor(player)
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Welfare
end

function Welfare:onDayTimer()
	local isMsg
	local day = server.serverRunDay
	if self.cache.month ~= 0 then
		isMsg = true
		if self.cache.month <= day then
			self.vipBag = nil
			self.rewardUp = nil
			self.offLineReward = nil
			self.cache.month = 0
		end
	end
	if self.cache.week ~= 0 then
		isMsg = true
		if self.cache.week <= day then
			self.cache.week = 0
		end
	end
	self.cache.welfareReward = 0
	if isMsg then
		local msg = self:packInfo()
		server.sendReq(self.player,"sc_welfare_info", msg)
	end

	self.vipBag = 0
	local monthNum, weekNum
	if self.cache.month > day then
		local baseConfig = self:GetWelfareBaseConfig()
		self.vipBag = baseConfig.moncardbag
		self.rewardUp = baseConfig.moncardup
		self.offLineReward = baseConfig.moncardoffline
		monthNum = day - self.cache.monthReward
		self.cache.monthReward = day

	elseif self.cache.month ~=0 and self.cache.month <= day then
		monthNum = self.cache.month - self.cache.monthReward
		self.cache.month = 0
		self.cache.monthReward = 0

	end
	if self.cache.week > day then
		weekNum = day - self.cache.weekReward
		self.cache.weekReward = day
	elseif self.cache.week ~= 0 and self.cache.week <= day then
		weekNum = self.cache.week - self.cache.weekReward
		self.cache.week = 0
		self.cache.weekReward = 0
	end
	local baseConfig= self:GetWelfareBaseConfig()
	if monthNum and monthNum ~= 0 then
--		for i=1,monthNum do
			local titleDay = baseConfig.maildailymoncard
			local msgDay = baseConfig.maildesdailymoncard
			local cardConfig = self:GetCardConfig(1)
			server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	
--		end
	end
	if weekNum and weekNum ~=0 then
--		for i=1,weekNum do
			local cardConfig = self:GetCardConfig(2)
			local titleDay = baseConfig.maildailyweekcard
			local msgDay = baseConfig.maildesdailweekcard
			server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	
--		end
	end
	if self.cache.forever == 1 then
		local cardConfig = self:GetCardConfig(3)
		local titleDay = baseConfig.maildailyperpetualcard
		local msgDay = baseConfig.maildesdailyperpetualcard
		server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	

	end
end	
	
function Welfare:onCreate()
	self:onLoad()
end

function Welfare:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.welfare
	local baseConfig= self:GetWelfareBaseConfig()
	if self.cache.forever == 1 then
		self.foreverBag = baseConfig.forevercardbag
		self.foreverUp = baseConfig.forevercardup
	end
end

function Welfare:IsVipBag()
	return self.vipBag or 0
end

function Welfare:IsRewardUp()
	return self.rewardUp or 0
end

function Welfare:IsForeverBag()
	return self.foreverBag or 0
end

function Welfare:IsForeverUp()
	return self.foreverUp or 0
end

function Welfare:IsOffLineRewardUp()
	return self.offLineReward
end

function Welfare:onInitClient()
	--发数据给客户端
	local msg = self:packInfo()
	server.sendReq(self.player,"sc_welfare_info", msg)
end

local _cardConfig = false
function Welfare:GetCardConfig(key)
	if _cardConfig then return _cardConfig[key] end
	_cardConfig = server.configCenter.CardConfig
	return _cardConfig[key]
end

local _welfareBaseConfig = false
function Welfare:GetWelfareBaseConfig()
	if _welfareBaseConfig then return _welfareBaseConfig end
	_welfareBaseConfig = server.configCenter.WelfareBaseConfig
	return _welfareBaseConfig
end

local _welfareConfig = false
function Welfare:GetWelfareConfig()
	if _welfareConfig then return _welfareConfig end
	_welfareConfig = server.configCenter.WelfareConfig
	return _welfareConfig
end

local _lvRewardConfig = false
function Welfare:GetLvRewardConfig(no)
	if _lvRewardConfig then return _lvRewardConfig[no] end
	_lvRewardConfig = server.configCenter.LvRewardConfig
	return _lvRewardConfig[no]
end

function Welfare:Activation(no)
	if no == 6 then
		no = 3
	else
		no = no - 1 
	end

	local cardConfig = self:GetCardConfig(no)
	local baseConfig= self:GetWelfareBaseConfig()
	local title, msg, titleDay, msgDay 
	local day = server.serverRunDay
	local rewards
	local weekday = self.cache.weekReward or 0
	local forever = self.cache.forever or 0
	local firstMonth = self.cache.firstMonth or 0
	if cardConfig.type == 1 then
		if self.cache.month > day then
			self.cache.month = self.cache.month + cardConfig.day
		else
			self.cache.month = day + cardConfig.day
				self.vipBag = baseConfig.moncardbag
			self.rewardUp = baseConfig.moncardup
			self.offLineReward = baseConfig.moncardoffline
			if self.cache.monthReward < day then
				self.cache.monthReward = day
				titleDay = baseConfig.maildailymoncard
				msgDay = baseConfig.maildesdailymoncard
			end
			
		end
		title = baseConfig.mailmoncard
		msg = baseConfig.maildesmoncard
		rewards = table.wcopy(cardConfig.reward)
		if not self.cache.firstMonth or self.cache.firstMonth == 0 then
			self.cache.firstMonth = 1
			for k,v in pairs(cardConfig.firstreward) do
				table.insert(rewards, table.wcopy(v))
			end
		end
		if firstMonth == 0 then
			server.mailCenter:SendMail(self.player.dbid, title, msg, rewards, self.YuanbaoRecordType, "月卡周卡永久激活"..cardConfig.type)
			if titleDay and msgDay then
				server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	
			end
		end
	elseif cardConfig.type == 2 then
		self.cache.week = math.max(self.cache.week, day) + cardConfig.day
		title = baseConfig.mailweekcard
		msg = baseConfig.maildesweekcard
		if self.cache.weekReward < day then
			self.cache.weekReward = day
			titleDay = baseConfig.maildailyweekcard
			msgDay = baseConfig.maildesdailyweekcard
		end
		rewards = table.wcopy(cardConfig.reward)
		if weekday == 0 then
			server.mailCenter:SendMail(self.player.dbid, title, msg, rewards, self.YuanbaoRecordType, "月卡周卡永久激活"..cardConfig.type)
			if titleDay and msgDay then
				server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	
			end
		end
	elseif cardConfig.type == 3 then
		self.cache.forever = 1
		self.foreverBag = baseConfig.forevercardbag
		self.foreverUp = baseConfig.forevercardup
		title = baseConfig.mailperpetualcard
		msg = baseConfig.maildesperpetualcard
		titleDay = baseConfig.maildailyperpetualcard
		msgDay = baseConfig.maildesdailyperpetualcard
		rewards = table.wcopy(cardConfig.reward)

		if forever == 0 then
			server.mailCenter:SendMail(self.player.dbid, title, msg, rewards, self.YuanbaoRecordType, "月卡周卡永久激活"..cardConfig.type)
			if titleDay and msgDay then
				server.mailCenter:SendMail(self.player.dbid, titleDay, msgDay, cardConfig.dailyreward, self.YuanbaoRecordType, "月卡周卡永久每日"..cardConfig.type)	
			end
		end
	end
	
	local msg = self:packInfo()
	server.sendReq(self.player,"sc_welfare_info", msg)

	local yb = 0
	for _, v in pairs(cardConfig.reward) do
		if v.type == ItemConfig.AwardType.Numeric and v.id == ItemConfig.NumericType.YuanBao then
			yb = yb + v.count
		end
	end
	return yb
end

function Welfare:LvReward(no)
	local rewardConfig = self:GetLvRewardConfig(no)
	if not rewardConfig then return {ret = false} end
	if rewardConfig.level > self.player.cache.level then return {ret = false} end
	local lvReward = self.cache.lvReward
	if lvReward & (2 ^ no) ~= 0 then return {ret = false} end
	self.cache.lvReward = lvReward | (2 ^ no)
	self.player:GiveRewardAsFullMailDefault(rewardConfig.reward, "等级礼包", self.YuanbaoRecordType, "等级礼包"..no)
	return  {ret = true, lvReward = self.cache.lvReward}
end

function Welfare:WelfareReward(no)
	if not self:Open() then return {ret = false} end

	local baseConfig = self:GetWelfareBaseConfig()
	local active = self.player.cache.daily_task.active
	if not baseConfig.score[no] or baseConfig.score[no] > active then
		return {ret = false}
	end
	if self.cache.welfareReward & (2 ^ no) ~= 0 then return {ret = false} end
	self.cache.welfareReward = self.cache.welfareReward | (2 ^ no)
	local avgLv = server.dailyActivityCenter:AvgLv()
	local welfareConfig = self:GetWelfareConfig()
	local lv = self.player.cache.level
	for k,v in pairs(welfareConfig) do
		if v.level[1] <= lv and (not v.level[2] or lv <= v.level[2]) then
			if (avgLv - lv) <= baseConfig.level then
				self.player:GiveRewardAsFullMailDefault(v.goldreward, "西游福利", self.YuanbaoRecordType, "西游福利_绑元"..no)
			else
				self.player:GiveRewardAsFullMailDefault(v.expreward, "西游福利", self.YuanbaoRecordType, "西游福利_经验"..no)
			end
		break
		end
	end
	return {ret = true, welfareReward = self.cache.welfareReward}
end

function Welfare:packInfo()
	local avgLv, rankData = server.dailyActivityCenter:RankData()
	local msg = {

		lvReward = self.cache.lvReward,
		welfareReward = self.cache.welfareReward,
		rankData = rankData,
		avgLv = avgLv or 0,
		forever = self.cache.forever or 0,
		firstMonth = self.cache.firstMonth or 0,
	}
	local day = server.serverRunDay
	if self.cache.month ~= 0 then
		msg.month = math.max(self.cache.month - day, 0)
	else
		msg.month = 0
	end
	if self.cache.week ~= 0 then
		msg.week = math.max(self.cache.week - day, 0)
	else
		msg.week = 0
	end
	return msg
end

function Welfare:upInfo(...)
	local args = {...}
	local msg = {}
	for _,v in pairs(arge) do
		if v == "month" then
			if self.cache.month ~= 0 then
				msg.month = math.max(self.cache.month - day, 0)
				-- msg.month = math.floor((self.cache.month - lua_app.now()) / ( 24 * 60 * 60)) + 1
			else
				msg.month = 0
			end
		elseif v == "week" then
			if self.cache.week ~= 0 then
				msg.week = math.max(self.cache.week - day, 0)
				-- msg.week = math.floor((self.cache.week - lua_app.now()) / ( 24 * 60 * 60)) + 1
			else
				msg.week = 0
			end
		else
			msg[v] = self.cache[v]
		end
	end
	server.sendReq(self.player,"sc_welfare_update", msg)
end

function Welfare:Open()
	local baseConfig = self:GetWelfareBaseConfig()
	local openConfig = server.configCenter.FuncOpenConfig[baseConfig.opentype]
	return openConfig.conditionnum <= self.player.cache.level and
		(openConfig.conditionnum2 and openConfig.conditionnum2 <= server.serverRunDay or true)

end

server.playerCenter:SetEvent(Welfare, "welfare")
return Welfare
