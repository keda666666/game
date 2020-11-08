local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Mail = require "player.mail.Mail"
local tbname = "global_mails"
local mailname = "mails"

local MailCenter = {}

MailCenter.MailKeepTime = 15 * 24 * 3600

function MailCenter:Init()
	self.mails = {}
	local caches = server.mysqlBlob:LoadDmg(tbname)
	local cleanTime = lua_app.now() - self.MailKeepTime
	for _, cache in ipairs(caches) do
		if cache.sendtime > cleanTime then
			self.mails[cache.dbid] = cache
		else
			server.mysqlBlob:DelDmg(tbname, cache)
		end
	end
end

function MailCenter:Release()
	for _, cache in pairs(self.mails) do
		cache(true)
	end
	self.mails = {}
end

local function _NewMail(playerid, head, context, award, type, log, sendtime)
	local data = {
		playerid = playerid,
		sendtime = sendtime or lua_app.now(),
		head = head,
		context = context,
		award = award or {},
		readstatus = 0,		-- 0 未读 1 已读
	}
	if award and next(award) then
		data.awardstatus = 0	-- 0 未领取 1 领取
		data.log_type = type or 0
		data.log = log
	else
		data.awardstatus = 1
	end
	return data
end

function MailCenter:SendMail(playerid, head, context, award, type, log, sendtime)
	local maildata = _NewMail(playerid, head, context, award, type, log, sendtime)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if player then
		local mail = player.mail:AddMail(maildata)
		server.sendReq(player, "sc_mail_add_info", { mailData = mail:GetMsgData() })
	else
		-- 没有缓存直接插入数据库
		lua_app.waitlockrun(playerid, function()
				local player = server.playerCenter:GetPlayerByDBID(playerid)
				if player then
					local mail = player.mail:AddMail(maildata)
					server.sendReq(player, "sc_mail_add_info", { mailData = mail:GetMsgData() })
				else
					maildata.dbid = server.mysqlBlob:GetUID(mailname)
					server.mysqlCenter:insert_s(mailname, maildata, playerid)
				end
			end, 3)
	end
end

function MailCenter:GiveRewardAsFullMail(playerid, award, head, context, type, log, showTip)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if player then
		player:GiveRewardAsFullMail(award, head, context, type, log, showTip)
	end
end

function MailCenter:GiveRewardAsFullMailDefault(playerid, award, sourceName, type, log, showTip)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if player then
		player:GiveRewardAsFullMailDefault(award, sourceName, type, log, showTip)
	end
end

function MailCenter:SendGlobalMail(head, context, award, type, log)
	local newtime = lua_app.now()
	local globalMail = {
		sendtime = newtime,
		head = head,
		context = context,
		award = award or {},
		log_type = type,
		log = log,
	}
	local cache = server.mysqlBlob:CreateDmg(tbname, globalMail)
	self.mails[cache.dbid] = cache
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		self:SendMail(player.dbid, head, context, award, type, log, newtime)
		player.cache.global_mails[cache.dbid] = true
	end
end

function MailCenter:GetNewGlobalMails(player)
	local delMails = {}
	local nowMails = {}
	local sendedMails = player.cache.global_mails
	local cleanTime = lua_app.now() - self.MailKeepTime
	for dbid, cache in pairs(self.mails) do
		if cache.sendtime > cleanTime then
			if not sendedMails[dbid] and player.cache.createtime < cache.sendtime then
				local maildata = _NewMail(player.dbid, cache.head, cache.context, cache.award, cache.log_type, cache.log, cache.sendtime)
				player.mail:AddMail(maildata)
			end
			nowMails[dbid] = true
		else
			server.mysqlBlob:DelDmg(tbname, cache)
			delMails[dbid] = true
		end
	end
	for dbid, _ in pairs(delMails) do
		self.mails[dbid] = nil
	end
	player.cache.global_mails = nowMails
end

server.SetCenter(MailCenter, "mailCenter")
return MailCenter
