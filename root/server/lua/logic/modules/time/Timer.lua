local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local tbname = "datalist"
local tbcolumn = "timers"

local Timer = {}

function Timer:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	if self.cache.serverOpenTime == 0 then
		self.cache.serverOpenTime = lua_app.now()
	end
	server.serverOpenTime = self.cache.serverOpenTime
	server.serverRunDay = self.cache.serverRunDay
	server.serverCenter:BroadcastLocal("SendRunModFun", "timerCenter", "SetServerTimer", server.serverRunDay, server.serverOpenTime)
	local function _RunDayTimer()
		self:DayTimer()
	end
	self.dayTimerId = lua_timer.add_timer_day("00:00:05", -1, _RunDayTimer)

	local function _RunHalfHour()
		self:HalfHour()
	end
	self.hourtimer = lua_timer.add_timer_hour("00:05", -1, _RunHalfHour)
	self.halfhourtimer = lua_timer.add_timer_hour("30:05", -1, _RunHalfHour)
end

function Timer:SetResetServer()
	lua_app.log_info("Timer:SetResetServer::", server.serverid, server.serverOpenTime, server.serverRunDay)
	server.serverOpenTime = lua_app.now()
	server.serverRunDay = 1
	self.cache.serverOpenTime = server.serverOpenTime
	self.cache.serverRunDay = server.serverRunDay
	server.serverCenter:BroadcastLocal("SendRunModFun", "timerCenter", "SetServerTimer", server.serverRunDay, server.serverOpenTime)
	server.onevent(server.event.resetserver)
	server.serverCenter:BroadcastLocal("onrecvevent", server.event.resetserver)
end

function Timer:ServerOpen()
	self:DayTimer()
end

function Timer:DayTimer()
	local today = os.intervalDays(server.serverOpenTime)
	if today > server.serverRunDay + 3 then
		lua_app.log_error("Timer:DayTimer:: error day pass, reset serverRunDay:", server.serverRunDay, today)
		server.serverRunDay = today + 1
	else
		lua_app.log_info("Timer:DayTimer", server.serverRunDay, today + 1)
	end
	for i = server.serverRunDay, today do
		server.serverRunDay = i + 1
		self.cache.serverRunDay = server.serverRunDay
		server.onevent(server.event.daytimer, server.serverRunDay)
	end
	server.serverCenter:BroadcastLocal("SendRunModFun", "timerCenter", "SetServerTimer", server.serverRunDay, server.serverOpenTime)
end

function Timer:HalfHour()
	local hour = lua_app.hour()
	local minute = lua_app.minute()
	server.onevent(server.event.halfhourtimer, hour, minute)
end

server.SetCenter(Timer, "timerCenter")
return Timer
