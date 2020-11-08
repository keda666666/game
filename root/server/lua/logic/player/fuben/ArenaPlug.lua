local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local ArenaPlug = oo.class()

function ArenaPlug:ctor(player)
	self.player = player
end

function ArenaPlug:onCreate()
	local ArenaConfig = server.configCenter.ArenaConfig
	self:onLoad()
	self.cache.pkcount = ArenaConfig.normalPKCount
	self.cache.reverttime = 0
	self.cache.maxrank = ArenaConfig.initRank
	self.cache.buycount = 0
	self.cache.buytime = 0
end

function ArenaPlug:onLoad()
	self.cache = self.player.cache.arena
end

function ArenaPlug:onInitClient()
	self:RevertPKCount()
end

-- 回复挑战次数
function ArenaPlug:RevertPKCount()
	local pkcount = self.cache.pkcount
	local reverttime = self.cache.reverttime

	local ArenaConfig = server.configCenter.ArenaConfig
	local nomalpkcount = ArenaConfig.normalPKCount
	local revertinterval = ArenaConfig.revertInterval * 60
	local revertpkcount = ArenaConfig.revertPKCount
	local now = lua_app.now() 
	if pkcount < nomalpkcount then
		local rcount  = math.floor((now - reverttime) / revertinterval);
		if rcount > 0 then
			self.cache.pkcount = math.min(pkcount + (revertpkcount * rcount), nomalpkcount)
			self.cache.reverttime = reverttime + rcount * revertinterval
			lua_app.log_info("ArenaPlug:RevertPKCount",  self.cache.pkcount, self.cache.reverttime)
		end
	end
end

-- 剩余回复时间
function ArenaPlug:GetRemainTime()
	local ArenaConfig = server.configCenter.ArenaConfig
	local now = lua_app.now()
	local remaintime = 0
    if self.cache.pkcount < ArenaConfig.normalPKCount then
    	remaintime = self.cache.reverttime + ArenaConfig.revertInterval * 60 - now
    end
	return remaintime
end


-- 扣除挑战次数
function ArenaPlug:CheckDelPKCount()
	local pkcount = self.cache.pkcount
	if pkcount <= 0 then
		return false
	end

	self.cache.pkcount = pkcount - 1
	if pkcount == server.configCenter.ArenaConfig.normalPKCount then
		self.cache.reverttime = lua_app.now() 
	end

	lua_app.log_info("ArenaPlug:CheckDelPKCount",  self.cache.pkcount, self.cache.reverttime)
	return true
end

-- 获取竞技场数据
function ArenaPlug:GetArenaInfo()
	self:RevertPKCount()
	self:RefreshBuy()

    local targetranks = server.arenaCenter:GenTargets(self.player.dbid)
    local targets = {}
    for i,targetrank in ipairs(targetranks) do
    	local targetid = server.arenaCenter:GetRankPlayerId(targetrank)
    	local target = {
    		rank = targetrank,
	    }
	    local targetplayer
	    if targetid then
	    	targetplayer = server.playerCenter:DoGetPlayerByDBID(targetid)
	    end
	     
	    if not targetplayer then
	    	local ArenaRobotConfig = server.configCenter.ArenaRobotConfig
	    	target.id = 0
	    	target.power = ArenaRobotConfig[targetrank] and ArenaRobotConfig[targetrank].power or 0
	    	target.name = "挑战者"
	    	for k,v in pairs(ArenaRobotConfig[targetrank].initmonsters) do
	    		if v.pos == 8 then
	    			target.monId = v.monid
	    		end
	    	end
	    else
	    	target.id = targetid
    		target.power = targetplayer.cache.totalpower
    		target.name = targetplayer.cache.name
    		target.job = targetplayer.cache.job
    		target.sex = targetplayer.cache.sex
    		target.shows = targetplayer.role:GetShows()
	    end
	    if i == 5 then
		    target.iskill = self:IsKill(target.power) 
		end
	    table.insert(targets, target)
    end


    local arenainfo = {
		targets		= targets,
		rank		= server.arenaCenter:GetRank(self.player.dbid),
		maxrank		= self.cache.maxrank,
		pkcount		= self.cache.pkcount,
		remaintime	= self:GetRemainTime(),
		buycount 	= self.cache.buycount,
		medal		= self.cache.medal,
	}

    return arenainfo
end

-- 挑战玩家
function ArenaPlug:ArenaPK(msg)
	local packinfo = server.dataPack:FightInfo(self.player)
	local targetrank = msg.rank
    local targetid = server.arenaCenter:GetRankPlayerId(targetrank)
    packinfo.exinfo = {
        targetrank = targetrank,
        targetid = targetid,
    }

    lua_app.log_info("ArenaPlug:ArenaPK",  targetrank)

    if server.raidMgr:IsInRaid(self.player.dbid) then
    	server.sendErr(self.player, "正在战斗中")
    	return
    end

    -- 检查目标是否可挑战
    if not server.arenaCenter:CheckTarget(self.player.dbid, targetrank) then
    	lua_app.log_info("ArenaPlug:ArenaPK can not pk this target", targetid, targetrank)
    	return
    end

    -- 扣除挑战次数
    if not self:CheckDelPKCount() then
    	lua_app.log_info("ArenaPlug:ArenaPK pkcount not enought", self.cache.pkcount)
    	return
    end

    if not targetid then
    	-- 机器人
    	local ArenaRobotConfig = server.configCenter.ArenaRobotConfig
    	local robot = ArenaRobotConfig[targetrank]
    	if robot and server.arenaCenter:IsLastTarget(self.player.dbid, targetrank) and self:IsKill(robot.power) then
    		self:DoPKResult(true, targetrank, true)
    	else
    		server.raidMgr:Enter(server.raidConfig.type.Arena, self.player.dbid, packinfo)
    	end
    else
	    local targetplayer = server.playerCenter:DoGetPlayerByDBID(targetid)
	    if targetplayer then
	    	if server.arenaCenter:IsLastTarget(self.player.dbid, targetrank) and self:IsKill(targetplayer.cache.totalpower) then
	    		self:DoPKResult(true, targetrank, true)
	    	else
	    		local targetpackinfo = server.dataPack:FightInfo(targetplayer)
	    		packinfo.exinfo.targetpack = targetpackinfo
	    		server.raidMgr:Enter(server.raidConfig.type.Arena, self.player.dbid, packinfo)
	    	end
	    else
	    	lua_app.log_error("ArenaPlug:ArenaPK no arena target", targetid, targetrank)
		end
	end
