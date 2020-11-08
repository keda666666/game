local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local dailyTaskConfig = require "resource.DailyTaskConfig"
local DailyTask = oo.class()

function DailyTask:ctor(player)
	-- local femaleDevaBaseConfig = server.configCenter.FemaleDevaBaseConfig
	-- FightConfig.FightStatus.Running
	-- self.skilllist = {{[3] = {11001}}}
	-- self:AddSkill(11001, true, 1)
	-- self.hskillNo = femaleDevaBaseConfig.hskill
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.DailyTask
end

function DailyTask:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.daily_task
	if self.cache.openDay == 0 then return end
	local allattr = self:Allattr()
	self.role:UpdateBaseAttr({}, allattr, server.baseConfig.AttrRecord.DailyTask)
	self:CheckAddMonster()
end

function DailyTask:CheckAddMonster()
	if self.cache.openDay == 0 then return end
	local data = self.cache.otherActivity.monster
	local baseConfig = self:GetDailyBaseConfig()
	local num = baseConfig.monlimit - #data.monsterList
	if num == 0 then return end
	local ti = lua_app.now() - data.time
	if ti < 0 then
		local timeout = data.time - lua_app.now()
		self.rumTime = lua_app.add_update_timer(timeout * 1000, self, "TimeOutAddMonster", true)
		return
	end 
	local addNum = math.floor(ti / (baseConfig.recovertime * 60)) + 1

	if (#data.monsterList + addNum) >= baseConfig.monlimit then
		addNum = baseConfig.monlimit - #data.monsterList
		data.time = 0
		-- data.timeout = 0
	else
		-- data.timeout = lua_app.now() + (baseConfig.recovertime * 60)
		local timeout = (baseConfig.recovertime * 60) - (ti % (baseConfig.recovertime * 60))
		data.time = lua_app.now() + timeout
		self.rumTime = lua_app.add_update_timer(timeout * 1000, self, "TimeOutAddMonster", true)
	end
	if addNum > 0 then
		self:AddMonster(addNum)
	end
end

function DailyTask:TimeOutAddMonster(_, notMsg)
	self.rumTime = nil
	self:AddMonster(1)
	local baseConfig = self:GetDailyBaseConfig()
	local data = self.cache.otherActivity.monster
	if #data.monsterList < baseConfig.monlimit then
		data.time = lua_app.now() + (baseConfig.recovertime * 60)
		-- data.timeout = lua_app.now() 
		self.rumTime = lua_app.add_update_timer((baseConfig.recovertime * 60) * 1000, self, "TimeOutAddMonster")
	else
		data.time = 0
		-- data.timeout = 0
	end
	if not notMsg then
		local msg = {}
		msg.monster = data
		server.sendReq(self.player, "sc_dailyTask_update", msg)
	end
end

function DailyTask:onDayTimer()
	if self.cache.openDay == 0 then return end
	local runDay = server.serverRunDay
	if (runDay - 1) ~= self.cache.openDay and (self.cache.find + 1) == runDay then
		self.cache.yesterday = self.cache.today
	else
		self.cache.yesterday = {}
	end
	self.cache.find = runDay
	self.cache.today = {}
	self.cache.findData = {item = {}, exp = {}}
	self.cache.active = 0
	self.cache.activeReward = 0 
	local data = self.cache.otherActivity

	data.chapterWar.num = 0
	data.chapterWar.reward = 0

	data.chapterWar.num = 0
	data.chapterWar.reward = 0
	
	data.monster.num = 0
	data.monster.reward = 0

	data.teamFB.num = 0
	data.teamFB.reward = 0
	
	self:onEventAdd(dailyTaskConfig.DailyTaskType.Login)
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_dailyTask_info", msg)
end	
	

function DailyTask:onCreate()
	self:onLoad()
end

function DailyTask:Allattr()
	--登录初始化数据
	return self:GetDailyAttrsConfig(self.cache.lv).attrpower
end

function DailyTask:onLevelUp(oldlevel, level)
	if self.cache.openDay ~= 0 then
		--如果玩家升级了需要更新怪物的等级
		local expDungeon = self:GetDailyExpDungeon()
		local oldId,newId
		for k,v in ipairs(expDungeon) do
			if v.level[1] <= oldlevel and (not v.level[2] or oldlevel <= v.level[2]) then
				oldId = k
			end
			if v.level[1] <= level and (not v.level[2] or level <= v.level[2]) then
				newId = k
				break
			end
		end
		if not oldId or not newId then return end

		if oldId == newId then return end
		local addnum = newId - oldId
		local data = self.cache.otherActivity.monster
		for k,v in pairs(data.monsterList) do
			data.monsterList[k] = v + (addnum * 7)
		end
		local msg = {}
		msg.monster = data
		server.sendReq(self.player, "sc_dailyTask_update", msg)
		return
	end
	local openlv = self:GetDailyBaseConfig().open
	local openConfig = server.configCenter.FuncOpenConfig[openlv]
	if openConfig.conditionnum <= level then
		self:Open()
	end
end

function DailyTask:Open()
	
	self.cache.openDay = server.serverRunDay
	local attrs = self:GetDailyAttrsConfig(self.cache.lv).attrpower
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.DailyTask)
	local baseConfig = self:GetDailyBaseConfig()
	self:AddMonster(baseConfig.monlimit)
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_dailyTask_info", msg)
	self:onEventAdd(dailyTaskConfig.DailyTaskType.Login)
