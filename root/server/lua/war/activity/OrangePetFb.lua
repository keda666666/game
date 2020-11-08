local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local OrangePetFb = {}

function OrangePetFb:Init()
	self.type = server.raidConfig.type.OrangePetFb
	self.fblist = {}
	self.rewards = {}
	server.raidMgr:SetRaid(self.type, OrangePetFb)
end

function OrangePetFb:Enter(dbid, datas)
	local info = self.fblist[dbid]
	if not info then
		info = {}
		self.fblist[dbid] = info
	end
	-- if info.fighting then
	-- 	lua_app.log_error("OrangePetFb:Enter player is in fighting", dbid)
	-- 	return false
	-- end
	local activityId = datas.exinfo.activityId
	local gid = datas.exinfo.gid
	local petCfg = server.configCenter.ActivityType22Config[activityId][gid]

	local fbid = petCfg.fbid
	local fighting = server.NewFighting()
	fighting:Init(fbid, self)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.fighting = fighting
	info.activityId = activityId
	info.gid = gid
	info.rewards = info.rewards or server.dropCenter:DropGroup(petCfg.rewards)
	fighting:StartRunAll()
	return true
end

function OrangePetFb:Exit(dbid)
	local info = self.fblist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
		self.fblist[dbid] = nil
	end
	return true
end

function OrangePetFb:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.fblist[dbid]
		if info then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
			info.iswin = iswin
			local msg = {}
			if iswin then
				msg.result = 1
				msg.rewards = info.rewards
				server.serverCenter:SendLocalMod("world", "activityMgr", "onFightResult", dbid, info.activityId)
			else
				msg.result = 0
				msg.rewards = {}
			end
			server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
		end
	end
end

function OrangePetFb:GetReward(dbid)
	local info = self.fblist[dbid]
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not info and not info.rewards and not info.iswin then return end
	info.rewards = nil
	info.iswin = nil
	player.activityPlug:ActivityReward(info.activityId, info.gid)
end

server.SetCenter(OrangePetFb, "OrangePetFb")
return OrangePetFb