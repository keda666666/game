local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = "mails"

local Mail = oo.class()

function Mail:ctor()
end

function Mail:Create(data)
	self:Init(server.mysqlBlob:CreateDmg(tbname, data))
end

function Mail:Init(cache)
	self.cache = cache
	self.dbid = self.cache.dbid
end

function Mail:Release()
	-- if self.cache then
		self.cache(true)
		self.cache = nil
		self.dbid = nil
	-- end
end

function Mail:Del()
	server.mysqlBlob:DelDmg(tbname, self.cache)
	self.cache = nil
	self.dbid = nil
end

function Mail:GetMsgData()
	return {
		handle   	= self.dbid,
		title 		= self.cache.head,
		times    	= self.cache.sendtime,
		type      	= self.cache.readstatus,
		receive		= self.cache.awardstatus,
	}
end

function Mail:DetailData()
	return {
		mailData	= self:GetMsgData(),
		text		= self.cache.context,
		rewardData	= self.cache.award,
	}
end

return Mail