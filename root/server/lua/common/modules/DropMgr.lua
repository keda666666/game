local server = require "server"
local lua_app = require "lua_app"
local share = require "lua_share"
local WeightData = require "WeightData"
local ItemConfig = require "resource.ItemConfig"

local DropMgr = {}

function DropMgr:GetDropTableConfig(id)
    return server.configCenter.DropTableConfig[id]
end

function DropMgr:GetDropGroupConfig(groupId)
    return server.configCenter.DropGroupConfig[groupId]
end

local function randomGold(item)
    if item.count and item.type == ItemConfig.AwardType.Numeric and item.id == ItemConfig.NumericType.Gold then
        local range = math.floor(item.count * 0.1)
        item.count = math.random(item.count - range, item.count + range)
    end
end

local _monthDay = { [0]=31,31,false,31,30,31,30,31,31,30,31,30,31 }
local _year2Day = {}
local function _GetYear2Day(year)
	if not _year2Day[year] then
		_year2Day[year] = (math.fmod(year, 4) == 0 and math.fmod(year, 100) ~= 0 or math.fmod(year, 400) == 0) and 29 or 28
	end
	return _year2Day[year]
end
local function _GetMonthDay(month, year)
	return _monthDay[month] or _GetYear2Day(year)
end

local Limit_Type = {
	Normal		= 1,
	Super		= 2,
	Kaifu		= 3,
	Hefu		= 4,
}
local _SuperCheck = {
	null		= 0,
	between		= 1,
	next		= 2,
}
local _TimeTypeList = { "year", "month", "day", "hour", "min", "sec" }

local function _GetWeedDays(weekStr)
	local weekDays = {}
	for v in (weekStr .. ","):gmatch("(%d),") do
		local i = tonumber(v)
		if i then
			weekDays[i] = true
		end
	end
	if next(weekDays) then
		return weekDays
	end
end

local _InitLimitType = {}
_InitLimitType[Limit_Type.Normal] = function(args)
	local tBegin, tEnd = {}, {}
	tBegin.year, tBegin.month, tBegin.day, tBegin.hour, tBegin.min, tBegin.sec, tEnd.year, tEnd.month, tEnd.day, tEnd.hour, tEnd.min, tEnd.sec = table.unpack(args)
	local beginTime, endTime = os.time(tBegin), os.time(tEnd)
	assert(beginTime and endTime)
	return { beginTime = beginTime, endTime = endTime }
end

local function _SetSuperTimeTableValue(limit, valueType, beginValue, endValue)
	if beginValue == "*" then
		limit.checkType[valueType] = _SuperCheck.null
	else
		beginValue, endValue = tonumber(beginValue), tonumber(endValue)
		assert(beginValue and endValue)
		limit.checkType[valueType] = beginValue > endValue and _SuperCheck.next or _SuperCheck.between
		limit.beginTable[valueType], limit.endTable[valueType] = beginValue, endValue
	end
end
_InitLimitType[Limit_Type.Super] = function(args)
	local limit = { checkType = {}, beginTable = {}, endTable = {} }
	for i = 1, 5 do
		_SetSuperTimeTableValue(limit, _TimeTypeList[i], args[i], args[i + 5])
	end
	return limit
end

_InitLimitType[Limit_Type.Kaifu] = function(args)
	local kaifu = tonumber(args[1])
	assert(kaifu)
	return { kaifu = kaifu }
end

_InitLimitType[Limit_Type.Hefu] = function(args)
	local hefu = tonumber(args[1])
	assert(hefu)
	return { hefu = hefu }
end

