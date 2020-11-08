local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local EightyOneHardPlug = oo.class()

function EightyOneHardPlug:ctor(player)
	self.player = player
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.EightyOneHard
end

function EightyOneHardPlug:onCreate()
	self:onLoad()
end

function EightyOneHardPlug:onLoad()
	self.cache = self.player.cache.eightyOneHard
end

function EightyOneHardPlug:onInitClient()
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info", msg)
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	if self.player.cache.level >= baseConfig.serverrewardlv then
		server.eightyOneHardCenter:GetFirstReward(self.player.dbid)
	end
end

function EightyOneHardPlug:onLevelUp(oldlevel, newlevel)
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	if self.player.cache.level == baseConfig.serverrewardlv then
		server.eightyOneHardCenter:GetFirstReward(self.player.dbid)
	end
end

function EightyOneHardPlug:packInfo()
	local msg = {
		clear = self.cache.clear,
		helpReward = self.cache.helpReward,
		buy = self:packListData(self.cache.buy),
		todayClearlist = self:packListData(self.cache.todayClearlist),
	}
	return msg
end

function EightyOneHardPlug:packUpInfo(...)
	local args = {...}
	local msg = {}
	for _,v in pairs(args) do
		if v == "todayClearlist" or v == "buy" then
			msg[v] = self:packListData(self.cache[v])
		else
			msg[v] = self.cache[v]
		end
	end
	return msg
end

function EightyOneHardPlug:packListData(data)
	local msg = {}
	for k,v in pairs(data) do
		table.insert(msg, {key1 = k, key2 = v})
	end
	return msg
end

function EightyOneHardPlug:DoResult(iswin, level, helpReward)
	self.fightresult = {iswin = iswin, level = level, helpReward = helpReward}
	local msg = {}
	if iswin then
		msg.result = 1
		self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.TeamFb)
		self.player.dailyTask:OtherActivityAdd(DailyTaskConfig.DailyActivity.TeamFb)
		server.teachersCenter:AddNum(self.player.dbid, 4)
	else
		msg.result = 0
	end
	self.rewards = self:GenRewards()
	self.keys = level
	msg.rewards = self.rewards

	self.player:sendReq("sc_raid_chapter_boss_result", msg)
end

function EightyOneHardPlug:GenRewards()
	if not self.fightresult then return end
	local iswin = self.fightresult.iswin
	local id = self.fightresult.level
	local fbConfig = server.configCenter.DisasterFbConfig[id]
	if not fbConfig then return end
	local key1, key2 = fbConfig.chapterid ,fbConfig.sectionid
	local helpReward = self.fightresult.helpReward
	self.fightresult = nil
	if iswin then
		local rewards = {}
		if not self:Clear(id) then
			--首胜奖励
			rewards = table.wcopy(fbConfig.firstreward)
			local normalrewards = server.dropCenter:DropGroup(fbConfig.drop)
			for _, v in pairs(normalrewards) do
				table.insert(rewards, v)
			end
		elseif helpReward and self.cache.helpReward < 10 then
			--助战奖励
			local fbbaseConfig = server.configCenter.DisasterFbBaseConfig
			rewards = table.wcopy(fbbaseConfig.assistreward)
		end
		return rewards
	end
end

function EightyOneHardPlug:SetData(id, data)
	server.eightyOneHardCenter:SetData(id, data)
end

function EightyOneHardPlug:GetReward(helpReward)
	if not self.rewards or #self.rewards == 0 then return end
	--判断给玩家发什么奖励
	--发奖以及记录次数
	-- self.cache.rewardcount = self.cache.rewardcount + 1
	local fbConfig = server.configCenter.DisasterFbConfig[self.keys]
	if not fbConfig then return end
	local key1, key2 = fbConfig.chapterid ,fbConfig.sectionid

	if not self:Clear(self.keys) then
		self:SetClear(key1, key2)
		self.player.shop:onUpdateUnlock()
	elseif self.cache.helpReward < 10 then
		self.cache.helpReward = self.cache.helpReward + 1
	end
	self.player:GiveRewardAsFullMailDefault(self.rewards, "跨服组队", server.baseConfig.YuanbaoRecordType.CrossTeam)
	self.rewards = nil
	self.keys = nil
	local msg = self:packUpInfo("clear", "helpReward", "todayClearlist")
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info_update", msg)
end

function EightyOneHardPlug:Check(id)

	if id == 1 then return true end
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	if openConfig[baseConfig.openid].conditionnum > self.player.cache.level then return false end
	if not baseConfig then return false end
	return (self.cache.clear + 1) >= id
end

function EightyOneHardPlug:Clear(id)
	local fbBaseConfig = server.configCenter.DisasterFbBaseConfig
	local lv = fbBaseConfig.openid
	local data = self.cache.clear
	return data >= id
end

function EightyOneHardPlug:SetClear(key1, key2)
	self.cache.clear = self.cache.clear + 1

	local data = self.cache.todayClearlist[key1] or 0
	self.cache.todayClearlist[key1] = data | (2 ^ key2)
