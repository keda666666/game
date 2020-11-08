--萌新三连  qq15413469
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "common.resource.ItemConfig"

local LuckPlug = oo.class()

function LuckPlug:ctor(player)
	self.player = player
end

function LuckPlug:onCreate()
	self:onLoad()
end

function LuckPlug:onLoad()
	self.cache = self.player.cache.luck
end

function LuckPlug:onInitClient()
	self:GetInfo()
end

function LuckPlug:onDayTimer()
	self.cache.daylist = {}
	self.cache.equipdaylist = {}
end

function LuckPlug:onLogout(player)
end

function LuckPlug:onLogin(player)
end

function LuckPlug:GetInfo()
	for i=1, #server.configCenter.LuckConfig do
		self.cache.list[i] = self.cache.list[i] or 0
	end
	for i=1, #server.configCenter.EquipLotteryConfig do
		self.cache.equiplist[i] = self.cache.equiplist[i] or 0
	end
	for i=1, #server.configCenter.TotemsLotteryConfig do
		self.cache.totemslist[i] = self.cache.totemslist[i] or 0
	end
	self.cache.daylist = self.cache.daylist or {}
	for i=1, #server.configCenter.LuckConfig do
		self.cache.daylist[i] = self.cache.daylist[i] or 0
	end
	self.cache.equipdaylist = self.cache.equipdaylist or {}
	for i=1, #server.configCenter.EquipLotteryConfig do
		self.cache.equipdaylist[i] = self.cache.equipdaylist[i] or 0
	end
	self.cache.totemsdaylist = self.cache.totemsdaylist or {}
	for i=1, #server.configCenter.TotemsLotteryConfig do
		self.cache.totemsdaylist[i] = self.cache.totemsdaylist[i] or 0
	end
	-- self.cache.lucky = self.cache.lucky or 0
	-- self.cache.lastlucky = self.cache.lastlucky or 0
	-- self.cache.round = self.cache.round or 1
	local msg = {
		counts = self.cache.list,
		records = server.luckCenter.records,
		tenNum = self.cache.tianshen.tenNum,
		lucky = self.cache.lucky,
		equipcounts = self.cache.equiplist,
		equiplucky = self.cache.equiplucky,
		equiprecords = server.luckCenter.equipRecords,
		daylist = self.cache.daylist,
		equipdaylist = self.cache.equipdaylist,
		round = self.cache.round,
		equipround = self.cache.equipround,

		totemscounts = self.cache.totemslist,
		totemslucky = self.cache.totemslucky,
		totemsrecords = server.luckCenter.totemsRecords,
		totemsdaylist = self.cache.totemsdaylist,
		totemsround = self.cache.totemsround,

	}
	-- print("发送协议============")
	-- table.ptable(msg,5)
	self.player:sendReq("sc_luck_info", msg)
end

function LuckPlug:GetLuckCfg(LuckConfigList, count)
	print("LuckConfigList===",LuckConfigList,count)
	local LuckConfig
	local max = 0
	for level, v in pairs(LuckConfigList) do
		LuckConfig = LuckConfig or v
		if level >= max and count >= level then
			max = level
			LuckConfig = v
		end
	end
	return LuckConfig
end

function LuckPlug:IsReset(rewards, resetitem)
	local isreset = false
	for _, v in pairs(rewards) do
		for _, id in ipairs(resetitem) do
			if v.id == id then
				isreset = true
			end
		end
	end
	return isreset
end

local SetLucky = {}
SetLucky[1] = function(self, lucky, lastlucky, round)
	self.cache.lucky = lucky
	self.cache.lastlucky = lastlucky
	self.cache.round = round
end
SetLucky[2] = function(self, equiplucky, equiplastlucky, equipround)
	self.cache.equiplucky = equiplucky
	self.cache.equiplastlucky = equiplastlucky
	self.cache.equipround = equipround
end
SetLucky[3] = function(self, totemslucky, totemslastlucky, totemsround)
	self.cache.totemslucky = totemslucky
	self.cache.totemslastlucky = totemslastlucky
	self.cache.totemsround = totemsround
end

local _LuckData = {}
_LuckData[1] = function(self, index)
	local LuckConfigList = server.configCenter.LuckConfig[index]
	local LuckBaseConfig = server.configCenter.LuckBaseConfig
	local ChatNo = 7

	local lucky = self.cache.lucky or 0
	local list = self.cache.list or {}
	local lastlucky = self.cache.lastlucky or 0
	local round = self.cache.round or 1
	local daylist = self.cache.daylist or {}
	return lucky, list, lastlucky, round, daylist, LuckConfigList, LuckBaseConfig, ChatNo
