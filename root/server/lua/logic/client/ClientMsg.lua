local ws = require "lua_ws"
local server = require "server"
local lua_app = require "lua_app"
local clientDriver = require "ControlerDriver"

local _lprint = false		-- 完全关闭(false) 无打印(0) 第一位表示打印接收(1) 第二位表示打印发送(2) 两位表示全打印(3)
local _listenmsg = {
	false,					-- false 排除消息 true 包含消息
	-- "sc_bag_deal_add_item",
	-- "sc_bag_deal_delete_item",
	-- "exp_change",
	-- "gold_change",
}
local _listenplayer = {
	false,					-- false 排除玩家 true 包含玩家
	-- "wdjfgg",
}

local function _print(first, ...)
	print(server.wholename .. os.date("[%X]") .. (first or ""), ...)
end
local _printfunc = _print
-- local _printfunc = lua_app.log_info

local _printread = 1
local _printwrite = 2
function server.GetClientMsgPrintType()
	lua_app.ret(_lprint, _listenmsg, _listenplayer)
end
local __listenmsg = false
local function _IsListenMsg(name)
	if __listenmsg then return (not _listenmsg[1]) == (not __listenmsg[name]) end
	__listenmsg = {}
	for i = 2, #_listenmsg do
		__listenmsg[_listenmsg[i]] = true
	end
	return (not _listenmsg[1]) == (not __listenmsg[name])
end
local __listenplayer = false
local function _IsListenPlayer(name)
	if __listenplayer then return (not _listenplayer[1]) == (not __listenplayer[name]) end
	__listenplayer = {}
	for i = 2, #_listenplayer do
		if _listenplayer[i] ~= "" then
			__listenplayer[_listenplayer[i]] = true
		end
	end
	return (not _listenplayer[1]) == (not __listenplayer[name])
end
local _printpre = {
	[_printread]		= "---- recvReq",
	[_printwrite]		= "++++ sendReq",
}
local function _ListenPrint(printtype, id, name, args)
	if _IsListenMsg(name) then
		local loginer = server.loginerCenter:GetLoginer(id)
		if _IsListenPlayer(loginer.account) then
			_printfunc(_printpre[printtype], id, name, loginer.account)
			-- table.ptable(args, 6, nil, _printfunc)
		end
	end
end
-- 发送
function server.SendClient(loginer, msg)
	if not loginer or loginer.protocol == 0 or not loginer.socket or loginer.socket == 0 then
		return
	end
	lua_app.raw_send(lua_app.self(), loginer.protocol, loginer.socket, lua_app.MSG_CLIENT, msg, #msg)
end

local session = 0
function server.sendToClient(protocol, socket, name, param)
	if not protocol or protocol == 0 or not socket or socket == 0 then
		return
	end
	session = session + 1
	local data = server.protoSender(name, param, session)
	local msg = ws.pack_binary(data)
	if _lprint and _lprint & _printwrite ~= 0 then
		_ListenPrint(_printwrite, socket, name, param)
	end
	lua_app.raw_send(lua_app.self(), protocol, socket, lua_app.MSG_CLIENT, msg, #msg)
end

-- 接收
local handler = {}

-- function handler.text(id, data)
-- 	local txt = ws.pack_text(data)
-- 	local loginer = server.loginerCenter:GetLoginer(id)
-- 	server.SendClient(loginer, txt)
-- end

function handler.binary(id, msg)
	local startTime = lua_app.now_ms()
	local size = #msg
	local msgtype, name, args, response = server.protoHoster:dispatch(msg, size)
	if msgtype == "REQUEST" then
		if server[name] == nil then
			if name ~= "cs_send_heart_beat" then
				lua_app.log_error("logic func name not exist:", name)
			end
			return
		end
		if _lprint and _lprint & _printread ~= 0 then
			_ListenPrint(_printread, id, name, args)
		end
		local startMem = collectgarbage("count")
		local r = server[name](id, args)
		local overMem = collectgarbage("count")
		if overMem - startMem > 100 then
			lua_app.log_info("Cost Mem Too Large", name, overMem - startMem)
		end
		if response and r then
			local res = response(r)
			local loginer = server.loginerCenter:GetLoginer(id)
			server.SendClient(loginer, ws.pack_binary(res))
		end
	elseif msgtype == "RESPONSE" then
		print("error, server not support response")
	end
	local overTime = lua_app.now_ms()
	if overTime - startTime > 10000 then
		lua_app.log_error("Cost Time Too Long", name, overTime - startTime)
	end
end

function handler.open(socket, channel, _, ip)
	server.loginerCenter:CreateLoginer(socket, channel, ip)
end

function handler.close(socket, data)
	ws.close(socket)
	server.loginerCenter:DelLoginer(socket)
	server.LogoutBySocket(socket)
end

function handler.disconnect(id)

end

server[clientDriver.CONTROLER_RESULT_ACCEPT] = function(socket, protocol, ...)
	ws.accept(socket, protocol, handler, ...)
end

server[clientDriver.CONTROLER_RESULT_CONNECT] = function()
	ws.connected()
end

server[clientDriver.CONTROLER_RESULT_DATA] = function(socket, protocol, data, size)
	ws.message(socket, data, size)
end

server[clientDriver.CONTROLER_RESULT_CLOSE] = function(socket, protocol, ...)
	ws.closed(socket)
	server.loginerCenter:DelLoginer(socket)
	server.LogoutBySocket(socket, protocol)
end

function server.CloseSocket(socket)
	server.loginerCenter:DelLoginer(socket)
	ws.close(socket)
end

-- 启动
function server.OpenClient(addr)
	server.clientCenter = lua_app.new_process("Acceptor", addr, 10000, "WebSocket", lua_app.MSG_CLIENT, 0, 0)
	lua_app.send(server.clientCenter, lua_app.MSG_TEXT, "group", 10)
	lua_app.send(server.clientCenter, lua_app.MSG_TEXT, "watch", lua_app.self())
	lua_app.send(server.clientCenter, lua_app.MSG_TEXT, "start")
end
-- 关闭
function server.CloseClient()
	if server.clientCenter and server.clientCenter ~= 0 then
		lua_app.send(server.clientCenter, lua_app.MSG_TEXT, "stop")
	end
	lua_app.log_info("server.CloseClient KickOffAll start")
	server.playerCenter:KickOffAll()
	lua_app.log_info("server.CloseClient KickOffAll end")
end

-- 断线重连
function server.reconnection(source, socket, protocol, msg)

end

if not server.protoSender then
	server.protoSender = true
	require "modules.Event"
	lua_app.regist_protocol
	{
		name = "client",
		id = lua_app.MSG_CLIENT,
		pack = function(...)
			return ...
		end,
		unpack = clientDriver.unpack,
		dispatch = function(source,session,type,socket,protocol,...)
			server[type](socket,protocol,...)
		end
	}
	local function _RegSprotoSender()
		local sprotoloader = require "sproto.sprotoloader"
		local host = sprotoloader.load(1):host("package")
		local send = host:attach(sprotoloader.load(2))
		server.protoSender = nil
		server.protoSender = send
		server.protoHoster = host
	end
	server.regfunc(server.event.main, _RegSprotoSender)
end

return handler