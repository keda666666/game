local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local GuildSprite = {}

function GuildSprite:Init()
	self.type = server.raidConfig.type.GuildSprite
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, GuildSprite)
end

function GuildSprite:Enter(dbid, datas)
	local fubenId = datas.exinfo.fubenId
	local dropId = datas.exinfo.dropId
	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("GuildSprite:Enter player is in fighting", dbid)
		return false
	end
	local fighting = server.NewFighting()
	fighting:Init(fubenId, self)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.fighting = fighting
	info.rewards = info.rewards or server.dropCenter:DropGroup(dropId)
	info.taskId = datas.exinfo.taskId
	fighting:StartRunAll()
	return true
end

function GuildSprite:Exit(dbid)
	local info = self.playerlist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function GuildSprite:FightResult(retlist, round)
	for dbid, iswin in pairs(retlist) do
		local info = self.playerlist[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		local msg = {}
		if iswin then
			msg.result = 1
			msg.rewards = info.rewards
		else
			msg.result = 0
			msg.rewards = {}
		end
		info.iswin = iswin
		msg.result = 1
		info.iswin = true
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function GuildSprite:GetReward(dbid)
	local info = self.playerlist[dbid]
	local rewards = info.rewards
	if rewards and info.iswin then
		info.rewards = nil
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.guild.guildMap:NotifyTaskComplete(info.taskId, rewards)	 --通知战斗胜利
	end
end

server.SetCenter(GuildSprite, "guildSprite")
return GuildSprite