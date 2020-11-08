local ws = require "lua_ws"
local server = require "server"
local lua_app = require "lua_app"

local _lprint
local _listenmsg
local _listenplayer
local function _print(...)
	print(server.wholename .. os.date("[%X]"), ...)
end
local _printfunc = _print
-- local _printfunc = lua_app.log_info

local _printread = 1
local _printwrite = 2
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
	-- [_printread]		= "---- recvReq",
	[_printwrite]		= "++++ sendReq",
}
local function _ListenPrint(printtype, id, name, args)
	if _IsListenMsg(name) then
		local player = server.playerCenter:GetPlayerBySocket(id)
		local account = player and player.cache.account() or ""
		if _IsListenPlayer(account) then
			_printfunc(_printpre[printtype], id, name, account)
			-- table.ptable(args, 6, nil, _printfunc)
		end
	end
end
local function _InitPrint()
	_lprint, _listenmsg, _listenplayer = server.serverCenter:CallLocal("logic", "GetClientMsgPrintType")
end
-- 发送
local session = 0
function server.sendToClient(protocol, socket, name, param)
	if not protocol or protocol == 0 or not socket or socket == 0 then
		return
	end
	session = session + 1
	local data = server.protoSender(name, param, session)
	local msg = ws.pack_binary(data)
	if _lprint ~= false then
		if _lprint == nil then
			_InitPrint()
		end
		if _lprint and _lprint & _printwrite ~= 0 then
			_ListenPrint(_printwrite, socket, name, param)
		end
	end
	lua_app.raw_send(lua_app.self(), protocol, socket, lua_app.MSG_CLIENT, msg, #msg)
end

function server.sendToPlayer(player, name, param)
	if not player then return end
	server.sendToClient(rawget(player, "protocol"), rawget(player, "socket"), name, param)
end


if not server.protoSender then
	server.protoSender = true
	require "modules.Event"
	local clientDriver = require "ControlerDriver"
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
	server.regfunc(server.event.init, _InitPrint)
	server.regfunc(server.event.main, _RegSprotoSender)
end