end

function DailyTask:packInfo()
	local today = {}
	for k,v in pairs(self.cache.today) do
		table.insert(today, {no = k, num = v})
	end
	local yesterday = {}
	for k,v in pairs(self.cache.yesterday) do
		table.insert(yesterday, {no = k, num = v})
	end
	local findItem = {}
	for k,v in pairs(self.cache.findData.item) do
		table.insert(findItem, {no = k, num = v})
	end
	local findExp = {}
	for k,v in pairs(self.cache.findData.exp) do
		table.insert(findExp, {no = k, num = v})
	end
	local msg = {
		lv = self.cache.lv,
		exp = self.cache.exp,
		today = today,
		yesterday = yesterday,
		findItem = findItem,
		findExp = findExp,
		active = self.cache.active,
		activeReward = self.cache.activeReward,
		monster = self.cache.otherActivity.monster,
		chapterWar = self.cache.otherActivity.chapterWar,
		teamFB = self.cache.otherActivity.teamFB,
		find = self.cache.find,
	}
	return msg
end

local _dailyBaseConfig = false
function DailyTask:GetDailyBaseConfig()
	if _dailyBaseConfig then return _dailyBaseConfig end
	_dailyBaseConfig = server.configCenter.DailyBaseConfig
	return _dailyBaseConfig
end

local _dailyAttrsConfig = false
function DailyTask:GetDailyAttrsConfig(no)
	if _dailyAttrsConfig then return _dailyAttrsConfig[no] end
	_dailyAttrsConfig = server.configCenter.DailyAttrsConfig
	return _dailyAttrsConfig[no]
end

local _dailyProgressConfig = false
function DailyTask:GetDailyProgressConfig(no)
	if _dailyProgressConfig then return _dailyProgressConfig[no] end
	_dailyProgressConfig = server.configCenter.DailyProgressConfig
	return _dailyProgressConfig[no]
end

local _dailyActiveConfig = false
function DailyTask:GetDailyActiveConfig(no)
	if _dailyActiveConfig then return _dailyActiveConfig[no] end
	_dailyActiveConfig = server.configCenter.DailyActiveConfig
	return _dailyActiveConfig[no]
end

local _dailyRetrieveConfig = false
function DailyTask:GetDailyRetrieveConfig(key1, key2, key3)
	if _dailyRetrieveConfig then return _dailyRetrieveConfig[key1][key2][key3] end
	_dailyRetrieveConfig = server.configCenter.DailyRetrieveConfig
	return _dailyRetrieveConfig[key1][key2][key3]
end

local _dailyBonusConfig = false
function DailyTask:GetDailyBonusConfig(no)
	if _dailyBonusConfig then return _dailyBonusConfig[no] end
	_dailyBonusConfig = server.configCenter.DailyBonusConfig
	return _dailyBonusConfig[no]end

local _dailyLevelRetrieveConfig = false
function DailyTask:GetDailyLevelRetrieveConfig(no)
	if _dailyLevelRetrieveConfig then return _dailyLevelRetrieveConfig[no] end
	_dailyLevelRetrieveConfig = server.configCenter.DailyLevelRetrieveConfig
	return _dailyLevelRetrieveConfig[no]
end

local _dailyExpDungeon = false
function DailyTask:GetDailyExpDungeon()
	if _dailyExpDungeon then return _dailyExpDungeon end
	_dailyExpDungeon = server.configCenter.DailyExpDungeon
	return _dailyExpDungeon
end

