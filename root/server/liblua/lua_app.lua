local clib = require "app"
local serialize = require "Serialize"
local server = require "server"

local tostring = tostring
local tonumber = tonumber
local coroutine = coroutine
local assert = assert
local pairs = pairs
local pcall = pcall


local add_local_timer_cnt = 0
local co_create = coroutine.create
local co_yield = coroutine.yield
local co_resume = coroutine.resume
local co_running = coroutine.running


local lua_app = 
{
	MSG_TEXT = 0,
	MSG_RESPONSE = 1,
	MSG_SYSTEM = 2,
	MSG_SOCKET = 3,
	MSG_LUA_SOCKET = 4,
	MSG_ROUTER = 5,
	MSG_CENTER = 6,
	MSG_ERROR = 7,
	MSG_CLIENT = 8,
	MSG_MONGO = 9,

	MSG_LUA = 10,
	MSG_LUA_ROUTER = 11,
	MSG_ROUTER_TEXT = 12,
	MSG_MYSQL = 13,
	MSG_CLIENT_QUIK = 14,

	MSG_TEST = 15,
}

lua_app.SVC_LOGIN = 1
lua_app.SVC_LOGIC = 2
lua_app.SVC_FIGHT = 3
lua_app.SVC_CACHE = 4
lua_app.SVC_SCENE = 5
lua_app.SVC_CENTER = 6

local session_to_co = {}
local co_to_session = {}
local co_to_address = {}
local wakeup_session = {}
local sleeping_session = {}
local watching_process = {}
local watching_session = {}
local error_session = {}

local session_response = {}
local unresponse = {}



local protocols = {}
local co_pool = {}
local fork_queue = {}
local name = assert(clib.start_cmd())

local regist_name
local regist_protocol
local regist_dispatch
local new_co
local dispatch_wakeup
local dispatch_message
local unknown_response
local suspend
local add_local_timer
local del_local_timer
local add_timer
local del_timer
local run_after
local sleep
local yield
local wait
local fork


local self
local self_ptr
local new_process
local new_lua

local raw_send
local send
local call
local raw_call
local ret
local wake
local exit
local kill
local get_env
local set_env
local change_env

local log_info
local log_debug
local log_warning
local log_error

local get_table_size

function regist_protocol(protocol)
	local name = protocol.name
	local id = protocol.id
	assert(protocols[name] == nil)
	assert(type(name) == "string" and type(id) == "number" and id >= 0 and id <=255)
	protocols[name] = protocol
	protocols[id] = protocol
end


function regist_dispatch(type_name,func)
	local protocol = assert(protocols[type_name],tostring(type_name))
	assert(protocol.dispatch == nil,tostring(type_name))

	protocol.dispatch = func
end

regist_name = clib.regist_name

