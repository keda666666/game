local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local KingCityFb = {}

function KingCityFb:Init()
	self.type = server.raidConfig.type.KingCity
	self.fblist = {}
	server.raidMgr:SetRaid(self.type, KingCityFb)
end

function KingCityFb:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	-- if info.fighting then
	-- 	lua_app.log_error("KingCityFb:Enter player is in fighting", dbid)
	-- 	return false
	-- end

	local kingcity = datas.exinfo.kingcity
	local fbid = datas.exinfo.fbid
	local fighting = server.NewFighting()
	if not next(kingcity.guards) then
		-- 防守玩家是空就打防守怪物
		fighting:Init(fbid, self, table.wcopy(kingcity.monsterhps))
	else
		-- 打防守玩家
		fighting:InitPvP(fbid, self)
		fighting.pvp = false
		for i, guardData in pairs(kingcity.guards) do
			fighting:AddPlayer(FightConfig.Side.Def, nil, guardData, i)
		end
	end
	info.players = {}
	for i, data in pairs(datas.playerlist) do
		local playerid = data.playerinfo.dbid
		table.insert(info.players, playerid)
		fighting:AddPlayer(FightConfig.Side.Attack, playerid, data, i)
		kingcity.map:SetFighting(playerid, true)
	end
	info.kingcity = kingcity
	info.fighting = fighting
	info.attackercamp = datas.exinfo.attackercamp
	info.attackers = datas.playerlist
	fighting:StartRunAll()
	return true
end

function KingCityFb:Exit(dbid)
	server.kingCenter:SetFighting(dbid, false)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		-- if info.kingcity then
		-- 	for _, playerid in ipairs(info.players) do
		-- 		info.kingcity.map:SetFighting(playerid, false)
		-- 	end
		-- 	info.kingcity.map:BroadcastFightingChange()
		-- end
		info.iswin = nil
		self.fblist[dbid] = nil
	end
	return true
end

function KingCityFb:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			
			local poshps = info.fighting:GetHPs(FightConfig.Side.Def)
			info.kingcity:AttackResult(iswin, dbid, info.attackercamp, info.attackers, poshps)
			info.fighting = nil
			local msg = {}
			if iswin then
				msg.result = 1
				msg.rewards = {}
			else
				msg.result = 0
				msg.rewards = {}
			end
			
			-- for _, playerid in ipairs(info.players) do
			-- 	server.sendReqByDBID(playerid, "sc_raid_chapter_boss_result", msg)
			-- end
		end
	end
end

function KingCityFb:GetReward(dbid)
end

server.SetCenter(KingCityFb, "kingCityFb")
return KingCityFb