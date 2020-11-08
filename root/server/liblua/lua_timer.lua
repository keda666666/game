local lua_app = require "lua_app"
local lua_util = require "lua_util"

local api = {}
local timer_id = 0
api.timer_dict_day = {}
api.timer_dict_week = {}
api.timer_dict_month = {}
api.timer_dict_year = {}
api.timer_dict_hour = {}

local TimerType = {
	Day 	= 1,
	Week 	= 2,
	Month 	= 3,
	Year 	= 4,
	Hour 	= 5,
}

local function create_data()
	local data = {}
	timer_id = timer_id + 1
	data.config = nil
	data.timerid = timer_id
	data.handler = nil
	data.number = 0
	data.nexttime = 0
	data.args = nil

	data.pre = nil
	data.next = nil
	return data
end

local _get_next_timer = {}
_get_next_timer[TimerType.Day] = function(cur_timer)
	if cur_timer.number ~= -1 then cur_timer.number = cur_timer.number - 1 end
	if cur_timer.number == 0 then
		api.timer_dict_day[cur_timer.timerid] = nil
		return false
	else
		cur_timer.nexttime = cur_timer.nexttime + 3600*24
		return true
	end
end

_get_next_timer[TimerType.Week] = function(cur_timer)
	if cur_timer.number ~= -1 then cur_timer.number = cur_timer.number - 1 end
	if cur_timer.number == 0 then
		api.timer_dict_week[cur_timer.timerid] = nil
		return false
	else
		cur_timer.nexttime = cur_timer.nexttime + 7*3600*24
		return true
	end
end

_get_next_timer[TimerType.Month] = function(cur_timer)
	if cur_timer.number ~= -1 then cur_timer.number = cur_timer.number - 1 end
	if cur_timer.number == 0 then
		api.timer_dict_month[cur_timer.timerid] = nil
		return false
	else
		local tb = os.date("*t", cur_timer.nexttime)
		tb.month = tb.month + 1
		cur_timer.nexttime = os.time(tb)
		return true
	end
end

_get_next_timer[TimerType.Year] = function(cur_timer)
	if cur_timer.number ~= -1 then cur_timer.number = cur_timer.number - 1 end
	if cur_timer.number == 0 then
		api.timer_dict_year[cur_timer.timerid] = nil
		return false
	else
		local tb = os.date("*t", cur_timer.nexttime)
		tb.year = tb.year + 1
		cur_timer.nexttime = os.time(tb)
		return true
	end
end

_get_next_timer[TimerType.Hour] = function(cur_timer)
	if cur_timer.number ~= -1 then cur_timer.number = cur_timer.number - 1 end
	if cur_timer.number == 0 then
		api.timer_dict_hour[cur_timer.timerid] = nil
		return false
	else
		cur_timer.nexttime = cur_timer.nexttime + 3600
		return true
	end
end

local timer_running_data = {}
for _, i in pairs(TimerType) do
	timer_running_data[i] = {
		timer_run_head = {
			nexttime = 0,
		},
		timer_run_end = {
			nexttime = math.huge,
		},
		run_timerid = false,
		timer_new_insert = {},
		timer_min_intertime = math.huge,
	}
	timer_running_data[i].timer_run_head.next = timer_running_data[i].timer_run_end
	timer_running_data[i].timer_run_end.pre = timer_running_data[i].timer_run_head
end

local function tick(_, timer_type)
	local running_data = timer_running_data[timer_type]
	if #running_data.timer_new_insert > 0 then
		table.sort(running_data.timer_new_insert, function(a, b)
				return a.nexttime < b.nexttime
			end)
		local cur_timer = running_data.timer_run_head
		for i, v in ipairs(running_data.timer_new_insert) do
			if not v.delete then
				while v.nexttime >= cur_timer.next.nexttime do
					cur_timer = cur_timer.next
				end
				local next_timer = cur_timer.next
				v.pre = cur_timer
				v.next = next_timer
				cur_timer.next = v
				next_timer.pre = v
				cur_timer = v
			end
		end
		running_data.timer_new_insert = {}
	end
	local now_time = lua_app.now()
	local cur_timer = running_data.timer_run_head.next
	while cur_timer.nexttime <= now_time do
		local next_timer = cur_timer.next
		cur_timer.pre.next = next_timer
		next_timer.pre = cur_timer.pre
		local result,msg = pcall(cur_timer.handler, cur_timer.args,cur_timer.timerid)
		if not result then
			lua_app.log_error("timer tick run error",cur_timer.timerid,msg)
		end
		if _get_next_timer[timer_type](cur_timer) then
			local endpre = running_data.timer_run_end.pre
			cur_timer.pre = endpre
			cur_timer.next = running_data.timer_run_end
			running_data.timer_run_end.pre = cur_timer
			endpre.next = cur_timer
		end
		cur_timer = running_data.timer_run_head.next
	end
	running_data.timer_min_intertime = cur_timer.nexttime
	if cur_timer.nexttime ~= math.huge then
		running_data.run_timerid = lua_app.add_timer((cur_timer.nexttime - now_time) * 1000, tick, timer_type)
	else
		running_data.run_timerid = false
	end
end

local function add_timer(timedata, timer_type)
	local running_data = timer_running_data[timer_type]
	table.insert(running_data.timer_new_insert, timedata)
	if running_data.timer_min_intertime > timedata.nexttime then
		running_data.timer_min_intertime = timedata.nexttime
		if running_data.run_timerid then
			lua_app.del_timer(running_data.run_timerid)
		end
		running_data.run_timerid = lua_app.add_timer((timedata.nexttime - lua_app.now()) * 1000, tick, timer_type)
	end
