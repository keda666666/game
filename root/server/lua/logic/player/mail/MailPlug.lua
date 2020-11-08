local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Mail = require "player.mail.Mail"
local tbname = "mails"

local MailPlug = oo.class()

local readType = {
	Unread = 0,
	readed = 1,
}
local receiveType = {
	Unreceive = 0,
	received = 1,
}

function MailPlug:ctor(player)
	self.player = player
	self.mails = {}
end

function MailPlug:onLoad()
	local caches = server.mysqlBlob:LoadDmg(tbname, { playerid = self.player.dbid })
	for _, cache in ipairs(caches) do
		local mail = Mail.new()
		mail:Init(cache)
		self.mails[mail.dbid] = mail
	end
end

function MailPlug:onRelease()
	for _, mail in pairs(self.mails) do
		mail:Release()
	end
end

function MailPlug:AddMail(maildata)
	local mail = Mail.new()
	mail:Create(maildata)
	self.mails[mail.dbid] = mail
	return mail
end

function MailPlug:ReadMail(handle)
	local mail = self.mails[handle]
	mail.cache.readstatus = readType.readed
	server.sendReq(self.player, "sc_mail_detailed_info", mail:DetailData())
end

function MailPlug:GetMailsAward(handles)
	local datas = {}
	local showWarnBagSpace = false
	for _, handle in pairs(handles) do
		local mail = self.mails[handle]
		if mail.cache.awardstatus ~= receiveType.received then
			mail.cache.awardstatus = receiveType.received
			local award = mail.cache.award
			if self.player:GiveRewardIfCan(award, nil, mail.cache.log_type, mail.cache.log) then
				mail.cache.readstatus = readType.readed
				table.insert(datas, {
						handle = handle,
						type = readType.readed,
						receive = receiveType.received,
					})
			else
				mail.cache.awardstatus = receiveType.Unreceive
				showWarnBagSpace = true
				break
			end
		end
	end
	server.sendReq(self.player, "sc_mail_update_info", { updateData = datas, showWarnBagSpace = showWarnBagSpace })
end

function MailPlug:DelMail(handle)
	self.mails[handle]:Del()
	self.mails[handle] = nil
	server.sendReq(self.player, "sc_mail_delete", { handle = handle })
end

local function _CheckDelMails(self)
	local mails = {}
	local cleanTime = lua_app.now() - server.mailCenter.MailKeepTime
	local cleanMails = {}
	for dbid, mail in pairs(self.mails) do
		if mail.cache.sendtime <= cleanTime then
			cleanMails[dbid] = mail
		else
			table.insert(mails, mail)
		end
	end
	local function _DeleteMail(mail)
		-- server.sendReq(self.player,"sc_mail_delete", { handle = mail.dbid })
		self.mails[mail.dbid] = nil
		mail:Del()
	end
	for _, mail in pairs(cleanMails) do
		_DeleteMail(mail)
	end
	if #mails >= 100 then
		table.sort(mails, function(a, b)
				return a.cache.sendtime > b.cache.sendtime
			end)
		for i = 100, #mails do
			_DeleteMail(mails[i])
		end
	end
end

function MailPlug:onBeforeLogin()
	server.mailCenter:GetNewGlobalMails(self.player)
	_CheckDelMails(self)
end

function MailPlug:onInitClient()
	local datas = {}
	for _, mail in pairs(self.mails) do
		table.insert(datas, mail:GetMsgData())
	end
	server.sendReq(self.player, "sc_mail_init_info", { mailData = datas })
end

server.playerCenter:SetEvent(MailPlug, "mail")
return MailPlug
