local server = require "server"
local lua_app = require "lua_app"
local lua_shield = require "lua_shield"
local lua_util = require "lua_util"
local ChatConfig = require "resource.ChatConfig"
local RaidConfig = require "resource.RaidConfig"
local utf8 = require("lua_utf8")
local ChatCenter = {}

local _ChatType = ChatConfig.ChatType
local _LinkId = ChatConfig.LinkId
local _MaxPrivateRecord = 20

function ChatCenter:Init()
	self.record = server.baseRecord:Ins(server.baseRecord.RecordType.WorldChat, server.configCenter.ChatConstConfig.saveChatListSize, true)
	self.systemrecord = server.baseRecord:Ins(server.baseRecord.RecordType.System, server.configCenter.ChatConstConfig.saveSystemChatcount, true)
	self.playerlist = {}
	self.privateChatRecord = {}
	self.offlineChat = {}
	self.playershareinfo = {}
	self.chatrecordOfbanned = {}
end

function ChatCenter:onDayTimer(player)
	self.playerlist = {}
end

function ChatCenter:onInitClient(player)
	local worlddatas = self.record:SendRecord(player)
	local systemdatas = self.systemrecord:SendRecord(player)
	server.sendReq(player, "sc_chat_init_msg", {
			chatDatas = self:FilteChat(worlddatas, systemdatas)
		})
	self:PrivateOfflineChat(player)
end

--设置过滤名单
function ChatCenter:SetFilter(flag, playerid)
	if flag ~= 0 then
		server.broadcastReq("sc_chat_filte_list", {
				filter = playerid,
			})
	end
end