end

local function del_timer(timedata, timer_type)
	timedata.delete = true
	if timedata.pre then
		assert(timedata.next)
		timedata.pre.next = timedata.next
		timedata.next.pre = timedata.pre
	end
end

--hour:min:sec
function api.add_timer_day(time,cnt,handler,args)
	local ttime = lua_util.split(time,":")
	local ctime = lua_util.split(os.date("%H:%M:%S"),":")
	local TH = tonumber(ttime[1])
	local TM = tonumber(ttime[2])
	local TS = tonumber(ttime[3])
	local CH = tonumber(ctime[1])
	local CM = tonumber(ctime[2])
	local CS = tonumber(ctime[3])
	local intertime = (TH-CH)*3600 + (TM-CM)*60 + TS - CS
	if intertime < 0 then
		intertime = intertime + 24*3600
	end
	local timedata = create_data()
	timedata.config = time
	timedata.handler = handler
	timedata.number = cnt
	timedata.nexttime = intertime + os.time()
	timedata.args = args
	api.timer_dict_day[timer_id] = timedata
	add_timer(timedata, TimerType.Day)
	return timedata.timerid
end

--week:hour:min:sec  week(0-6 0 sunday)
function api.add_timer_week(time,cnt,handler,args)
	local ttime = lua_util.split(time,":")
	local ctime = lua_util.split(os.date("%w:%H:%M:%S"),":")
	local TW = tonumber(ttime[1])
	local TH = tonumber(ttime[2])
	local TM = tonumber(ttime[3])
	local TS = tonumber(ttime[4])
	local CW = tonumber(ctime[1])
	local CH = tonumber(ctime[2])
	local CM = tonumber(ctime[3])
	local CS = tonumber(ctime[4])
	local intertime = (TW-CW)*3600*24 + (TH-CH)*3600 + (TM-CM)*60 + TS - CS
	if intertime < 0 then
		intertime = intertime + 7*24*3600
	end
	local timedata = create_data()
	timedata.config = time
	timedata.handler = handler
	timedata.number = cnt
	timedata.nexttime = intertime + os.time()
	timedata.args = args
	api.timer_dict_week[timer_id] = timedata
	add_timer(timedata, TimerType.Week)
	return timedata.timerid
end

--day:hour:min:sec
function api.add_timer_month(time,cnt,handler,args)
	local ttime = lua_util.split(time,":")
	local ctime = lua_util.split(os.date("%Y:%m:%d:%H:%M:%S"),":")
	local tb = {}
	tb.year = tonumber(ctime[1])
	tb.month = tonumber(ctime[2])
	tb.day = tonumber(ttime[1])
	tb.hour = tonumber(ttime[2])
	tb.min = tonumber(ttime[3])
	tb.sec = tonumber(ttime[4])
	assert(tb.day <= 28)
	local intertime = os.time(tb)
	if intertime < os.time() then
		tb.month = tb.month + 1
		intertime = os.time(tb)
	end
	local timedata = create_data()
	timedata.config = time
	timedata.handler = handler
	timedata.number = cnt
	timedata.nexttime = intertime
	timedata.args = args
	api.timer_dict_month[timer_id] = timedata
	add_timer(timedata, TimerType.Month)
	return timedata.timerid
end

--month:day:hour:min:sec
function api.add_timer_year(time,cnt,handler,args)
	local ttime = lua_util.split(time,":")
	local ctime = lua_util.split(os.date("%Y:%m:%d:%H:%M:%S"),":")
	local tb = {}
	tb.year = ctime[1]
	tb.month = ttime[1]
	tb.day = ttime[2]
	tb.hour = ttime[3]
	tb.min = ttime[4]
	tb.sec = ttime[5]
	local intertime = os.time(tb)
	if intertime < os.time() then
		tb.year = tb.year + 1
		intertime = os.time(tb)
	end
	local timedata = create_data()
	timedata.config = time
	timedata.handler = handler
	timedata.number = cnt
	timedata.nexttime = intertime
	timedata.args = args
	api.timer_dict_year[timer_id] = timedata
	add_timer(timedata, TimerType.Year)
	return timedata.timerid
end

function api.add_timer_hour(time,cnt,handler,args)
	local ttime = lua_util.split(time,":")
	local ctime = lua_util.split(os.date("%M:%S"),":")
	local TM = tonumber(ttime[1])
	local TS = tonumber(ttime[2])
	local CM = tonumber(ctime[1])
	local CS = tonumber(ctime[2])
	local intertime = (TM-CM)*60 + TS - CS
	if intertime < 0 then
		intertime = intertime + 3600
	end
	local timedata = create_data()
	timedata.config = time
	timedata.handler = handler
	timedata.number = cnt
	timedata.nexttime = intertime + os.time()
	timedata.args = args
	api.timer_dict_hour[timer_id] = timedata
	add_timer(timedata, TimerType.Hour)
	return timedata.timerid
end


function api.del_timer_day(id)
	del_timer(api.timer_dict_day[id], TimerType.Day)
	api.timer_dict_day[id] = nil
end

function api.del_timer_week(id)
	del_timer(api.timer_dict_week[id], TimerType.Week)
	api.timer_dict_week[id] = nil
end

function api.del_timer_month(id)
	del_timer(api.timer_dict_month[id], TimerType.Month)
	api.timer_dict_month[id] = nil
end

function api.del_timer_year(id)
	del_timer(api.timer_dict_year[id], TimerType.Year)
	api.timer_dict_year[id] = nil
end

function api.del_timer_hour(id)
	del_timer(api.timer_dict_hour[id], TimerType.Hour)
	api.timer_dict_hour[id] = nil
end

return api
