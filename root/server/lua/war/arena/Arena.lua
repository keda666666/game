local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local Arena = {}

function Arena:Init()
	self.type = server.raidConfig.type.Arena
	self.arenalist = {}
	server.raidMgr:SetRaid(self.type, Arena)
end

function Arena:Enter(dbid, datas)
	local ArenaConfig = server.configCenter.ArenaConfig
	local ArenaRobotConfig = server.configCenter.ArenaRobotConfig
	local targetrank = datas.exinfo.targetrank
	local targetid = datas.exinfo.targetid
	local info = self.arenalist[dbid]
	if not info then
		info = {}
		self.arenalist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("Arena:Enter player is in fighting", dbid)
		return false
	end

	local fighting = server.NewFighting()
	if not targetid then
		-- 打机器人
		local robot = ArenaRobotConfig[targetrank]
		if robot then
			local attrs = {}
			local attr = table.wcopy(robot)
			attrs[0] = attr
			fighting:Init(ArenaConfig.fbId, self, nil, robot.initmonsters, attrs)
			fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
		else
			lua_app.log_error("Arena:Enter no arena robot", targetrank)
			return false
		end
	else
		fighting:InitPvP(ArenaConfig.fbId, self)
		fighting:AddPlayer(FightConfig.Side.Def, nil, datas.exinfo.targetpack)
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	end
	info.targetrank = targetrank
	info.targetid = targetid
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function Arena:Exit(dbid)
	local info = self.arenalist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function Arena:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.arenalist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			if player then
				player.arena:DoPKResult(iswin, info.targetrank)
			end
		end
	end
end

function Arena:GetReward(dbid)
end

server.SetCenter(Arena, "arena")
return Arena