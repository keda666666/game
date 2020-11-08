local server = require "server"
local lua_app = require "lua_app"

function server.checkAccount(id, msg)
	local token = msg.token
	if server.environment ~= "" then
		msg.serverid = server.serverid
		msg.lid = ""
	end
	local serverid = msg.serverid
	local loginer = server.loginerCenter:GetLoginer(id)
	assert(loginer)
	if not serverid then
		-- server.sendLoginer(loginer,"checkAccountRet", { result = 4 })
		return { result = 4 }
	end
	local oldLoginer = server.loginerCenter:GetLoginerByToken(token .. "," .. serverid .. "," .. (msg.lid or ""))
	if oldLoginer == -1 then
		lua_app.log_info("server.checkAccount:: relogin token", token, serverid)
		return { result = 6 }
	end
	local loginResult, uid, account, channelId, gm_level, ip
	if oldLoginer then
		loginResult = true
		account = oldLoginer.account
		gm_level = oldLoginer.gm_level
		-- ip = oldLoginer.ip
		uid = oldLoginer.uid
		channelId = oldLoginer.channelId
	else
		if server.environment ~= "" then
			account = token
			loginResult = (account and account ~= "" or false)
			if server.environment == "debug" then
				gm_level = 0
			else
				gm_level = 0
			end
			uid = loginResult and token or 2
			channelId = server.environment
		else		-- 平台验证
			local httppindex = tonumber(string.match(msg.lid or "", "^(.-)_")) or 1
			local logininfo, error_code = server.serverCenter:CallOneMod("httpp", httppindex, "loginCenter", "PlayerLogin", token, serverid, msg.lid)
			if not logininfo then
				loginResult, uid = false, error_code
			elseif not logininfo.username then
				loginResult, uid = false, 2
			else
				loginResult, uid, account, channelId, gm_level, ip = true, logininfo.uid, logininfo.username,
					logininfo.channelId, logininfo.gm_level, logininfo.ip
			end
		end
	end
	if not loginResult then
		-- server.sendLoginer(loginer, "checkAccountRet", { result = uid })
		return { result = uid }
	end
	local loginning = server.loginerCenter:GetLogining(account)
	if loginning then
		if loginning == loginer then
			lua_app.log_info("account:", account, "is loginning")
			return { result = 5 }
		else
			server.CloseSocket(loginning.socket)
		end
	end
	loginer.account = account
	loginer.serverid = serverid
	loginer.gm_level = gm_level
	loginer.ip = ip or loginer.ip
	loginer.uid = uid
	loginer.channelId = channelId
	loginer.lid = msg.lid
	server.loginerCenter:AddLogining(account, loginer)
	server.loginerCenter:SetToken(loginer.socket, token .. "," .. serverid .. "," .. (msg.lid or ""))
	-- if isRegist then
	-- 	server.recordServer:Call("PlayerRegist", account, uid, channelId, loginer.ip)
	-- end
	-- local exist, oldSock = server.checkAcountOK(id, loginer.protocol, account, msg.serverid)
	-- if exist then
	-- 	lua_ws.close(oldSock)
	-- 	server.loginerCenter:DelLoginer(oldSock, true)
	-- end
	-- server.sendLoginer(loginer, "checkAccountRet", { result = 0 })
	return { result = 0 }
end

function server.QueryList(id, msg)
	local loginer = server.loginerCenter:GetLoginer(id)
	if loginer then
		local value = loginer.datalist
		if not value then
			value = server.GetPlayerBaseValue(loginer.account)
			loginer.datalist = value
		end
		if #value > 1 then
			for _, v in ipairs(value) do
				if v.serverid == loginer.serverid then
					return {
						code = true,
						actorid = v.dbid,
					}
				end
			end
			return {
				code = false,
				actorid = -1,
				actorlist = value,
			}
		end
		local actorid = 0
		if value[1] then
			actorid = value[1].dbid
		end
		if actorid == 0 then
			lua_app.log_info(">>> new player regist", loginer.account, loginer.uid, loginer.channelId, loginer.ip)
			server.serverCenter:SendDtbMod("httpr", "playerCenter", "PlayerRegist", server.serverid, loginer.account,
				loginer.uid, loginer.channelId, loginer.ip)
		end
		return {
			code = (actorid ~= 0),
			actorid = actorid,
		}
	else
		return { code = false, actorid = 0, }
	end
end

function server.EnterGame(id, msg)
	local tb = { result = 0 }
	local loginer = server.loginerCenter:GetLoginer(id)
	if not loginer or not loginer.datalist then
		tb.result = 1
		return tb
	end
	server.loginerCenter:DelLogining(loginer.account)
	if msg.actorid == 0 then
		tb.result = 3
		return tb
	end
	local data = false
	for _, v in ipairs(loginer.datalist) do
		if v.dbid == msg.actorid then
			data = v
			break
		end
	end
	if not data then
		tb.result = 2
		return tb
	end
	if loginer.entergamelock and loginer.entergamelock + 20 < lua_app.now() then
		tb.result = 5
		return tb
	end
	loginer.entergamelock = lua_app.now()
	tb.result = server.PlayerEnterGame(id, loginer.protocol, msg.actorid, server.loginerCenter:GetInfo(id))
	loginer.entergamelock = nil
	if tb.result == 4 then
		tb.QQ = server.serverCenter:CallNextMod("mainrecord", "recordCenter", "GetQQ")
	end
	return tb
end

function server.CreateActor(id, msg)
	local loginer = server.loginerCenter:GetLoginer(id)
	if not loginer then
		return { result = 1, actorid = 0, }
	end
	if not loginer.datalist or next(loginer.datalist) then
		return { result = 2, actorid = 0, }
	end
	if loginer.createlock then
		return { result = 3, actorid = 0, }
	end
	loginer.createlock = true
	local ret, info = server.GameCreatePlayer(id, msg, server.loginerCenter:GetInfo(id))
	loginer.createlock = false
	if info then
		table.insert(loginer.datalist, info)
	end
	return ret
end
