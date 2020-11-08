local server = require "server"
local lua_app = require "lua_app"

local LoginerMgr = {}

function LoginerMgr:Init()
	self.loginingList = {}
	self.loginerList = {}

	self.logintokens = {}
	self.accountToToken = {}
end

function LoginerMgr:CreateLoginer(socket, protocol, ip)
	local loginer = {}
	loginer.protocol = protocol
	loginer.socket = socket
	loginer.ip = ip
	self:AddLoginer(loginer)
end

function LoginerMgr:GetInfo(socket)
	local loginer = self.loginerList[socket]
	if not loginer then
		lua_app.log_error("LoginerMgr:GetInfo no loginer", socket)
		return
	end
	return {
		account = loginer.account,
		gm_level = loginer.gm_level,
		ip = loginer.ip,
		uid = loginer.uid,
		channelId = loginer.channelId,
		lid = loginer.lid,
	}
end

function LoginerMgr:GetLogining(name)
	local loginer = self.loginingList[name]
	if not loginer or loginer.logintime < lua_app.now() + 60 then
		return loginer
	end
end

function LoginerMgr:AddLogining(name, loginer)
	loginer.logintime = lua_app.now()
	self.loginingList[name] = loginer
end

function LoginerMgr:DelLogining(name)
	self.loginingList[name] = nil
end

function LoginerMgr:AddLoginer(loginer)
	self.loginerList[loginer.socket] = loginer
end

function LoginerMgr:DelLoginer(socket, notaccount)
	local loginer = self.loginerList[socket]
	if loginer then
		self.loginerList[socket] = nil
		if not notaccount and loginer.account then
			if loginer == self.loginingList[loginer.account] then
				self.loginingList[loginer.account] = nil
			end
		end
	end
end

function LoginerMgr:GetLoginer(socket)
	return self.loginerList[socket]
end

function LoginerMgr:GetLoginerByToken(token)
	local loginer = self.logintokens[token]
	if loginer then
		local nowtime = lua_app.now()
		if loginer.tokenlock and loginer.tokenlock + 10 > nowtime then
			return -1
		end
		loginer.tokenlock = nowtime
	end
	return loginer
end

function LoginerMgr:SetToken(socket, token)
	local loginer = self.loginerList[socket]
	if loginer then
		loginer.tokenlock = nil
		loginer.token = token
		if self.accountToToken[loginer.account] then
			self.logintokens[self.accountToToken[loginer.account]] = nil
		end
		self.logintokens[token] = loginer
		self.accountToToken[loginer.account] = token
	end
end

server.SetCenter(LoginerMgr, "loginerCenter")
return LoginerMgr
