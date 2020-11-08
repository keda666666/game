local oo = require "class"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local server = require "server"
local lua_app = require "lua_app"
local WeightData = require "WeightData"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local Escort = oo.class()

Escort.fightType = {
	rob = 1,		--拦截
	avenge = 2,		--复仇
}

Escort.refreshType = {
	itemRef = 1,		--道具刷橙
	QuickNumericRef = 2, 	--货币刷橙
	numericRef = 3,		--货币刷新
}

local _Status = {
	origin 		= 0,	--初始
	refresh 	= 1, 	--刷新完成
	start 		= 2,	--护送中
	finish 		= 3,	--护送完成
}

local _MaxRecord = 100
local _MaxQuality = 5

function Escort:ctor(player)
	self.player = player
	self.doubletime = false
end

function Escort:onCreate()
	self:onLoad()
end

function Escort:onLoad()
	self.cache = self.player.cache.escort_data
	if next(self.cache) == nil then self:Init() end 
end

function Escort:Init()
	local data = self.cache
	data.escortTotalCount = 0
	data.escortDayCount = 0
	data.quality = 1
	data.robCount = 0
	data.status = _Status.origin
	data.finishTime = 0
	data.recordId = 0
	data.record = {}
end

function Escort:onInitClient()
	self:SendRecord()
end

--护送
function Escort:PerformEscort()
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	if self.cache.escortDayCount >= EscortBaseConfig.escortnum then
		lua_app.log_info(">>Escort: escort reach the upper limit. escortDayCount", self.cache.escortDayCount)
		return
	end
	if self.cache.status ~= _Status.refresh then
		lua_app.log_info(">>Escort:PerformEscort status faild. status:",self.cache.status)
		return
	end
	local nowTime = lua_app.now()
	local intervar = EscortBaseConfig.escorttime * 60
	self.cache.finishTime = nowTime + intervar
	local data = {
		playerid = self.player.dbid,
		playerName = self.player.cache.name,
		power = self.player.cache.totalpower,
		catchCount = 0,
		finishTime = self.cache.finishTime,
		quality = self.cache.quality,
		guildName = self.player.guild:GetGuildName(),
		robMark = false,
		robPlayer = {},
	}
	self.cache.escortInfo = {
		quality = self.cache.quality,
		record = {}
	}
	self.cache.escortDayCount = self.cache.escortDayCount + 1
	self:UpdateStatus(_Status.start)

	server.escortCenter:AddEscort(data)
	if self.cache.quality == _MaxQuality then
		server.chatCenter:ChatLink(4, self.player, nil, self.player.cache.name)
	end
	server.dailyActivityCenter:SendJoinActivity("escort", self.player.dbid)
end

--拦截护送
function Escort:Rob(playerId)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local EscortAwardConfig = server.configCenter.EscortAwardConfig
	local catchPlayer = server.playerCenter:DoGetPlayerByDBID(playerId)
	local ret, quality = server.escortCenter:CheckCatch(self.player.dbid, playerId)
	if not ret then
		lua_app.log_info(">>Escort: Players can not be catch. playerid:"..playerId)
		return false
	end
	if self.cache.robCount >= EscortBaseConfig.robtime then
		lua_app.log_info(">>Escort: Number of rob by player reach upper limit. robCount:"..self.cache.robCount)
		return false
	end
	self.cache.robCount = self.cache.robCount + 1
	local data = {
		type = self.fightType.rob,
		quality = quality,
		rewards = EscortAwardConfig[quality].robreward,
	}
	local packinfo = server.dataPack:FightInfo(self.player)
	local enemyinfo = server.dataPack:FightInfo(catchPlayer)
    packinfo.exinfo = {
        enemyinfo = enemyinfo,
        data = data,
    }
    server.raidMgr:Enter(server.raidConfig.type.Escort, self.player.dbid, packinfo)
    server.dailyActivityCenter:SendJoinActivity("escort", self.player.dbid)
end

