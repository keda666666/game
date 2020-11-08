local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local WeightData = require "WeightData"
local GuildConfig = require "common.resource.GuildConfig"

local GuildMap = oo.class()

local _exchangeMark = 0xffff

function GuildMap:ctor(player, guildctrl)
	self.player = player
	self.guildctrl = guildctrl
end

function GuildMap:Init(datas)
	local map = datas.map
	if not map then
		map = {}
		map.gatherTask = {
			id = GuildConfig.Task.GuildGather,
			count = 0,
			recount = 0,
			rewardStatus = false,
		}
		map.monsterTask = {
			id = GuildConfig.Task.GuildMonster,
			count = 0,
			recount = 0,
			rewardStatus = false,
		}
		map.refreshCount = 0
		map.exchangeMark = _exchangeMark
		map.exchangeShop = {}
		map.refreshTime = 0
		map.guildBag = {}
		datas.map = map
	end
	self.cache = map
	self.guildBag = map.guildBag
end

function GuildMap:ResetTask(datas, reset)
	datas.count = 0
	datas.recount = reset and 0 or  datas.recount + 1
	datas.rewardStatus = false
end

function GuildMap:PerformTask(taskId)
	local GuildMonsterConfig = server.configCenter.GuildMonsterConfig
	local GuildMapTaskConfig = server.configCenter.GuildMapTaskConfig
	local level = self.guildctrl:GetGuildLevel()
	local taskType = GuildMapTaskConfig[taskId].type
	local dropId = GuildMonsterConfig[level][taskType].table
	--需要进入战斗
	if taskId == GuildConfig.Task.GuildMonster then
		local fubenId = GuildMonsterConfig[level][taskType].fbid
		local packinfo = server.dataPack:FightInfo(self.player)
	        packinfo.exinfo = {
	            fubenId = fubenId,
	            dropId = dropId,
	            taskId = taskId,
	        }
	   	server.raidMgr:Enter(server.raidConfig.type.GuildSprite, self.player.dbid, packinfo)
	   	return
	end
	local rewards = server.dropCenter:DropGroup(dropId)
	self:NotifyTaskComplete(taskId, rewards)
end

function GuildMap:NotifyTaskComplete(taskId, rewards)
	local GuildMapTaskConfig = server.configCenter.GuildMapTaskConfig
	local datas = self:GetDataByTaskId(taskId)
	if datas.count > GuildMapTaskConfig[taskId].number then
		return
	end
	self:AddItemToGuildBag(rewards)
	self:AddTaskComplete(datas)
	if datas.count == GuildMapTaskConfig[taskId].number then
		self.guildctrl:UpdateActive(taskId)
	end
	self:SendClientTaskInfo(taskId)
end

function GuildMap:SendClientTaskInfo(taskId)
	server.sendReq(self.player, "sc_guild_map_one_update", self:GetDataByTaskId(taskId))
end

function GuildMap:GetDataByTaskId(taskId)
	local dataName = GuildConfig.MapDataname[taskId]
	if not dataName then
		lua_app.error("taskId not exist GuildConfig. taskId:"..taskId)
		return
	end
	return self.cache[dataName]
end

function GuildMap:AddItemToGuildBag(rewards)
	for _, item in pairs(rewards) do
		self.guildBag[item.id] = self.guildBag[item.id] and self.guildBag[item.id] + item.count or item.count
	end
	server.sendReq(self.player, "sc_guild_map_reward", {
			reward = rewards,
		})
end

function GuildMap:AddTaskComplete(datas)
	datas.count = datas.count + self:GetTaskRate()
end

function GuildMap:GetTaskRate()
	local GuildConfig = server.configCenter.GuildConfig
	local thetime = GuildConfig.doubletime
	local rate = 1
	local nowTime = lua_app.now()
	local startTime = os.getTimestamp(thetime.star)
	local endTime = os.getTimestamp(thetime.ends)
	if nowTime >= startTime and nowTime < endTime then
		rate = math.random(GuildConfig.doublenum.min, GuildConfig.doublenum.max)
	end
	return rate
end

