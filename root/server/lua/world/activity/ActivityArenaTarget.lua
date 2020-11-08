local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActCfg = require "resource.ActivityConfig"
local ActivityBaseType = require "activity.ActivityBaseType"

local ActivityArenaTarget = oo.class(ActivityBaseType)

function ActivityArenaTarget:ctor(id)

end

function ActivityArenaTarget:GetMyConfig(activityId)
	return ActCfg:GetActConfig("ActivityType17Config", activityId)
end

function ActivityArenaTarget:PackData(player, activityId)
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
	data2.target = record.targetBin

	local data3 = {}
	data3.type17 = data2 
	return data3
end

function ActivityArenaTarget:DayTimer()
	
end


function ActivityArenaTarget:AddPlayer(player)
	local targetdata = player.activityPlug:TargetData()
	self:DoTarget(player, targetdata)
end

function ActivityArenaTarget:DoTarget(player, targetdata)
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			local record = server.activityMgr:GetActData(player, activityId)
			local upCfg = self:GetMyConfig(activityId)
			for id,cfg in pairs(upCfg) do
				local done
				local value = targetdata[cfg.type]
				if type(value) == "number" then
					if cfg.type == "arenarank" then
						done = (value <= cfg.value)
					else
						done = (value >= cfg.value)
					end
					record.targetBin[id] = value
				else
					local v = value[cfg.value[1]] or 0
					done = (v >= cfg.value[2])
					record.targetBin[id] = v
				end
				if done then
					if record.drawBin[id] == ActCfg.LevelStatus.NoReach then
						record.drawBin[id] = ActCfg.LevelStatus.ReachNoReward
					end
				end
			end
			player.activityPlug:SetActData(activityId, record)
			print("ActivityArenaTarget:DoTarget-------------")
		end
		self:SendActivityData(player,activityId)
	end
end

function ActivityArenaTarget:Reward(dbid, index, activityId)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local activityId,activity = next(self.activityListByType)
	local record = server.activityMgr:GetActData(player, activityId)
	local data = player.activityPlug:PlayerData()
	local ActivityType17Config = self:GetMyConfig(activityId)
	local cfg = ActivityType17Config[index]
	if cfg == nil then
		lua_app.log_error("activity target config not exist")
		return
	end
	if record.drawBin[index] ~= ActCfg.LevelStatus.ReachNoReward then
		server.sendErr(player, "领取失败")
		return
	end
	record.drawBin[index] = ActCfg.LevelStatus.Reward
	player.activityPlug:GiveReward(activityId, record, table.wcopy(cfg.rewards), "竞技目标")
	self:SendActivityData(player, activityId)
end

return ActivityArenaTarget
