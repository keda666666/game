--------- 这个是不是该去player
local lua_app = require "lua_app"
local server = require "server"

function server.LogoutBySocket(socket)
	server.playerCenter:PlayerLogout(socket)
end

function server.GetPlayerBaseValue(account)
	return server.mysqlCenter:query("players", { account = account }, { dbid=true, serverid=true, name=true })
end

function server.PlayerEnterGame(socket, protocol, dbid, logininfo)
	local player = server.playerCenter:GetPlayerBySocket(socket)
	if player then
		return 6
	end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player and player.socket then
		local oldSock = player.socket
		server.sendErr(player, "您的账号已在别处登录")
		server.sendReq(player, "sc_base_replace_account")
		server.CloseSocket(oldSock)
		server.playerCenter:PlayerUpdate(player, socket, protocol, logininfo)
		return 0
	end
	return server.playerCenter:PlayerLogin(socket, protocol, dbid, logininfo)
end

function server.GameCreatePlayer(socket, msg, logininfo)
	if msg.job ~= 1 and msg.job ~= 2 and msg.job ~= 3 or msg.sex ~= 0 and msg.sex ~= 1 then
		return { result = 4, actorid = 0, }
	end
	local result = server.CheckPlayerName(msg.actorname)
	if result ~= 0 then
		return { result = result, actorid = 0, }
	end
	local player = server.playerCenter:CreatePlayer(msg, logininfo)
	server.UnLockPlayerName(msg.actorname)
	server.UnLockPlatformName(msg.actorname)
	if not player then
		return { result = 3, actorid = 0, }
	end
	if server.environment == "" then
		local httppindex = tonumber(string.match(logininfo.lid or "", "^(.-)_")) or 1
		server.serverCenter:SendOneMod("httpp", httppindex, "loginCenter", "PlayerCreateActor", player.cache.serverid, player.account,
			player.cache.name, player.cache.job, player.cache.sex)
	end
	return {
		result = 0,
		actorid = player.dbid,
	}, {
		dbid = player.dbid,
		serverid = player.cache.serverid,
	}
end