end

_LuckData[2] = function(self, index)
	local LuckConfigList = server.configCenter.EquipLotteryConfig[index]
	local LuckBaseConfig = server.configCenter.EquipLotteryBaseConfig
	local ChatNo = 40

	local lucky = self.cache.equiplucky or 0
	local list = self.cache.equiplist or {}
	local lastlucky = self.cache.equiplastlucky or 0
	local round = self.cache.equipround or 1
	local daylist = self.cache.equipdaylist or {}
	return lucky, list, lastlucky, round, daylist, LuckConfigList, LuckBaseConfig, ChatNo
end

_LuckData[3] = function(self, index)
	local LuckConfigList = server.configCenter.TotemsLotteryConfig[index]
	local LuckBaseConfig = server.configCenter.TotemsLotteryBaseConfig
	local ChatNo = 45

	local lucky = self.cache.totemslucky or 0
	local list = self.cache.totemslist or {}
	local lastlucky = self.cache.totemslastlucky or 0
	local round = self.cache.totemsround or 1
	local daylist = self.cache.totemsdaylist or {}
	return lucky, list, lastlucky, round, daylist, LuckConfigList, LuckBaseConfig, ChatNo
end

-- 抽
function LuckPlug:Draw(typ, index)
	local lucky, list, lastlucky, round, daylist, LuckConfigList, LuckBaseConfig, ChatNo = _LuckData[typ](self, index)
	local resetitem = LuckBaseConfig.resetitem
	-- local LuckConfigList = server.configCenter.LuckConfig[index]
	-- local LuckBaseConfig = server.configCenter.LuckBaseConfig
	if not LuckConfigList then
		return
	end

	-- self.cache.lucky = self.cache.lucky or 0
	-- self.cache.list[index] = self.cache.list[index] or 0
	local count = list[index]
	local LuckConfig = self:GetLuckCfg(LuckConfigList, count)

	local isfree = false
	if LuckBaseConfig.free then
		for k,v in pairs(LuckBaseConfig.free) do
			if index == v and (not daylist[index] or daylist[index] == 0) then
				isfree = true
			end
		end
	end

	if not isfree and not self.player:PayRewards({LuckConfig.cost}, server.baseConfig.YuanbaoRecordType.Luck, "Luck:"..typ..index) then
		server.sendErr(self.player, "元宝不足")
		return
	end

	local dropid = LuckConfig.reward[round]
	local rewards = {}
	if not list[index] or list[index] == 0 then
		dropid = LuckConfig.firstreward[round]
	elseif server.serverRunDay <= LuckBaseConfig.openday then
		dropid = LuckConfig.openreward[round]
	end

	local addlucky = LuckBaseConfig.luckvalue[index]
	if addlucky then
		for k,v in pairs(LuckBaseConfig.luckitem) do
			if round == v.id and 
				lucky >= v.num and 
				lastlucky < v.num then
				lastlucky = v.num--数据有修改
				dropid = v.dropid
			end
		end
		if LuckBaseConfig.luckpro and lucky >= LuckBaseConfig.luckpro then
			lucky = 0 --数据有修改
			lastlucky = 0
		else
			lucky = lucky + addlucky --数据有修改
		end
	end
	print("LuckPlug:Draw---", self.player.dbid, typ, index, lucky, round)

	for i=1, LuckConfig.count do
		local oncerewards = server.dropCenter:DropGroup(dropid)
		for k,v in pairs(oncerewards) do
			table.insert(rewards, v)
		end
		if self:IsReset(oncerewards, resetitem) then
			list[index] = 1
			lucky = 0 --数据有修改
			lastlucky = 0
			round = round + 1 --数据有修改
			if round > #LuckBaseConfig.resetitem then
				round = 1 --数据有修改
			end
			LuckConfig = self:GetLuckCfg(LuckConfigList, 1)
		end
		if dropid ~= LuckConfig.reward[round] then
			dropid = LuckConfig.reward[round]
		end
	end

	self.player:GiveRewardAsFullMailDefault(rewards, "寻宝", server.baseConfig.YuanbaoRecordType.Luck, "luck", 0)
	list[index] = (list[index] or 0) + 1
	daylist[index] = (daylist[index] or 0) + 1

	self.player:GiveRewardAsFullMailDefault(table.wcopy(LuckConfig.rewards), "寻宝", server.baseConfig.YuanbaoRecordType.Luck)

	local msg = {type = typ, index = index, rewards = rewards}
	self.player:sendReq("sc_luck_ret", msg)
	server.luckCenter:DoRecord(typ, self.player.cache.name, rewards)

	SetLucky[typ](self, lucky, lastlucky, round)
	self:GetInfo()

	local noticerewards = {}
	for __, id in ipairs(LuckBaseConfig.notice) do
		for __, reward in ipairs(rewards) do
			if id == reward.id then
				table.insert(noticerewards, reward)
			end
		end
	end
	if next(noticerewards) == nil then return end
	server.chatCenter:ChatLink(ChatNo, self.player, nil, self.player.cache.name, ItemConfig:ConverLinkText(noticerewards))
