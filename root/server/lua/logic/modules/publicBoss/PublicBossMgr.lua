local server = require "server"
local lua_app = require "lua_app"

local PublicBossMgr = {}

function PublicBossMgr:Init()
	self.recoverlist = {}
	self:SecondTimer()
end

function PublicBossMgr:Release()
end

function PublicBossMgr:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end
	local function _DoSecond()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		self:ScheduleRecover()
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

function PublicBossMgr:ScheduleRecover()
	local nowtime = lua_app.now()
	local recoverlist = table.wcopy(self.recoverlist)
	for dbid, time in pairs(recoverlist) do
		if nowtime >= time then
			self:IncreaseDefi(dbid)
		end
	end
end

function PublicBossMgr:AddActionRecover(dbid, recovertime)
	self.recoverlist[dbid] = recovertime
end

function PublicBossMgr:IncreaseDefi(dbid)
	self.recoverlist[dbid] = nil
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		player.publicboss:IncreaseDefi()
	end
end

function PublicBossMgr:VerifyRecorve(dbid)
	return self.recoverlist[dbid]
end

function PublicBossMgr:Test()
	table.ptable(self.recoverlist, 3)
end

server.SetCenter(PublicBossMgr, "publicBossMgr")
return PublicBossMgr
