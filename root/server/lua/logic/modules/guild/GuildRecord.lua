local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local GuildConfig = require "common.resource.GuildConfig"

local GuildRecord = oo.class()

GuildRecord.RecordType = {
	History 	= 1,
	Chat 		= 2,
	Share  		= 3,
}

function GuildRecord:ctor(guild)
	self.records = {}
	self.guild = guild
end

function GuildRecord:Init()
	local records = self.guild.cache.records
	records[GuildRecord.RecordType.History] = records[GuildRecord.RecordType.History] or {}
	records[GuildRecord.RecordType.Chat] = records[GuildRecord.RecordType.Chat] or {}
	records[GuildRecord.RecordType.Share] = records[GuildRecord.RecordType.Share] or {}

	local ChatConstConfig = server.configCenter.ChatConstConfig
	self:SetRecordData(records[GuildRecord.RecordType.History], ChatConstConfig.saveChatListSize)
	self:SetRecordData(records[GuildRecord.RecordType.Chat], ChatConstConfig.saveChatListSize)
	self:SetRecordData(records[GuildRecord.RecordType.Share], ChatConstConfig.saveGuildChatcount)
	self.records = records
end

function GuildRecord:SetRecordData(data, maxsize)
	if next(data) == nil then
		data.records = {}
		data.maxsize = maxsize
		data.nextindex = 1
	end
	local records = {}
	local maxrecord = #data.records
	for i = 1, maxrecord do
		if data.nextindex > maxrecord then
			records[#records + 1] = data.records[i]
		else
			records[#records + 1] = data.records[(data.nextindex - 2 + i) % data.maxsize]
		end
	end
	data.records = records
	data.nextindex = maxsize > maxrecord and maxrecord + 1 or 1
	data.maxsize = maxsize
end

function GuildRecord:AddRecord(recordtype, data)
	local record = self.records[recordtype]
	local index = record.nextindex
	record.records[index] = data
	record.nextindex = index % record.maxsize + 1
	self.senddatas = false
end

function GuildRecord:AddGuildHistorys(type, name1, name2, param1, param2, param3)
	local data = {
		historyRecord = {
			guildid = self.guild.dbid,
			time = lua_app.now(),
			type = type,
			name1 = name1,
			name2 = name2,
			param1 = param1,
			param2 = param2,
			param3 = param3,
		},
		type = self.RecordType.History
	}
	self:AddGuildRecord(data)
	local noticeChat = GuildConfig.GetNoticeStr(data.historyRecord)
	if noticeChat then
		self:AddGuildChat(noticeChat)
	end
end

function GuildRecord:AddGuildChat(content, playerId, share, ttype)
	local data = {
		chatRecord = {
			guildid = self.guild.dbid,
			content = content,
			type = ttype or (playerId and 1) or 0,
			time = lua_app.now(),
			share = share,
		},
		type = self.RecordType.Chat,
	}
	if playerId and data.chatRecord.type == 1 then
		local player = server.playerCenter:DoGetPlayerByDBID(playerId)
		local status = player.cache.silent
		if status > lua_app.now() then
			server.sendErr(player, "您已经被禁言,剩余时间" .. (status - lua_app.now()) .. "秒")
			return
		end

		data.chatRecord.playerid = playerId
		data.chatRecord.name = player.cache.name
		data.chatRecord.job = player.cache.job
		data.chatRecord.sex = player.cache.sex
		data.chatRecord.vipLv = player.cache.vip
		data.chatRecord.office = self.guild:GetOffice(playerId)
		data.chatRecord.headframe = player.head:GetFrame()
		--永久禁言玩家特殊处理
		if status == -1 then
			return server.sendReq(player, "sc_guild_record_add", { record = data })
		end
	end
	self:AddGuildRecord(data)
end

function GuildRecord:AddGuildRecord(data)
	local recordtype = data.type
	if data.chatRecord and data.chatRecord.type == 0 then
		recordtype = GuildRecord.RecordType.Share
	end
	self:AddRecord(recordtype, data)
	self.guild:Broadcast("sc_guild_record_add", {
		record = data,
		})
end

function GuildRecord:SendGuildRecord(player)
	if not self.senddatas then
		local datas = {}
		for __, recordtype in pairs(GuildRecord.RecordType) do
			for __, data in pairs(self.records[recordtype].records) do
				if data.type == GuildRecord.RecordType.Chat and
				server.chatCenter:CheckFilteChat(data.chatRecord.playerid) then
				 	datas[#datas + 1] = data
				else
					datas[#datas + 1] = data
				end
			end
		end
		self.senddatas = datas
	end
	server.sendReq(player,"sc_guild_record_data", {
		records = self.senddatas
		})
end

function GuildRecord:onLogin(player)
	self:SendGuildRecord(player)
end

return GuildRecord