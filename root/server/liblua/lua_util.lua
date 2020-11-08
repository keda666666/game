local lua_util = {}
local lua_app = require "lua_app"


local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next
function lua_util.print(root)
	if root == nil then
		return
	end
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	print(_dump(root, "",""))
end

table.print = lua_util.print

function lua_util.info(root)
	if root == nil then
		return
	end
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	lua_app.log_info(_dump(root, "",""))
end

table.info = lua_util.info

local max_deep_for_ptable = 9
-- ptable(tablename, deepnumber) 只写到屏幕，并输出总结果个数
local function ptable(t, h, d, printfunc)
	printfunc = printfunc or print
	if d and d > max_deep_for_ptable then
		printfunc("max_deep_for_ptable is " .. max_deep_for_ptable .. "got " .. d)
		d = max_deep_for_ptable
	end
	local num = 0
	local function _ptable(_t, _h, _d)
		for i,v in pairs(_t) do
			-- print("-+-+-+-", _d, i, v, type(i), type(v))
			printfunc(string.rep("	", _d) .. (tostring(i) or "ERROR") .. "	" .. (tostring(v) or "ERROR"))
			num = num + 1
			if type(v) == "table" and _h > _d then
				_ptable(v, _h, _d+1)
			end
		end
	end
	printfunc(tostring(t))
	if type(t) == "table" then
		_ptable(t, h or 0, d or 0)
	end
	printfunc("all value number: " .. num)
end
table.ptable = ptable

