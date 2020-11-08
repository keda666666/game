local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = "items"

local Item = oo.class()

function Item:ctor()
end

function Item:Create(data)
	self:Init(server.mysqlBlob:CreateDmg(tbname, data))
end

function Item:Init(cache)
	self.cache = cache
	self.dbid = self.cache.dbid
end

function Item:Release()
	-- if self.cache then
		self.cache(true)
		self.cache = nil
		self.dbid = nil
	-- end
end

function Item:Del()
	server.mysqlBlob:DelDmg(tbname, self.cache)
	self.cache = nil
	self.dbid = nil
end

function Item:GetMsgData()
	return {
		handle   	= self.dbid,
		id 		 	= self.cache.id,
		count    	= self.cache.count,
		attrs      	= self.cache.attrs,
		invalidtime	= self.cache.invalidtime,
	}
end

function Item:IsInvalid()
	local invalidtime = self.cache.invalidtime
	return invalidtime ~= 0 and invalidtime <= lua_app.now()
end

function Item:GetConfig()
	return server.configCenter.ItemConfig[self.cache.id]
end
return Item