end

function LuckPlug:DrawTianshen(typ)
	local luckConfig = server.configCenter.TianShenLuckConfig
	local baseConfig  = server.configCenter.TianShenLuckBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	--if self.player.cache.level < openConfig[baseConfig.openlv].conditionnum then
	--	return {ret = false}
	--end
	local LuckConfig
	local max = 0
	local data = self.cache.tianshen
	local count = data.num
	for level, v in pairs(luckConfig[typ]) do
		LuckConfig = LuckConfig or v
		if level >= max and count >= level then
			max = level
			LuckConfig = v
		end
	end
	if not self.player:PayRewards(LuckConfig.cost, server.baseConfig.YuanbaoRecordType.LuckTianshen, "Lucktianshen:"..typ) then
		server.sendErr(self.player, "元宝不足")
		return {ret = false}
	end
	local data = self.cache.tianshen
	local luckNum = 10
	local rewards = {}
	if typ == 2 then
		data.num = data.num + 1
		data.allNum = data.allNum + 1
		luckNum = 1
	elseif typ ==3 then
		data.num = data.num + 1
		data.allNum = data.allNum + 1
		data.tenNum = data.tenNum + 1
	end

	local firstReward = baseConfig.firstitme[data.tenNum]
	if firstReward and (data.reward & (1<<firstReward)) == 0 then
		data.reward = data.reward | (1<<firstReward)
		luckNum = luckNum - 1
		local reward = server.dropCenter:DropGroup(firstReward)
		self.player:GiveRewardAsFullMailDefault(reward, "天神降临", server.baseConfig.YuanbaoRecordType.LuckTianshen, "天神降临1")
		for k,v in pairs(reward) do
			table.insert(rewards, {id = v.id, num = v.count})
			if baseConfig.notice[v.id] then
				server.chatCenter:ChatLink(5, nil, nil, self.player.cache.name, ItemConfig:ConverLinkText(v))
				--server.serverCenter:SendLogicsMod("noticeCenter", "Notice", baseConfig.post, player.cache.name, petName)
			end
			if baseConfig.resetitem[v.id] then
				data.num = 0
			end
		end
	end
	local day = server.serverRunDay
	local rewardNo
	if baseConfig.openday > day then
		rewardNo = LuckConfig.openreward
	else
		rewardNo = LuckConfig.reward
	end
	for i=1, luckNum do
		local reward = server.dropCenter:DropGroup(rewardNo)
		self.player:GiveRewardAsFullMailDefault(reward, "天神降临", server.baseConfig.YuanbaoRecordType.LuckTianshen, "天神降临2")
		for _,v in pairs(reward) do
			table.insert(rewards, {id = v.id, num = v.count})
			if baseConfig.notice[v.id] then
				server.chatCenter:ChatLink(5, nil, nil, self.player.cache.name, ItemConfig:ConverLinkText({v}))
				--server.serverCenter:SendLogicsMod("noticeCenter", "Notice", baseConfig.post, player.cache.name, petName)
			end
			if baseConfig.resetitem[v.id] then
				data.num = 0
			end
		end
	end
	self.player.shop:onUpdateUnlock()
	local msg = {
		ret = true,
		rewards = rewards,
		tenNum = data.tenNum,
	}
	return msg
end

function LuckPlug:GetLuckTianshenNum()
	return self.cache.tianshen.allNum
end

server.playerCenter:SetEvent(LuckPlug, "luckPlug")
return LuckPlug