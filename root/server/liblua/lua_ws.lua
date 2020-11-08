local byte = string.byte
local char = string.char
local sub = string.sub
local concat = table.concat
local str_char = string.char
local type = type
local rand = math.random
-----for parser
local lpeg = require "lpeg"
local R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local Cf = lpeg.Cf
local sdp ={}
local l = {}
lpeg.locale(l)

local space_c = function(pat)
   local sp = P" "^0
   return sp * C(pat) *sp 
--   return l.space^0 * pat * l.space^0
end

local space_cg = function(pat,key)
   local sp = P" "^0
   return sp * Cg(C(pat),key) *sp 
--   return l.space^0 * pat * l.space^0
end

function sdp.space(pat) 
   local sp = P" "^0
   return sp * pat *sp 
end

local any = P(1)^1
local crlf = P"\r\n"
local tab =  P'\t'
local space = P' ' --l.space
local alpha = l.alpha
local alnum = l.alnum
local digit = l.digit
local safe = alnum + S'-./:?#$&*;=@[]^_{|}+~"' + P"'"  
local email_safe = safe + space + tab
local pos_digit = R"19"
local integer = pos_digit * digit^0
local decimal_uchar = C(
   P'1' * digit * digit
      +P'2' * R('04') * digit
      +P'2' * P'5' * R('05')
      +(pos_digit * digit)
      +digit 
)
local byte1 = P(1) - S("\0\r\n") 
local byte_string =  byte1^1--P"0x" * l.xdigit * l.xdigit
local text = safe^1
local b1 = decimal_uchar - P'0' -- -P'127'
local b4 = decimal_uchar - P'0'
local ip4_address = b1 * P'.' * decimal_uchar * P'.' * decimal_uchar * P'.' * b4 
local unicast_address = ip4_address
local fqdn1 = alnum + S("-.")
local fqdn = fqdn1 * fqdn1 * fqdn1 * fqdn1
local addr =  unicast_address  + fqdn
local addrtype = P"IP4" +P"IP6"
local nettype = P"IN"
local phone = P"+" * pos_digit * (P" " + P"-" + digit)^1
local phone_number = phone 
   + (phone + P"(" + email_safe + P")")
   + (email_safe * P"<" * phone * P">")

local username = safe^1
local bandwidth = digit^1
local bwtype = alnum^1
local fixed_len_timer_unit = S("dhms")
local typed_time = digit^1 * fixed_len_timer_unit^-1
local repeat_interval = typed_time
local time = pos_digit * digit^-9
local start_time = time + P"0"
local stop_time = time + P"0"
local ttl = decimal_uchar
local multicast_address = decimal_uchar * P"." * decimal_uchar * P"." * decimal_uchar * P"." * decimal_uchar * P"/" * ttl * (P"/" * integer)^-1
local connection_address = multicast_address + addr
local sess_version = digit^1
local sess_id = digit^1
local att_value = byte_string
local att_field = (safe - P":") ^1
local attribute =(att_field * P":" * att_value) 
   + att_field
local port = digit^1
local proto = (alnum + S"/")^1
local fmt = alnum^1
local media = alnum^1

local proto_version = P"v=" * Cg(digit^1/tonumber,"v") * crlf

local req_line = Cg(Ct(space_c(text)^1) * crlf,"line")   
local head_value = byte_string
local head_field = (safe - P":") ^1
local header = Cg(space_c(head_field) * P":" * space_c(head_value)) * crlf
local headers = Cg(Cf(Ct("") *header^1,rawset),"headers")
local req = Ct(req_line * headers)

local lua_app = require "lua_app"
local socket_driver = require "SocketDriver"
local buffer = require "Util"
local str_lower = string.lower
local char = string.char
local str_find = string.find
local crypto = require "crypt"
local url = require "lua_url"
local type = type
local setmetatable = setmetatable

local assert = assert
local api = {}

api.connectCenter = 0

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local types = {
    [0x0] = "continuation",
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}
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

local conns_connect = setmetatable(
	{},
	{__gc = function(p)
		for id,v in pairs(p) do
			socket_driver.close(id)
			p[id] = nil
		end
	end
	}
)
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




