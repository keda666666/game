local lua_app = require "lua_app"
local socket = require "http.sockethelper"
local url = require "http.url"
local internal = require "http.internal"
local dns = require "tmpdnsdriver"
local string = string
local table = table

local httpc = {}

local function request(fd, method, host, url, recvheader, header, content)
	local read = socket.readfunc(fd)
	local write = socket.writefunc(fd)
	local header_content = ""
	if header then
		if not header.host then
			header.host = host
		end
		for k,v in pairs(header) do
			header_content = string.format("%s%s:%s\r\n", header_content, k, v)
		end
	else
		header_content = string.format("host:%s\r\n",host)
	end
	if content and #content > 0 then
		local data = string.format("%s %s HTTP/1.1\r\n%scontent-length:%d\r\n\r\n", method, url, header_content, #content)
		write(data)
		write(content)
	else
		local request_header = string.format("%s %s HTTP/1.1\r\n%scontent-length:0\r\n\r\n", method, url, header_content)
		write(request_header)
	end

	local tmpline = {}
	local body = internal.recvheader(read, tmpline, "")
	if not body then
		error(socket.socket_error)
	end
	local statusline = tmpline[1]

	local code, info = statusline:match "HTTP/[%d%.]+%s+([%d]+)%s+(.*)$"

	code = assert(tonumber(code))

	local header = internal.parseheader(tmpline,2,recvheader or {})
	if not header then
		error("Invalid HTTP response header")
	end

	local length = header["content-length"]
	if length then
		length = tonumber(length)
	end
	local mode = header["transfer-encoding"]
	if mode then
		if mode ~= "identity" and mode ~= "chunked" then
			error ("Unsupport transfer-encoding")
		end
	end
	
	if mode == "chunked" then
		body, header = internal.recvchunkedbody(read, nil, header, body)
		if not body then
			error("Invalid response body")
		end
	else
		-- identity mode
		if length then
			if #body >= length then
				body = body:sub(1,length)
			else
				local data = read(length - #body)
				if data then
					body = body..data
				end
			end
		else
			-- no content-length, read all
			local status,data,size = socket.readall(fd)
			if status == true then
				body = body .. lua_app.tostring(data,size)
			end
		end
	end

	return code, body
end

local async_dns
local dns_cache = {}
local function dns_resolve(hostname)
	if dns_cache[hostname] then return dns_cache[hostname] end
	local ret, ips = dns.resolve(hostname)
	if ret then dns_cache[hostname] = ips end
	return dns_cache[hostname]
end

function httpc.dns_resolve(host)
	local hostname = host:match"([^:]+):?(%d*)$"
	return dns_resolve(hostname)
end

httpc.timeout = 5000
function httpc.request(method, host, url, recvheader, header, content)
	local timeout = httpc.timeout	-- get httpc.timeout before any blocked api
	local hostname, port = host:match"([^:]+):?(%d*)$"
	if port == "" then
		port = 80
	else
		port = tonumber(port)
	end
	local ip = dns_resolve(hostname)[1]
	if not ip then
		return -1, "Invalid hostname:" .. hostname
	end
	local fd = socket.connect(ip, port, timeout)
	if not fd then return end
	socket.start(fd)
	local finish
	if timeout then
		lua_app.run_after(timeout, function()
			if not finish then
				finish = true
				socket.close(fd)
			end
		end)
	end
	local ok , statuscode, body = pcall(request, fd,method, host, url, recvheader, header, content)
	if not finish then
		finish = true
		socket.close(fd)
	end
	if ok then
		return statuscode, body
	else
		return statuscode
	end
end

function httpc.get(...)
	return httpc.request("GET", ...)
end

local function escape(s)
	return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function httpc.post(host, url, form, recvheader)
	local header = {
		["content-type"] = "application/x-www-form-urlencoded"
	}
	local body = {}
	for k,v in pairs(form) do
		table.insert(body, string.format("%s=%s",escape(k),escape(v)))
	end

	return httpc.request("POST", host, url, recvheader, header, table.concat(body , "&"))
end

return httpc
