local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local Qualifying = {}

function Qualifying:Init()
	self.type = server.raidConfig.type.Qualifying
	self.qualifyingList = {}
	server.raidMgr:SetRaid(self.type, Qualifying)
end

function Qualifying:Enter(dbid, datas)
	local baseConfig = server.configCenter.XianDuMatchBaseConfig
	
	local fighting = server.NewFighting()

	local index = datas.atkDbid or datas.defDbid or dbid
	fighting:InitPvP(baseConfig.fbid, self)
	local aFightData = server.qualifyingCenter:GetFightData(dbid)
	local dFightData = server.qualifyingCenter:GetFightData(datas.enemy)

	fighting:AddPlayer(FightConfig.Side.Def, datas.defDbid, dFightData)
	local playerid = datas.atkDbid
	if not datas.atkDbid and not datas.defDbid then
		playerid = dbid
	end
	fighting:AddPlayer(FightConfig.Side.Attack, playerid, aFightData)
	if not datas.atkDbid and not datas.defDbid then
		fighting:SetSilence()
	end
	local info = self.qualifyingList[index] or {}
	info.fighting = fighting
	info.play = dbid
	info.enemy = datas.enemy
	info.rank = datas.rank
	info.fightType = datas.fightType
	if datas.fightType == 2 then
		info.the = datas.the
		info.field = datas.field
	else

	end

	self.qualifyingList[index] = info
	fighting:StartRunAll()
	return true
end

function Qualifying:Exit(dbid)
	local info = self.qualifyingList[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function Qualifying:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.qualifyingList[dbid]
		if info then
			info.fighting:BroadcastFighting()
			
			if info.fightType == 1 then
				server.qualifyingCenter:SetPreliminaryRes(info.rank,info.play, info.enemy, iswin, true)
			elseif info.fightType == 2 then
				if info.play ~= dbid then
					iswin = not iswin
				end
				server.qualifyingCenter:SetKnockoutRes(info.the, info.rank, info.field, info.fighting.record, iswin)
			end
			
			info.fighting:Release()
			self.qualifyingList[dbid] = nil
		end
		
	end
end

function Qualifying:GetReward(dbid)
end

server.SetCenter(Qualifying, "qualifying")
return Qualifying