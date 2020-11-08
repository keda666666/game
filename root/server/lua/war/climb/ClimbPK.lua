local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local ClimbPK = {}

function ClimbPK:Init()
	self.type = server.raidConfig.type.ClimbPK
	self.fblist = {}
	self.resultlist = {}
	server.raidMgr:SetRaid(self.type, ClimbPK)
end

function ClimbPK:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("ClimbPK:Enter player is in fighting", dbid)
		return false
	end

	local layer = datas.exinfo.layer
	local fighting = server.NewFighting()
	local ClimbTowerConfig = server.configCenter.ClimbTowerConfig[layer.index]
	local targetdatas = datas.exinfo.target
	if targetdatas then
		local fbid = ClimbTowerConfig.pkfbid
		fighting:InitPvP(fbid, self)
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)

		local targetid = targetdatas.playerinfo.dbid
		fighting:AddPlayer(FightConfig.Side.Def, targetid, targetdatas)
		layer:SetFighting(targetid, true)
	else
		local fbid = ClimbTowerConfig.fbid
		fighting:Init(fbid, self)
		fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
		layer:SetMonFighting(datas.exinfo.targetid, true, dbid)
	end
	
	layer:SetFighting(dbid, true)
	info.targetid = datas.exinfo.targetid
	info.layer = layer
	info.fighting = fighting
	fighting:StartRunAll()
	return true
end

function ClimbPK:Exit(dbid)
	server.climbCenter:MapDo(dbid, "LayerDo", dbid, "SetFighting", dbid, false)
	local result = self.resultlist[dbid]
	if result then
		result.layer:PKUpDown(result.iswin, dbid, result.targetid)
	end
	self.resultlist[dbid] = nil
	local info = self.fblist[dbid]
	if info then
		
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function ClimbPK:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()

			local targetid = info.targetid
			self.resultlist[dbid] = {iswin = iswin, layer = info.layer, targetid = targetid}
			info.layer:PkResult(iswin, dbid, targetid)

			info.fighting = nil
			info.iswin = iswin
			local msg = {}
			local targetmsg = {}
			if iswin then
				msg.result = 2
				msg.rewards = {}
				targetmsg.result = 0
				targetmsg.rewards = {}
			else
				msg.result = 0
				msg.rewards = {}
				targetmsg.result = 2
				targetmsg.rewards = {}
			end
			
			server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
			if targetid > 10 then
				self.resultlist[targetid] = {iswin = not iswin, layer = info.layer, targetid = dbid}
				server.sendReqByDBID(info.targetid, "sc_raid_chapter_boss_result", targetmsg)
			end
			self.fblist[dbid] = nil
		end
	end
end

function ClimbPK:GetReward(dbid)
end

server.SetCenter(ClimbPK, "climbPK")
return ClimbPK