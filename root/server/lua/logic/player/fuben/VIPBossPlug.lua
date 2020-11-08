local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local VIPBossPlug = oo.class()

function VIPBossPlug:ctor(player)
	self.player = player
end

function VIPBossPlug:onCreate()
	self.cache = self.player.cache.vipboss
end

function VIPBossPlug:onLoad()
	self.cache = self.player.cache.vipboss
end

function VIPBossPlug:onDayTimer()
	for _, infos in pairs(self.cache.list) do
		infos.daycount = 0
	end
end

function VIPBossPlug:AddCount(index)
	local infos = self.cache.list[index]
	if not infos then
		infos = {
			id = index,
			count = 1,
			daycount = 1,
		}
		self.cache.list[index] = infos
	else
		infos.count = infos.count + 1
		infos.daycount = infos.daycount + 1
	end
	self.player.enhance:AddPoint(23, 1)
	self.player:sendReq("sc_vipboss_update_one", { bossInfo = infos })
end

function VIPBossPlug:SendBossInfo()
	local msglist = {}
	for _, infos in pairs(self.cache.list) do
		table.insert(msglist, infos)
	end
	-- for _, cfg in pairs(server.configCenter.VipBossConfig) do
	-- 	table.insert(msglist, self.cache.list[cfg.id] or {
	-- 			id = cfg.id,
	-- 			count = 0,
	-- 			daycount = 0,
	-- 		})
	-- end
	self.player:sendReq("sc_vipboss_base_list", { bossInfos = msglist })
end

server.playerCenter:SetEvent(VIPBossPlug, "vipBoss")
return VIPBossPlug