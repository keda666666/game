local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local CrossTeamPlug = oo.class()

function CrossTeamPlug:ctor(player)
	self.player = player
end

function CrossTeamPlug:onCreate()
	self:onLoad()
end

function CrossTeamPlug:onLoad()
	self.cache = self.player.cache.crossTeamFb
end

function CrossTeamPlug:onInitClient()
	-- local resettime = server.clockCenter.crossTeamResetRewardTime
	-- if resettime and self.cache.lastresettime ~= resettime then
	-- 	self:ResetRewardCount(resettime)
	-- end
	self:SendRewardCount()
end

function CrossTeamPlug:onDayTimer()
	self.cache.rewardcount = 0
end

-- function CrossTeamPlug:ResetRewardCount(time)
-- 	self.cache.rewardcount = 0
-- 	self.cache.lastresettime = time
-- end

function CrossTeamPlug:DoResult(iswin, level, membercount)
	self.fightresult = {iswin = iswin, level = level, membercount = membercount}
	local msg = {}
	if iswin then
		msg.result = 1
		self.player.task:onEventAdd(server.taskConfig.ConditionType.TeamFb)
		self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.TeamFb)
		self.player.dailyTask:OtherActivityAdd(DailyTaskConfig.DailyActivity.TeamFb)
		server.teachersCenter:AddNum(self.player.dbid, 4)
		self.player.enhance:AddPoint(15, 1)
	else
		msg.result = 0
	end
	self.rewards = self:GenRewards()
	msg.rewards = self.rewards

	self.player:sendReq("sc_raid_chapter_boss_result", msg)
end

function CrossTeamPlug:GenRewards()
	if not self.fightresult then return end
	local iswin = self.fightresult.iswin
	local level = self.fightresult.level
	local membercount = self.fightresult.membercount
	self.fightresult = nil

	local fb = server.configCenter.CrossTeamFbConfig[level]
	if not fb then return end

	local CrossTeamConfig = server.configCenter.CrossTeamConfig
	local CrossTeamVIPConfig = server.configCenter.CrossTeamVIPConfig
	local limitcount = CrossTeamVIPConfig[self.player.cache.vip] and CrossTeamVIPConfig[self.player.cache.vip].rewardCount or CrossTeamConfig.rewardCount
	if self.cache.rewardcount >= limitcount then return end

	if iswin then
		local rewards = {}
		
		if not self.cache.clearlist[level] then
			-- 首通奖励
			self.cache.clearlist[level] = 1
			local firstrewards = server.dropCenter:DropGroup(fb.firstReward)
			for _, v in pairs(firstrewards) do
				table.insert(rewards, v)
			end
		end

		self.cache.clearlist[level] = self.cache.clearlist[level] + 1
		local dropid = fb.normalReward
		-- 满员
		if membercount == 3 then
			dropid = fb.fullReward
		end
		-- 固定奖励
		local normalrewards = server.dropCenter:DropGroup(dropid)
		-- 双倍时段加成
		if self:IsDoubleTime() then
			for _, v in pairs(normalrewards) do
				if v.type == ItemConfig.NumericType.Exp or 
					v.type == ItemConfig.NumericType.Gold then
					v.count = v.count * 2
				end
			end
		end
		
		for _, v in pairs(normalrewards) do
			table.insert(rewards, v)
		end

		-- 几率奖励
		local luckrewards = server.dropCenter:DropGroup(fb.luckReward)
		for _, v in pairs(luckrewards) do
			table.insert(rewards, v)
		end
		return rewards
	end
end

function CrossTeamPlug:GetReward()
	if not self.rewards or #self.rewards == 0 then return end
	self.cache.rewardcount = self.cache.rewardcount + 1
	self.player:GiveRewardAsFullMailDefault(self.rewards, "跨服组队", server.baseConfig.YuanbaoRecordType.CrossTeam)
	self.rewards = nil
end

-- 是否是双倍时段
function CrossTeamPlug:IsDoubleTime()
	local CrossTeamConfig = server.configCenter.CrossTeamConfig
	local hour = lua_app.hour()
	local minute = lua_app.hour()
	local relativetime = hour * 3600 + minute * 60
	local doublebegin = CrossTeamConfig.doubleBeginTime.hour * 3600 + CrossTeamConfig.doubleBeginTime.minute * 60
	local doubleend = CrossTeamConfig.doubleEndTime.hour * 3600 + CrossTeamConfig.doubleEndTime.minute * 60
	local doublebegin2 = CrossTeamConfig.doubleBeginTimeSecond.hour * 3600 + CrossTeamConfig.doubleBeginTimeSecond.minute * 60
	local doubleend2 = CrossTeamConfig.doubleEndTimeSecond.hour * 3600 + CrossTeamConfig.doubleEndTimeSecond.minute * 60
	local isdouble = false
	
	if CrossTeamConfig.doubleBeginTime.day == 1 then
		-- 跨天
		isdouble = isdouble or (relativetime >= doublebegin or relativetime <= doubleend)
	else
		-- 不跨天
		isdouble = isdouble or (doublebegin <= relativetime and relativetime <= doubleend)
	end

	if CrossTeamConfig.doubleEndTimeSecond.day == 1 then
		-- 跨天
		isdouble = isdouble or (relativetime >= doublebegin2 or relativetime <= doubleend2)
	else
		-- 不跨天
		isdouble = isdouble or (doublebegin2 <= relativetime and relativetime <= doubleend2)
	end

	-- 开服第一天默认双倍
	if server.serverRunDay == 1 then
		isdouble = true
	end

	return isdouble
end

function CrossTeamPlug:GetRewardCount()
	local CrossTeamConfig = server.configCenter.CrossTeamConfig
	local CrossTeamVIPConfig = server.configCenter.CrossTeamVIPConfig
	local limitcount = CrossTeamVIPConfig[self.player.cache.vip] and CrossTeamVIPConfig[self.player.cache.vip].rewardCount or CrossTeamConfig.rewardCount
	local count = limitcount - self.cache.rewardcount
	return count
end

function CrossTeamPlug:SendRewardCount()
	local count = self:GetRewardCount()
	local msg = {}
	msg.count = count
	msg.clear = {}
	for level, count in pairs(self.cache.clearlist) do
		table.insert(msg.clear, {level = level, count = count})
	end
	self.player:sendReq("sc_cross_team_reward_count", msg)
end

server.playerCenter:SetEvent(CrossTeamPlug, "crossTeam")
return CrossTeamPlug