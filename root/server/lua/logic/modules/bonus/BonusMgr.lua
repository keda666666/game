local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local BonusMgr = {}

function BonusMgr:Init()
	self.bonusQueue = {}
	self.queueId = 0
	self.waitQueue = {}
	self.queueNum = 0
end

--添加队列
function BonusMgr:AddQueue(dbid, rechargeNum)
	print(">>BonusMgr:AddQueue..++++++++++++++", dbid, rechargeNum, self.queueNum)
	--table.ptable(self.waitQueue, 3)
	local bonusId = self:CalcBonusId(rechargeNum)
	--0不进入队列
	if bonusId == 0 then return end

	local BonusBaseConfig = server.configCenter.BonusBaseConfig
	if server.serverRunDay > BonusBaseConfig.opendays then
		return
	end

	if self.queueNum >= BonusBaseConfig.maxlimit then
		self:PushWaitQueue(dbid, rechargeNum)
		return
	end
	local interval = BonusBaseConfig.falltime + BonusBaseConfig.staytime

	self.queueNum = self.queueNum + 1
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local data = {
		id = self.queueId,
		name = player.cache.name,
		bonusId = bonusId,
		endtime = lua_app.now() + interval,
		players = {},
	}
	self.bonusQueue[self.queueId] = data
	self.queueId = (self.queueId + 1) % 1000

	server.broadcastReq("sc_welfare_bonus_add", {
			id = data.id,
			name = data.name,
			endtime = data.endtime,
		})
	--print("----------server.broadcastReq-------------")
	--table.ptable(data, 3)
	--时间到了取出
	lua_app.add_timer(interval * 1000, function()
		self:PopQueue(self.queueId)
	end)
end

--取出队列
function BonusMgr:PopQueue(squeueId)
	self.bonusQueue[squeueId] = nil
	self.queueNum = self.queueNum - 1
end

function BonusMgr:PushWaitQueue(dbid, rechargeNum)
	table.insert(self.waitQueue, {
			dbid = dbid,
			rechargeNum = rechargeNum,
		})
	if self.waittimer then return end
	self.waittimer = lua_app.add_update_timer(2000, self, "PopWaitQueue")
end

function BonusMgr:PopWaitQueue()
	local BonusBaseConfig = server.configCenter.BonusBaseConfig
	if self.queueNum < BonusBaseConfig.maxlimit then
		local data = table.remove(self.waitQueue, 1)
		self:AddQueue(data.dbid, data.rechargeNum)
	end
	if #self.waitQueue > 0 then 
		self.waittimer = lua_app.add_update_timer(2000, self, "PopWaitQueue")
	else
		self.waittimer = nil
	end
end

function BonusMgr:CalcBonusId(num)
	local BonusConfig = server.configCenter.BonusConfig
	local bonusId = 0
	for i, data in ipairs(BonusConfig) do
		if num >= data.recharge[1] then
			bonusId = i
		end
	end
	return bonusId
end

function BonusMgr:OpenBonus(dbid, id)
	local data = self.bonusQueue[id]
	if not data then return false end
	if data.players[dbid] then
		lua_app.log_info(">>BonusMgr:OpenBonus the award has been received.")
		return false
	end
	data.players[dbid] = true
	local BonusConfig = server.configCenter.BonusConfig
	local BonusBaseConfig = server.configCenter.BonusBaseConfig
	local rate = math.random(BonusBaseConfig.randnum[1], BonusBaseConfig.randnum[2])
	local bybNum = math.ceil(BonusConfig[data.bonusId].normalnum * rate / 100)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	player:GiveReward(ItemConfig.AwardType.Numeric, ItemConfig.NumericType.BYB, bybNum, nil, server.baseConfig.YuanbaoRecordType.BonusMgr)
	return true, bybNum
end

server.SetCenter(BonusMgr, "bonusMgr")
return BonusMgr