local _matchLimitStr = {
	[Limit_Type.Normal]		= "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+):(%d+) ~ (%d+)%.(%d+)%.(%d+)-(%d+):(%d+):(%d+)",
	[Limit_Type.Super]		= "([%d%*]+)%.([%d%*]+)%.([%d%*]+)-([%d%*]+):([%d%*]+) ^ ([%d%*]+)%.([%d%*]+)%.([%d%*]+)-([%d%*]+):([%d%*]+)",
	[Limit_Type.Kaifu]		= "@(%d+)",
	[Limit_Type.Hefu]		= "#(%d+)",
}
local _timeLimit = {}
local function _GetTimeLimit(timestr)
	if _timeLimit[timestr] then return _timeLimit[timestr] end
	for t, match in pairs(_matchLimitStr) do
		local args = { string.match(timestr, match) }
		if next(args) then
			_timeLimit[timestr] = _InitLimitType[t](args)
			local weekStr = string.match(timestr, "%[([%d,]*)%]")
			if weekStr then
				_timeLimit[timestr].week = _GetWeedDays(weekStr)
			end
			_timeLimit[timestr].type = t
			return _timeLimit[timestr]
		end
	end
	lua_app.log_error("_GetTimeLimit: error timestr:", timestr)
end

local _TimeCheckFunc = {}
_TimeCheckFunc[Limit_Type.Normal] = function(limit, checkTime)
	if limit.week then
		if not limit.week[os.date("%w", checkTime)] then return false end
	end
	return checkTime >= limit.beginTime and checkTime <= limit.endTime
end

local _SuperCheckFunc = {}
_SuperCheckFunc[_SuperCheck.null] = function(check, beginvalue, up)
	if check == beginvalue then return true, up end
	return true, 0
end
_SuperCheckFunc[_SuperCheck.between] = function(check, beginvalue, up, min, max, upvalue)
	if max + up >= upvalue + beginvalue then
		return _SuperCheckFunc[_SuperCheck.next](check, beginvalue, 0, min + up, beginvalue)
	end
	return (check >= min + up and check <= max + up), 0
end
_SuperCheckFunc[_SuperCheck.next] = function(check, beginvalue, up, min, max)
	if check >= min + up then
		return true, 0
	elseif check <= max + up then
		return true, 1
	else
		return false, 0
	end
end

_TimeCheckFunc[Limit_Type.Super] = function(limit, checkTime)
	local checkTable = os.date("*t", checkTime)
	if limit.week then
		if not limit.week[checkTable.wday - 1] then return false end
	end
	local result, up = _SuperCheckFunc[limit.checkType.min](checkTable.min, 0, 0, limit.beginTable.min, limit.endTable.min, 60)
	if not result then return false end
	result, up = _SuperCheckFunc[limit.checkType.hour](checkTable.hour, 0, up, limit.beginTable.hour, limit.endTable.hour, 24)
	if not result then return false end
	result, up = _SuperCheckFunc[limit.checkType.day](checkTable.day, 1, up, limit.beginTable.day, limit.endTable.day, _GetMonthDay(checkTable.month - 1, checkTable.year))
	if not result then return false end
	result, up = _SuperCheckFunc[limit.checkType.month](checkTable.month, 1, up, limit.beginTable.month, limit.endTable.month, 12)
	if not result then return false end
	return (_SuperCheckFunc[limit.checkType.year](checkTable.year, 1, up, limit.beginTable.year, limit.endTable.year, math.huge))
end

_TimeCheckFunc[Limit_Type.Kaifu] = function(limit, checkTime)
	--return checkTime - server.serverOpenTime <= limit.kaifu
	return os.intervalDays(server.serverOpenTime) < limit.kaifu
end

_TimeCheckFunc[Limit_Type.Hefu] = function(limit, checkTime)
	assert(false)
	--return checkTime - server.hefuTime <= limit.hefu
end

local function CheckInTime(timeLimitList, checkTime)
	--do return true end
	if not timeLimitList then return true end
	if not checkTime then checkTime = lua_app.now() end
	for _, v in ipairs(timeLimitList) do
		local limit = _GetTimeLimit(v)
		if _TimeCheckFunc[limit.type](limit, checkTime) then
			return true
		end
	end
	return false