--复仇
function Escort:Avenge(recordId)
	local record = self.cache.record[recordId]
	if not record then
		lua_app.log_info("Escort: avenge recordId not exist. recordId",recordId)
		return
	end
	local EscortAwardConfig = server.configCenter.EscortAwardConfig
	local robPlayer = server.playerCenter:DoGetPlayerByDBID(record.playerId)
	local packinfo = server.dataPack:FightInfo(self.player)
	local enemyinfo = server.dataPack:FightInfo(robPlayer)
	local data = {
		type = self.fightType.avenge,
		recordId = recordId,
		quality = record.quality,
		rewards = EscortAwardConfig[record.quality].revengeaward
	}
	packinfo.exinfo = {
		enemyinfo = enemyinfo,
		data = data,
	}
	server.raidMgr:Enter(server.raidConfig.type.Escort, self.player.dbid, packinfo)
	server.dailyActivityCenter:SendJoinActivity("escort", self.player.dbid)
end

function Escort:onFightResult(iswin, enemy, data)
	if data.type == self.fightType.rob then
		local player = server.playerCenter:DoGetPlayerByDBID(enemy.playerinfo.dbid)
		self:AddRecord(data.quality, enemy.playerinfo.dbid, enemy.playerinfo.name, enemy.playerinfo.power,data.type, iswin)
		--更新护送信息
		local catchData = {
			robId = self.player.dbid,
			name = self.player.cache.name,
			isWin = iswin,
			guildName = self.player.guild:GetGuildName(),
		}
		player.escort:AddCatchInfo(catchData)
		--拦截成功添加记录
		if iswin then
			server.escortCenter:Catch(self.player.dbid, enemy.playerinfo.dbid)
			player.escort:AddRecord(data.quality, self.player.dbid, self.player.cache.name, self.player.cache.totalpower, self.fightType.avenge, iswin)
		end
	elseif data.type == self.fightType.avenge then
		local record = self.cache.record[data.recordId]
		record.isWin = iswin
		record.operate = true
		server.sendReq(self.player, "sc_escort_record_update", {
			record = record,
		})
		if iswin then
			server.noticeCenter:Notice(28, self.player.cache.name, enemy.playerinfo.name)
		end
	end
end

--护送双倍奖励
function Escort:GetEscortRate()
	local rate = 1
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	if server.escortCenter:GetDoubleStatus() then
		rate = EscortBaseConfig.doublerad
	end
	return rate
end
--
function Escort:AddCatchInfo(data)
	local record = self.cache.escortInfo.record
	table.insert(record, data)
end

--完成护送
function Escort:CompleteEscort(data)
	local completedata = self:DecorateCompleteData(data)
	local EscortAwardConfig = server.configCenter.EscortAwardConfig
	local reachRewards = lua_util.GetArrayPlus("count")
	local subRewards = lua_util.GetArrayPlus("count")

	local function _AddReward(rewards, newReward, rewardRate)
		rewardRate = rewardRate or 1
		for rate = 1, rewardRate do
			for _,element in ipairs(newReward) do
				rewards = rewards + element
			end
		end
	end
	local rate = self:GetEscortRate()
	local escortReward = EscortAwardConfig[completedata.quality].reward
	local lossReward = EscortAwardConfig[completedata.quality].loss or {}
	_AddReward(reachRewards, escortReward, rate)
	_AddReward(reachRewards, lossReward, completedata.catchCount)
	_AddReward(subRewards, lossReward, completedata.catchCount)
	self.cache.reachReward = reachRewards
	self.cache.lossReward = subRewards
	self:UpdateStatus(_Status.finish)
	self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.Escort)
	server.teachersCenter:AddNum(self.player.dbid, 9)
	self.cache.escortTotalCount = self.cache.escortTotalCount + 1
	self.player.shop:onUpdateUnlock()
end

function Escort:DecorateCompleteData(data)
	local completedata = {
		quality = data and data.quality or self.cache.quality,
		catchCount = data and data.catchCount or 0,
	}
	return completedata
end

function Escort:GetEscortTotalCount()
	return self.cache.escortTotalCount
end

local _RefreshList = false
local function _GetQuality(quality)
	local EscortAwardConfig = server.configCenter.EscortAwardConfig
	if not _RefreshList then
		_RefreshList = WeightData.new()
		for _,v in ipairs(EscortAwardConfig) do
			_RefreshList:Add(v.rat, v.quality)
		end
	end
	local minRat = 1
	local maxRat = _RefreshList:GetMaxProb()
	for i = 1, quality - 1 do
		minRat = minRat + EscortAwardConfig[i].rat
	end
	local random = math.random(minRat, maxRat)
	return _RefreshList:Get(random)
