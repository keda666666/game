local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local GuildwarNotice = oo.class()

function GuildwarNotice:ctor(guilwarMap)
	self.record = {}
	self.guilwarMap = guilwarMap
	self.recordNoticeMax = 0
end

function GuildwarNotice:Release()
end

function GuildwarNotice:NoticeStr(str, type)
	local data = {
			type = type,
			str = str,
			time = lua_app.now(),
		}
	if #self.record >= self.recordNoticeMax then
		table.remove(self.record, 1)
	end

	table.insert(self.record, data)
	self.guilwarMap:BroadcastOnline("sc_record_add", {
			type = 1,
			record = data,
		})
end

function GuildwarNotice:Notice(id, ...)
	local NoticeConfig = server.configCenter.NoticeConfig[id]
	local args = {...}
	local str
	if args[1] then
		str = string.format(NoticeConfig.content, ...)
	else
		str = NoticeConfig.content
	end
	self:NoticeStr(str, NoticeConfig.type)
end

function GuildwarNotice:onInitClient(dbid)
	server.sendReqByDBID(dbid, "sc_record_datas", {
			type = 1,
			record = self.record,
		})
end

return GuildwarNotice
