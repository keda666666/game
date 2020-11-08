local lua_app = require "lua_app"
local server = require "server"
local share = require "lua_share"
local shield = require "lua_shield"

local _SpecificCharList = {
	[string.byte'@']	= true,
	[string.byte'%']	= true,
	[string.byte'&']	= true,
	[string.byte' ']	= true,
	[string.byte'"']	= true,
	[string.byte"'"]	= true,
	[string.byte";"]	= true,
	[string.byte"\\"]	= true,
	[127]	= true,
}
local function _InitSpecificCharList()
	for i = 0, 31 do
		_SpecificCharList[i] = true
	end
end
_InitSpecificCharList()
local function _HasSpecificStr(str)
	local length = #str
	if length == 0 then return true end
	for i = 1, length do
		if _SpecificCharList[string.byte(str, i)] then
			return true
		end
	end
	return false
end

local _lockGuildNames = {}
function server.CheckGuildName(name)
	if _HasSpecificStr(name) then return 6 end
	if string.len(name) > 19 then return 7 end
	if shield:check(name) then return 8 end
	if _lockGuildNames[name] then return 5 end
	_lockGuildNames[name] = true
	local values = server.mysqlCenter:query("guild", { name = name }, { dbid=true })
	if values[1] then
		_lockGuildNames[name] = nil
		return 5
	end
	return 0
end
function server.UnLockGuildName(name)
	_lockGuildNames[name] = nil
end

local _platformLockNames = {}
local _checkPlatformLockNameTimer = false
local function _CheckLockNames()
	local losttime = lua_app.now() - 60
	local remove = {}
	for name, ttime in pairs(_platformLockNames) do
		if ttime < losttime then
			remove[name] = true
		end
	end
	for name, _ in pairs(remove) do
		_platformLockNames[name] = nil
	end
	if not next(_platformLockNames) then
		-- lua_app.del_timer(_checkPlatformLockNameTimer)
		_checkPlatformLockNameTimer = false
	else
		_checkPlatformLockNameTimer = lua_app.add_timer(90000, _CheckLockNames)
	end
end

function server.CheckPlatformLockName(name)
	if _platformLockNames[name] then
		return false
	end
	if not _checkPlatformLockNameTimer then
		_checkPlatformLockNameTimer = lua_app.add_timer(90000, _CheckLockNames)
	end
	_platformLockNames[name] = lua_app.now()
	return true
end
function server.UnLockPlatformName(name)
	_platformLockNames[name] = nil
end

local _lockNames = {}
function server.CheckPlayerName(name)
	if _HasSpecificStr(name) then return 6 end
	if string.len(name) > 19 then return 7 end
	if shield:check(name) then return 8 end
	if _lockNames[name] then return 5 end
	_lockNames[name] = true
	local values = server.mysqlCenter:query("players", { name = name }, { dbid=true })
	if values[1] then
		_lockNames[name] = nil
		return 5
	end
	return 0
end

function server.UnLockPlayerName(name)
	_lockNames[name] = nil
end

function server.GetRandname(sex)
	if sex ~= 0 and sex ~= 1 then
		return ""
	end
	local boydata = share.query("random_boy")
	local girldata = share.query("random_girl")
	if sex == 0 then
		return boydata[math.random(1,#boydata)]
	elseif sex == 1 then
		return girldata[math.random(1,#girldata)]
	end
end

function server.CheckName(name, length)
	if _HasSpecificStr(name) then return 6 end
	if string.len(name) > 19 then return 7 end
	if shield:check(name) then return 8 end
	return 0
end

function server.RandName(id, msg)
	for i = 1, 30 do
		local name = server.GetRandname(msg.sex)
		if _HasSpecificStr(name) or string.len(name) > 19 or shield:check(name)
			or not server.mysqlCenter:query("players", { name = name }, { dbid=true })[1] then
			-- print("server.RandName", name)
			return {
				result = 0,
				actorname = name,
			}
		end
		print("server.RandName:: unused name", name)
	end
	lua_app.log_error("server.RandName: zenmedoucunzai")
	return {
		result = 1
	}
end

function server.GetRandName(src, sex)
	lua_app.ret(server.RandName(nil, { sex = sex }).actorname or "")
end

function server.PlatCheckLockName(src, name)
	if not server.CheckPlatformLockName(name) then
		lua_app.ret(9)
		return
	end
	local result = server.CheckPlayerName(name)
	if result ~= 0 then
		server.UnLockPlatformName(name)
		lua_app.ret(result)
		return
	end
	server.UnLockPlayerName(name)
	lua_app.ret(0)
end
