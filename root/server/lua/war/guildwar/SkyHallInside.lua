local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local BaseBarrier = require "guildwar.BaseBarrier"
local GuildwarConfig = require "resource.GuildwarConfig"


local SkyHallInside = oo.class(BaseBarrier)
local _bosspos = 8
local _ThroughNumOfGuild = 3

function SkyHallInside:ctor(barrierId, guildwarMap)
end

function SkyHallInside:Release()
end

function SkyHallInside:Init()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.guards = {}
	self.maxhp = 0
	self.currhp = 0
	self.maxShield = GuildBattleBaseConfig.s_shieldvalue
	self.shield = self.maxShield
	self.shielddroptime = 0
	self.recovertime = 0

	self.bosssurvival = true
	self.throughguild = {}

	local GuildBattleSlongConfig = server.configCenter.GuildBattleSlongConfig
	self.fblv = self:GetFbLevel(GuildBattleSlongConfig)

	self.fbid = GuildBattleSlongConfig[self.fblv].fbid
	local instancecfg = server.configCenter.InstanceConfig[self.fbid] or server.configCenter.Instance2SConfig[self.fbid]
	for _, monsterinfo in pairs(instancecfg.initmonsters) do
		if monsterinfo.pos == _bosspos then
			local monconfig = server.configCenter.MonstersConfig[monsterinfo.monid] or server.configCenter.Monsters2SConfig[monsterinfo.monid]
			self.maxhp = self.maxhp + monconfig.hp
		end
	end
	self.currhp = self.maxhp
	self:RegisteFunc(GuildwarConfig.Datakeys[self.barrierId])
end

--发送进入消息
function SkyHallInside:SendEnterMsg(dbid)
	self:SendBossMsg(dbid)
	self:SendPlayerRankDataMsg(dbid, "skyhallinside_injureRank")
	self:SendGuildRankDataMsg(dbid, "skyhallinside_injureRank")
	self:SendGuildDataMsg(dbid)
	self:SendThroughGuild(dbid)
end

function SkyHallInside:GendefaultData(dbid)
	self:UpdatePlayer(dbid, {
			skyhallinside_injure = 0
		})
end

--每秒定时器
function SkyHallInside:DoSecond(now)
	if not self.opening then return end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.shielddroptime = self.shielddroptime or now + GuildBattleBaseConfig.s_losstime
	if now > self.shielddroptime and self.bosssurvival then
		self.shielddroptime = now + GuildBattleBaseConfig.s_losstime
		self:DropShield(GuildBattleBaseConfig.s_autoloss)
	end
end

--进攻
function SkyHallInside:AttackHook(fightexinfo)
	--进攻掉护盾
	self:DropShield(server.configCenter.GuildBattleBaseConfig.s_attackloss)
	return true
end

--攻击检测
function SkyHallInside:CanAttack(dbid)
	if not BaseBarrier.CanAttack(self, dbid) then
		return false
	end
	if not self.bosssurvival then
		return false
	end
	return true
end

