local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"

local Timer = {}

function Timer:Init()
	local function _RunDayTimer()
		self:DayTimer()
	end
	self.dayTimerId = lua_timer.add_timer_day("00:00:08", -1, _RunDayTimer)

	local function _RunHalfHour()
		self:HalfHour()
	end
	self.hourtimer = lua_timer.add_timer_hour("00:05", -1, _RunHalfHour)
	self.halfhourtimer = lua_timer.add_timer_hour("30:05", -1, _RunHalfHour)
end

function Timer:DayTimer()
	print("Timer:DayTimer------------------")
	server.onevent(server.event.daytimer, server.serverRunDay)
end

function Timer:HalfHour()
	print("Timer:HalfHour------------------")
	local hour = lua_app.hour()
	local minute = lua_app.minute()
	server.onevent(server.event.halfhourtimer, hour, minute)
end

function Timer:SetServerTimer(serverRunDay, serverOpenTime)
	print("Timer:SetServerTimer-------", serverRunDay, serverOpenTime)
	server.serverRunDay = serverRunDay
	server.serverOpenTime = serverOpenTime
end

server.SetCenter(Timer, "timerCenter")
return Timer
