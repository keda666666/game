local lua_app = require "lua_app"
local lua_util = require "lua_util"
local sharedata = require "share.share_core"
local table = table

local NORET = {}
local pool = {}
local pool_count = {}
local objmap = {}
local collect_tick = 600

local function newobj(name, tbl)
	assert(pool[name] == nil, name)
	local cobj = sharedata.host.new(tbl)
	sharedata.host.incref(cobj)
	-- local v = { value = tbl , obj = cobj, watch = {} }
	local v = { obj = cobj, watch = {} }
	objmap[cobj] = v
	pool[name] = v
	pool_count[name] = { n = 0, threshold = 1000 }
end

local function collect10sec()
	if collect_tick > 10 then
		collect_tick = 10
	end
end

local function collectobj()
	while true do
		lua_app.sleep(100)	-- sleep 1s
		if collect_tick <= 0 then
			collect_tick = 600	-- reset tick count to 600 sec
			collectgarbage()
			for obj, v in pairs(objmap) do
				if v == true then
					if sharedata.host.getref(obj) <= 0  then
						objmap[obj] = nil
						sharedata.host.delete(obj)
					end
				end
			end
		else
			collect_tick = collect_tick - 1
		end
	end
end

local CMD = {}

local env_mt = { __index = _ENV }

local function InitValueLanguage(path)
	local strAdd = {}
	table.insert(strAdd, "local LAN ={")
	local fp = io.popen("ls " .. path .. "/*.config")
	for filename in fp:lines() do
		local file = io.open(filename)
		local readall = file:read("*a")
		file:close()
		table.insert(strAdd, readall)
	end
	fp:close()
	table.insert(strAdd, "};return LAN")
	local str = table.concat(strAdd)
	local result,configtable = load(str)
	if not result then
		lua_app.log_error("InitValueLanguage:",filename,configtable)
		return
	end
	result,configtable = pcall(result)
	if not result then
		lua_app.log_error("InitValueLanguage:",filename,configtable)
		return
	end
	return configtable
end

local function InitName(path)
	if not path or string.len(path) == 0 then
		return
	end
	local file = io.open(path .. "/boy.txt", "r")
	if nil == file then
	    print("open file boy.txt fail")
	    return
	end
	local readall = file:read("*a")
	file:close()
	local boyCfg = string.split(readall, "\r\n")

	file = io.open(path .. "/girl.txt", "r")
	if nil == file then
	    print("open file girl.txt fail")
	    return
	end
	readall = file:read("*a")
	file:close()
	local girlCfg = string.split(readall, "\r\n")

	CMD.new("random_boy",boyCfg)
	CMD.new("random_girl",girlCfg)
end

local function InitConfig(path)
	local LAN = InitValueLanguage(path .. "/server/language/lang")
	local configPaths = {}

	local function LoadConfig(filename,env)
		local result,msg = loadfile(filename, nil, env)
		if not result then
			lua_app.log_error("LoadConfig:",filename,msg)
		else
			result,msg = pcall(result)
			if not result then
				lua_app.log_error("LoadConfig:",filename,msg)
			end
		end
		for name,config in pairs(env) do
			if name ~= "LAN" then
				configPaths[name] = filename
				CMD.new(name,config)
			end
		end
	end

	--[[
	local Lang = {}
	for filename in io.popen("ls " .. path .. "/language/zh-cn/*.txt"):lines() do
		LoadConfig(filename, Lang)
	end
	]]

	local cmd = string.format("find %s -name *.config",path .. "/server")
	local fp = io.popen(cmd)
	for filename in fp:lines() do
		if not string.find(filename, "language") then
			LoadConfig(filename,{LAN = LAN})
		end
	end
	fp:close()

	CMD.new("LAN",LAN)
	CMD.new("**tbPaths**",configPaths)
end

