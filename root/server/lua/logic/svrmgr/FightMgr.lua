local server = require "server"
local lua_app = require "lua_app"
local RaidCheck = require "resource.RaidCheck"

local FightMgr = {}

function FightMgr:Call(dbid, funcname, ...)
	local israid, raidtype = server.raidMgr:IsInRaid(dbid)
	if israid then
		if RaidCheck:CheckCross(raidtype) then
			return server.serverCenter:CallDtb("war", "FightCall", funcname, ...)
		else
			return server.serverCenter:CallLocal("war", "FightCall", funcname, ...)
		end
	end
end

function FightMgr:Send(dbid, funcname, ...)
	local israid, raidtype = server.raidMgr:IsInRaid(dbid)
	if israid then
		if RaidCheck:CheckCross(raidtype) then
			server.serverCenter:SendDtb("war", "FightSend", funcname, ...)
		else
			server.serverCenter:SendLocal("war", "FightSend", funcname, ...)
		end
	end
end

function FightMgr:UseSkill(dbid, msg)
	self:Send(dbid, "UseSkill", dbid, msg)
end

function FightMgr:PlayFinish(dbid)
	self:Send(dbid, "PlayFinish", dbid)
end

function FightMgr:SetAuto(dbid, isauto)
	self:Send(dbid, "SetAuto", dbid, isauto, true)
end

server.SetCenter(FightMgr, "fightMgr")
return FightMgr