local server = require "server"
local lua_app = require "lua_app"
local ContestBossBase = require "boss.ContestBossBase"

local GuildBoss = ContestBossBase:new()

function GuildBoss:Init()
	self.type = server.raidConfig.type.GuildBoss
	self:Load()
end

function GuildBoss:BossEnterHook()
	self.entertimetmp = lua_app.now()
end

function GuildBoss:BossDeadHook()
	self.status = 4
	self.statuschangetime = lua_app.now()
	self:BroadcastReq(self:DecorateSproto("sc_contestboss_info"), { status = self.status, changetime = self.statuschangetime })
	if self.rebornTimer then
		lua_app.del_local_timer(self.rebornTimer)
		self.rebornTimer = nil
	end
	local intervaltime = server.configCenter.GuildBossBaseConfig.bossrevivetime * 1000
	self.rebornTimer = lua_app.add_update_timer(intervaltime, self, "BossReborn")
	self.entertime = self.entertimetmp
	self.deadtime = lua_app.now()
end

function GuildBoss:CloseHook()
	if not self.entertimetmp or not self.deadtime then return end
	if self.entertimetmp > self.deadtime then
		if lua_app.now() - self.entertimetmp > 3600 then
			self.entertime = self.entertimetmp
			self.deadtime = lua_app.now()
		end
	end
end

function GuildBoss:HotFix()
	print("GuildBoss:HotFix--------", self.status)
end

function GuildBoss:BossReborn()
	if self.status == 4 then
		self:BossEnter()
	end
end

function GuildBoss:SendRankRewards()
	local ranks = {}
	for dbid, v in pairs(self.damagelist) do
		ranks[#ranks+1] = {
			dbid = dbid,
			damage = v.damage,
		}
	end
	table.sort(ranks, function(priordata, laterdata)
		return priordata.damage > laterdata.damage
	end)

	local GuildBossRankRewardConfig = server.configCenter.GuildBossRankRewardConfig
	local cfg = self.baseConfig.ContestBaseConfig
	for rank, rankdata in ipairs(ranks) do
		local player = server.playerCenter:GetPlayerByDBID(rankdata.dbid)
		if player then
			local dropcfg = table.matchValue(GuildBossRankRewardConfig, function(childcfg)
				return childcfg.rank - rank
			end) or GuildBossRankRewardConfig[#GuildBossRankRewardConfig]
			rankdata.rank = rank
			rankdata.rewards = server.dropCenter:DropGroup(dropcfg.reward)
			if rank == 1 then
				local maildes = string.format(cfg.maildes, self.first.name, self.first.name)
				player.server.mailCenter:SendMail(rankdata.dbid, cfg.mailtitle, maildes, rankdata.rewards, self:GetYunbaoRecordType())
			else
				player.server.mailCenter:SendMail(rankdata.dbid, cfg.mailtitle2, cfg.maildes2, rankdata.rewards, self:GetYunbaoRecordType())
			end
		end
	end
	self:SendLogicsMod(self:GetBossCenterDescribe(), "SendShowRewards", ranks)
end

function GuildBoss:GetYunbaoRecordType()
	return server.baseConfig.YuanbaoRecordType.GuildBoss
end

function GuildBoss:GetConfig(cfgname)
	return server.configCenter.GuildBossBaseConfig
end

function GuildBoss:GenFbid()
	self.fbid = self.fbid or server.configCenter.GuildBossBaseConfig.fbid
	if not self.deadtime or not self.entertime then return end
	local usetime = self.deadtime - self.entertime
	if usetime > 0 then
		for _, v in pairs(server.configCenter.GuildBossBaseConfig.adjusttime) do
			if v[1] <= usetime and usetime < v[2] then
				self.fbid = self.fbid + v[3]
			end
		end
	end
	self.fbid = math.max(math.min(self.fbid, server.configCenter.GuildBossBaseConfig.maxFBLv), server.configCenter.GuildBossBaseConfig.minFBLv)
	print("GuildBoss:GenFbid----", self.deadtime, self.entertime, self.fbid)
end

function GuildBoss:GetSprotoDescribe()
	return "guildboss"
end

function GuildBoss:GetBossCenterDescribe()
	return "guildBossMgr"
end

server.SetCenter(GuildBoss, "guildBoss")
return GuildBoss