local _dailyExpDungeonStar = false
function DailyTask:GetDailyExpDungeonStar(no)
	if _dailyExpDungeonStar then return _dailyExpDungeonStar[no] end
	_dailyExpDungeonStar = server.configCenter.DailyExpDungeonStar
	return _dailyExpDungeonStar[no]
end

function DailyTask:upLevel()
	local nextLv = self.cache.lv + 1
	local nextAttrsConfig = self:GetDailyAttrsConfig(nextLv)
	if not nextAttrsConfig then return {ret = false} end
	if self.cache.exp < nextAttrsConfig.proexp then return {ret = false} end
	local attrsConfig = self:GetDailyAttrsConfig(self.cache.lv) 
	self.cache.exp = self.cache.exp - nextAttrsConfig.proexp
	self.cache.lv = self.cache.lv + 1
	local newAttrs = nextAttrsConfig.attrpower
	local oldAttrs = attrsConfig.attrpower
	self.player:GiveRewardAsFullMailDefault(attrsConfig.rewards, "历练升级", self.YuanbaoRecordType, "历练升级"..self.cache.lv)
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.DailyTask)
	return {ret = true, exp = self.cache.exp,lv = self.cache.lv}
end

function DailyTask:ActivityReward(activityNo)
	local data = self:GetDailyActiveConfig(activityNo)
	if not data then return {ret = false} end
	if data.target > self.cache.active then return {ret = false} end
	local activeReward = self.cache.activeReward
	if activeReward & (2 ^ activityNo) ~= 0 then return {ret = false} end
	self.cache.activeReward = activeReward | (2 ^ activityNo)
	local rewards = data.reward
	self.player:GiveRewardAsFullMailDefault(rewards, "活跃奖励", self.YuanbaoRecordType, "活跃奖励"..activityNo)
	return {ret = true, activityReward = self.cache.activeReward}
end

function DailyTask:onInitClient()
	-- 登陆更新到客户端
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_dailyTask_info", msg)
end

function DailyTask:OtherActivityAdd(key)
	if self.cache.openDay == 0 then return end
	local num = self:GetDailyBaseConfig()[key]
	if self.cache.otherActivity[key].num >= num then return end
	self.cache.otherActivity[key].num = self.cache.otherActivity[key].num + 1
	local msg = {}
	msg[key] = self.cache.otherActivity[key]
	server.sendReq(self.player, "sc_dailyTask_update", msg)
end

function DailyTask:onEventAdd(no, num)
	if self.cache.openDay == 0 then return end
	num = num or 1
	local point = self.cache.today[no] or 0
	
	local progressConfig = self:GetDailyProgressConfig(no)
	if point >= progressConfig.maxtimes then return end
	if (point + num) > progressConfig.maxtimes then 
		num = progressConfig.maxtimes - point
	end

	self.cache.today[no] = point + num
	local addExp = progressConfig.exp
	local addActive = addExp * num
	self.cache.exp = self.cache.exp + addActive
	self.cache.active = self.cache.active + addActive
	self.player.auctionPlug:onAddActive(addActive)

	local today = {}
	for k,v in pairs(self.cache.today) do
		table.insert(today, {no = k, num = v})
	end
	local msg = {
		exp = self.cache.exp,
		active = self.cache.active,
		today = today,
	}
	server.sendReq(self.player, "sc_dailyTask_update", msg)
end

