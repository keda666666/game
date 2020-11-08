local lua_app = require "lua_app"
local socket_driver = require "SocketDriver"
local buffer = require "Util"

local assert = assert
local api = {}
local net_cmds = {}

local conns = setmetatable(
	{},
	{__gc = function(p)
		for id,v in pairs(p) do
			socket_driver.close(id)
			p[id] = nil
		end
	end
	}
)

lua_app.regist_protocol
{
	name = "socket",

	id = lua_app.MSG_SOCKET,

	unpack = assert(socket_driver.unpack),

	dispatch = function(source,session,msgtype,socket,...)
		local net_func = net_cmds[msgtype]

		if net_func == nil then

		else
			net_func(socket,...)
		end
	end
}

local function wait(conn)

	assert(not conn.co)

	conn.co = coroutine.running()


	lua_app.wait()
end

local function wake(conn)
	local co = conn.co
	if co == nil then
		return
	end

	conn.co = nil


	lua_app.wake(co)
end

net_cmds[socket_driver.SOCKET_RESULT_ACCEPT] = function(socket,new_socket,fd,ip)

	local accept_conn = conns[socket]

	assert(accept_conn)

	local conn =
	{
		socket = new_socket,
		connected = true,
		closed = false;
		callback = func,
		co = nil,
		buffer = nil,
		reading = nil,
	}

	conns[new_socket] = conn

	assert(accept_conn.callback)

	accept_conn.callback(socket,new_socket,fd,ip)
end

net_cmds[socket_driver.SOCKET_RESULT_CONNECT] = function(socket,sucess,fd)

	local conn = conns[socket]

	if conn == nil then
		return
	end

	conn.connected = sucess

	wake(conn)

end

net_cmds[socket_driver.SOCKET_RESULT_DATA] = function(socket,data,size)

	local conn = conns[socket]

	if conn == nil then
		lua_app.log_info("socket:ddrop data from "..socket)
		return
	end

	local total_size = socket_driver.buffer_append(conn.buffer,data,size)
	local read_op = conn.reading
	local read_type = type(conn.reading)

	if read_type == "number" then

		if total_size >= read_op then
			conn.reading = nil
			wake(conn)
		end

	elseif read_type == "string" then

		local find_size = socket_driver.buffer_find(conn.buffer,read_op)

		if find_size > 0 then
			conn.reading = find_size
			wake(conn)
		end
	end
end

net_cmds[socket_driver.SOCKET_RESULT_CLOSE] = function(socket)

	local conn = conns[socket]

	if conn == nil then

		return

	end

	conn.connected = false

	conn.closed = true

	wake(conn)

end


function api.accept(addr,port,func)

	local id = socket_driver.accept(addr,port)

	if not id then

		return

	end

	local conn =
	{
		socket = id,
		connected = false,
		closed = false,
		callback = func,
		co = nil,
		buffer = nil,
		reading = nil,
	}

	conns[id] = conn

	return id
end


function api.start_input()
	local id = socket_driver.input()

	if not id then

		return

	end

	local conn =
	{
		socket = id,
		connected = false,
		closed = false,
		callback = nil,
		co = nil,
		buffer = nil,
		reading = nil,
		connected = true,
	}

	conn.buffer = socket_driver.buffer_new()

	conns[id] = conn

	return id
end


function api.connect(addr,port)

	local id = socket_driver.connect(addr,port)

	if id == 0 then

		return nil

	end

	local conn =
	{
		socket = id,
		connected = false,
		closed = false,
		callback = nil,
		co = nil,
		buffer = nil,
		reading = nil,
	}

	conns[id] = conn

	wait(conn)

	if conn.connected == true then
		return id
	end

end

function api.start(id)

	local conn = conns[id]

	assert(conn)

	-- assert(conn.callback == nil)

	conn.buffer = socket_driver.buffer_new()

	socket_driver.start(id)
end

-- 移交给其他服务处理
function api.move(id)
	local conn = conns[id]
	assert(conn)
	assert(not conn.buffer)
	conns[id] = nil
end
-- 被移交的服务
function api.transfer(id)
	local conn = {
		socket = id,
		connected = true,
		closed = false;
		callback = nil,
		co = nil,
		buffer = nil,
		reading = nil,
	}
	conns[id] = conn
	conn.buffer = socket_driver.buffer_new()
	socket_driver.start(id)
end

function api.readall(id)

	local conn = conns[id]

	assert(conn)

	if conn.connected == false then

		return false

	end

	local total_size = socket_driver.buffer_size(conn.buffer)

	if total_size > 0 then
		local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)
		return true,data,size
	end

	wait(conn)

	if conn.connected == false then

		return false

	end

	local total_size = socket_driver.buffer_size(conn.buffer)

	local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)

	return true,data,size

end

function api.writedata(id, data)
	local stream = buffer.Stream(#data)
	local writer = buffer.Writer(stream)
	writer:write_bytes(data)
	api.write(id, stream:data(), stream:size())

	return true
end

function api.readdata(id, size)
	local ok, data, realsize = api.read(id, size)
	if ok then
		local stream = buffer.Stream(data, realsize)
		return stream:data()
	end
	return nil
end

function  api.read(id,size)
	local conn = conns[id]
	assert(conn)
	if conn.connected == false then
		return
	end

	if size == nil then
		local total_size = socket_driver.buffer_size(conn.buffer)
		local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)
		if size ~= 0 then
			return lua_app.tostring(data,size)
		end

		if not conn.connected then
			return
		end
		assert(not conn.reading)
		conn.reading = 0
		wait(conn)
		local total_size = socket_driver.buffer_size(conn.buffer)
		local data ,size = socket_driver.buffer_fetch(conn.buffer,total_size)

		if total_size ~= 0 then
			return lua_app.tostring(data,size)
		else
			return
		end
	end
	local total_size = socket_driver.buffer_size(conn.buffer)

	if total_size < size then
		conn.reading = size
		wait(conn)
		if conn.connected == false then
			return
		end
		local data,size = socket_driver.buffer_fetch(conn.buffer,size)
		return lua_app.tostring(data,size)
	else
		local data,size = socket_driver.buffer_fetch(conn.buffer,size)
		return lua_app.tostring(data,size)
	end
end

function api.read_line(id,sep)

	sep = sep or "\n"

	local conn = conns[id]

	assert(conn,string.format("%d not exist",id))

	if conn.connected == false then
		return
	end

	local size = socket_driver.buffer_find(conn.buffer,sep)

	if size == 0 then
		conn.reading = sep
		wait(conn)
	else
		conn.reading = size
	end

	if conn.connected == false then

		return

	end

	local read_size = conn.reading

	local data = socket_driver.buffer_fetch(conn.buffer,read_size)

	local str = lua_app.tostring(data,read_size - #sep)

	return str
end

api.write = assert(socket_driver.write)


function api.close(id)

	local conn = conns[id]

	if conn == nil then

		return

	end

	if conn.closed == false then

		socket_driver.close(id)

		conn.closed = true
	end

	conn.buffer = nil

	conns[id] = nil

end

return api