end

function EightyOneHardPlug:Sweep(id)
	local fbConfig = server.configCenter.DisasterFbConfig[id]
	local key1, key2 = fbConfig.chapterid ,fbConfig.sectionid
	local data = self.cache.todayClearlist[key1] or 0
	if data & (2 ^ key2) ~= 0 then return end
	local rewards = {}
	for k,v in pairs(fbConfig.perdayreward) do
		if not rewards[v.id] then
			rewards[v.id] = table.wcopy(v)
		else
			rewards[v.id].count = rewards[v.id].count + v.count
		end
	end
	local normalrewards = server.dropCenter:DropGroup(fbConfig.drop)
	for _,v in pairs(normalrewards) do
		if not rewards[v.id] then
			rewards[v.id] = table.wcopy(v)
		else
			rewards[v.id].count = rewards[v.id].count + v.count
		end
	end
	self.cache.todayClearlist[key1] = data | (2 ^ key2)
	local reward = {}
	for _,v in pairs(rewards) do
		table.insert(reward, v)
	end
	self.player:GiveRewardAsFullMailDefault(reward, "八十一难", self.YuanbaoRecordType, "八十一难"..key1.."->"..key2)
	
	local msg = self:packUpInfo("todayClearlist")
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info_update", msg)
	msg = {}
	msg.rewards = reward
	msg.result = 1
	self.player:sendReq("sc_raid_sweep_reward", msg)
end

function EightyOneHardPlug:SweepAll()
	local rewards = {}
	local fbConfig = server.configCenter.DisasterFbConfig
	local todayClearlist = self.cache.todayClearlist
	for i = 1 , self.cache.clear do
		local data = fbConfig[i]
		local key1, key2 = data.chapterid, data.sectionid
		local num = todayClearlist[key1] or 0
		if num & (2 ^ key2) == 0 then
			todayClearlist[key1] = num | (2 ^ key2)
			for _,v1 in pairs(data.perdayreward) do
				if not rewards[v1.id] then
					rewards[v1.id] = table.wcopy(v1)
				else
					rewards[v1.id].count = rewards[v1.id].count + v1.count
				end
			end
			local normalrewards = server.dropCenter:DropGroup(data.drop)
			for _,v1 in pairs(normalrewards) do
				if not rewards[v1.id] then
					rewards[v1.id] = table.wcopy(v1)
				else
					rewards[v1.id].count = rewards[v1.id].count + v1.count
				end
			end
		end
	end
	local reward = {}
	for _,v in pairs(rewards) do
		table.insert(reward, v)
	end
	self.player:GiveRewardAsFullMailDefault(reward, "八十一难", self.YuanbaoRecordType, "八十一难All")
	local msg = self:packUpInfo("clear", "todayClearlist")
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info_update", msg)
	msg = {}
	msg.rewards = reward
	msg.result = 1
	self.player:sendReq("sc_raid_sweep_reward", msg)
end

function EightyOneHardPlug:Buy(id)
	if self.cache.clear < id then return end
	local fbConfig = server.configCenter.DisasterFbConfig[id]
	local key1,key2 = fbConfig.chapterid ,fbConfig.sectionid
	local data = self.cache.buy[key1] or 0
	if data & (2 ^ key2) ~= 0 then return end
	-- local fbConfig = server.configCenter.DisasterFbConfig
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	if not self.player:PayReward(0, 2, baseConfig.openboxprice, self.YuanbaoRecordType, "eightone"..id) then return end
	self.cache.buy[key1] = data | (2 ^ key2)
	self.player:GiveRewardAsFullMailDefault(baseConfig.boxreward, "八十一难", self.YuanbaoRecordType, "八十一难宝箱")

	local boxConfig = server.configCenter.DisasterBoxConfig
	local maxNum = 0
	for _,v in pairs(boxConfig) do
		maxNum = maxNum + v.weight
	end
	local rd = math.random(1, maxNum)
	for _, vv in ipairs(boxConfig) do
		if vv.weight < rd then
			rd = rd - vv.weight
		else
			local rewards = vv.item
			self.player:GiveRewardAsFullMailDefault({rewards}, "八十一难", self.YuanbaoRecordType, "八十一难"..key1.."->"..key2)
			break
		end
	end
	local msg = self:packUpInfo("buy")
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info_update", msg)
end

function EightyOneHardPlug:onDayTimer()
	self.cache.helpReward = 0
	self.cache.buy = {}
	self.cache.todayClearlist = {}
	local msg = self:packUpInfo("helpReward","buy","todayClearlist")
	server.sendReq(self.player, "sc_fuben_eightyOneHard_info_update", msg)
end

function EightyOneHardPlug:GetNum()
	return self.cache.clear
end

server.playerCenter:SetEvent(EightyOneHardPlug, "eightyOneHard")
return EightyOneHardPlug