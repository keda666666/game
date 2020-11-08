local server = require "server"
local lua_app = require "lua_app"
local ContestBossBase = require "boss.ContestBossBase"

local KfBoss = ContestBossBase:new()

function KfBoss:Init()
	self.type = server.raidConfig.type.KFBoss
	self:Load()
end

function KfBoss:BossDeadHook()
	self:DamageRankRewards()
	self.entertime = self.entertimetmp
	self.deadtime = lua_app.now()
end

function KfBoss:BossEnterHook()
	self.entertimetmp = lua_app.now()
end

function KfBoss:CloseHook()
	if not self.entertimetmp or not self.deadtime then return end
	if self.entertimetmp > self.deadtime then
		if lua_app.now() - self.entertimetmp > 3600 then
			self.entertime = self.entertimetmp
			self.deadtime = lua_app.now()
		end
	end
end

function KfBoss:SendReport(auctionrewards)
	for guildid, rewards in pairs(auctionrewards) do
		self.warReport:AddAuctionRewards(guildid, rewards)
	end
	self.warReport:BroadcastReport()
end

function KfBoss:DamageRankRewards()
	local damageRanks = {}
	for dbid, info in pairs(self.damagelist) do
		table.insert(damageRanks, {
				dbid = dbid,
				damage = info.damage,
				serverid = info.serverid,
			})
	end
	table.sort(damageRanks, function(currdata, backdata)
		return currdata.damage > backdata.damage
	end)

	local KfBossBaseConfig = server.configCenter.KfBossBaseConfig
	local KFBossRankRewardConfig = server.configCenter.KFBossRankRewardConfig
	local title = KfBossBaseConfig.mailtitle5
	local match = table.matchValue
	for rank, data in ipairs(damageRanks) do
		local rewardCfg = match(KFBossRankRewardConfig, function(cfg)
			return rank - cfg.rank
		end)

		local rewards = server.dropCenter:DropGroup(rewardCfg.reward)
		local context = string.format(KfBossBaseConfig.maildes5, rank)
		server.serverCenter:SendOneMod("logic", data.serverid, "mailCenter", "SendMail", 
			data.dbid, title, context, rewards, self:GetYunbaoRecordType())
		self.warReport:AddRewards(data.dbid, rewards)
	end
end

function KfBoss:GetYunbaoRecordType()
	return server.baseConfig.YuanbaoRecordType.KfBoss
end

function KfBoss:GetConfig(cfgname)
	return server.configCenter.KfBossBaseConfig
end

function KfBoss:GenFbid()
	self.fbid = self.fbid or server.configCenter.KfBossBaseConfig.fbid
	if not self.deadtime or not self.entertime then return end
	local usetime = self.deadtime - self.entertime
	if usetime > 0 then
		for _, v in pairs(server.configCenter.KfBossBaseConfig.adjusttime) do
			if v[1] <= usetime and usetime < v[2] then
				self.fbid = self.fbid + v[3]
			end
		end
	end
	self.fbid = math.max(math.min(self.fbid, server.configCenter.KfBossBaseConfig.maxFBLv), server.configCenter.KfBossBaseConfig.minFBLv)
	print("KfBoss:GenFbid----", self.deadtime, self.entertime, self.fbid)
end


function KfBoss:GetSprotoDescribe()
	return "kfboss"
end

function KfBoss:GetBossCenterDescribe()
	return "kfBossCenter"
end


server.SetCenter(KfBoss, "kfBoss")
return KfBoss