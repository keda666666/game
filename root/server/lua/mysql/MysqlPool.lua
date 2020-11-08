local oo = require "class"
local mysql = require "mysql"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

local MysqlPool = oo.class()

function MysqlPool:ctor()
	self.connList = {}
	self.randId = 0
	self.consByName = {}
	self.lockid = 0
	self.hashCache = {}
	self.hashCacheCount = 0
end

function MysqlPool:Init(cfgCenter)
	local cache = cfgCenter.cache
	self:init(cache.ip, tonumber(cache.port), cache.user, cache.pass, cache.dbname, tonumber(cache.num))
end

function MysqlPool:HotFix()
	self:CheckClearCache(99)
end

function MysqlPool:Release()
	self:WaitRelease()
end

function MysqlPool:CheckClearCache(maxcount)
	if self.hashCacheCount <= maxcount then return end
	self.hashCache = {}
	self.hashCacheCount = 0
end

function MysqlPool:init(ip, port, user, pass, name, num)
	assert(num < 50)
	if type(name) == "table" then
		name = name[1] and name[1].value
	end
	assert(type(name) == "string", type(name))
	for i = 1,num do
		local conn = mysql.client(ip,port,user,pass,name)
		if conn == 0 then
			print("create mysql connect failed")
		else
			self.connList[i] = conn
		end
	end
end

function MysqlPool:EscapeString(str)
	return mysql:escape_string(str)
end

function MysqlPool:GetInterfaceRand()
	self.randId = self.randId + 1
	return self.connList[self.randId%(#self.connList)+1]
end

function MysqlPool:GetInterfaceByDBID(rolerid)
	local index = rolerid%(#self.connList)+1
	return self.connList[index]
end

function MysqlPool:GetInterfaceByTbName(name)
	local con = self.consByName[name]
	if con == nil then
		self.lockid = self.lockid + 1
		con = self.connList[self.lockid%(#self.connList)+1]
		self.consByName[name] = con
	end
	return con
end

function MysqlPool:GetHash(str)
	if self.hashCache[str] then return self.hashCache[str] end
	local id = 0
	for i=#str, 1, -1 do
		id = id + str:byte(i)
	end
	self.hashCache[str] = id % (#self.connList) + 1
	self.hashCacheCount = self.hashCacheCount + 1
	return self.hashCache[str]
end

function MysqlPool:GetInterfaceByHash(hash)
	return self.connList[hash]
end

function MysqlPool:GetInterfaceByIndex(index)
	if type(index) == "string" then
		return self.connList[self:GetHash(index)]
	elseif type(index) == "number" then
		return self.connList[index % (#self.connList) + 1]
	else
		return self:GetInterfaceRand()
	end
end

function MysqlPool:WaitRelease()
	for _, con in pairs(self.connList) do
		con:call_execute("select 1;")
	end
end

function MysqlPool:GetDBIF(index, tbName, cond)
	index = index or cond and cond.dbid
	return self:GetInterfaceByIndex(index)
end

function MysqlPool:get_query(tbName, cond, field, index)
	local dbInterface = self:GetDBIF(index, tbName, cond)
	return dbInterface:get_query(tbName, cond, field)
end

function MysqlPool:query(tbName, cond, field, index)
	local dbInterface = self:GetDBIF(index, tbName, cond)
	local data = dbInterface:query(tbName, cond, field)
	return data
end

function MysqlPool:query_l(tbName, cond, field, skip, number, index)
	local dbInterface = self:GetDBIF(index, tbName, cond)
	local data = dbInterface:query(tbName, cond, field, skip, number)
	return data
end

function MysqlPool:insert_m(tbName, tbData, index)
	local dbInterface = self:GetDBIF(index, tbName)
	local result, insertId = dbInterface:insert_m(tbName, tbData)
	return result, insertId
end

function MysqlPool:insert(tbName, tbData, index)
	local dbInterface = self:GetDBIF(index, tbName)
	local result, insertId = dbInterface:insert(tbName, tbData)
	return result, insertId
end

function MysqlPool:insert_ms(tbName, tbData, index)
	local dbInterface = self:GetDBIF(index, tbName)
	dbInterface:insert_ms(tbName, tbData)
end

function MysqlPool:insert_s(tbName, tbData, index)
	local dbInterface = self:GetDBIF(index, tbName)
	dbInterface:insert_s(tbName, tbData)
end

function MysqlPool:update(tbName, cond, tbData, index)
	local dbInterface = self:GetDBIF(index, tbName, cond)
	dbInterface:update(tbName, cond, tbData)
end

function MysqlPool:delete(tbName, cond, index)
	local dbInterface = self:GetDBIF(index, tbName, cond)
	dbInterface:delete(tbName, cond)
end

function MysqlPool:send_execute(sql, index)
	local dbInterface = self:GetDBIF(index)
	dbInterface:send_execute(sql)
end

function MysqlPool:call_execute(sql, index)
	local dbInterface = self:GetDBIF(index)
	return dbInterface:call_execute(sql)
end

server.NewCenter(MysqlPool, "mysqlPool")
return MysqlPool