function DailyTask:Find(activityNo, cashtype, findType, num)
	if num == 0 then return {ret = false} end
	if self.cache.openDay == 0 and self.cache.find == 0 then return {ret = false} end
	local retrieveConfig = self:GetDailyRetrieveConfig(activityNo, cashtype, findType)
	if not retrieveConfig then return {ret = false} end
	local progressConfig = self:GetDailyProgressConfig(activityNo)
	local findData = self.cache.findData
	local playNum = self.cache.yesterday[activityNo] or 0
	if findType == 1 then
		if (playNum + (findData.item[activityNo] or 0) + num) > progressConfig.maxtimes then
			return {ret = false}
		end
	else
		if (playNum + (findData.exp[activityNo] or 0) + num) > progressConfig.maxtimes then
			return {ret = false}
		end
	end
	local levelRetrieveConfig = self:GetDailyLevelRetrieveConfig(retrieveConfig.index)
	for _,v in pairs(levelRetrieveConfig) do
		if self.player.cache.level >= v.level[1] and (not v.level[2] or self.player.cache.level <= v.level[2]) then
			local cost = table.wcopy(v.cost)
			for _,vv in pairs(cost) do
				vv.count = vv.count * num
			end
			if not self.player:PayRewardsByShop(cost, self.YuanbaoRecordType) then 
				return {ret = false}
			end
			local exp
			if findType == 1 then
				local rewards = table.wcopy(v.res)
				for _,v in pairs(rewards) do
					v.count = v.count * num 
				end
				findData.item[activityNo] = (findData.item[activityNo] or 0) + num
				self.player:GiveRewardAsFullMailDefault(rewards, "找回物品", self.YuanbaoRecordType, "活跃找回".."|"..activityNo.."|"..cashtype.."|"..findType.."|"..num)
			else
				findData.exp[activityNo] = (findData.exp[activityNo] or 0) + num
				exp = v.res * num
				self.cache.exp = self.cache.exp + exp
				lua_app.log_info("[dailyTask]playe:"..self.player.dbid.."addExp:"..self.cache.exp)
			end

			local msg ={
				ret = true,
				exp = self.cache.exp,
				activityNo = activityNo,
				findType = findType,

			}
			if findType == 1 then
				msg.num = findData.item[activityNo]
			else
				msg.num = findData.exp[activityNo]
				msg.findExpNum = exp
			end
			return msg
		end
	end
	return {ret = false}

end

function DailyTask:FindAllExp()
	if self.cache.openDay == 0 and self.cache.find == 0 then return {ret = false} end
	local retrieveConfig = server.configCenter.DailyRetrieveConfig
	local costNum = 0
	local activityNoList = {}
	local exp = 0
	for k,v in pairs(retrieveConfig) do
		for _,v1 in pairs(v) do
			for k1,v2 in pairs(v1) do
				if k1 == 2 then
					local levelRetrieveConfig = self:GetDailyLevelRetrieveConfig(v2.index)
					for _,v3 in pairs(levelRetrieveConfig) do
						if self.player.cache.level >= v3.level[1] and (not v3.level[2] or self.player.cache.level < v3.level[2]) then
							local cost = table.wcopy(v3.cost)
							local progressConfig = self:GetDailyProgressConfig(k)
							local num = progressConfig.maxtimes - (self.cache.yesterday[k] or 0) - (self.cache.findData.exp[k] or 0)
							if num > 0 then
								for _,v4 in pairs(cost) do
									costNum = costNum + (v4.count * num)
								end
								table.insert(activityNoList, {no = k, num = num})
								exp = exp + (v3.res * num)
							end
						end
					end
				end
			end
		end
	end
	if costNum == 0 then return {ret = false} end
	if not self.player:PayReward(0, 2 , costNum, self.YuanbaoRecordType) then return {ret = false} end
	-- if not self.player:PayRewardsByShop(costList, self.YuanbaoRecordType) then return end
	for _,v in pairs(activityNoList) do
		self.cache.findData.exp[v.no] = (self.cache.findData.exp[v.no] or 0) + v.num
	end
	self.cache.exp = self.cache.exp + exp
	local findExp = {}
	for k,v in pairs(self.cache.findData.exp) do
		table.insert(findExp, {no = k, num = v})
	end
	local msg ={
		exp = self.cache.exp,
		findExp = findExp,
	}
	server.sendReq(self.player, "sc_dailyTask_update", msg)
	return {ret = true, findExpNum = exp}
end

function DailyTask:OtherComplete(no)
	local act = "teamFB"
	if no == 2 then
		act = "chapterWar"
	elseif no == 1 then
		act = "monster"
	end
	local baseConfig = self:GetDailyBaseConfig()
	local bonusConfig = self:GetDailyBonusConfig(no)
	local data = self.cache.otherActivity[act]
	if not data then return end
	if data.num >= baseConfig[act] then return end
	local clearNum = baseConfig[act] - data.num
	local cost = table.wcopy(baseConfig[act.."cost"])
	for _,v in pairs(cost) do
		v.count = v.count * clearNum
	end
	if not self.player:PayRewardsByShop(cost, self.YuanbaoRecordType) then return end
	self.cache.otherActivity[act].num = baseConfig[act]
	for k,v in pairs(bonusConfig) do
		if data.reward & (2 ^ k) ==0 then
			for _,v1 in pairs(v) do
				if self.player.cache.level >= v1.level[1] and (not v1.level[2] or self.player.cache.level <= v1.level[2]) then
					data.reward = data.reward | (2 ^ k)
					local rewards = v1.itemid
					self.player:GiveRewardAsFullMailDefault(rewards, act, self.YuanbaoRecordType, "act"..v1.reward)
				end
			end
		end
	end
	local msg = {}
	msg[act] = self.cache.otherActivity[act]
	server.sendReq(self.player, "sc_dailyTask_update", msg)
	if no == 1 then
		--师门任务
		for i=1,clearNum do
			self.player.task:onEventAdd(server.taskConfig.ConditionType.DailyTaskMonster)
		end
		self.player.enhance:AddPoint(14, clearNum)
	end

	if act == "teamFB" then
		self.player.enhance:AddPoint(15, clearNum)
	end
