local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ActivityBase = require "activity.ActivityBase"
local ActivityConfig = require "resource.ActivityConfig"

local ActivityBaseType = oo.class()

function ActivityBaseType:ctor(id)
	self.activityId = id
	self.openType = 0
	self.activityListByType = {}
end

function ActivityBaseType:AddPlayer(player)

end

function ActivityBaseType:SendActivityData(player, activityId)
	local data = {}
	data.datas = {}
	local packData = self:PackData(player, activityId)
	if packData ~= nil then
		server.activityMgr:AddConfigStr(packData)
		table.insert(data.datas,packData)
		server.sendReqByDBID(player.dbid, "sc_activity_init_info",data)
	end
end

function ActivityBaseType:SendActivityDataOne(player, activityId)
	local packData = self:PackData(player, activityId)
	if packData ~= nil then
		local data = {
			index = activityId,
			data = packData,
		}
		server.sendReqByDBID(player.dbid, "sc_activity_update_info", data)
	end
end

function ActivityBaseType:PackData(player, activityId)
	
end

function ActivityBaseType:IsOpen(player, activityId)
	
end
 
function ActivityBaseType:PackDataList(player)
	local now = lua_app.now()
	local tb = {}
	for id,activity in pairs(self.activityListByType) do
		if activity.openStatus or 
			activity.endRewardTime >= now or 
			self:IsOpen(player, id) then
			local data = self:PackData(player, id)
			if data ~= nil then
				table.insert(tb,data)
			end
		end
	end
	return tb
end

function ActivityBaseType:DayTimer()

end

function ActivityBaseType:Action()

end

function ActivityBaseType:ResetPlayer(player, activityId)

end

function ActivityBaseType:AddActivity(id)
	local record = ActivityBase.new()
	record.activityType = self.activityId
	if not record:Load({activity_id = id}) then
		local data = {}
		data.activity_id = id
		record:Create(data)
	end
	self.activityListByType[id] = record
	self:InitActivity(id)
end

function ActivityBaseType:DelActivity(id)
	local activity = self.activityListByType[id]
	if activity then
		if activity.openStatus then
			activity.openStatus = false
			local players = server.playerCenter:GetOnlinePlayers()
			for _, player in pairs(players) do
				self:SendActivityData(player, id)
			end
		end
		self.activityListByType[id] = nil
	end
end

function ActivityBaseType:TickActivity()
	for id,activity in pairs(self.activityListByType) do
		if activity.openStatus == false then
			if activity.startTime < lua_app.now() then
				if activity.stopTime > lua_app.now() or activity.stopTime == 0 then
					self:OpenActivity(id)
				end
			end
		end
		if activity.cache.activity_init_status == 1 then
			if activity.stopTime < lua_app.now() and activity.stopTime ~= 0 then
				self:CloseActivity(id)
			end
		end
		if activity.openStatus == false then
			
		end
	end
end

function ActivityBaseType:OpenActivity(activityId)
	local activity = self.activityListByType[activityId]
	local players = server.playerCenter:GetOnlinePlayers()
	activity.openStatus = true
	activity:OpenHandler()
	self:OpenHandler(activityId)
	for _, player in pairs(players) do
		self:SendActivityData(player, activityId)
	end
end

function ActivityBaseType:OpenHandler(activityId)
	
end

function ActivityBaseType:CloseHandler(activityId)

end

function ActivityBaseType:CloseActivity(id)
	local activity = self.activityListByType[id]
	activity.openStatus = false
	activity:CloseHandler()
	local players = server.playerCenter:GetOnlinePlayers()
	for _, player in pairs(players) do
		self:SendActivityData(player, id)
	end
	self:CloseHandler(id)
end

function ActivityBaseType:InitTypeZero(timeCfg)
	local tb = lua_util.split(timeCfg,"-")
	local tb2 =lua_util.split(tb[2],":")
	return tonumber(tb[1]),tonumber(tb2[1]),tonumber(tb2[2])
end

function ActivityBaseType:InitTypeOne(timeCfg)
	local tb = lua_util.split(timeCfg,"-")
	local tb2 =lua_util.split(tb[1],".")
	local tb3 =lua_util.split(tb[2],":")
	local tb4 = {}
	tb4.year = tonumber(tb2[1])
	tb4.month = tonumber(tb2[2])
	tb4.day = tonumber(tb2[3])
	tb4.hour = tonumber(tb3[1])
	tb4.min = tonumber(tb3[2])
	return tb4
end

local function serverStartTime()
	local t = os.date("*t",server.serverOpenTime)
	t.hour = 0
	t.min = 0
	t.sec = 0
	return os.time(t)
end