function ChatCenter:FilteChat(...)
	local arg = {...}
	local newchatdata = {}
	for __, chatdatas in ipairs(arg) do
		for __, chat in ipairs(chatdatas) do
			if self:CheckFilteChat(chat.id) then
				newchatdata[#newchatdata + 1] = chat
			end
		end
	end
	return newchatdata
end

function ChatCenter:CheckFilteChat(dbid)
	if not dbid then return true end
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local status = player.cache.silent
	return status ~= -1 and status <= lua_app.now()
end

function ChatCenter:GetRecord(chattype)
	if chattype == server.baseRecord.RecordType.WorldChat or
		chattype == server.baseRecord.RecordType.WorldShare then
		return self.record
	else
		return self.systemrecord
	end
end

local function _CheckChatCount(sender, count)
	local ChatLevelConfig = server.configCenter.ChatLevelConfig
	local powerValue = sender.cache.totalpower
	local index = #ChatLevelConfig
	for i = #ChatLevelConfig, 1, -1 do
		local cfg = ChatLevelConfig[i]
		if powerValue >= cfg.power then
			index = i
			if count < cfg.chatSize then
				return true
			elseif not ChatLevelConfig[i + 1] then
				return false, cfg.errortips
			else
				return false, string.format(cfg.errortips, ChatLevelConfig[i + 1].power)
			end
		end
	end
	return false, ChatLevelConfig[#ChatLevelConfig].errortips
end

function ChatCenter:CheckAddCount(sender)
	local playerinfo = self.playerlist[sender.dbid]
	if not playerinfo then
		playerinfo = {
			chatdaycount = 0,
		}
		self.playerlist[sender.dbid] = playerinfo
	end
	local nowtime = lua_app.now()
	local ChatConstConfig = server.configCenter.ChatConstConfig
	if not server.funcOpen:Check(sender, ChatConstConfig.openLevel) then
		server.sendErr(sender, "等级不足，不能发言")
		return false
	end
	local waittime = ChatConfig:GetWaitInterval("chat."..sender.dbid, ChatConstConfig.chatCd)
	if waittime > 0 then
		server.sendErr(sender, "聊天cd中")
		return false
	end
	local checkcountret, errmsg = _CheckChatCount(sender, playerinfo.chatdaycount)
	if not checkcountret then
		server.sendErr(sender, errmsg)
		return false
	end
	playerinfo.chatdaycount = playerinfo.chatdaycount + 1
	return true
end

local _Chatting = {}
_Chatting[_ChatType.WorldChat] = function(self, sender, str, recvId, pointId)	-- 世界聊天
	if not self:CheckAddCount(sender) then
		return false
	end
	local data = {
			type = _ChatType.WorldChat,
			id = sender.dbid,
			name = sender.cache.name,
			vip = sender.cache.vip,
			str = str,
			job = sender.cache.job,
			sex = sender.cache.sex,
			headframe = sender.head:GetFrame(),
			time = lua_app.now(),
		}
	--禁言玩家消息只有自己能看到
	if not self:CheckFilteChat(sender.dbid) then
		server.sendReq(sender, "sc_chat_new_msg", { chatData = data })
		return true
	end

	self.record:AddRecord(data)
	server.broadcastReq("sc_chat_new_msg", { chatData = data })
	sender.task:onEventAdd(server.taskConfig.ConditionType.ChatWorld)
	return true
end

_Chatting[_ChatType.PrivateChat] = function(self, sender, str, recvId)	-- 私聊
	local ret = server.friendCenter:ChatCheck(sender, recvId)
	if ret == 1 then
		server.sendErr(sender, "你屏蔽该玩家了")
		return
	elseif ret == 2 then
		server.sendErr(sender, "你被该玩家屏蔽了")
		return
	end
	local data = {
			type = _ChatType.PrivateChat,
			id = sender.dbid,
			name = sender.cache.name,
			vip = sender.cache.vip,
			str = str,
			job = sender.cache.job,
			sex = sender.cache.sex,
			frame = sender.head:GetFrame(),
			time = lua_app.now(),
		}
	--禁言玩家消息只有自己能看到
	if not self:CheckFilteChat(sender.dbid) then
		server.sendReq(sender, "sc_chat_private_new_msg", {
			session = self:GetPrivateChatId(sender.dbid, recvId),
			chatData = data,
		})
		return true
	end

	local receiver = server.playerCenter:DoGetPlayerByDBID(recvId)
	self:AddPrivateChatRecord(sender, receiver, data)
	return true
end

function _StrRepeatCount(src, cond)
	return select(2, string.gsub(src, string.format("%s[^|]*", cond), ""))
end
--禁言检测
function ChatCenter:CheckBanned(dbid, chatstr)
	local ChatshutupConfig = server.configCenter.ChatshutupConfig
	local record = self.chatrecordOfbanned[dbid]
	if not record then
		record = { nextindex = 1 }
		self.chatrecordOfbanned[dbid] = record
	end
	local text = table.concat(record, "|")
	for __, str in ipairs(ChatshutupConfig.jlibrary) do
		if  _StrRepeatCount(text, str) > ChatshutupConfig.zicount then
			return true
		end
	end
	for __, str in ipairs(ChatshutupConfig.mlibrary) do
		if  _StrRepeatCount(text, str) > ChatshutupConfig.shutupcount then
			return true
		end
	end
	local count = 0
	for w in string.gmatch(text, "[^|]+") do
		if w == chatstr then
			count = count + 1
		end
		if count > ChatshutupConfig.repeatcount then
			return true
		end
	end
	
	local len = utf8.len(chatstr)
	if len >= ChatshutupConfig.count then
		record[record.nextindex] = chatstr
		record.nextindex = record.nextindex % ChatshutupConfig.historycount + 1
	end
	return false
end

function ChatCenter:Chat(sender, type, str, recvId)
	if sender.cache.vip < 13 then
        server.sendErr(sender, "需要vip13才能聊天哦")
        return false
    end
	local status = sender.cache.silent
	if status ~= -1 and self:CheckBanned(sender.dbid, str) then
		sender.cache.silent = -1
		self:SetFilter(-1, sender.dbid)
		lua_app.log_info("CheckBanned:Prohibit players from chatting.", sender.dbid, sender.cache.name)
	end

	if status > lua_app.now() then
		server.sendErr(sender, "您已经被禁言,剩余时间" .. (status - lua_app.now()) .. "秒")
		return false
	end

	if string.len(str) >= server.configCenter.ChatConstConfig.chatLen then
		server.sendErr(sender, "字节太长,超过160个字节")
		return false
	end

	str = lua_shield:string(str)
	return _Chatting[type](self, sender, str, recvId)
end

local CheckLinkCondition = setmetatable({}, {__index = function()
	return function() return true end
end})

CheckLinkCondition[_LinkId.AssistPkBoss] = function(sender)
	local ChaptersCommonConfig = server.configCenter.ChaptersCommonConfig
	local appealtime = sender.cache.chapter.appealtime
	if appealtime >= ChaptersCommonConfig.appealtime then
		server.sendErr(sender, "当日求助次数达到上限")
		return false
	end
	return true
end

function ChatCenter:CheckChatLink(id, sender)
	if not CheckLinkCondition[id](sender) then
		return false
	end
	local waittime = ChatConfig:GetWaitInterval("CheckChatLink."..sender.dbid)
	if waittime > 0 then
		server.sendErr(sender, string.format("%d秒后才能发送", waittime))
		return false
	end
	local tips = ChatConfig.LinkTips[id] or "发送成功"
	server.sendErr(sender, tips)
	return true
end

--param1 分享id， param2为玩家的id列表
function ChatCenter:ChatLink(shareid, sender, checkflag, ...)
	if checkflag then
		if not self:CheckChatLink(shareid, sender) then
			return
		end
	end
	print("shareid", "--------------------------")
	local chatData = ChatConfig:PackLinkData(shareid, sender, ...)
	local record = self:GetRecord(chatData.type)
	record:AddRecord(chatData)
	server.broadcastReq("sc_chat_new_msg", {
		chatData = chatData
		})
	return true
end

--战斗通知
local _NoticeRaid = setmetatable({}, {__index = function() return function() end end})

_NoticeRaid[RaidConfig.type.GuildFb] = function(dbid, level)
	local GuildFubenConfig = server.configCenter.GuildFubenConfig[level]
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	player.guild:ChatLink(11, 0, {ChatConfig.CollectType.Fb, level, RaidConfig.type.GuildFb}, player.cache.name, GuildFubenConfig.uititle)
end

_NoticeRaid[RaidConfig.type.CrossTeamFb] = function(dbid, level)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	server.chatCenter:ChatLink(14, player, nil, {ChatConfig.CollectType.Fb, level, RaidConfig.type.CrossTeamFb}, player.cache.name, level)
end

_NoticeRaid[RaidConfig.type.EightyOneHard] = function(dbid, level)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local DisasterFbConfig = server.configCenter.DisasterFbConfig[level]
	server.chatCenter:ChatLink(15, player, nil, {ChatConfig.CollectType.Fb, level, RaidConfig.type.EightyOneHard}, player.cache.name, DisasterFbConfig.name)
end

_NoticeRaid[RaidConfig.type.GuildBoss] = function(dbid, level, guildid)
	local guild = server.guildCenter:GetGuild(guildid)
	if not guild then
		return
	end
	local chatdata = server.chatConfig:PackLinkData(8)
	guild.guildRecord:AddGuildChat(chatdata.str, nil, chatdata.share)
end

_NoticeRaid[RaidConfig.type.FieldBoss] = function(dbid, level)
	server.chatCenter:ChatLink(13)
end

local _NoticeCheck = {}
function ChatCenter:NoticeFb(raidtype, dbid, level, ...)
	local recordkey = string.format("%s%s%s", raidtype, dbid, level)
	local waittime = ChatConfig:GetWaitInterval(recordkey)
	if waittime > 0 then return end
	_NoticeRaid[raidtype](dbid, level, ...)
end

function ChatCenter:EmitTeamRecruit(dbid)
	 local waittime = ChatConfig:GetWaitInterval(dbid)
	 if waittime > 0 then
	 	server.sendErrByDBID(dbid, string.format("%d秒后才能招募", waittime))
        return false
    end
    server.sendErrByDBID(dbid, "招募成功")
    return true
end

function ChatCenter:AddPrivateChatRecord(sender, receiver, data)
	local session = self:GetPrivateChatId(sender.dbid, receiver.dbid)
	local records = self.privateChatRecord[session]
	if not records then
		records = {}
		self.privateChatRecord[session] = records
	end
	if #records > _MaxPrivateRecord then
		table.remove(records, 1)
	end
	table.insert(records, data)
	server.sendReq(sender, "sc_chat_private_new_msg", {
			session = session,
			chatData = data,
		})
	if receiver.isLogin then
		server.sendReq(receiver, "sc_chat_private_new_msg", {
				session = session,
				chatData = data,
			})
	else
		local offlineChat = self.offlineChat[receiver.dbid]
		if not offlineChat then
			offlineChat = {}
			self.offlineChat[receiver.dbid] = offlineChat
		end
		offlineChat[session] = true
	end
end

function ChatCenter:PrivateOfflineChat(player)
	local offlineChat = self.offlineChat[player.dbid]
	if not offlineChat then
		return
	end
	for session,_ in pairs(offlineChat) do
		local records = self.privateChatRecord[session]
		server.sendReq(player, "sc_chat_private_init_msg", {
			session = session,
			chatData = records,
		})
	end
	self.offlineChat[player.dbid] = nil
end

function ChatCenter:PrivateChatStart(sender, recvId)
	local session = self:GetPrivateChatId(sender.dbid, recvId)
	local records = self.privateChatRecord[session]
	if not records then
		records = {}
		self.privateChatRecord[session] = records
	end
	server.sendReq(sender, "sc_chat_private_init_msg", {
			session = session,
			chatData = records,
		})
end

function ChatCenter:GetPrivateChatId(senderId, receiverId)
	return (senderId < receiverId and senderId ..":".. receiverId or receiverId ..":".. senderId)
end

function ChatCenter:ClearChat()
	self.record:ClearRecord()
end

function ChatCenter:ChatSysInfo(dbid, str)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if player then
		local data = {
				type = _ChatType.SysChat,
				id = dbid,
				name = player.cache.name,
				vip = player.cache.vip,
				str = str,
				job = player.cache.job,
				sex = player.cache.sex,
				time = lua_app.now(),
			}
		player:sendReq("sc_chat_new_msg", { chatData = data })
	end
end

function ChatCenter:BroadcastSysInfo(str)
	local data = {
				type = _ChatType.SysChat,
				id = 0,
				name = player.cache.name,
				vip = player.cache.vip,
				str = str,
				job = player.cache.job,
				sex = player.cache.sex,
				time = lua_app.now(),
			}
	server.broadcastReq("sc_chat_new_msg", { chatData = data })
end

function ChatCenter:ResetServer()
	self.record:ClearRecord()
	self.systemrecord:ClearRecord()
	self.playerlist = {}
	self.privateChatRecord = {}
	self.offlineChat = {}
end

server.SetCenter(ChatCenter, "chatCenter")
return ChatCenter