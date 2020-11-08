local server = require "server"
local lua_app = require "lua_app"
local MapConfig = require "resource.MapConfig"

local RaidMgr = {}

function RaidMgr:Init()
	self.raidlist = self.raidlist or {}
end

function RaidMgr:SetRaid(raidtype, mod)
	self.raidlist = self.raidlist or {}
	self.raidlist[raidtype] = mod
end

function RaidMgr:Enter(raidtype, dbid, datas, lockids)
	assert(self.raidlist[raidtype], "no raidtype:" .. raidtype)
	-- local player = server.playerCenter:GetPlayerByDBID(dbid)
	-- if not player then
	-- 	lua_app.log_error("RaidMgr:Enter error:", dbid)
	-- 	return
	-- end
	if self.raidlist[raidtype]:Enter(dbid, datas) then
		if lockids then
			for _, id in ipairs(lockids) do
				local tmpplayer = server.playerCenter:GetPlayerByDBID(id)
				if tmpplayer then
					tmpplayer.server.raidMgr:SetPlayerInfo(id, raidtype)
					server.mapCenter:SetStatus(id, MapConfig.status.Fighting)
				end
			end
		else
			local tmpplayer = server.playerCenter:GetPlayerByDBID(dbid)
			if tmpplayer then
				tmpplayer.server.raidMgr:SetPlayerInfo(dbid, raidtype)
			end
			server.mapCenter:SetStatus(dbid, MapConfig.status.Fighting)
		end
		return raidtype
	end
end

function RaidMgr:Exit(raidtype, dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then
		lua_app.log_error("RaidMgr:Exit error:", raidtype, dbid)
		return
	end
	if not self.raidlist[raidtype]:Exit(dbid) then
		lua_app.log_error("RaidMgr:Exit exit failed", raidtype, dbid)
		return
	end
	server.mapCenter:SetStatus(dbid, MapConfig.status.Act)
	player.server.raidMgr:SetPlayerInfo(dbid)
	return true
end

function RaidMgr:Call(raidtype, funcname, dbid, ...)
	local raid = self.raidlist[raidtype]
	if not raid[funcname] then
		lua_app.log_error("RaidMgr:Call", raidtype, funcname, dbid, ...)
		return
	end
	return raid[funcname](raid, dbid, ...)
end

function RaidMgr:Send(raidtype, funcname, dbid, ...)
	local raid = self.raidlist[raidtype]
	if not raid[funcname] then
		lua_app.log_error("RaidMgr:Send", raidtype, funcname, dbid, ...)
		return
	end
	raid[funcname](raid, dbid, ...)
end

function RaidMgr:GetReward(raidtype, dbid)
	self.raidlist[raidtype]:GetReward(dbid)
end

-- function server.EnterRaid(src, raidtype, dbid, datas)
-- 	lua_app.ret(server.raidMgr:Enter(raidtype, dbid, datas))
-- end

-- function server.ExitRaid(src, raidtype, dbid)
-- 	lua_app.ret(server.raidMgr:Exit(raidtype, dbid))
-- end

-- function server.RaidGetReward(src, raidtype, dbid)
-- 	server.raidMgr:GetReward(raidtype, dbid)
-- end

server.SetCenter(RaidMgr, "raidMgr")
return RaidMgr