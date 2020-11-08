--连续充值
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBaseType = require "activity.ActivityBaseType"
local ActCfg = require "resource.ActivityConfig"

local SpendWheel = oo.class(ActivityBaseType)

local SPEND_TYPE = {
	YUANBAO = 0, 	--元宝
	CASH = 1, 	--人民币
}

function SpendWheel:ctor(id)
end

function SpendWheel:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType6Config", activityId)
end

function SpendWheel:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.reachindex = record.index
	data2.drawrecord = record.drawrecord
	data2.drawtime = record.drawtime
	data2.value = record.value

	local data3 = {}
	data3.type06 = data2
	return data3
end

function SpendWheel:onLogin(player)
end

function SpendWheel:AddRecord(player, count, spendtype)
	for activityId, activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local spwCfg = self:GetMyConfig(activityId)
			if spwCfg[1].type == spendtype then
				local record = server.activityMgr:GetActData(player, activityId)
				record.value = record.value + count
				for index, cfg in ipairs(spwCfg) do
					if record.value >= cfg.value and record.index < index then
						record.drawtime = record.drawtime + cfg.count
						record.index = index
					end
				end 
				player.activityPlug:SetActData(activityId, record)
				self:SendActivityDataOne(player, activityId)
			end
		end
	end
end

function SpendWheel:AddRechargeCash(player, count)
	self:AddRecord(player, count, SPEND_TYPE.CASH)
end

function SpendWheel:SpendYuanBao(player, count)
	self:AddRecord(player, count, SPEND_TYPE.YUANBAO)
end

function SpendWheel:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activity = self.activityListByType[activityId]
	local record = server.activityMgr:GetActData(player, activityId)
	local spmCfg = self:GetMyConfig(activityId)
	if not activity.openStatus then
		return
	end
	local drawid = record.drawrecord + 1
	local drawCfg = spmCfg[drawid]
	if not drawCfg then
		server.sendErr(player, "没有可抽取的奖励了")
		return
	end
	if record.drawtime <= 0 then
		server.sendErr(player, "抽奖次数不足")
		return
	end
	local rewards = server.dropCenter:DropGroup(drawCfg.reward)
	record.drawtime = record.drawtime - 1
	record.curremain[drawid] = record.curremain[drawid] - 1
	if record.curremain[drawid] <= 0 then
		record.drawrecord = record.drawrecord + 1
	end
	player.activityPlug:GiveReward(activityId, record, rewards, "消费转盘", nil, 0)
	self:SendActivityDataOne(player, activityId)
	server.sendReq(player, "sc_activity_luckwheel_ret", {
		activityid = activityId,
		rewards = rewards,
	})
end

return SpendWheel
