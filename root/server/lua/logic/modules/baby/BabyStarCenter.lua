local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "babystar"
local BabyStarCenter = {}

function BabyStarCenter:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
end

function BabyStarCenter:Release()
	if self.cache then
		self.cache(true)
		-- self.cache = nil
	end
end

function BabyStarCenter:SetData(data)
	table.insert(self.cache.data, data)
	if #self.cache.data > 5 then
		table.remove(self.cache.data, 1)
	end
end

function BabyStarCenter:GetData()
	return self.cache.data
end

server.SetCenter(BabyStarCenter, "babyStarCenter")
return BabyStarCenter
