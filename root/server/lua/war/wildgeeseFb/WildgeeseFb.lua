local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local WildgeeseFb = {}

function WildgeeseFb:Init()
	self.type = server.raidConfig.type.WildgeeseFb
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, WildgeeseFb)
end

function WildgeeseFb:Enter(dbid, packinfo)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local wildgeeseFb = player.cache.wildgeeseFb()
	local fubenNo = wildgeeseFb.layer + 1
	local wildgeeseFbData = server.configCenter.WildgeeseFbConfig[fubenNo]
	if not wildgeeseFbData then return end
	-- if wildgeeseFbData.degree ~= wildgeeseFb.hard then return
	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end

	info.fubenNo = fubenNo
	local fighting = server.NewFighting()

	fighting:Init(wildgeeseFbData.fbId, self, nil, server.configCenter.InstanceConfig[wildgeeseFbData.fbId].initmonsters)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, packinfo)
	info.fighting = fighting
	info.rewards = info.rewards or table.wcopy(wildgeeseFbData.firstAward)
	fighting:StartRunAll()
	return 1
end

function WildgeeseFb:Exit(dbid)--强行退出 ，没奖励 当失败
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

function WildgeeseFb:FightResult(retlist)--round 回合数战斗结束后吧奖励列表显示给玩家看 
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
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function WildgeeseFb:GetReward(dbid)
	local info = self.playerlist[dbid]
	local rewards = info.rewards
	if rewards and info.iswin then
		info.rewards = nil
		info.iswin = nil

		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player.cache.wildgeeseFb.layer = info.fubenNo
		local wildgeeseFb = player.cache.wildgeeseFb()
		self:upMsg(player.dbid, wildgeeseFb)
		player:GiveRewardAsFullMailDefault(rewards, "大雁塔", server.baseConfig.YuanbaoRecordType.WildgeeseFb, "大雁塔"..info.fubenNo)
		player.activityPlug:onDoTarget()
		player.task:onEventCheck(server.taskConfig.ConditionType.WildgeeseFbLayer)
		player.enhance:AddPoint(13, 1)
	end
end

function WildgeeseFb:upMsg(dbid, wildgeeseFb)
	local msg = {
		hard = wildgeeseFb.hard,
		layer = wildgeeseFb.layer,
	}
	server.sendReqByDBID(dbid, "sc_fuben_wildgeeseFb_info", msg)
end

function WildgeeseFb:onInitClient(player)
	if server.serverCenter:IsCross() then return end
	local wildgeeseFb = player.cache.wildgeeseFb()
	self:upMsg(player.dbid, wildgeeseFb)
end

server.SetCenter(WildgeeseFb, "wildgeeseFb")
return WildgeeseFb