function receive_http(id)
	local str = api.readline(id,"\r\n\r\n")
	if not str then
	  print("not valid protocol!")
	  return nil , "not valid protocol"
	end
	local req = req:match(str.."\r\n\r\n")
	local headers = req.headers
	local val = headers.Upgrade or headers.upgrade
	if type(val) == "table" then
	  val = val[1]
	end
	if not val or str_lower(val) ~= "websocket" then
	  return nil, "bad \"upgrade\" request header"
	end
	local key = headers["Sec-WebSocket-Key"] or headers["sec-websocket-key"] 
	if type(key) == "table" then
	  key = key[1]
	end
	if not key then
	  return nil, "bad \"sec-websocket-key\" request header"
	end

	local ver = headers["Sec-WebSocket-Version"] or headers["sec-websocket-version"] 
	if type(ver) == "table" then
	  ver = ver[1]
	end
	if not ver or ver ~= "13" then
	  return nil, "bad \"sec-websock-version\" request header"
	end

	local protocols = headers["Sec-WebSocket-Protocol"] or headers["sec-websocket-protocol"]
	if type(protocols) == "table" then
	  protocols = protocols[1]
	end

	local ngx_header = {}
	if protocols then
	  ngx_header["Sec-WebSocket-Protocol"] = protocols
	end
	ngx_header["connection"] = "Upgrade"
	ngx_header["upgrade"] = "websocket"
	local sha1 = crypto.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11",true)
	ngx_header["sec-websocket-accept"] = crypto.base64encode(sha1)
	local status = 101
	local request_line = "HTTP/1.1 ".. status .." Switching Protocols"
	local rep ={}
	table.insert(rep,request_line)
	local k,v
	for k,v in pairs(ngx_header) do
	  local str = string.format('%s: %s',k,v)
	  table.insert(rep,str)
	end
	rep = table.concat(rep,"\r\n")
	rep = rep.."\r\n\r\n"

	local conn = conns[id]
    local dest = conn.channel
	local sock = conn.socket
	lua_app.raw_send(lua_app.self(),dest,sock,lua_app.MSG_CLIENT,rep,#rep)
	return true
end

function api.receive_frame(socketid)
    local data = api.read(socketid,2)
    if not data then
        return nil, nil, "failed to receive the first 2 bytes: " 
    end

    local fst, snd = byte(data, 1, 2)

    local fin = (fst & 0x80) ~= 0
    -- print("fin: ", fin)

    if (fst & 0x70) ~= 0 then
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = (fst & 0x0f)
    -- print("opcode: ", tohex(opcode))

    if opcode >= 0x3 and opcode <= 0x7 then
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        return nil, nil, "reserved control frames"
    end

    local mask = (snd & 0x80) ~= 0

    if not mask then
        return nil, nil, "frame unmasked"
    end

    local payload_len = (snd & 0x7f)
    -- print("payload len: ", payload_len)

    if payload_len == 126 then
        local data, err = api.read(socketid,2)
        if not data then
            return nil, nil, "failed to receive the 2 byte payload length: "
                             .. (err or "unknown")
        end

        payload_len = ((byte(data, 1) << 8) | byte(data, 2))

    elseif payload_len == 127 then
        local data, err = api.read(socketid,8)
        if not data then
            return nil, nil, "failed to receive the 8 byte payload length: "
                             .. (err or "unknown")
        end

        if byte(data, 1) ~= 0
           or byte(data, 2) ~= 0
           or byte(data, 3) ~= 0
           or byte(data, 4) ~= 0
        then
            return nil, nil, "payload len too large"
        end

        local fifth = byte(data, 5)
        if (fifth & 0x80) ~= 0 then
            return nil, nil, "payload len too large"
        end

        payload_len = ((fifth<<24) |
                          (byte(data, 6) << 16)|
                          (byte(data, 7)<< 8)|
                          byte(data, 8))
    end

    if (opcode & 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, nil, "too long payload for control frame"
        end

        if not fin then
            return nil, nil, "fragmented control frame"
        end
    end

    -- print("payload len: ", payload_len, ", max payload len: ",
          -- max_payload_len)

    if payload_len > 65535 then
        return nil, nil, "exceeding max payload len"
    end

    local rest
    if mask then
        rest = payload_len + 4

    else
        rest = payload_len
    end
    -- print("rest: ", rest)

    local data, err
    if rest > 0 then
        data, err = api.read(socketid,rest)
        if not data then
            return nil, nil, "failed to read masking-len and payload: "
                             .. (err or "unknown")
        end
    else
        data = ""
    end

    -- print("received rest")

    if opcode == 0x8 then
        -- being a close frame
        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte"
                                 .. " status code"
            end

            local msg, code
            if mask then
                local fst = (byte(data, 4 + 1) ~ byte(data, 1))
                local snd = (byte(data, 4 + 2) ~ byte(data, 2))
                code = ((fst << 8) | snd)

                if payload_len > 2 then
                    -- TODO string.buffer optimizations
                    local bytes = new_tab(payload_len - 2, 0)
                    for i = 3, payload_len do
                        bytes[i - 2] = str_char((byte(data, 4 + i) |
                                                     byte(data,
                                                          (i - 1) % 4 + 1)))
                    end
                    msg = concat(bytes)

                else
                    msg = ""
                end

            else
                local fst = byte(data, 1)
                local snd = byte(data, 2)
                code = ((fst << 8) | snd)

                -- print("parsing unmasked close frame payload: ", payload_len)

                if payload_len > 2 then
                    msg = sub(data, 3)

                else
                    msg = ""
                end
            end

            return msg, "close", code
        end

        return "", "close", nil
    end

    local msg
    if mask then
        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char((byte(data, 4 + i) ~
                                     byte(data, (i - 1) % 4 + 1)))
        end
        msg = concat(bytes)

    else
        msg = data
    end

    return msg, types[opcode], not fin and "again" or nil

end

function api.new(socketid,channelid)
	local conn = 
	{
		channel = channelid,
		socket = socketid,
		connected = true,
		moved = false,
		co = nil,
		buffer = socket_driver.buffer_new(),
		reading = nil,
	}
	conns[socketid] = conn
end

function api.transfer(socketid,channelid,handle)
	api.new(socketid,channelid)
	lua_app.send(channelid,lua_app.MSG_TEXT,"forward",socketid,lua_app.self())
	lua_app.send(channelid,lua_app.MSG_TEXT,"add",socketid)
	api.message_loop(channelid,socketid,handle)
end

function api.move(socketid)
	local conn = conns[socketid]

	if conn == nil then
		lua_app.log_info("socket:ddrop data from "..socketid)
		return
	end
	conn.moved = true
	wake(conn)
end

function api.accept(socketid,channelid,handle,...)
	api.new(socketid,channelid)
	lua_app.send(channelid,lua_app.MSG_TEXT,"forward",socketid,lua_app.self())
	lua_app.send(channelid,lua_app.MSG_TEXT,"add",socketid)

	local status = receive_http(socketid)

	if not status then
		print("http hand failed")
		return nil
	end
	
	if handle.open then
		lua_app.fork(handle.open,socketid,channelid,...)
	end
	api.message_loop(channelid,socketid,handle)
end

function api.message_loop(channelid,socketid,handle)
	lua_app.run_after(0,function()
		while true do
			local conn = conns[socketid]
			if not conn or not conn.connected then
				return 
			end
			local data ,typ,err = api.receive_frame(socketid)
			if not data then 
				if conn.moved then
					conn.buffer = nil
					return
				end
				if handle.disconnect then
					handle["disconnect"](socketid)
				end
				api.clear(socketid)
				return
			end
			local f = handle[typ]
			if  f then			
				lua_app.fork(function()
					f(socketid,data)
				end)
			else
				print("no handle msg",data,typ,err)
				return
			end
		end
   end)
end

function api.message(socket,data,size)

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

local function send_http(conn,host,port,path)
    local proto_header, sock_opts
    if opts then
       local protos = opts.protocols
        if protos then
			if type(protos) == "table" then
			  proto_header = "Sec-WebSocket-Protocol: ".. concat(protos, ",") .. "\r\n"
			else
			   proto_header = "Sec-WebSocket-Protocol: " .. protos .. "\r\n"
			end
        end

        local pool = opts.pool
        if pool then
            sock_opts = { pool = pool }
        end
    end

    if not proto_header then
       proto_header = ""
    end

    local bytes = char(rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1)

    local key = crypto.base64encode(bytes)
    local req = "GET " .. path .. " HTTP/1.1\r\nUpgrade: websocket\r\nHost: "
                .. host .. ":" .. port
                .. "\r\nSec-WebSocket-Key: " .. key
                .. proto_header
                .. "\r\nSec-WebSocket-Version: 13"
                .. "\r\nConnection: Upgrade\r\n\r\n"

	local dest = conn.channel
	local sock = conn.socket
	lua_app.raw_send(lua_app.self(),dest,sock,lua_app.MSG_CLIENT,req,#req)
    local header_reader = api.readline(sock,"\r\n\r\n")
	return true
end

function api.connect(addr,index,handle)
    local parsed = url.parse(addr)    
    local host = parsed.host
    local port = parsed.port
    local path = parsed.path
    if not port then
        port = 80
    end
    if type(port) == "string" then
       port = tonumber(port)
    end
    if path == "" then
        path = "/"
    end

	if api.connectCenter == 0 then
		local id = lua_app.new_process("Connecter","WebSocket",lua_app.MSG_CLIENT)
		lua_app.send(id,lua_app.MSG_TEXT,"group",10)
		lua_app.send(id,lua_app.MSG_TEXT,"watch",lua_app.self())
		api.connectCenter = id
	end
	local conn = 
	{
		channel = 0,
		socket = 0,
		connected = false,
		co = nil,
		buffer = socket_driver.buffer_new(),
		reading = nil,
	}
	conns_connect[index] = conn
	lua_app.send(api.connectCenter,lua_app.MSG_TEXT,"connect",host..":"..port,index,0)
	wait(conn)
	conns_connect[index] = nil
	conns[conn.socket] = conn
	local channel = conn.channel
	local socketid = conn.socket
	lua_app.send(channel,lua_app.MSG_TEXT,"forward",socketid,lua_app.self())
	lua_app.send(channel,lua_app.MSG_TEXT,"add",socketid)
	local status = send_http(conn,host,port,path)

	if not status then
		print("http hand failed")
		return nil
	end

	if handle.open then
		lua_app.fork(handle.open,socketid,channelid)
	end
	api.message_loop(channelid,socketid,handle)
end


function api.connected(tag,channelId,socketId)
	local conn = conns_connect[tag]
	if conn == nil then
		return
	end
	conn.connected = true
	conn.socket = socketId
	conn.channel = channelId
	wake(conn)
end

function api.readall(id)

	local conn = conns[id]

	assert(conn)

	if conn.connected == false or conn.moved then

		return false

	end

	local total_size = socket_driver.buffer_size(conn.buffer)

	if total_size > 0 then
		local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)
		return true,data,size
	end

	wait(conn)

	if conn.connected == false or conn.moved then

		return false

	end

	local total_size = socket_driver.buffer_size(conn.buffer)

	local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)
	
	return true,data,size

end

function  api.read(id,size)
	local conn = conns[id]
	assert(conn)
	if conn.connected == false or conn.moved then
		return 
	end

	if size == nil then
		local total_size = socket_driver.buffer_size(conn.buffer)
		local data,size = socket_driver.buffer_fetch(conn.buffer,total_size)
		if size ~= 0 then
			return lua_app.tostring(data,size)
		end

		if not conn.connected or conn.moved then
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
		if conn.connected == false or conn.moved then
			return 
		end
		local data,size = socket_driver.buffer_fetch(conn.buffer,size)
		return lua_app.tostring(data,size)
	else
		local data,size = socket_driver.buffer_fetch(conn.buffer,size)
		return lua_app.tostring(data,size)
	end
end

function api.readline(id,sep)
	
	sep = sep or "\n"

	local conn = conns[id]

	assert(conn,string.format("%d not exist",id))

	if conn.connected == false or conn.moved then
		return 
	end

	local size = socket_driver.buffer_find(conn.buffer,sep)

	if size == 0 then
		conn.reading = sep
		wait(conn)
	else
		conn.reading = size
	end

	if conn.connected == false or conn.moved then

		return 

	end

	local read_size = conn.reading

	local data = socket_driver.buffer_fetch(conn.buffer,read_size)

	local str = lua_app.tostring(data,read_size - #sep)

	return str
end

function api.clear(id)
	local conn = conns[id]
	if conn == nil then
		return
	end
	conn.connected = false
	conn.buffer = nil
	conns[id] = nil
end

function api.close(id)
	local conn = conns[id]
	if conn == nil then
		return
	end
	if conn.connected == true then
		local data = api.pack_close()
		lua_app.raw_send(lua_app.self(),conn.channel,conn.socket,lua_app.MSG_CLIENT,data,#data)
		lua_app.send(conn.channel,lua_app.MSG_TEXT,"close",conn.socket)
		conn.connected = false
		wake(conn)
	end
	conn.buffer = nil
	conns[id] = nil
end

function api.closed(id)
	local conn = conns[id]
	if conn == nil then
		return
	end
	conn.connected = false
	wake(conn)
end

local function build(fin, opcode, payload_len, payload, masking)
    local fst
    if fin then
        fst = (0x80 | opcode)
    else
        fst = opcode
    end

    local snd, extra_len_bytes
    if payload_len <= 125 then
        snd = payload_len
        extra_len_bytes = ""

    elseif payload_len <= 65535 then
        snd = 126
        extra_len_bytes = char(((payload_len >> 8) & 0xff),
	   (payload_len & 0xff))

    else
        if (payload_len & 0x7fffffff) < payload_len then
            return nil, "payload too big"
        end

        snd = 127
        -- XXX we only support 31-bit length here
        extra_len_bytes = char(0, 0, 0, 0, ((payload_len >> 24) & 0xff),
                               ((payload_len >> 16) & 0xff),
                               ((payload_len >> 8)& 0xff),
                               (payload_len & 0xff))
    end

    local masking_key
    if masking then
        -- set the mask bit
        snd = (snd | 0x80)
        local key = rand(0xffffffff)
        masking_key = char(((key >> 24) & 0xff),
	   ((key >> 16) & 0xff),
	   ((key >> 8) & 0xff),
	   (key & 0xff))

        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char((byte(payload, i) ~
                                     byte(masking_key, (i - 1) % 4 + 1)))
        end
        payload = concat(bytes)

    else
        masking_key = ""
    end
    return char(fst, snd) .. extra_len_bytes .. masking_key .. payload
end


local function pack(fin, opcode, payload,masking)

    if not payload then
        payload = ""

    elseif type(payload) ~= "string" then
        payload = tostring(payload)
    end

    local payload_len = #payload

    if payload_len > 1048560 then
        return nil, "payload too big"
    end

    if (opcode & 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, "too much payload for control frame"
        end
        if not fin then
            return nil, "fragmented control frame"
        end
    end

    local frame, err = build(fin, opcode, payload_len, payload,
                                   masking)
    if not frame then
        return nil, "failed to build frame: " .. err
    end
	return frame
end

function api.pack_text(data)
    return pack(true, 0x1, data)
end


function api.pack_binary(data)
    return pack(true, 0x2, data)
end


function api.pack_close(code, msg)
    local payload
    if code then
        if type(code) ~= "number" or code > 0x7fff then
        end
        payload = char(((code>> 8) & 0xff), (code & 0xff))
                        .. (msg or "")
    end
    return pack(true, 0x8, payload)
end

function api.pack_ping(data)
    return pack(true, 0x9, data)
end


function api.pack_pong(data)
    return pack(true, 0xa, data)
end

function api.show()

end

return api
