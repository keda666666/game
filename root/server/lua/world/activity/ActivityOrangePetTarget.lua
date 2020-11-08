--冲级
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"
local RaidConfig = require "common.resource.RaidConfig"
local ItemConfig = require "resource.ItemConfig"

local ActivityOrangePetTarget = oo.class(ActivityBaseType)

function ActivityOrangePetTarget:ctor(activityId)
end

function ActivityOrangePetTarget:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType22Config", activityId)
end

function ActivityOrangePetTarget:OpenHandler(activityId)
end

function ActivityOrangePetTarget:Action(dbid, activityId)
	local activity = self.activityListByType[activityId]
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if activity.openStatus then
		local record = server.activityMgr:GetActData(player, activityId)
		local upCfg = self:GetMyConfig(activityId)
		local cfg = upCfg[record.gid + 1]
		if not cfg then
			server.sendErr(player, "已经通关了")
			return
		end
		local datas = player.server.dataPack:FightInfoByDBID(dbid)
		datas.exinfo = {
			activityId = activityId,
			gid = record.gid + 1,
		}
		server.serverCenter:CallLocalMod("war", "raidMgr", "Enter", RaidConfig.type.OrangePetFb, dbid, datas, {dbid})
	end
end

function ActivityOrangePetTarget:onFightResult(dbid, activityId)
	local activity = self.activityListByType[activityId]
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if activity.openStatus then
		local record = server.activityMgr:GetActData(player, activityId)
		local upCfg = self:GetMyConfig(activityId)
		record.gid = record.gid + 1
		for id, cfg in pairs(upCfg) do
		 	if id <= record.gid then
		 		record.drawBin[id] = math.max(record.drawBin[id], ActCfg.LevelStatus.ReachNoReward)
		 	end
		end
		player.activityPlug:SetActData(activityId, record)
		self:SendActivityDataOne(player, activityId)
	end
end

function ActivityOrangePetTarget:PackData(player, activityId)
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
	data2.record = record.drawBin
	data2.gid = record.gid

	local data3 = {}
	data3.type22 = data2 
	return data3
end

function ActivityOrangePetTarget:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local record = server.activityMgr:GetActData(player, activityId)
	local ActivityConfig = self:GetMyConfig(activityId)
	local cfg = ActivityConfig[index]
	if cfg == nil then
		lua_app.log_error("activity upgrade config not exist")
		return
	end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	local rewards = server.dropCenter:DropGroup(cfg.rewards)
	player.activityPlug:GiveReward(activityId, record, rewards, "橙宠目标活动")
	self:SendActivityDataOne(player, activityId)
	if index >= 8 then 
		server.serverCenter:SendLocalMod("logic", "chatCenter", "ChatLink", 34, nil, nil, player.cache.name(), cfg.fbname, ItemConfig:ConverLinkText(cfg.showitem))
	end
end

return ActivityOrangePetTarget