function GuildMap:QuickComplete(taskId)
	local GuildMonsterConfig = server.configCenter.GuildMonsterConfig
	local GuildMapTaskConfig = server.configCenter.GuildMapTaskConfig
	--支付
	local cost = GuildMapTaskConfig[taskId].onekeycost
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.GuildMap) then
		lua_app.log_info(">>Onekey cost fail. cost info:",cost.type, cost.id, cost.count)
		return false
	end
	local level = self.guildctrl:GetGuildLevel()
	local taskType = GuildMapTaskConfig[taskId].type
	local taskCount = GuildMapTaskConfig[taskId].number
	local dropId = GuildMonsterConfig[level][taskType].table
	local datas = self:GetDataByTaskId(taskId)
	for completeCount = datas.count + 1, taskCount do
		local rewards = server.dropCenter:DropGroup(dropId)
		self:NotifyTaskComplete(taskId, rewards)
	end
	return true
end

--重置任务
function GuildMap:PerformReset(taskId)
	local GuildMapTaskConfig = server.configCenter.GuildMapTaskConfig
	local VipPrivilegeConfig = server.configCenter.VipPrivilegeConfig
	local vipLv = self.player.cache.vip
	local recountMax = VipPrivilegeConfig[vipLv].buyreset
	
	local datas = self:GetDataByTaskId(taskId)
	if datas.recount >= recountMax then
		lua_app.log_info(">>Recount reach the upper Limit. recountMax:"..recountMax..", recount:"..datas.recount)
		return false
	end
	local cost = GuildMapTaskConfig[taskId].resetcost
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.GuildMap) then
		lua_app.log_info(">>PerformReset cost fail. cost info:",cost.type, cost.id, cost.count)
		return false
	end
	self:ResetTask(datas)
	return true
end

function GuildMap:GetTaskReward(taskId)
	local datas = self:GetDataByTaskId(taskId)
	if datas.rewardStatus then
		lua_app.log_info(">>The rewards have been received. acount:"..self.player.cache.name)
		return false
	end
	local GuildMapTaskConfig = server.configCenter.GuildMapTaskConfig
	local taskConf = GuildMapTaskConfig[taskId]
	local needTaskCount = taskConf.number
	local nowTaskCount = datas.count
	if nowTaskCount < needTaskCount then
		lua_app.log_info(">>>Task count not enough. now count:"..nowTaskCount..", need count:"..needTaskCount)
		return false
	end
	local rewards = taskConf.reward
	self.player:GiveRewardAsFullMailDefault(rewards, "帮派任务", server.baseConfig.YuanbaoRecordType.GuildMap)
	datas.rewardStatus = true
	self:SendClientTaskInfo(taskId)

	return true
end

local _ExchangeGroupList = false
local function _InitExchangeGroupList()
	_ExchangeGroupList = {}
	local GuildRefreshConfig = server.configCenter.GuildRefreshConfig
	for _, v in ipairs(GuildRefreshConfig) do
		if not _ExchangeGroupList[v.level] then
			_ExchangeGroupList[v.level] = WeightData.new()
		end
		for _, item in pairs(v.table) do
			_ExchangeGroupList[v.level]:Add(item.rate, item.id)
		end
	end
end

local function _GetExchangeGroupByLevel(level)
	if not _ExchangeGroupList then
		_InitExchangeGroupList()
	end
	if not _ExchangeGroupList[level] then
		lua_app.log_error("_GetExchangeGroupByLevel: level(", level)
		return
	end
	return _ExchangeGroupList[level]:GetRandomCounts(server.configCenter.GuildConfig.collectionnum)
end

function GuildMap:Purchase(id)
	if not self:CheckPurchase(id)then
		lua_app.log_info(">>CheckPurchase false. id:"..id)
		return false
	end
	local GuildMapBuyConfig = server.configCenter.GuildMapBuyConfig
	local cost = GuildMapBuyConfig[id].cost
	if not self:ExchangePay(cost) then
		lua_app.log_info("ExchangePay fail.")
		return false
	end
	local rewards = GuildMapBuyConfig[id].reward
	self.player:GiveRewardAsFullMailDefault(rewards, "帮会收购", server.baseConfig.YuanbaoRecordType.GuildMap)
	local mark = self.cache.exchangeMark
	self.cache.exchangeMark = lua_util.bit_shut(mark, id)
	self.player.guild:UpdateActive(GuildMapBuyConfig[id].taskid)		--活跃更新
	return true
