local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"
local ItemConfig = require "resource.ItemConfig"

local VIPBoss = {}
local bosspos = 8

function VIPBoss:Init()
	self.type = server.raidConfig.type.VIPBoss
	self.playerinfos = {}
	server.raidMgr:SetRaid(self.type, VIPBoss)
end

function VIPBoss:Enter(dbid, datas)
	local index = datas.exinfo.index
	local cfg = server.configCenter.VipBossConfig[index]
	local info = self.playerinfos[dbid]
	if not info then
		info = {}
		self.playerinfos[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("VIPBoss:Enter player is in fighting", dbid)
		return false
	end
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local cacheinfos = player.cache.vipboss.list[index]()
	local vip = player.cache.vip()
	if vip < cfg.viplvlimit and player.cache.level() < cfg.levelLimit then
		lua_app.log_error("VIPBoss:Enter level, vip", player.cache.level(), vip, dbid, index)
		return false
	end
	if cacheinfos and cacheinfos.daycount >= cfg.vipCount[vip] then
		lua_app.log_error("VIPBoss:Enter daycount, vip", cacheinfos.daycount, vip, dbid, index)
		return false
	end
	if not player:PayReward(cfg.cost.type, cfg.cost.id, cfg.cost.count, server.baseConfig.YuanbaoRecordType.VIPBoss, "VIPBoss:PK")
		and not player:PayReward(cfg.costgold.type, cfg.costgold.id, cfg.costgold.count, server.baseConfig.YuanbaoRecordType.VIPBoss, "VIPBoss:PK") then
		lua_app.log_error("VIPBoss:Enter no enough money", player.cache.yuanbao(), dbid, index)
		return false
	end
	local rewardslist = {
		server.dropCenter:DropGroup(cfg.suredropId),
		server.dropCenter:DropGroup(cfg.dropId)
	}
	local rewards = ItemConfig:MergeRewardsList(rewardslist)
	if cacheinfos and cacheinfos.count >= cfg.needsuccess then
		-- 扫荡
		player.vipBoss:AddCount(index)
		player:GiveRewardAsFullMailDefault(rewards, "至尊BOSS", server.baseConfig.YuanbaoRecordType.VIPBoss)
		return false
	end
	-- 战斗
	local fighting = server.NewFighting()
	fighting:Init(cfg.fbid, self)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.fighting = fighting
	info.index = index
	info.rewards = rewards
	fighting:StartRunAll()
	return true
end

function VIPBoss:Exit(dbid)
	local info = self.playerinfos[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function VIPBoss:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.playerinfos[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		local msg = {}
		if iswin then
			msg.result = 1
			msg.rewards = info.rewards
			local player = server.playerCenter:GetPlayerByDBID(dbid)
			player.vipBoss:AddCount(info.index)
		else
			msg.result = 0
			msg.rewards = {}
		end
		info.iswin = iswin
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function VIPBoss:GetReward(dbid)
	local info = self.playerinfos[dbid]
	local rewards = info.rewards
	if rewards and info.iswin then
		info.rewards = nil
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player:GiveRewardAsFullMailDefault(rewards, "至尊BOSS", server.baseConfig.YuanbaoRecordType.VIPBoss)
	end
end

server.SetCenter(VIPBoss, "vipBoss")
return VIPBoss