--战斗结果
function SkyHallInside:AttackResult(iswin, dbid, attackers, poshps)
	self.currhp = poshps[_bosspos]
	self.monsterhps = {
		[_bosspos] = self.currhp
	}
	local GuildBattlePointsConfig = server.configCenter.GuildBattlePointsConfig

	local attackerName = {}
	--处理玩家伤害
	for _, data in ipairs(attackers) do
		local injure = 0
		for _, entitydata in pairs(data.entitydatas) do
			injure = injure + (entitydata.hit or 0)
		end
		local range = math.ceil(injure / self.maxhp * 100)
		local rangeCfg = table.matchValue(GuildBattlePointsConfig, function(comparedata)
			return comparedata.range - range
		end) or GuildBattlePointsConfig[#GuildBattlePointsConfig]
		
		self:UpdatePlayer(data.playerinfo.dbid, {
				skyhallinside_injure = injure,
				score = rangeCfg.points,
		})
		table.insert(attackerName, data.playerinfo.name)
	end

	if self.currhp <= 0 then
		self.bosssurvival = false
		local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
		self:Notice(GuildBattleBaseConfig.killNotice, string.format("[%s]", table.concat(attackerName, "],[")))
		self:GenerateThroughGuild()
	else
		for _, data in ipairs(attackers) do
			self.guildwarMap:Reborn(data.playerinfo.dbid)
		end
	end
	--广播boss状态
	self:BroadcastBossMsg()
end

--生成通关的帮派
function SkyHallInside:GenerateThroughGuild()
	local injurerankdatas = self:GetGuildRankdata("skyhallinside_injureRank")
	local parlayCount = 0
	self.parlayinfo = {}
	for __, guilddata in ipairs(injurerankdatas) do
		self.throughguild[guilddata.guildid] = true
		table.insert(self.parlayinfo, {
			guildId = guilddata.guildid,
			guildName = guilddata.guildname,
			serverId = guilddata.serverid,
		})
		parlayCount = parlayCount + 1
		if parlayCount == _ThroughNumOfGuild then break end
	end

	--积分排行
	local scorerankdata = self:GetGuildRankdata("scoreRank")
	for __, guilddata in ipairs(scorerankdata) do
		if parlayCount == _ThroughNumOfGuild then break end
		if not self.throughguild[guilddata.guildid] then
			table.insert(self.parlayinfo, {
				guildId = guilddata.guildid,
				guildName = guilddata.guildname,
				serverId = guilddata.serverid,
			})
			self.throughguild[guilddata.guildid] = true
			parlayCount = parlayCount + 1
		end
	end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local interval = GuildBattleBaseConfig.sready_time
	self.countdown = lua_app.now() + interval
	self:SendThroughGuild()

	--广播通关帮会玩家
	local playerlist = self:GetPlayerlist()
	for dbid, playerdata in pairs(playerlist) do
		if self.throughguild[playerdata.guildid] then
			self:SendPlayerDataMsg(dbid)
		end
	end
	self.guildwarMap:UltimateFight(self.countdown)
end

--检查进入下一关
function SkyHallInside:Checkpoint(dbid)
	if not BaseBarrier.Checkpoint(self, dbid) then
		lua_app.log_info("SkyHallInside:Checkpoint BaseBarrier return false.")
		return false
	end
	if self.bosssurvival then
		print("SkyHallInside:Checkpoint boss is survival.")
		return false
	end

	local playerdata = self:GetPlayerData(dbid)
	if not self.throughguild[playerdata.guildid] then
		return false
	end
	return true
end

--减少护盾
function SkyHallInside:DropShield(dropval)
	self.shield = math.max(self.shield - dropval, 0)
	if self.shield > 0 then
		self:BroadcastBossMsg()
		return
	end
	if self.shieldtimer then return end

	local recorvertime = server.configCenter.GuildBattleBaseConfig.s_shieldtime
	self.recovertime = lua_app.now() + recorvertime
	self.shieldtimer = lua_app.add_timer(recorvertime * 1000, function()
		self.shieldtimer = nil
		self.shield = self.maxShield
		self:DropShield(0)
	end)
	self:BroadcastBossMsg()
end

function SkyHallInside:GetExconfig()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local resetattr = {
		[_bosspos] = {
			[EntityConfig.Attr.atDamageReductionPerc] = GuildBattleBaseConfig.s_reductionvalue * 100
		}
	}

	local exconfig = {
		[_bosspos] = {
			[EntityConfig.SpecAttr.satShield] = self.shield,
			[EntityConfig.SpecAttr.satMaxShield] = self.maxShield,
		}
	}

	if self.shield > 0 then
		return resetattr, exconfig
	else
		return nil, exconfig
	end
end

--战斗奖励
function SkyHallInside:GetReward(iswin, poshps)
	local GuildBattleSlongConfig = server.configCenter.GuildBattleSlongConfig
	local rewards = server.dropCenter:DropGroup(GuildBattleSlongConfig[self.fblv].l_inreward)
	local result = iswin and 1 or 3
	return rewards, result
end

--Boss数据
function SkyHallInside:GetBossMsgData()
	local data = {
		barrierId = self.barrierId,
		shield = math.ceil(self.shield /self.maxShield  * 100),
		hp = math.ceil(self.currhp / self.maxhp * 100),
		recovertime = self.recovertime,
	}
	return data
end

--发送帮会伤害排行
function SkyHallInside:SendGuildRank(dbid)
	if not self.opening then return end 
	server.sendReqByDBID(dbid, "sc_guildwar_all_guild_rank_info", {
			rankinfos = self:GetGuildRankMsgData("skyhallinside_injureRank"),
		})
end

--发送玩家排行
function SkyHallInside:SendPersonRank(dbid)
	if not self.opening then return end 
	server.sendReqByDBID(dbid, "sc_guildwar_all_player_rank_info", {
			killrank = self:GetPlayerRankMsgData("killRank", 160),
			injurerank = self:GetPlayerRankMsgData("skyhallinside_injureRank", 160),
			scorerank = self:GetPlayerRankMsgData("scoreRank", 160),
		})
end

--补充帮会信息
function SkyHallInside:AppendGuildMsgData(data, guildinfo)
	data.rankData = {
		injure = guildinfo.skyhallinside_injure,
		injureRank = guildinfo.skyhallinside_injureRank,
	}
end

--发送通关帮会
function SkyHallInside:SendThroughGuild(dbid)
	if self.bosssurvival then return end
	if dbid then
		self:SendReqByInside(dbid, "sc_guildwar_enter_dragon_guild", {
			guildinfos = self.parlayinfo,
			countdown = self.countdown or 0,
		})
	else
		self:Broadcast("sc_guildwar_enter_dragon_guild", {
			guildinfos = self.parlayinfo,
			countdown = self.countdown or 0,
		})
	end
end

function SkyHallInside:Shut()
	BaseBarrier.Shut(self)
	local GuildBattleRewardConfig = server.configCenter.GuildBattleRewardConfig
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local title = GuildBattleBaseConfig.personalIntegralHead
	local context = GuildBattleBaseConfig.personalIntegralContext
	local rankdatas = self:GetPlayerRankdata("skyhallinside_injureRank")
	for rank, playerdata in ipairs(rankdatas) do
		if playerdata.skyhallinside_injure > 0 then
			local rewardCfg = GuildBattleRewardConfig[rank] or GuildBattleRewardConfig[#GuildBattleRewardConfig]
			local rewards
			if self.bosssurvival then
				rewards = server.dropCenter:DropGroup(rewardCfg.rewards)
			else
				rewards = server.dropCenter:DropGroup(rewardCfg.reward)
			end
			self:SendMail(playerdata.dbid, title, string.format(context, rank), rewards, server.baseConfig.YuanbaoRecordType.Guildwar)
			self.warReport:AddRewards(playerdata.dbid, rewards)
			print("SkyHallInside:Shut----------", rank, playerdata.dbid)
		end
	end
end

--广播Boss消息
function SkyHallInside:BroadcastBossMsg()
	self:Broadcast("sc_guildwar_boss_info", self:GetBossMsgData())
end

--发送Boss消息
function SkyHallInside:SendBossMsg(dbid)
	self:SendReqByInside(dbid, "sc_guildwar_boss_info", self:GetBossMsgData())
end

return SkyHallInside