local function mergeStartTime()
	local t = os.date("*t",server.svrMgr:GetMergeTime())
	t.hour = 0
	t.min = 0
	t.sec = 0
	return os.time(t)
end


function ActivityBaseType:InitActivity(id)
	local record = self.activityListByType[id]
	local cfg = ActivityConfig:GetActTypeConfig(id)
	local timeType = cfg.timeType
	if timeType == 0 then
		local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
		local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
		record.startTime = serverStartTime()+d1*24*60*60+h1*60*60+m1*60
		if d2 == nil then
			record.stopTime = 0
		else
			record.stopTime = serverStartTime()+d2*24*60*60+h2*60*60+m2*60
		end
	elseif timeType == 1 then
		local opentb = self:InitTypeOne(cfg.startTime)
		local stoptb = self:InitTypeOne(cfg.endTime)
		record.startTime = os.time(opentb)
		record.stopTime = os.time(stoptb)
	-- elseif timeType == 2 then
	-- 	local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
	-- 	local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
	-- 	record.startTime = mergeStartTime()+d1*24*60*60+h1*60*60+m1*60
	-- 	if d2 == nil then
	-- 		record.stopTime = 0
	-- 	else
	-- 		record.stopTime = mergeStartTime()+d2*24*60*60+h2*60*60+m2*60
	-- 	end
	end
	record.activityId = id
	record.activityType = self.activityId
	record.clearStatus = cfg.endClear
	if record.startTime < lua_app.now() then
		if record.stopTime > lua_app.now() or record.stopTime == 0 then
			self:OpenActivity(id)
		end
	end
end

function ActivityBaseType:ResetActivity()
	for activityId,activity in pairs(self.activityListByType) do
		if activity.openStatus then
			self:CloseActivity(activityId)
		end
		local activity = self.activityListByType[activityId]
		local cfg = ActivityConfig:GetActTypeConfig(activityId)
		local timeType = cfg.timeType
		if timeType == 0 then
			local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
			local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
			activity.startTime = serverStartTime()+d1*24*60*60+h1*60*60+m1*60
			if d2 == nil then
				activity.stopTime = 0
			else
				activity.stopTime = serverStartTime()+d2*24*60*60+h2*60*60+m2*60
			end
		elseif timeType == 1 then
			local opentb = self:InitTypeOne(cfg.startTime)
			local stoptb = self:InitTypeOne(cfg.endTime)
			activity.startTime = os.time(opentb)
			activity.stopTime = os.time(stoptb)
		-- elseif timeType == 2 then
		-- 	local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
		-- 	local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
		-- 	activity.startTime = mergeStartTime()+d1*24*60*60+h1*60*60+m1*60
		-- 	if d2 == nil then
		-- 		activity.stopTime = 0
		-- 	else
		-- 		activity.stopTime = mergeStartTime()+d2*24*60*60+h2*60*60+m2*60
		-- 	end
		end
		activity.clearStatus = cfg.endClear
		if activity.startTime < lua_app.now() then
			if activity.stopTime > lua_app.now() or activity.stopTime == 0 then
				self:OpenActivity(activityId)
			end
		end
		activity.endRewardTime = activity.stopTime + cfg.closetime * 3600
	end
end

function ActivityBaseType:RecalActivity()
	for activityId,activity in pairs(self.activityListByType) do
		local activity = self.activityListByType[activityId]
		local cfg = ActivityConfig:GetActTypeConfig(activityId)
		local timeType = cfg.timeType
		if timeType == 0 then
			local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
			local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
			activity.startTime = serverStartTime()+d1*24*60*60+h1*60*60+m1*60
			if d2 == nil then
				activity.stopTime = 0
			else
				activity.stopTime = serverStartTime()+d2*24*60*60+h2*60*60+m2*60
			end
		elseif timeType == 1 then
			local opentb = self:InitTypeOne(cfg.startTime)
			local stoptb = self:InitTypeOne(cfg.endTime)
			activity.startTime = os.time(opentb)
			activity.stopTime = os.time(stoptb)
		-- elseif timeType == 2 then
		-- 	local d1,h1,m1 = self:InitTypeZero(cfg.startTime)
		-- 	local d2,h2,m2 = self:InitTypeZero(cfg.endTime)
		-- 	activity.startTime = mergeStartTime()+d1*24*60*60+h1*60*60+m1*60
		-- 	if d2 == nil then
		-- 		activity.stopTime = 0
		-- 	else
		-- 		activity.stopTime = mergeStartTime()+d2*24*60*60+h2*60*60+m2*60
		-- 	end
		end
		activity.endRewardTime = activity.stopTime + cfg.closetime * 3600
	end
end

function ActivityBaseType:CheckOpenStatus()

end

return ActivityBaseType
