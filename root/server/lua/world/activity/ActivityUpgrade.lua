--冲级
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityUpgrade = oo.class(ActivityBaseType)

function ActivityUpgrade:ctor(activityId)
	-- self.levelRecords = {}
end

function ActivityUpgrade:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType1Config", activityId)
end

function ActivityUpgrade:OpenHandler(activityId)
	-- self.levelRecords[activityId] = {}
	-- local upCfg = self:GetMyConfig(activityId)
	-- for id,cfg in pairs(upCfg) do
	-- 	self.levelRecords[activityId][id] = 0
	-- end
	-- local caches = server.mysqlCenter:query("players", {})
	-- for dbid, cache in pairs(caches) do
	-- 	local level = cache.level
	-- 	for id,cfg in pairs(upCfg) do
	-- 		if level >= cfg.value then
	-- 			self.levelRecords[activityId][id] = self.levelRecords[activityId][id] + 1
	-- 		end
	-- 	end
	-- end
	print("ActivityUpgrade Open --------------------------", activityId)
end

function ActivityUpgrade:CloseHandler(activityId)
	print("-------------- ActivityUpgrade:CloseHandler-----------------", activityId)
	local playerlist = server.playerCenter:GetOnlinePlayers()
	for __, player in pairs(playerlist) do
		for activityId,__ in pairs(self.activityListByType) do
			local record = server.activityMgr:GetActData(player, activityId)
			local actCfg = self:GetMyConfig(activityId)
			for id, drawbin in ipairs(record.drawBin) do
				if drawbin == ActCfg.LevelStatus.ReachNoReward then
					player:SendMail("开服冲级活动", "这是你在开服活动中，达成等级目标活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
					record.drawBin[id] = ActCfg.LevelStatus.Reward
				end
			end
			record.closeaward = true
			player.activityPlug:SetActData(activityId, record)
		end
	end
end

function ActivityUpgrade:onLogin(player)
	for activityId, activity in pairs(self.activityListByType) do
		if not activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			if not record.closeaward then
				local actCfg = self:GetMyConfig(activityId)
				for id, drawbin in ipairs(record.drawBin) do
					if drawbin == ActCfg.LevelStatus.ReachNoReward then
						player:SendMail("开服冲级活动", "这是你在开服活动中，达成等级目标活动奖励，请注意查收", table.wcopy(actCfg[id].rewards), server.baseConfig.YuanbaoRecordType.Activity)
						record.drawBin[id] = ActCfg.LevelStatus.Reward
					end
				end
				record.closeaward = true
				player.activityPlug:SetActData(activityId, record)
			end
		end
	end
end


function ActivityUpgrade:UpdatePlayerLv(player, level)
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			print("ActivityUpgrade:UpdatePlayerLv----------------------", level)
			local upCfg = self:GetMyConfig(activityId)
			local isChange = false
			for id,cfg in pairs(upCfg) do
				if level >= cfg.value and record.index < id then
					record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
					record.index = id
					isChange = true
				end
			end
			player.activityPlug:SetActData(activityId, record)
			if isChange then
				self:SendActivityDataOne(player, activityId)
			end
		end
	end
end

function ActivityUpgrade:UpdatePlayerRecord(player, activityId)
	local record = server.activityMgr:GetActData(player, activityId)
	local upCfg = self:GetMyConfig(activityId)
	local level = player.cache.level()
	for id, cfg in pairs(upCfg) do
		if level >= cfg.value and record.index < id then
			record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
			record.index = id
		end
	end
	player.activityPlug:SetActData(activityId, record)
end

function ActivityUpgrade:PackData(player, activityId)
	local activity = self.activityListByType[activityId]
	local data1 = {}
	data1.id = activityId
	data1.startTime = activity.startTime
	data1.endTime = activity.stopTime
	data1.type = activity.activityType
	data1.openState = activity.openStatus and 1 or 0

	self:UpdatePlayerRecord(player, activityId)
	local data2 = {}
	local record = server.activityMgr:GetActData(player, activityId)
	data2.baseData = data1
	data2.record = record.drawBin
	-- data2.nums = {}
	-- local upCfg = self:GetMyConfig(activityId)
	-- for id,cfg in pairs(upCfg) do
	-- 	data2.nums[id] = self.levelRecords[activityId][id]
	-- end

	local data3 = {}
	data3.type01 = data2 
	return data3
end

function ActivityUpgrade:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local ActivityConfig = self:GetMyConfig(activityId)
	local cfg = ActivityConfig[index]
	if cfg == nil then
		lua_app.log_error("activity upgrade config not exist")
		return
	end
	-- local needlv = cfg.level
	-- local level = data.level
	-- if level < needlv then
	-- 	server.sendErr(player, "等级不足")
	-- 	return
	-- end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "冲级活动")
	self:SendActivityDataOne(player, activityId)
end

return ActivityUpgrade
