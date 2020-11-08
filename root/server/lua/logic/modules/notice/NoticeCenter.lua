local server = require "server"
local lua_app = require "lua_app"
local WeightData = require "WeightData"

local NoticeCenter = {}

function NoticeCenter:Init()
	self.record = server.baseRecord:Ins(server.baseRecord.RecordType.Notice, 99)
	self.recordNoticeTimers = {}
	self.recordNoticeMax = 0
	self.randomnotice = WeightData.new()
	local ChatConstConfig = server.configCenter.ChatConstConfig
	for _,id in ipairs(ChatConstConfig.ratnotice) do
		self.randomnotice:Add(10, id)
	end
	self:RandomNotice()
end

function NoticeCenter:NoticeStr(str, type)
	self.record:AddRecord({
			type = type,
			str = str,
			time = lua_app.now(),
		})
end

function NoticeCenter:RandomNotice()
	if self.noticetimer then
		lua_app.del_timer(self.noticetimer)
		self.noticetimer = nil
	end
	local ChatConstConfig = server.configCenter.ChatConstConfig
	self.noticetimer = lua_app.add_update_timer(ChatConstConfig.noticetime * 1000, self, "RandomNotice")
	local noticeid = self.randomnotice:GetRandom()
	self:Notice(noticeid)
end

function NoticeCenter:RecordNoticeTimer(str, type, interval, starttime, endtime)
	self.recordNoticeMax = self.recordNoticeMax + 1
	local num = self.recordNoticeMax
	local function runNotice()
		if lua_app.now() > endtime then
			self.recordNoticeTimers[num] = nil
			return
		end
		self:NoticeStr(str, type)
		self.recordNoticeTimers[num] = lua_app.add_timer(interval, runNotice)
	end
	if starttime then
		self.recordNoticeTimers[num] = lua_app.add_timer((starttime - lua_app.now()) * 1000, runNotice)
	else
		runNotice()
	end
	return num
end

function NoticeCenter:RecordDelNoticeTimer(num)
	if not num or num < 0 then
		for _, ttimer in pairs(self.recordNoticeTimers) do
			if ttimer then
				lua_app.del_timer(ttimer)
			end
		end
		self.recordNoticeTimers = {}
		self.recordNoticeMax = 0
		return
	end
	if self.recordNoticeTimers[num] then
		lua_app.del_timer(self.recordNoticeTimers[num])
		self.recordNoticeTimers[num] = nil
	end
end

function NoticeCenter:Notice(id, ...)
	print("NoticeCenter:Notice------",id,...)
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

function NoticeCenter:ClearNotice()
	self.record:ClearRecord()
end

function NoticeCenter:onInitClient(player)
	self.record:SendRecord(player)
end

function NoticeCenter:ResetServer()
	self:ClearNotice()
end

server.SetCenter(NoticeCenter, "noticeCenter")
return NoticeCenter
