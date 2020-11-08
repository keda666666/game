local server = require "server"
local lua_app = require "lua_app"
local RaidCheck = require "resource.RaidCheck"
local MapConfig = require "resource.MapConfig"

local RaidMgr = {}

function RaidMgr:Init()
	self.playerinfo = {}
end

function RaidMgr:CheckRaid(dbid)
	local playerinfo = self.playerinfo[dbid]
	if not playerinfo then
		playerinfo = {}
		self.playerinfo[dbid] = playerinfo
	end
	if playerinfo.raidlock then
		lua_app.log_info("RaidMgr:Enter raidlock", playerinfo.raidlock)
		return false
	end
	if playerinfo.enterraidtype then
		if lua_app.now() > playerinfo.enterraidtype.time + 60 then
			self:Exit(dbid)
		else
			lua_app.log_info("RaidMgr:Enter enterraidtype", playerinfo.enterraidtype.raidtype, lua_app.now() - playerinfo.enterraidtype.time)
			return false
		end
	end
	return true
end

function RaidMgr:Enter(raidtype, dbid, datas, others)
	if not raidtype then
		lua_app.log_error("RaidMgr:Enter not raidtype")
		return false
	end
	if not self:CheckRaid(dbid) then
		return false
	end
	local playerinfo = self.playerinfo[dbid]
	playerinfo.raidlock = true
	server.teamMgr:Leave(dbid)

	if others then
		for _, playerid in ipairs(others) do
			if not self:CheckRaid(playerid) then
				return false
			end
			server.teamMgr:Leave(playerid)
		end
	end

	local ret = self:CallRaidType(raidtype, "Enter", dbid, datas)
	-- if RaidCheck:CheckCross(raidtype) then
	-- 	ret = server.serverCenter:CallDtb("war", "EnterRaid", raidtype, dbid, datas)
	-- else
	-- 	ret = server.serverCenter:CallLocal("war", "EnterRaid", raidtype, dbid, datas)
	-- end
	if ret then
		self:SetPlayerInfo(dbid, raidtype)
		server.mapMgr:SetStatus(dbid, MapConfig.status.Fighting)
		if others then
			for _, playerid in ipairs(others) do
				self:SetPlayerInfo(playerid, raidtype)
				server.mapMgr:SetStatus(playerid, MapConfig.status.Fighting)
			end
		end
	end
	playerinfo.raidlock = false
	return raidtype
end

function RaidMgr:Exit(dbid)
	local playerinfo = self.playerinfo[dbid]
	if not playerinfo then
		lua_app.log_info("RaidMgr:Exit Invalid", dbid)
		return
	end

	server.mapMgr:SetStatus(dbid, MapConfig.status.Act)
	
	if playerinfo.raidlock and not playerinfo.enterraidtype then
		-- 这种情况是进入副本时候副本内报错被锁住
		lua_app.log_info("RaidMgr:Exit Error because Enter error", dbid)
		playerinfo.enterraidtype = nil
		playerinfo.raidlock = false
		return
	end
	if not playerinfo.enterraidtype then
		lua_app.log_info("RaidMgr:Exit Invalid", dbid)
		return
	end
	playerinfo.raidlock = true
	local ret
	if server.raidConfig.type.ChapterBoss == playerinfo.enterraidtype.raidtype then
		ret = true
		self:SendRaidType(playerinfo.enterraidtype.raidtype, "Exit", dbid)
	else
		ret = self:CallRaidType(playerinfo.enterraidtype.raidtype, "Exit", dbid)
	end
	-- if RaidCheck:CheckCross(playerinfo.enterraidtype.raidtype) then
	-- 	ret = server.serverCenter:CallDtb("war", "ExitRaid", playerinfo.enterraidtype.raidtype, dbid)
	-- else
	-- 	ret = server.serverCenter:CallLocal("war", "ExitRaid", playerinfo.enterraidtype.raidtype, dbid)
	-- end
	if ret then
		self:SetPlayerInfo(dbid)
	end
	playerinfo.raidlock = false
	return ret
end

function RaidMgr:GetReward(dbid)
	local playerinfo = self.playerinfo[dbid]
	if not playerinfo or not playerinfo.enterraidtype then
		return
	end
	self:SendRaidType(playerinfo.enterraidtype.raidtype, "GetReward", dbid)
	-- if RaidCheck:CheckCross(playerinfo.enterraidtype.raidtype) then
	-- 	server.serverCenter:SendDtb("war", "RaidGetReward", playerinfo.enterraidtype.raidtype, dbid)
	-- else
	-- 	server.serverCenter:SendLocal("war", "RaidGetReward", playerinfo.enterraidtype.raidtype, dbid)
	-- end
end

function RaidMgr:SetPlayerInfo(dbid, raidtype)
	if not self.playerinfo[dbid] then self.playerinfo[dbid] = {} end
	if raidtype then
		self.playerinfo[dbid].enterraidtype = { raidtype = raidtype, time = lua_app.now() }
	else
		self.playerinfo[dbid].enterraidtype = nil
		if not server.mapMgr:GetMapid(dbid) then
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			player.chapter:SendChapterInitInfo()
		end
	end
end

function RaidMgr:IsInRaid(dbid)
	local playerinfo = self.playerinfo[dbid]
	if playerinfo and playerinfo.enterraidtype and playerinfo.enterraidtype.raidtype then
		return true, playerinfo.enterraidtype.raidtype
	else
		return false
	end
end

function RaidMgr:SendRaidType(raidtype, funcname, dbid, ...)
	if RaidCheck:CheckCross(raidtype) then
		server.serverCenter:SendDtbMod("war", "raidMgr", "Send", raidtype, funcname, dbid, ...)
	else
		server.serverCenter:SendLocalMod("war", "raidMgr", "Send", raidtype, funcname, dbid, ...)
	end
end

function RaidMgr:CallRaidType(raidtype, funcname, dbid, ...)
	if RaidCheck:CheckCross(raidtype) then
		return server.serverCenter:CallDtbMod("war", "raidMgr", "Call", raidtype, funcname, dbid, ...)
	else
		return server.serverCenter:CallLocalMod("war", "raidMgr", "Call", raidtype, funcname, dbid, ...)
	end
end

function RaidMgr:onLogout(player)
	self:Exit(player.dbid)
end

server.SetCenter(RaidMgr, "raidMgr")
return RaidMgr