function lua_util.split(str,sep,jump)
	if str == nil or str == "" or sep == nil then
		return {}
	end
	jump = jump or 0
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)  
	str:gsub(pattern, function (c)
		if jump > 0 then
			jump = jump - 1
		else
			fields[#fields + 1] = c 
		end
	end)
	return fields
end

string.split = lua_util.split

function lua_util.gsplit(str)
	local str_tb = {}
	
	if string.len(str) == 0 then
		return {}
	end

	for i = 1,string.len(str) do
		local new_str = string.sub(str,i,i)
		local new_bit = string.byte(new_str)
		if (new_bit >= 48 and new_bit <= 57) or (new_bit >= 65 and new_bit <= 90) or (new_bit >= 97 and new_bit <=122) then
			table.insert(str_tb,string.sub(str,i,i))
		else
			print("error string")
			return {}
		end
	end
	return str_tb
end

string.gsplit = lua_util.gsplit

function lua_util.stack()
    local startLevel = 2
    local maxLevel = 2 
 
    for level = startLevel, maxLevel do
        local info = debug.getinfo( level, "nSl") 
        if info == nil then break end
        print( string.format("[ line : %-4d]  %-20s :: %s", info.currentline, info.name or "", info.source or "" ) )
 
        local index = 1 
        while true do
            local name, value = debug.getlocal( level, index )
            if name == nil then break end
 
            local valueType = type( value )
            local valueStr
            if valueType == 'string' then
                valueStr = value
            elseif valueType == "number" then
                valueStr = string.format("%.2f", value)
            end
            if valueStr ~= nil then
                print( string.format( "\t%s = %s\n", name, value ) )
            end
            index = index + 1
        end
    end
end

function lua_util.random(N)
	local ms = lua_app.now_ms()
	math.randomseed(ms)
	return math.random(N)
end

function lua_util.merge(t1,t2)
	for k,v in pairs(t2) do
		t1[k] = v
	end
	return t1
end

table.merge = lua_util.merge

function lua_util.mergeAr(...)
	local tb = {...}
	local ar = {}
	for i = 1,#tb do
		if type(tb[i]) == "table" then
			for k,v in pairs(tb[i]) do
				table.insert(ar,v)
			end
		end
	end
	return ar
end

table.mergeAr = lua_util.mergeAr

function lua_util.diff(t1,t2)
	local t3 = {}
	for k,v in pairs(t1) do
		if t2[k] == nil then
			t3[k] = v
		end
	end
	return t3
end

table.diff = lua_util.diff

function lua_util.empty(t)
	return _G.next(t) == nil
end

table.empty = lua_util.empty

function lua_util.length(t)
	local cnt = 0
	local key = nil
	while true do
		key = _G.next(t,key)
		if key ~= nil then
			cnt = cnt + 1
		else
			break
		end
	end
	return cnt
end

table.length = lua_util.length

function lua_util.intervalHifeHours(time1, time2)
	return math.floor((time2 or lua_app.now()) / 1800) - math.floor(time1 / 1800)
end
os.intervalHifeHours = lua_util.intervalHifeHours

function lua_util.hifehourEndTime(time)
	return math.ceil((time or lua_app.now()) / 1800) * 1800
end
os.hifehourEndTime = lua_util.hifehourEndTime

function lua_util.intervalHours(time1, time2)
	return math.floor((time2 or lua_app.now()) / 3600) - math.floor(time1 / 3600)
end
os.intervalHours = lua_util.intervalHours

function lua_util.hourEndTime(time)
	return math.ceil((time or lua_app.now()) / 3600) * 3600
end
os.hourEndTime = lua_util.hourEndTime

local _begindaytime = false
local function _BeginDayTime()
	if _begindaytime then return _begindaytime end
	local t = os.date("*t", 0)
	t.hour = 24
	_begindaytime = os.time(t)
	return _begindaytime
end
-- 判断两个时间间隔多少天
-- time2 默认值当前时间点
function lua_util.intervalDays(time1, time2)
	return math.floor(((time2 or lua_app.now()) - _BeginDayTime()) / 86400) - math.floor((time1 - _BeginDayTime()) / 86400)
end
os.intervalDays = lua_util.intervalDays

function lua_util.dayEndTime(time)
	return math.ceil(((time or lua_app.now()) - _BeginDayTime()) / 86400) * 86400 + _BeginDayTime()
end
os.dayEndTime = lua_util.dayEndTime

local _beginweektime = false
local function _BeginWeekTime()
	if _beginweektime then return _beginweektime end
	local t = os.date("*t", 0)
	t.hour = 24
	_beginweektime = (t.wday-2)%7 * 86400 + os.time(t)
	return _beginweektime
end

function lua_util.intervalWeeks(time1, time2)
	return math.floor(((time2 or lua_app.now()) - _BeginWeekTime()) / 86400) - math.floor((time1 - _BeginWeekTime()) / 86400)
end
os.intervalWeeks = lua_util.intervalWeeks

function lua_util.weekEndTime(time)
	return math.ceil(((time or lua_app.now()) - _BeginWeekTime()) / 604800) * 604800 + _BeginWeekTime()
end
os.weekEndTime = lua_util.weekEndTime

function lua_util.getTimestamp(strtime)
	local time = lua_util.split(strtime,":")
	local t = os.date("*t", lua_app.now())
	t.hour = tonumber(time[1])
	t.min = tonumber(time[2])
	t.sec = tonumber(time[3]) or 0
	return os.time(t)
end
os.getTimestamp = lua_util.getTimestamp

function lua_util.distance(sx,sy,tx,ty)
	local disx = tx - sx
	local disy = ty - sy
	return math.sqrt(disx*disx + disy*disy)
end

function lua_util.copy(tb)
	local ret_tb = {}
	local function func(obj)
		if type(obj) ~= "table" then
			return obj
		end
		local new_tb = {}
		ret_tb[obj] = new_tb
		for k,v in pairs(obj) do
			new_tb[func(k)] = func(v)
		end
		return setmetatable(new_tb,getmetatable(obj))
	end
	return func(tb)
end

table.copy = lua_util.copy

function lua_util.packKey(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,k)
	end
	return table.concat(ar,",")
end
table.packKey = lua_util.packKey

function lua_util.packKeyArray(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,k)
	end
	return ar
end
table.packKeyArray = lua_util.packKeyArray

function lua_util.packValue(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,v)
	end
	return table.concat(ar,",")
end
table.packValue = lua_util.packValue

function lua_util.matchValue(tb, condfunc, default)
	local index = default
	local diffvalue = math.huge
	local quit = false
	local hunt = false
	for id, data in ipairs(tb) do
		local val = condfunc(data)
		hunt = true
		if diffvalue > val and val >= 0 then
			index = id
			diffvalue = val
			hunt = false
			quit = true
		end
		if quit and hunt then break end
	end
	return index and tb[index]
end
table.matchValue = lua_util.matchValue

function lua_util.randTB(tb,num,handler)
	local ar = {}
	local len = 0
	for k,v in pairs(tb) do
		table.insert(ar,k)
		len = len + 1
	end

	local retb = {}
	local cnt = 0
	for i = 1, len do
		if cnt >= num then
			break
		end
		local tail = len - i + 1
		local randValue = math.random(1, tail)
		if handler then
			if handler(tb[ar[randValue]]) then
				retb[ar[randValue]] = tb[ar[randValue]]
				cnt = cnt + 1
			end
		else
			retb[ar[randValue]] = tb[ar[randValue]]
			cnt = cnt + 1
		end
		
		ar[randValue] = ar[tail]
	end
	return retb
end

-- 所有表全部重新创建，不能有循环表，不然会无限循环
function _wcopy(tvalue)
	if type(tvalue) ~= "table" then return tvalue end
	local tb = {}
	for k, v in pairs(tvalue) do
		if type(k) == "table" then
			k = _wcopy(k)
		end
		if type(v) == "table" then
			v = _wcopy(v)
		end
		tb[k] = v
	end
	return tb
end
lua_util.wcopy = _wcopy
table.wcopy = _wcopy
-- 同上，不过key会尽量转换为number类型
local function _numkeywcopy(tvalue)
	if type(tvalue) ~= "table" then return tvalue end
	local tb = {}
	for k, v in pairs(tvalue) do
		if type(k) == "table" then
			k = _numkeywcopy(k)
		end
		if type(v) == "table" then
			v = _numkeywcopy(v)
		end
		tb[tonumber(k) or k] = v
	end
	return tb
end
lua_util.nkcopy = _numkeywcopy
table.nkcopy = _numkeywcopy

function lua_util.weakCopy(tvalue)
	local tb = {}
	for k, v in pairs(tvalue) do
		tb[k] = v
	end
	return tb
end
table.weakCopy = lua_util.weakCopy

function lua_util.randArray(ar,num)
	local tb = {}
	local result = {}
	if #ar <= num then
		return ar
	end
	for i = 1,#ar do
		table.insert(tb,i)
	end
	for i = 1,num do
		local key = math.random(1,#tb)
		table.insert(result,ar[tb[key]])
		table.remove(tb,key)
	end
	return result
end

function lua_util.randArray2(ar)
	local tb = {}
	local result = {}
	for i = 1,#ar do
		table.insert(tb,i)
	end
	for i = 1,#ar do
		local key = math.random(1,#tb)
		table.insert(result,ar[tb[key]])
		table.remove(tb,key)
	end
	return result
end

function lua_util.getarray(ar, num)
	local max = #ar
	if num >= max then return lua_util.weakCopy(ar) end
	local realmax = max + 1
	local indexs, ret = {}, {}
	for i = 1, num do
		local index = math.random(1, max)
		max = max - 1
		while indexs[index] do
			index = realmax - indexs[index]
		end
		indexs[index] = i
		table.insert(ret, ar[index])
	end
	return ret
end

function lua_util.DelArray(ar,num)
	if num <= 0 then
		return ar
	end
	if #ar <= num then
		return {}
	end
	local ar2 = {}
	for i = num+1,#ar do
		table.insert(ar2,ar[i])
	end
	return ar2
end

-- 转换数组对象
function lua_util.ConverToArray(data, startIndex, endIndex)
	local tmp = {}
	local insert = table.insert
	for i = startIndex, endIndex do
		insert(tmp, data[i])
	end
	return tmp
end

local function _NewTable()
	return {}
end

function lua_util.CreateArray(length, fill)
	fill = fill or _NewTable
	local tmp = {}
	local insert = table.insert
	for i = 1, length do
		if type(fill) == "function" then
			insert(tmp, fill(i))
		else
			insert(tmp, fill)
		end
	end
	return tmp
end

function lua_util.bit_open(data, pos)
	return (data | 1 << pos - 1)
end

function lua_util.bit_shut(data, pos)
	return (data & ~(1 << pos - 1))
end

function lua_util.bit_status(data, pos)
	return ((data >> pos - 1 & 1) ~= 0)
end

function lua_util.GetArrayPlus(addKey)
	local pluskey = addKey
    local recordkey = {}

    local function _GetTick(tb)
    	local tick = {}
    	for k, v in pairs(tb) do
    		if k ~= pluskey then
    			table.insert(tick, v)
    		end
    	end
        return table.concat(tick, ".")
    end

    local function _Merger(sourceTb, newTb)
    	for __,v in pairs(newTb) do
    		if type(v) == "table" then
    			_Merger(sourceTb, v)
    		else
    			local tick = _GetTick(newTb) 
    			local index = recordkey[tick]
    			if index then
    				sourceTb[index][pluskey] = sourceTb[index][pluskey] + newTb[pluskey]
    			else
    				table.insert(sourceTb, table.wcopy(newTb))
    				recordkey[tick] = #sourceTb
    			end
    			break
    		end
    	end
    end

    local operateTb = setmetatable({}, {__add = function(sourceTb, addTb)
    	addTb = addTb or {}
    	_Merger(sourceTb, addTb)
    	return sourceTb
    end})

    return operateTb
end
table.GetTbPlus = lua_util.GetArrayPlus

return lua_util
