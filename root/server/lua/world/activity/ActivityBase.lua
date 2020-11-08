local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("activitys")

local ActivityBase = oo.class()

function ActivityBase:ctor(acType)
	self.activityId = 0
	self.startTime = 0
	self.stopTime = 0
	self.endRewardTime = 0
	self.openStatus = false
	self.activityType = acType
	self.clearStatus = false
	self.save = false
	self.ex = {}
end

function ActivityBase:RewardTime()
	local now = lua_app.now()
	return (self.startTime <= now and now <= self.endRewardTime)
end

function ActivityBase:OpenHandler()
	--开启需要重置数据
	if self.cache.activity_init_status == 0 then
		self.cache.activity_data = {}
	end
	self.cache.activity_init_status = 1
end

function ActivityBase:CloseHandler()
	self.cache.activity_init_status = 0
end

function ActivityBase:DayTimer()

end

function ActivityBase:GetRunDay()
	return os.intervalDays(self.startTime) + 1
end

function ActivityBase:SendActivityData(actor)
	
end

function ActivityBase:AddDay(num)
	self.startTime = self.startTime - num*24*3600
	if self.stopTime ~= 0 then
		self.stopTime = self.stopTime - num*24*3600
	end
end


function ActivityBase:Create(data)
	data = data or {}
	local actdata = {
		activity_id = data.activity_id or 0,
		activity_init_status = data.activity_init_status or 0,
		activity_over_status = data.activity_over_status or 0,
		activity_data = data.activity_data or {},
	}
	self.cache = server.mysqlBlob:CreateDmg(tbname, actdata)
end

function ActivityBase:Load(cond)
	if cond ~= nil and type(cond) == "table" then
		local data = server.mysqlBlob:LoadDmg(tbname, cond)
		if data ~= nil and type(data[1]) == "table" then
			self.cache = data[1]
            return true
		end
	end
end

function ActivityBase:Save()
    self.cache(true)
end

return ActivityBase