end

-- 是否可以秒杀
function ArenaPlug:IsKill(power)
	local secKill = server.configCenter.ArenaConfig.secKill
	if power < self.player.cache.totalpower * (100 - secKill) / 100 then
		return true
	else
		return false
	end
end

-- 挑战结果
function ArenaPlug:DoPKResult(iswin, targetrank, iskill)
	lua_app.log_info("ArenaPlug:DoPKResult", iswin, targetrank)
	local ArenaRewardConfig = server.configCenter.ArenaRewardConfig
	local winrewards = {}
	local lostrewards = {}
	for _,v in ipairs(ArenaRewardConfig) do
		if v.rankBegin <= targetrank and targetrank <= v.rankEnd then
			winrewards = server.dropCenter:DropGroup(v.winDropId)
			lostrewards = server.dropCenter:DropGroup(v.loseDropId)
			break
		end
	end

	local lastrank = server.arenaCenter:GetRank(self.player.dbid)
	local msg = {}
	msg.lastmaxrank = self.cache.maxrank
	if iswin then
		server.arenaCenter:ExchangeRank(self.player.dbid, targetrank)
		self.player.activityPlug:onDoTarget()
		self:CheckMaxRank(targetrank)
		self.rewards = winrewards

		msg.result = 1
		msg.rewards = winrewards
		msg.iskill = iskill
		msg.maxrank	= self.cache.maxrank
		msg.rank = targetrank < lastrank and targetrank or lastrank
		msg.lastrank = lastrank
	else
		self.rewards = lostrewards

		msg.result = 0
		msg.rewards = lostrewards
		msg.maxrank	= self.cache.maxrank
		msg.rank = lastrank
		msg.lastrank = lastrank
	end

	server.sendReqByDBID(self.player.dbid, "sc_arena_pk_result", msg)

	self.player.shop:onUpdateUnlock()
	self.player.task:onEventAdd(server.taskConfig.ConditionType.Arena)
	self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.Arena)
	server.teachersCenter:AddNum(self.player.dbid, 7)
end

-- 检查历史最高排名
function ArenaPlug:CheckMaxRank(targetrank)
	if targetrank < self.cache.maxrank then
		local ArenaConfig = server.configCenter.ArenaConfig
		local lastrank = self.cache.maxrank
		self.cache.maxrank = targetrank

		local count = math.max((lastrank - self.cache.maxrank) * ArenaConfig.promoteReward, 0)
		self.player:GiveReward(ItemConfig.AwardType.Numeric, ItemConfig.NumericType.BYB, count, 1, server.baseConfig.YuanbaoRecordType.Arena)
	end
end

-- 领取奖励
function ArenaPlug:GetReward()
	local rewards = self.rewards
	if rewards then
		self.rewards = nil
		self.player:GiveRewardAsFullMailDefault(rewards, "竞技场", server.baseConfig.YuanbaoRecordType.Arena)
	end
end

-- 刷新购买次数
function ArenaPlug:RefreshBuy()
	local dayinterval = os.intervalDays(self.cache.buytime or 0)
	if dayinterval > 0 then
		self.cache.buycount = 0
	end
end

-- 购买挑战次数
function ArenaPlug:BuyPK()
	self:RevertPKCount()
	self:RefreshBuy()
	local ArenaConfig = server.configCenter.ArenaConfig
	local ArenaVipConfig = server.configCenter.ArenaVipConfig
	local buycount = self.cache.buycount or 0
	local pkcount = self.cache.pkcount
	local buymax = ArenaVipConfig[self.player.cache.vip] and ArenaVipConfig[self.player.cache.vip].maxBuyTime or ArenaConfig.maxBuyTime

	if buycount >= buymax then
		lua_app.log_info("ArenaPlug:BuyPK today buy count reach max", buycount, buymax)
		return {ret = false, pkcount = pkcount, buycount = buycount}
	end

	if pkcount > ArenaConfig.maxPKCount then
		lua_app.log_info("ArenaPlug:BuyPK pk count reach max", pkcount, ArenaConfig.maxPKCount)
		return {ret = false, pkcount = pkcount, buycount = buycount}
	end

	if not self.player:PayReward(ItemConfig.AwardType.Numeric, ItemConfig.NumericType.YuanBao, ArenaConfig.pkCountPrice, server.baseConfig.YuanbaoRecordType.Arena, "Arena:Buy") then
		return {ret = false, pkcount = pkcount, buycount = buycount}
	end

	self.cache.buycount = buycount + 1
	self.cache.pkcount = pkcount + ArenaConfig.buyPKCount
	self.cache.buytime = lua_app.now()

	return {ret = true, pkcount = self.cache.pkcount, buycount = self.cache.buycount}
end

server.playerCenter:SetEvent(ArenaPlug, "arena")
return ArenaPlug