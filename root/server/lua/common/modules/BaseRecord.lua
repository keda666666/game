local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("records")

local BaseRecord = oo.class()

-- 公会ID：公会聊天		大于 1 << 34
BaseRecord.RecordType = {
	Notice		= 1,
	WorldChat	= 2,
	System 		= 3,
	WorldShare 	= 10,
}

function BaseRecord:ctor(type, maxSize, onlycache)
	self.recordType = type
	self.maxSize = maxSize
	self.onlycache = onlycache
end

function BaseRecord:InitRecord()
	self.records = {}
	local caches = server.mysqlBlob:LoadDmg(tbname, { type = self.recordType })
	table.sort(caches, function(a, b)
			return a.id < b.id
		end)
	for i, cache in ipairs(caches) do
		if i > self.maxSize then
			break
		end
		cache.id = i
		table.insert(self.records, cache)
	end
	self.nowindex = #self.records
	self.nextindex = self.nowindex + 1
end

function BaseRecord:AddRecord(data)
	self.nowindex = self.nowindex % self.maxSize + 1
	if self.nextindex > self.maxSize then
		local cache = self.records[self.nowindex]
		cache.record = data
		cache.id = self.nextindex
	else
		local cache = server.mysqlBlob:CreateDmg(tbname, {
				type = self.recordType,
				id = self.nextindex,
				record = data,
			})
		table.insert(self.records, cache)
	end
	self.nextindex = self.nextindex + 1
	self.senddatas = false
	if not self.onlycache then
		server.broadcastReq("sc_record_add", { type = self.recordType, record = data})
	end
	return data
end

function BaseRecord:ClearRecord()
	server.mysqlBlob:DelDmgs(tbname, self.records)
	self.records = {}
	self.nowindex = 1
	self.nextindex = 1
	self.senddatas = false
end

function BaseRecord:SendRecord(player)
	if not self.senddatas then
		local datas = {}
		local length = #self.records
		for i = self.nowindex, self.nowindex + length - 1 do
			if i > length then
				table.insert(datas, self.records[i - length].record)
			else
				table.insert(datas, self.records[i].record)
			end
		end
		self.senddatas = datas
	end
	if not self.onlycache then
		server.sendReq(player, "sc_record_datas", { type = self.recordType, record = self.senddatas })
	end
	return self.senddatas
end
--------------------- 下面是静态函数 ---------------------
function BaseRecord:Init()
	self._baseRecordList = {}
end

function BaseRecord:Ins(type, maxSize, onlycache)
	if self._baseRecordList[type] then return self._baseRecordList[type] end
	if not maxSize then
		lua_app.log_error("server.getBaseRecord:: no type:", type)
		return
	end
	local record = self.new(type, maxSize, onlycache)
	record:InitRecord()
	self._baseRecordList[type] = record
	return record
end

server.SetCenter(BaseRecord, "baseRecord")
return BaseRecord
