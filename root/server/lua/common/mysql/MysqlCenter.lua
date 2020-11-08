local oo = require "class"
local mysql = require "mysql"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

local MysqlCenter = {}

function MysqlCenter:Init(cfgCenter)
	if not self.source or self.source == 0 then
		self.source = lua_app.unique_lua("mysql/mysql", server.platformid)
		lua_app.call(self.source, "lua", "Start", cfgCenter)
		assert(self.source and self.source>0, self.source)
	end
end

function MysqlCenter:HotFix()
	lua_app.send(self.source, "lua", "HotFix")
end

function MysqlCenter:Release()
	if self.source and self.source > 0 then
		lua_app.call(self.source, "lua", "Stop")
	end
end

function MysqlCenter:Send(funcname, ...)
	lua_app.send(self.source, lua_app.MSG_LUA, "SendRunModFun", "mysqlPool", funcname, ...)
end

function MysqlCenter:Call(funcname, ...)
	return lua_app.call(self.source, lua_app.MSG_LUA, "CallRunModFun", "mysqlPool", funcname, ...)
end

function MysqlCenter:EscapeString(str)
	return self:Call("escape_string", str)
end

function MysqlCenter:get_query(tbName, cond, field, index)
	return self:Call("get_query", tbName, cond, field, index)
end

function MysqlCenter:query(tbName, cond, field, index)
	return self:Call("query", tbName, cond, field, index)
end

function MysqlCenter:query_l(tbName, cond, field, skip, number, index)
	return self:Call("query_l", tbName, cond, field, skip, number, index)
end

function MysqlCenter:insert_m(tbName, tbData, index)
	return self:Call("insert_m", tbName, tbData, index)
end

function MysqlCenter:insert(tbName, tbData, index)
	return self:Call("insert", tbName, tbData, index)
end

function MysqlCenter:insert_ms(tbName, tbData, index)
	self:Send("insert_ms", tbName, tbData, index)
end

function MysqlCenter:insert_s(tbName, tbData, index)
	self:Send("insert_s", tbName, tbData, index)
end

function MysqlCenter:update(tbName, cond, tbData, index)
	self:Send("update", tbName, cond, tbData, index)
end

function MysqlCenter:delete(tbName, cond, index)
	self:Send("delete", tbName, cond, index)
end

function MysqlCenter:send_execute(sql, index)
	self:Send("send_execute", sql, index)
end

function MysqlCenter:call_execute(sql, index)
	return self:Call("call_execute", sql, index)
end

server.SetCenter(MysqlCenter, "mysqlCenter")
return MysqlCenter