end

--刷新
function Escort:RefreshQuality(quality)
	self.cache.quality = _GetQuality(quality or 1)
end

--支付类型
local _PayRefresh = {}
 _PayRefresh[Escort.refreshType.itemRef] = function(player)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local cost = EscortBaseConfig.aotuitem
	return player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.Escort, "Escort:refresh:quality")
end

_PayRefresh[Escort.refreshType.QuickNumericRef] = function(player)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local cost = EscortBaseConfig.aotucost
	return player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.Escort, "Escort:quick:complete")
end

_PayRefresh[Escort.refreshType.numericRef] = function(player)
	local EscortBaseConfig = server.configCenter.EscortBaseConfig
	local cost = EscortBaseConfig.refreshcost
	return player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.Escort, "Escort:refresh:maximum:quality")
end

--付费刷新
function Escort:RefreshByPay(payType)
	if not _PayRefresh[payType](self.player) then
		lua_app.log_info("Escort: refresh pay fail.")
		return
	end
	if payType == Escort.refreshType.numericRef then
		self:RefreshQuality(self.cache.quality)
	else
		self:RefreshQuality(_MaxQuality)
	end
	self:UpdateStatus(_Status.refresh)
end

--发放奖励
function Escort:GrantReward()
	if self.cache.status ~= _Status.finish then
		lua_app.log_info("Escort: The mission's not finished..")
		return false
	end
	self.player:GiveRewardAsFullMailDefault(self.cache.reachReward, "护送奖励",server.baseConfig.YuanbaoRecordType.Escort)
	self.cache.rewards = nil
	self.cache.subRewards = nil
	self:UpdateStatus(_Status.origin)
end

function Escort:AddRecord(quality, playerId, name, power, type, isWin)
	local recordId = self.cache.recordId
	local data = {
		recordId = recordId,
		type = type,
		quality = quality,
		time = lua_app.now(),
		playerId = playerId,
		name = name,
		isWin = isWin,
		operate = false,
		power = power,
	}
	self.cache.record[recordId] = data
	self.cache.recordId = (recordId + 1) % _MaxRecord
	server.sendReq(self.player, "sc_escort_record_update", {
			record = data,
		})
end

function Escort:SendRecord()
	local datas = {}
	local tailId = self.cache.recordId
	for i = 1, _MaxRecord / 2 do 
		local recordId = (tailId - i) % _MaxRecord
		local data = self.cache.record[recordId]
		if not data then
			break
		end
		table.insert(datas, data)
	end
	server.sendReq(self.player, "sc_escort_record_data", {
		records = datas,
		})
end

local statusChange = {}
statusChange[_Status.origin] = function(self)
	self:RefreshQuality()
	self:UpdateStatus(_Status.refresh)
end

statusChange[_Status.refresh] = function(self)
	self:SendClientMsg()
end

statusChange[_Status.start] = function(self)
	self:SendClientMsg()
end

statusChange[_Status.finish] = function(self)
	self:SendClientMsg()
	self:SendRewardMsg()
end

--进入护送
function Escort:Enter()
	statusChange[self.cache.status](self)
end

function Escort:UpdateStatus(status)
	self.cache.status = status
	self:Enter()
end

function Escort:Release()
end

function Escort:SendClientMsg()
	server.sendReq(self.player, "sc_escort_info_update", {
		escortCount = self.cache.escortDayCount,
		robCount = self.cache.robCount,
		quality = self.cache.quality,
		status = self.cache.status,
		finishTime = self.cache.finishTime,
	})
end

function Escort:SendRewardMsg()
	server.sendReq(self.player, "sc_escort_reward_show", {
			quality = self.cache.escortInfo.quality,
			record = self.cache.escortInfo.record,
			reachReward = self.cache.reachReward,
			lossReward = self.cache.lossReward,
		})
end

function Escort:onDayTimer()
	self.cache.escortDayCount = 0
	self.cache.robCount = 0
	self:SendClientMsg()
end

server.playerCenter:SetEvent(Escort, "escort")
return Escort