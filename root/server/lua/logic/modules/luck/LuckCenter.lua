local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local ItemConfig = require "common.resource.ItemConfig"

local LuckCenter = {}

function LuckCenter:Init()
	self.records = {}
	self.items = {}
	for _, v in ipairs(server.configCenter.LuckBaseConfig.historynotice) do
		self.items[v] = true
	end

	self.equipRecords = {}
	self.equipItems = {}
	for _, v in ipairs(server.configCenter.EquipLotteryBaseConfig.historynotice) do
		self.equipItems[v] = true
	end

	self.totemsRecords = {}
	self.totemsItems = {}
	for _, v in ipairs(server.configCenter.TotemsLotteryBaseConfig.historynotice) do
		self.totemsItems[v] = true
	end

end

function LuckCenter:Release()
end

local _LuckRecord = {}

_LuckRecord[1] = function(self)
	return self.records, self.items
end

_LuckRecord[2] = function(self)
	return self.equipRecords, self.equipItems
end

_LuckRecord[3] = function(self)
	return self.totemsRecords, self.totemsItems
end

function LuckCenter:DoRecord(typ, name, rewards)
	local records,items = _LuckRecord[typ](self)

	for k,v in pairs(rewards) do
		if v.type == ItemConfig.AwardType.Item then
			if items[v.id] then
				if #records >= 30 then
					table.remove(records, 1)
				end
				table.insert(records, {name = name, reward = v, time = lua_app.now()})
			end
		end
	end
end

server.SetCenter(LuckCenter, "luckCenter")
return LuckCenter
