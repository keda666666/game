local socket = require "socket"
local lua_app = require "lua_app"

local readbytes = socket.read
local writebytes = socket.write

local sockethelper = {}
local socket_error = setmetatable({} , { __tostring = function() return "[Socket Error]" end })

sockethelper.socket_error = socket_error

local function preread(fd, str)
	return function (sz)
		if str then
			if sz == #str or sz == nil then
				local ret = str
				str = nil
				return ret
			else
				if sz < #str then
					local ret = str:sub(1,sz)
					str = str:sub(sz + 1)
					return ret
				else
					sz = sz - #str
					local ret = readbytes(fd, sz)
					if ret then
						return str .. ret
					else
						error(socket_error)
					end
				end
			end
		else
			local ret = readbytes(fd, sz)
			if ret then
				return ret
			else
				error(socket_error)
			end
		end
	end
end

function sockethelper.readfunc(fd, pre)
	if pre then
		return preread(fd, pre)
	end
	return function (sz)
		local ret = readbytes(fd, sz)
		if ret then
			-- if #ret > 0 then
			-- 	print("||+||", #ret, ret, "||-||")
			-- end
			return ret
		else
			-- lua_app.log_error("sockethelper.readfunc")
			return false
			-- error(socket_error)
		end
	end
end

sockethelper.readall = socket.readall

function sockethelper.writefunc(fd)
	return function(content)
		writebytes(fd, content)
		return true
	end
end

function sockethelper.connect(host, port, timeout)
	local fd
	if timeout then
		local drop_fd, connectover
		local co = coroutine.running()
		-- asynchronous connect
		lua_app.run_after(timeout, function()
			if connectover then return end
			if drop_fd then
				-- sockethelper.connect already return, and raise socket_error
				socket.close(fd)
			else
				-- socket.open before sleep, wakeup.
				lua_app.wake(co)
			end
		end)
		fd = socket.connect(host, port)
		connectover = true
		if not fd then
			-- not connect yet
			drop_fd = true
		end
	else
		-- block connect
		fd = socket.connect(host, port)
	end
	return fd
	-- error(socket_error)
end

function sockethelper.close(fd)
	socket.close(fd)
end

sockethelper.start = socket.start

function sockethelper.shutdown(fd)
	socket.close(fd)
end

return sockethelper