end

local _dropTableCache = {}
local function _GetDropTableCache(t)
	if _dropTableCache[t] then return _dropTableCache[t] end
	local weight = WeightData.new("float")
	for _, v in ipairs(t) do
		weight:Add(v.rate, v)
	end
	_dropTableCache[t] = weight
	return weight
end

local function dropTable(dropMgr, id, out)
    -- if eff == nil then eff = 1 end
	local conf = dropMgr:GetDropTableConfig(id)
	if not conf then
		lua_app.log_error("no DropTableConfig id:"..id)
		return {}
	end
	-- local ret = {}
	if conf.timeLimit ~= nil then
		if not CheckInTime(conf.timeLimit, lua_app.now()) then
			return
		end
	end
	if conf.type == 1 then
		for _, v in ipairs(conf.table) do
			local r = math.random() * 100
			if r < v.rate then
				local item = {type=v.type,id=v.id,count=v.count}
				randomGold(item)
				-- table.insert(ret, item)
				--print(string.format("item:%d %d %d", item.type, item.id, item.count))
				table.insert(out, item)
			end
		end
	elseif conf.type == 2 then
		local item = _GetDropTableCache(conf.table):Get(math.random() * 100)
		if item then
			item = {type=item.type,id=item.id,count=item.count}
            randomGold(item)
			table.insert(out, item)
		end
	-- elseif conf.type == 0 then
	-- 	return
	end
	-- return
end

local function dropTableExpected(dropMgr, id, out, count)
    local conf = dropMgr:GetDropTableConfig(id)
	if not conf then
		lua_app.log_error("no DropTableConfig id:"..id)
		return {}
	end
    local ret = {}
    for _, v in ipairs(conf.table) do
        local item = {type=v.type, id=v.id, count=v.count * v.rate/100*count}
        table.insert(ret, item)
        if out then table.insert(out, item) end
    end
    return ret
end

--接口
--参数 掉落组id， 效率，默认1,代表100%，
function DropMgr:DropGroup(groupId)
    -- if eff == nil then eff = 1 end
    local conf = self:GetDropGroupConfig(groupId)
	if not conf then
		lua_app.log_error("no DropGroupConfig groupId:"..tostring(groupId))
		return {}
	end
    local out = {}
    if conf.type == 1 then
        for _, v in ipairs(conf.group) do
            local r = math.random() * 100
            if r < v.rate then dropTable(self, v.id, out) end
        end
    elseif conf.type == 2 then
        local r = math.random() * 100
        for _, v in ipairs(conf.group) do
            if r < v.rate then
                dropTable(self, v.id, out)
                break
            else
                r = r - v.rate
            end
        end
    -- elseif conf.type == 0 then
    -- 	return {}
    end
    return out
end

function DropMgr:DropGroupExpected(id, count)
    local conf = self:GetDropGroupConfig(id)
	if not conf then
		lua_app.log_error("no DropGroupConfig id:"..tostring(id))
		return {}
	end
    local out = {}
    for _, v in ipairs(conf.group) do
        dropTableExpected(self, v.id, out, count * v.rate/100)
    end
    return out
end

function DropMgr:DropByTable(tb, type)
	local out = {}
	if type == 1 then
		for _, v in ipairs(tb) do
			local r = math.random() * 100
			if r < v.rate then
				local item = {type=v.type,id=v.id,count=v.count}
				randomGold(item)
				-- table.insert(ret, item)
				--print(string.format("item:%d %d %d", item.type, item.id, item.count))
				table.insert(out, item)
			end
		end
	elseif type == 2 then
		local item = _GetDropTableCache(tb):Get(math.random() * 100)
		if item then
			item = {type=item.type,id=item.id,count=item.count}
            randomGold(item)
			table.insert(out, item)
		end
	end
	return out
end

server.SetCenter(DropMgr, "dropCenter")
return DropMgr