end

function GuildMap:ExchangePay(cost)
	local guildBag = self.cache.guildBag
	for _, v in pairs(cost) do
		if (guildBag[v.id] or 0) < v.count then
			return false
		end
	end
	for _, v in pairs(cost) do
		if guildBag[v.id] < v.count then
			lua_app.log_error("GuildMap:ExchangePay:: 紧急的Clamant ERROR", self.player.cache.dbid, self.player.cache.name)
		end
		guildBag[v.id] = guildBag[v.id] - v.count
	end
	return true
end

function GuildMap:GetExchangeList()
	if lua_app.now() >= self.cache.refreshTime then
		self:RefreshExchangeList()
	end
	return self.cache.exchangeShop
end

--付费刷新
function GuildMap:RefreshManual()
	local GuildConfig = server.configCenter.GuildConfig
	local cost = GuildConfig.buycost
	local refreshMax = GuildConfig.number
	if self.cache.refreshCount >= refreshMax then
		lua_app.log_info(">>refresh reach the upper Limit.refreshCount:"..self.cache.refreshCount)
		return false
	end
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.GuildMap, "GuildMap:exchange:refresh") then
		lua_app.log_info("PayRewards fail. cost info:"..cost.type, cost.id, cost.count)
		return false
	end
	self:RefreshExchangeList()
	self.cache.refreshCount = self.cache.refreshCount + 1
	return true
end

function GuildMap:RefreshExchangeList()
	self.cache.refreshTime = lua_app.now() + server.configCenter.GuildConfig.buytime 
	local guild = self.player.guild:GetGuild()
	if not guild then
		lua_app.log_info(">>player not join guild.")
		return
	end
	local exchangeList = _GetExchangeGroupByLevel(guild:GetLevel())
	local newExchangelist = {}
	for _,id in pairs(exchangeList) do
		newExchangelist[id] = true
	end
	self.cache.exchangeShop = newExchangelist
	self.cache.exchangeMark = _exchangeMark
end

function GuildMap:CheckPurchase(id)
	local exchangeList = self:GetExchangeList()
	if not exchangeList[id] then
		return false
	end
	if not lua_util.bit_status(self.cache.exchangeMark, id) then
		return false
	end 
	return true
end

function GuildMap:GetTaskInfoById(taskId)
	local taskData = self:GetDataByTaskId(taskId)
	return {
		id = taskId,
		count = taskData.count,
		recount = taskData.recount,
		rewardStatus = taskData.rewardStatus
	}
end

function GuildMap:GetTaskInfo()
	local datas = {}
	for taskId,_ in pairs(GuildConfig.MapDataname) do
		local taskData = self:GetDataByTaskId(taskId)
		table.insert(datas, {
				id = taskId,
				count = taskData.count,
				recount = taskData.recount,
				rewardStatus = taskData.rewardStatus
			})
	end
	return datas
end

function GuildMap:GetExchangeInfo()
	local data = {
		refreshCount = self.cache.refreshCount,
		exchangeList = {},
		guildBag = {},
	}

	local exchangeList = self:GetExchangeList()
	for id,_ in pairs(exchangeList) do 
		table.insert(data.exchangeList, id)
	end
	for id, count in pairs(self.guildBag) do
		table.insert(data.guildBag, {
				id = id,
				count = count,
			})
	end
	data.refreshTime = self.cache.refreshTime
	data.exchangeMark = self.cache.exchangeMark
	return data
end

function GuildMap:onDayTimer()
	self:ResetTask(self.cache.gatherTask, true)
	self:ResetTask(self.cache.monsterTask, true)
	self.cache.refreshCount = 0
	self.cache.exchangeMark = _exchangeMark
end

return GuildMap