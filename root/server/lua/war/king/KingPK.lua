local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local KingPK = {}

function KingPK:Init()
	self.type = server.raidConfig.type.KingPK
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, KingPK)
end

function KingPK:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("KingPK:Enter player is in fighting", dbid)
		return false
	end

	local kingmap = datas.exinfo.kingmap
	local fighting = server.NewFighting()
	local KingBaseConfig = server.configCenter.KingBaseConfig
	local fbid = KingBaseConfig.fbid
	info.players = {}
	info.targets = {}
	fighting:InitPvP(fbid, self)
	for i, data in ipairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
		kingmap:SetFighting(playerid, true)
	end
	for i, data in ipairs(datas.exinfo.target.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.targets, playerid)
		fighting:AddPlayer(FightConfig.Side.Def, playerid, data, i)
		kingmap:SetFighting(playerid, true)
	end
	info.kingmap = kingmap
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function KingPK:Exit(dbid)
	server.kingCenter:SetFighting(dbid, false)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		-- if info.kingmap then
		-- 	for _,playerid in ipairs(info.players) do
		-- 		info.kingmap:SetFighting(playerid, false)
		-- 	end
		-- 	for _,targetid in ipairs(info.targets) do
		-- 		info.kingmap:SetFighting(targetid, false)
		-- 	end
		-- 	info.kingmap.map:BroadcastFightingChange()
		-- end
		info.iswin = nil
	end
	return true
end

function KingPK:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			
			info.kingmap:PKResult(iswin, info.players, info.targets)
			info.fighting = nil
			local msg = {}
			local targetmsg = {}
			if iswin then
				msg.result = 1
				msg.rewards = {}
				targetmsg.result = 0
				targetmsg.rewards = {}
			else
				msg.result = 0
				msg.rewards = {}
				targetmsg.result = 1
				targetmsg.rewards = {}
			end
			
			-- for _,playerid in ipairs(info.players) do
			-- 	server.sendReqByDBID(playerid, "sc_raid_chapter_boss_result", msg)
			-- end
			-- for _,targetid in ipairs(info.targets) do
			-- 	server.sendReqByDBID(targetid, "sc_raid_chapter_boss_result", targetmsg)
			-- end
			self.fblist[dbid] = nil
		end
	end
end

function KingPK:GetReward(dbid)
end

server.SetCenter(KingPK, "kingPK")
return KingPK