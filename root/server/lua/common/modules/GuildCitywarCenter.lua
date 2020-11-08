local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"

local GuildCitywarCenter = {}

function GuildCitywarCenter:Init()
	if server.index == 0 then return end

	-- local function _Test()
	-- 	self.testtimer = lua_app.add_timer(10000, _Test)
	-- 	self:ResetData()
	-- 	self.serverdatas = self:CallLogics("GenActivityData")
	-- 	self:DealData()
	-- end
	-- self.testtimer = lua_app.add_timer(10000, _Test)
end

function GuildCitywarCenter:CallLogics(funcname, ...)
	return server.serverCenter:CallLogics("GuildCitywarLogicCall", funcname, ...)
end

function GuildCitywarCenter:SendOne(serverid, funcname, ...)
	server.serverCenter:SendOne("logic", serverid, "GuildCitywarLogicSend", funcname, ...)
end

function GuildCitywarCenter:ResetData()
	self.serverdatas = {}
	self.guilddatas = {}
	self.guildpowers = {}
	self.matchlist = {}
end

-- 处理活动数据,生成帮会配对
function GuildCitywarCenter:DealData()
	lua_app.log_info("GuildCitywarCenter:DealData", src)
	for serverid, serverdata in pairs(self.serverdatas) do
		for guildid, datas in pairs(serverdata.datalist) do
			self.guilddatas[guildid] = datas
		end
		for guildid, power in pairs(serverdata.powerlist) do
			self.guildpowers[guildid] = power
		end
	end

	table.sort(self.guildpowers, function(a, b)
			return a.power > b.power
		end)

	self.matchlist = {}
	local left
	local right
	for _, guildinfo in ipairs(self.guildpowers) do
		if not left then
			left = guildinfo.guildid
		else
			right = guildinfo.guildid
			self.matchlist[left] = self.guilddatas[right]
			self.matchlist[right] = self.guilddatas[left]
			left = nil
			right = nil
		end
	end

	-- 把配对数据发送回游戏服
	for serverid, serverdata in pairs(self.serverdatas) do
		self.servermatchlist = {}
		for guildid, _ in pairs(serverdata.datalist) do
			self.servermatchlist[guildid] = self.matchlist[guildid]
		end
		self:SendOne(serverid, "SetMatchData", self.servermatchlist)
	end

end

-- function GuildCitywarCenter:onDayTimer(day)
-- 	if server.index == 0 then return end

-- 	local week = lua_app.week()
-- 	if week == 0 then
-- 		-- 周日活动开启向游戏服收集数据
-- 		self:ResetData()
-- 		self.serverdatas = self:CallLogics("GenActivityData")
-- 		self:DealData()
-- 	end
-- end


function server.GuildCitywarWarCall(src, funcname, ...)
	lua_app.ret(server.guildCitywarCenter[funcname](server.guildCitywarCenter, ...))
end

function server.GuildCitywarWarSend(src, funcname, ...)
	server.guildCitywarCenter[funcname](server.guildCitywarCenter, ...)
end

server.SetCenter(GuildCitywarCenter, "guildCitywarCenter")
return GuildCitywarCenter