end

function DailyTask:OtherReward(no, reward)
	local bonusConfig = self:GetDailyBonusConfig(no)[reward]
	local config = nil
	for _,v in ipairs(bonusConfig) do
		if self.player.cache.level >= v.level[1] and (not v.level[2] or self.player.cache.level <= v.level[2]) then
			config = v
			break
		end
	end

	if not config then return end
	
	local act = "teamFB"
	if no == 2 then
		act = "chapterWar"
	elseif no == 1 then
		act = "monster"
	end
	local data = self.cache.otherActivity[act]
	if data.reward & (2 ^ reward) ~=0 then return end
	if data.num < config.target then return end
	data.reward = data.reward | (2 ^ reward)
	local rewards = config.itemid
	self.player:GiveRewardAsFullMailDefault(rewards, act, self.YuanbaoRecordType, "act"..reward)
	local msg = {}
	msg[act] = self.cache.otherActivity[act]
	server.sendReq(self.player, "sc_dailyTask_update", msg)
end

function DailyTask:AddMonster(num)
	local data = self.cache.otherActivity.monster
	-- local ti = lua_app.now() - data.time
	-- local baseConfig = self:GetDailyBaseConfig()
	local expDungeon = self:GetDailyExpDungeon()
	for _,v in pairs(expDungeon) do
		if v.level[1] <= self.player.cache.level and (not v.level[2] or self.player.cache.level <= v.level[2]) then
			for i = 1, num do
				local no = v.dungeonlist[math.random(#v.dungeonlist)]
				table.insert(data.monsterList, no)
			end
			break
		end
	end
end

function DailyTask:FightMonster(no)
	local data = self.cache.otherActivity.monster
	local monsterNo = data.monsterList[no]
	if not monsterNo then return end
	local packinfo = server.dataPack:FightInfo(self.player)
	packinfo.exinfo = {
		monsterNo = monsterNo,
		no = no,
	}
	
	server.raidMgr:Enter(server.raidConfig.type.DailyTaskMonster, self.player.dbid, packinfo)
end

function DailyTask:UpMonster(no)
	local data = self.cache.otherActivity.monster
	local dungeonStar = self:GetDailyExpDungeonStar(data.monsterList[no])

	if not dungeonStar or not dungeonStar.refreshcost then return end
	if not self.player:PayRewards(dungeonStar.refreshcost,self.YuanbaoRecordType) then return end
	local data = self.cache.otherActivity.monster
	data.monsterList[no] = data.monsterList[no] + (7 - dungeonStar.star)
	local msg = {}
	msg.monster = data
	server.sendReq(self.player, "sc_dailyTask_update", msg)
end

function DailyTask:GetMonsterReward(no)
	

	local baseConfig = self:GetDailyBaseConfig()
	local data = self.cache.otherActivity.monster
	local id = table.remove(data.monsterList, no)
	local dungeonStar = self:GetDailyExpDungeonStar(id)
	
	if data.time == 0 then
		data.time = lua_app.now() + (baseConfig.recovertime * 60)
		-- data.timeout = baseConfig.recovertime * 60
		self.rumTime = lua_app.add_update_timer((baseConfig.recovertime * 60) * 1000, self, "TimeOutAddMonster")
	end
	self.player:GiveRewardAsFullMailDefault(dungeonStar.reward, "师门任务", self.YuanbaoRecordType, "师门任务")
	local msg = {}
	if data.num < baseConfig.monster then
		data.num = data.num + 1
	end
	msg.monster = data
	server.teachersCenter:AddNum(self.player.dbid, 3)
	server.sendReq(self.player, "sc_dailyTask_update", msg)
	self.player.task:onEventAdd(server.taskConfig.ConditionType.DailyTaskMonster)
	self.player.enhance:AddPoint(14, 1)
end

server.playerCenter:SetEvent(DailyTask, "dailyTask")
return DailyTask