local function UpdateAll()
	local paths = sharedata.box(pool["**tbPaths**"].obj)
	local LAN = sharedata.box(pool["LAN"].obj)
	if LAN == nil then
		lua_app.log_error("update config failed! LAN not exist",name)
		return
	end

	for name,path in pairs(paths) do
		local env = {LAN = LAN}
		local result,msg = loadfile(path, nil, env)
		if not result then
			lua_app.log_error("UpdateConfig:",path,msg)
		else
			result,msg = pcall(result)
			if not result then
				lua_app.log_error("UpdateConfig:",path,msg)
			end
		end

		for name,config in pairs(env) do
			if name ~= "LAN" then
				CMD.update(name,config)
				lua_app.log_info("update config:",name)
			end
		end
	end
end

local function UpdateOne(name)
	local paths = sharedata.box(pool["**tbPaths**"].obj)
	if paths[name] == nil then
		lua_app.log_error("update config failed! path not exist",name)
		return
	end
	local LAN = sharedata.box(pool["LAN"].obj)
	if LAN == nil then
		lua_app.log_error("update config failed! LAN not exist",name)
		return
	end

	local path = paths[name]
	local env = {LAN = LAN}
	local result,msg = loadfile(path, nil, env)
	if not result then
		lua_app.log_error("UpdateConfig:",path,msg)
	else
		result,msg = pcall(result)
		if not result then
			lua_app.log_error("UpdateConfig:",path,msg)
		end
	end

	for name,config in pairs(env) do
		if name ~= "LAN" then
			CMD.update(name,config)
			lua_app.log_info("update config:",name)
		end
	end
end

function CMD.init(namePath,configPath)
	InitName(namePath)
	InitConfig(configPath)
	collectgarbage()
end

function CMD.refresh(name)
	UpdateOne(name)
end

function CMD.refreshall()
	UpdateAll()
end

function CMD.new(name, t, ...)
	local dt = type(t)
	local value
	if dt == "table" then
		value = t
	elseif dt == "string" then
		value = setmetatable({}, env_mt)
		local f
		if t:sub(1,1) == "@" then
			f = assert(loadfile(t:sub(2),"bt",value))
		else
			f = assert(load(t, "=" .. name, "bt", value))
		end
		local _, ret = assert(pcall(f, ...))
		setmetatable(value, nil)
		if type(ret) == "table" then
			value = ret
		end
	elseif dt == "nil" then
		value = {}
	else
		error ("Unknown data type " .. dt)
	end
	newobj(name, value)
end

function CMD.delete(name)
	local v = assert(pool[name], name)
	pool[name] = nil
	pool_count[name] = nil
	assert(objmap[v.obj])
	objmap[v.obj] = true
	sharedata.host.decref(v.obj)
	for _,response in pairs(v.watch) do
		response(true)
	end
end

function CMD.query(name)
	local v = assert(pool[name], name)
	local obj = v.obj
	sharedata.host.incref(obj)
	lua_app.ret(v.obj)
end

function CMD.confirm(cobj)
	if objmap[cobj] then
		sharedata.host.decref(cobj)
	end
end

function CMD.update(name, t, ...)
	local v = pool[name]
	local watch, oldcobj
	if v then
		watch = v.watch
		oldcobj = v.obj
		objmap[oldcobj] = true
		sharedata.host.decref(oldcobj)
		pool[name] = nil
		pool_count[name] = nil
	end
	CMD.new(name, t, ...)
	local newobj = pool[name].obj
	if watch then
		sharedata.host.markdirty(oldcobj)
		for _,response in pairs(watch) do
			response(true, newobj)
		end
	end
	collect10sec()	-- collect in 10 sec
end

local function check_watch(queue)
	local n = 0
	for k,response in pairs(queue) do
		if not response "TEST" then
			queue[k] = nil
			n = n + 1
		end
	end
	return n
end

function CMD.monitor(name, obj)
	local v = assert(pool[name])
	if obj ~= v.obj then
		lua_app.ret(v.obj)
	end

	local n = pool_count[name].n + 1
	if n > pool_count[name].threshold then
		n = n - check_watch(v.watch)
		pool_count[name].threshold = n * 2
	end
	pool_count[name].n = n
	local f = lua_app.response()
	table.insert(v.watch, f)
end

lua_app.regist_dispatch("lua",function(source,session,cmd,...)
	local f = assert(CMD[cmd], cmd)
	f(...)
end)

function main()
	lua_app.fork(collectobj)
end