function new_co(f)

	local co = table.remove(co_pool)

	if co == nil then
		co = co_create(function(...)
			f(...)
			while true do
				f = nil
				co_pool[#co_pool+1] = co
				f = co_yield "EXIT"
				f(co_yield())
			end
		end)
	else
		co_resume(co,f)
	end
	return co
end

local function unknown_response(address,session,msg,sz)
	error(string.format("Unknown session:%d from %d",session,address))
end

local RESPONSE_TAG = lua_app.MSG_RESPONSE

local function raw_dispatch_message(type,source,session,data,size,...)
	if type == RESPONSE_TAG then
		local co = session_to_co[session]

		if co == "BREAK" then
			session_to_co[session] = nil	
		elseif co == nil then
			return
		else
			session_to_co[session] = nil
			suspend(co,co_resume(co,true,data,size))
		end
	else
		local protocol = assert(protocols[type],type)
		local dispatch = protocol.dispatch

		if dispatch then
			local co = new_co(dispatch)
			co_to_session[co] = session
			co_to_address[co] = source

			assert(protocol.unpack,string.format("type:%d unpack function is nil",type))
			suspend(co,co_resume(co,source,session,protocol.unpack(data,size,...)))
		else
			error(string.format("Can't dispatch type %s:",protocol.name))
		end
	end
end

local function dispatch_err_session()
	local session = table.remove(error_session)
	if session then
		local co = session_to_co[session]
		session_to_co[session] = nil
		return suspend(co,co_resume(co,false))
	end
end

local real_raw_dispatch_message

local function traceback(err)
	print(err)
	print(debug.traceback())
end

local function call_main(type,source,session)
	assert(type == lua_app.MSG_SYSTEM,"first msg should be fromsystem")
	real_raw_dispatch_message = nil
	assert(main,"there must be a main func in your process")
	local co = new_co(function()
		-- lua_app.log_info("call main start", lua_app.self())
		local ok,err = xpcall(main,traceback)
		if not ok then
			send(".launcher","lua","launch_err")
			exit()
		else
			-- lua_app.log_info("call main suc", lua_app.self())
			real_raw_dispatch_message = raw_dispatch_message
			send(".launcher","lua","launch_ok")
		end
	end)
	co_to_session[co] = 0
	co_to_address[co] = source

	suspend(co,co_resume(co))

	real_raw_dispatch_message = raw_dispatch_message
end

real_raw_dispatch_message = call_main

function dispatch_message(...)
	if real_raw_dispatch_message == nil then
		lua_app.log_info("dispatch_message", lua_app.self(), ...)
		lua_app.log_error("real_raw_dispatch_message is nil")
		exit()
	end
	local ok,err = pcall(real_raw_dispatch_message,...)
	while true do
		local key,co = next(fork_queue)
		if co == nil then
			break
		end
		fork_queue[key] = nil
		local fork_succ,fork_err = pcall(suspend,co,co_resume(co))
		if not fork_succ then
			if ok then
				ok = false
				err = tostring(fork_err)
			else
				err = tostring(err).."\n"..tostring(fork_err)
			end
		end
	end

	assert(ok,tostring(err))
end

local function error_dispatcher(monitor,session,process)
	if process then
		watching_process[process] = false

		for session,srv in pairs(watching_session) do
			if srv == process then
				table.insert(error_session,session)
			end
		end
	else
		if watching_session[session] then
			table.insert(error_session,session)
		end
	end
end

function suspend(co,result,command,param,size)
	if not result then
		local session = co_to_session[co]
		local address = co_to_address[co]
		if session and address and session~=0 and address~=0 then

		end
		co_to_session[co] = nil
		co_to_address[co] = nil
		error(debug.traceback(co,tostring(command)))
	end
	if command == "CALL" then
		session_to_co[param] = co	
	elseif command == "SLEEP" then
		session_to_co[param] = co
	elseif command == "RETURN" then
		local session = co_to_session[co]
		local address = co_to_address[co]

		if param == nil then
			error(debug.traceback(co))
		end
		clib.send(address,session,lua_app.MSG_RESPONSE,param,size)
		return suspend(co,co_resume(co))
	elseif command == "EXIT" then
		co_to_session[co] = nil
		co_to_address[co] = nil
		session_response[co] = nil
	elseif command == "RESPONSE" then
		local co_session = co_to_session[co]
		local co_address = co_to_address[co]
		if session_response[co] then
			error(debug.traceback(co))
		end
		local f = param
		local function response(ok, ...)
			if ok == "TEST" then
				if watching_process[co_address] == false then
					unresponse[response] = nil
					return false
				else
					return true
				end
			end
			local ret
			if watching_process[co_address] == false then
				ret = false
			else
				if ok then
					ret = clib.send(co_address,co_session,lua_app.MSG_RESPONSE, f(...))
					if not ret then
						clib.send(co_address, lua_app.MSG_ERROR, co_session, "")
					end
				else
					ret = clib.send(co_address, lua_app.MSG_ERROR, co_session, "") ~= nil
				end
			end
			unresponse[response] = nil
			f = nil
			return ret
		end
		session_response[co] = true
		unresponse[response] = true
		return suspend(co, co_resume(co,response))
	else
		error("Unknow command :"..command.."\n"..debug.traceback(co))
	end

	dispatch_wakeup()
	dispatch_err_session()
end


function dispatch_wakeup()

	local co = next(wakeup_session)

	if co == nil then
		return
	end

	wakeup_session[co] = nil

	local session = sleeping_session[co]

	if session == nil then
		return
	end
	sleeping_session[co] = "BREAK"
	return suspend(co,co_resume(co,true))
end

function run_after(delay_ms,func,...)
	local args = {...}
	local session = clib.run_after(delay_ms) 
	local co = new_co(function()
		func(table.unpack(args))
	end)
	assert(session_to_co[session] == nil)

	session_to_co[session] = co
end

function add_local_timer(delay_ms,func,obj,...)
	local args = {...}
	local session = clib.run_after(delay_ms)

	table.insert(args,1,session)
	table.insert(args,1,obj)

	local co = new_co(function()
		func(table.unpack(args))
	end)

	assert(session_to_co[session] == nil)
	session_to_co[session] = co

	return session
end

local _weaktb = {}
setmetatable(_weaktb,{__mode="k"})
function add_update_timer(delay_ms,obj,func,...)
	local args = {...}
	local session = clib.run_after(delay_ms)

	table.insert(args,1,session)
	table.insert(args,1,obj)

	local co = new_co(function()
		obj[func](table.unpack(args))
	end)

	assert(session_to_co[session] == nil)
	session_to_co[session] = co
	
	_weaktb[obj] = {func,"obj"}
	_weaktb[args] = {func,"args"}

	return session
end

function del_local_timer(session)
	session_to_co[session] = nil
end

local add_timer_cnt = 0
function add_timer(delay_ms,func,...)
	add_timer_cnt = add_timer_cnt + 1
	local args = {...}
	local session = clib.run_after(delay_ms)
	table.insert(args,1,session)

	local co = new_co(function()
		func(table.unpack(args))
	end)

	assert(session_to_co[session] == nil)
	session_to_co[session] = co

	return session
end

function del_timer(session)
	session_to_co[session] = nil
end

function year()
	return os.date("*t", lua_app.now()).year
end

function month()
	return os.date("*t", lua_app.now()).month
end

function day()
	return os.date("*t", lua_app.now()).day
end

-- 0 sunday
function week()
	local w = os.date("*t", lua_app.now()).wday - 1
	if w == 0 then
		return 7
	else
		return w
	end
end

function hour()
	return os.date("*t", lua_app.now()).hour
end

function minute()
	return os.date("*t", lua_app.now()).min
end

local function yield_sleep(session)
	sleeping_session[co_running()] = true
	local succ,ret = co_yield("SLEEP",session)
	sleeping_session[co_running()] = nil
end

local function yield_wait(session)
	yield_sleep(session)

	local co = co_running()

	sleeping_session[co] = nil
	session_to_co[session] = nil
end

local function yield_call(process,session)
	watching_session[session] = process
	local succ,msg,sz = co_yield("CALL",session)
	watching_session[session] = nil
	if not succ then
		return nil,nil
	end
	return msg,sz
end

local function yield_return(data,size)
	co_yield("RETURN",data,size)
end

function sleep(delay_ms)
	local session = clib.run_after(delay_ms)
	assert(session)

	yield_sleep(session)
end

function yield()
	sleep(0)
end

function wait()
	local session = clib.new_session()
	yield_wait(session)
end

function fork(func,...)
	local args = {...}
	local co = new_co(function()
		func(table.unpack(args))
	end)
	table.insert(fork_queue,co)
	return co
end

local function waitmultrun(func, list, ...)
	if not next(list) then return {} end
	local args = {...}
	local tmp, ret = 0, {}
	local co = co_running()
	for i, v in pairs(list) do
		tmp = tmp + 1
		run_after(0, function()
				ret[i] = func(i, v, table.unpack(args))
				tmp = tmp - 1
				if tmp == 0 then
					lua_app.wake(co)
				end
			end)
	end
	lua_app.wait()
	return ret
end

local function waitoneret(func, list, ...)
	if not next(list) then return end
	local args = {...}
	local tmp, key, ret = 0
	local co = co_running()
	for i, v in pairs(list) do
		tmp = tmp + 1
		run_after(0, function()
				local r = func(i, v, table.unpack(args))
				if not ret then
					if r then
						key = i
						ret = r
						lua_app.wake(co)
					elseif tmp == 1 then
						lua_app.wake(co)
					else
						tmp = tmp - 1
					end
				end
			end)
	end
	lua_app.wait()
	return key, ret
end

local _lockwaitlist = {}
local _lockwaiting = {}
local function waitlockrun(lock, func, waitprintcount)
	if not _lockwaiting[lock] then
		_lockwaiting[lock] = {}
	end
	local co = co_running()
	if _lockwaitlist[lock] then
		table.insert(_lockwaiting[lock], co)
		if waitprintcount and #_lockwaiting[lock] > waitprintcount then
			lua_app.log_error("waitlockrun:: waitcount:", #_lockwaiting[lock], lock)
		end
		lua_app.wait()
	end
	_lockwaitlist[lock] = true
	func()
	_lockwaitlist[lock] = nil
	local waitco = table.remove(_lockwaiting[lock])
	if waitco then
		lua_app.wake(waitco)
	end
end
local function runwaitlock(lock, num)
	if not num then num = math.huge end
	for i = 1, num do
		local waitco = table.remove(_lockwaiting[lock])
		if not waitco then break end
		lua_app.wake(waitco)
	end
end

local _runtimertag = {}
local function rununtiltrue(tag, interval, func)
	if _runtimertag[tag] then return end
	_runtimertag[tag] = true
	local function _RunFunc()
		if func() then
			_runtimertag[tag] = nil
			return
		end
		run_after(interval, _RunFunc)
	end
	run_after(interval, _RunFunc)
end

self = assert(clib.self)

local _self_handler = 0
local function self()
	if _self_handler == 0 then
		_self_handler = clib.self()
	end
	return _self_handler
end

self_ptr = assert(clib.self_ptr)

function new_process(name,...)
	local args = table.concat({...}," ")
	local handle = clib.new_process(name,args)
	return handle
end

function new_lua(name,...)
	local handle = clib.unpack(raw_call(".launcher","lua",clib.pack("new_process","LuaProxy",name,...)))
	if type(handle) == "number" then
		return handle
	end

	return 0
end

function unique_lua(name,...)
	local handle = clib.unpack(raw_call(".launcher","lua",clib.pack("unique_process","LuaProxy",name,...)))
	if type(handle) == "number" then
		return handle
	end

	return 0
end

function raw_send(source,dest,session,type_name,...)
	local protocol = protocols[type_name]
	if watching_process[dest] == false then
		error("Service is dead")
	end
	return clib.raw_send(source,dest,session,protocol.id,protocol.pack(...))
end

function send(dest,type_name,...)
	local protocol = protocols[type_name]
	if watching_process[dest] == false then
		error("Service is dead")
	end

	return clib.send(dest,0,protocols[type_name].id,protocol.pack(...))
end

function call(addr,type_name,...)
	local protocol = protocols[type_name]

	if watching_process[addr] == false then
		error("Service is dead")
	end

	local session = clib.new_session()
	local ret = clib.send(addr,session,protocol.id,protocol.pack(...))
	if ret == nil or ret == -1 then
		error("call to invalid address "..tostring(addr))
	end
	return protocol.unpack(yield_call(addr,session))
end

function supercall(time,addr,type_name,...)
	local protocol = protocols[type_name]

	if watching_process[addr] == false then
		error("Service is dead")
	end

	local session = clib.new_session()

	local ret = clib.send(addr,session,protocol.id,protocol.pack(...))
	if ret == nil or ret == -1 then
		error("call to invalid address "..tostring(addr))
	end
	lua_app.run_after(time,function()
		local co = session_to_co[session]
		if co == nil then
			return
		end
		session_to_co[session] = nil
		suspend(co,co_resume(co,false))
	end)
	local msg,sz = yield_call(addr,session)
	if msg == nil then
		return nil
	else
		return protocol.unpack(msg,sz)
	end
end

function raw_call(addr,type_name,data,sz)
	local protocol = protocols[type_name]
	local session = clib.new_session()
	local ret = assert(clib.send(addr,session,protocol.id,data,sz),"call to invalid address")
	return yield_call(addr,session)
end

function ret(...)
	return yield_return(clib.pack(...))
end

local function response(func)
	if func == nil then
		func = clib.pack
	end
	return co_yield("RESPONSE", func)
end

local function wake(co)
	if sleeping_session[co] and wakeup_session[co] == nil then
		wakeup_session[co] = true
	end
end

function exit()
	send(".launcher","lua","remove",self())
	clib.kill(0)
end

function kill(who)
	if type(who) == "number" then
		send(".launcher","lua","remove",who)
	end
	clib.kill(who)
end

get_env = assert(clib.get_env)

function set_env(key,val)
	clib.set_env(key,tostring(val))
end

function change_env(key,val)
	clib.change_env(key,tostring(val))
end

clib.callback(dispatch_message)


local function log_detail()
	local info = debug.getinfo(3, "nSl") 
	local name = info.source:match(".+%/(.+)$")
	local line = info.currentline
	local func = info.name
	info = string.format("%s-%d: ",name,line)
	return info
end


local __info_pre = (server.wholename or "") .. ":INFO"
function log_info(...)
	local t = {...}
	for i = 1,#t do
		t[i] = tostring(t[i])
	end
	local str = table.concat(t," ")
	local info = log_detail()
	return clib.log_script(__info_pre,info..str)
end

function log_debug(...)
	local t = {...}
	for i = 1,#t do
		t[i] = tostring(t[i])
	end
	local str = table.concat(t," ")
	local info = log_detail()
	return clib.log_script("DEBUG",info..str)
end

function log_warning(...)
	local t = {...}
	for i = 1,#t do
		t[i] = tostring(t[i])
	end
	local str = table.concat(t," ")
	local info = log_detail()
	return clib.log_script("WARNING",info..str)
end

local __error_pre = (server.wholename or "") .. ":ERROR"
function log_error(...)
	local t = {...}
	for i = 1,#t do
		t[i] = tostring(t[i])
	end
	local str = table.concat(t," ")
	local info = log_detail() .. str
	local str_stack = debug.traceback(info)
	return clib.log_error(__error_pre,str_stack)
end

local function T2S(_t)
    local szRet = "{"
    function doT2S(_i, _v)
        if "number" == type(_i) then
            szRet = szRet .. "[" .. _i .. "] = "
            if "number" == type(_v) then
                szRet = szRet .. _v .. ","
            elseif "string" == type(_v) then
                szRet = szRet .. '"' .. _v .. '"' .. ","
            elseif "table" == type(_v) then
                szRet = szRet .. sz_T2S(_v) .. ","
            else
                szRet = szRet .. "nil,"
            end
        elseif "string" == type(_i) then
            szRet = szRet .. '["' .. _i .. '"] = '
            if "number" == type(_v) then
                szRet = szRet .. _v .. ","
            elseif "string" == type(_v) then
                szRet = szRet .. '"' .. _v .. '"' .. ","
            elseif "table" == type(_v) then
                szRet = szRet .. sz_T2S(_v) .. ","
            else
                szRet = szRet .. "nil,"
            end
        end
    end
    table.foreach(_t, doT2S)
    szRet = szRet .. "}"
    return szRet
end

local function S2T(str)
    str = "return " .. str;
    local fun = load(str);
    return fun();
end

--print = log_info

do
	regist_protocol
	{
		name = "text",
		id = lua_app.MSG_TEXT,
		pack = function(...)
			local n = select("#",...)
			if n == 0 then
				return ""
			elseif n == 1 then
				return tostring(...)
			else
				return table.concat({...},";")
			end
		end,
		unpack = clib.tostring,
		dispatch = function(...)
			-- print("ddddddddddddd", ...)
		end,
	}

	regist_protocol
	{
		name = "router_text",
		id = lua_app.MSG_ROUTER_TEXT,
		pack = function(...)
			local n = select("#",...)
			if n == 0 then
				return ""
			elseif n == 1 then
				return tostring(...)
			else
				return table.concat({...},";")
			end
		end,
		unpack = clib.tostring
	}
	regist_protocol
	{
		name = "response",
		id = lua_app.MSG_RESPONSE,
		pack = clib.pack,
		unpack = clib.unpack,
	}
	regist_protocol
	{
		name = "lua",
		id = lua_app.MSG_LUA,
		pack = clib.pack,
		unpack = clib.unpack,
	}
	regist_protocol
	{
		name = "lua_router",
		id = lua_app.MSG_LUA_ROUTER,
		pack = clib.pack,
		unpack = clib.unpack,
	}

	regist_protocol
	{
		name = "error",
		id = lua_app.MSG_ERROR,
		pack = function(...)
			local n = select("#",...)
			if n == 0 then
				return ""
			elseif n == 1 then
				return tostring(...)
			else
				return table.concat({...},";")
			end
		end,
		unpack = clib.tostring,
		dispatch = error_dispatcher;
	}

end

local check = function(name)
	local ret = call(clib.get_router(),lua_app.MSG_ROUTER_TEXT,"search",name)	
	return tonumber(ret)
end

local unpack_table = function(str)
	local fun = load('return ' .. str)
	return fun()
end

lua_app.regist_name = regist_name
lua_app.regist_protocol = regist_protocol
lua_app.regist_dispatch = regist_dispatch
lua_app.send = send
lua_app.raw_send = raw_send
lua_app.call = call
lua_app.supercall = supercall
lua_app.now = assert(clib.now)
lua_app.run_after = run_after
lua_app.add_local_timer = add_local_timer
lua_app.del_local_timer = del_local_timer
lua_app.add_timer = add_timer
lua_app.del_timer = del_timer 
lua_app.add_update_timer = add_update_timer
lua_app.year = year
lua_app.month = month
lua_app.day = day
lua_app.week = week
lua_app.hour = hour
lua_app.minute = minute

lua_app.new_lua = new_lua
lua_app.unique_lua = unique_lua
lua_app.new_process = new_process
lua_app.ret = ret
lua_app.response = response
lua_app.sleep = sleep
lua_app.get_env = get_env
lua_app.set_env = set_env
lua_app.change_env = change_env
lua_app.pack = clib.pack
lua_app.unpack = clib.unpack
lua_app.exit = exit
lua_app.name = name
lua_app.tostring = clib.tostring
lua_app.self = self
lua_app.die = clib.die
lua_app.wait = wait
lua_app.kill = kill
lua_app.wake = wake
lua_app.log_info = log_info
lua_app.log_debug = log_debug
lua_app.log_warning = log_warning
lua_app.log_error = log_error
lua_app.fork = fork
lua_app.waitmultrun = waitmultrun
lua_app.waitoneret = waitoneret
lua_app.waitlockrun = waitlockrun
lua_app.runwaitlock = runwaitlock
lua_app.rununtiltrue = rununtiltrue
lua_app.now_ms = clib.now_ms
lua_app.now_us = clib.now_us
lua_app.set_core_flag = clib.set_flag
lua_app.reset_core_flag = clib.reset_flag
lua_app.time_zone = clib.time_zone
lua_app.malloc_stats = clib.malloc_stats
lua_app.malloc_trim = clib.malloc_trim
lua_app.malloc_free = clib.malloc_free
lua_app.get_router = clib.get_router
lua_app.pack_table = clib.table_encode
lua_app.unpack_table = clib.table_decode
lua_app.pack_tableA = clib.table_encodeA
lua_app.unpack_tableA = clib.table_decodeA
lua_app.send_socket = clib.send_socket
lua_app.get_distance = clib.get_distance
lua_app.check = check
lua_app.hashcode = clib.get_hashcode
lua_app.md5code = clib.get_md5code
lua_app.uuid = clib.gen_uuid
lua_app.guid = clib.gen_guid
lua_app.encode = clib.encode
lua_app.decode = clib.decode
lua_app.weaktb = _weaktb

lua_app.show = function()
	local cnt = 0
	for co,tb in pairs(_weaktb) do
		cnt = cnt + 1
		lua_app.log_info(co,tb[1],tb[2])
	end
	lua_app.log_info("update timer args num:",cnt)
end

return lua_app
