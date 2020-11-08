--[[
local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local MysqlCenter = require "mysql.MysqlCenter"

local MultMysqlPool = oo.class()

function MultMysqlPool:ctor()
	self.poolList = {}
end

function MultMysqlPool:init(ip, port, user, pass, dbname, num)
	for _, v in pairs(dbname) do
		local name = type(v) == "table" and v.value or v
		local pool = MysqlCenter.new()
		pool:init(ip, port, user, pass, name, num)
		self.poolList[name] = pool
	end
end

function MultMysqlPool:WaitRelease()
	lua_app.waitmultrun(function(name, pool)
			pool:WaitRelease()
		end, self.poolList)
end

function MultMysqlPool:multquery(tbName, cond, field, index)
	local rpool = next(self.poolList)
	if not rpool then
		lua_app.log_error("MultMysqlPool:multquery no poolList", tbName, cond, field, index)
		return {}
	end
	local sql = pool:get_query(tbName, cond, field, index)
	return self:multcall_execute(sql, index)
end

function MultMysqlPool:query(dbName, tbName, cond, field, index)
	if not self.poolList[dbName] then
		lua_app.log_error("MultMysqlPool:query no dbName", dbName, tbName, index)
		return {}
	end
	return self.poolList[dbName]:query(tbName, cond, field, index)
end

function MultMysqlPool:insert_m(dbName, tbName, tbData, index)
	return self.poolList[dbName]:insert_m(tbName, tbData, index)
end

function MultMysqlPool:insert(dbName, tbName, tbData, index)
	return self.poolList[dbName]:insert(tbName, tbData, index)
end

function MultMysqlPool:update(dbName, tbName, cond, tbData, index)
	self.poolList[dbName]:update(tbName, cond, tbData, index)
end

function MultMysqlPool:delete(dbName, tbName, cond, index)
	self.poolList[dbName]:delete(tbName, cond, index)
end

function MultMysqlPool:send_execute(dbName, sql, index)
	self.poolList[dbName]:send_execute(sql, index)
end

function MultMysqlPool:multcall_execute(sql, index)
	local list = {}
	lua_app.multrun(function(name, pool)
			list[name] = pool:call_execute(sql, index)
		end, self.poolList)
	return list
end

function MultMysqlPool:call_execute(dbName, sql, index)
	return self.poolList[dbName]:call_execute(sql, index)
end

-- function server.rpc_sql(src, funcname, ...)
-- 	local ret, ret1, ret2, ret3 = server[funcname](...)
-- 	if ret ~= nil then
-- 		lua_app.ret(ret, ret1, ret2, ret3)
-- 	end
-- end

function server.Init_MultMysqlPool(cacheConfig, num)
	local ip = cacheConfig.ip
	local port = cacheConfig.port
	local user = cacheConfig.user
	local pass = cacheConfig.pass
	local dbname = cacheConfig.dbname
	server.mysqlCenter = MultMysqlPool.new()
	server.mysqlCenter:init(ip, tonumber(port), user, pass, dbname, num)
end

return MultMysqlPool
--]]