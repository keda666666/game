local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local BaseBarrier = require "guildwar.BaseBarrier"
local GuildwarConfig = require "resource.GuildwarConfig"

local SouthDoor = oo.class(BaseBarrier)
local _bosspos = 8

function SouthDoor:ctor(barrierId, guildwarMap)
end

function SouthDoor:Release()
end

function SouthDoor:Init()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.guards = {}
	self.maxhp = 0
	self.currhp = 0
	self.maxShield = GuildBattleBaseConfig.n_shieldvalue
	self.shield = self.maxShield
	self.recovertime = 0
	self.bosssurvival = true
	self.fbid = server.configCenter.GuildBattleBaseConfig.n_fbid

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
function SouthDoor:SendEnterMsg(dbid)
	self:SendReqByInside(dbid, "sc_guildwar_boss_info", self:GetBossMsgData())
	self:SendGuildRankDataMsg(dbid, "southdoor_injureRank")
	self:SendGuildDataMsg(dbid)
end

--加入排行
function SouthDoor:GendefaultData(dbid)
	self:UpdatePlayer(dbid, {
		southdoor_injure = 0,
		southdoor_attacktime = 0,
	})
end

--每秒定时器
function SouthDoor:DoSecond(now)
	if not self.opening then return end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.shielddroptime = self.shielddroptime or now + GuildBattleBaseConfig.n_losstime
	if now > self.shielddroptime and self.bosssurvival then
		self.shielddroptime = now + GuildBattleBaseConfig.n_losstime
		self:DropShield(GuildBattleBaseConfig.n_autoloss)
	end
end

--进攻
function SouthDoor:AttackHook(fightexinfo)
	self:DropShield(server.configCenter.GuildBattleBaseConfig.n_attackloss)
	return true
end

--攻击检测
function SouthDoor:CanAttack(dbid)
	if not BaseBarrier.CanAttack(self, dbid) then
		return false
	end
	if not self.bosssurvival then
		return false
	end
	return true
end

--战斗结果
function SouthDoor:AttackResult(iswin, dbid, attackers, poshps)
	if not poshps[_bosspos] then
		print("SouthDoor:AttackResult---", iswin, dbid)
		table.ptable(attackers, 3)
		table.ptable(poshps, 3)
		return
	end
	self.currhp = poshps[_bosspos]
	self.monsterhps = {
		[_bosspos] = self.currhp
	}
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig

	--处理玩家伤害
	local attackerName = {}
	for __, data in ipairs(attackers) do
		local injure = 0
		for _, entitydata in pairs(data.entitydatas) do
			injure = injure + (entitydata.hit or 0)
		end
		self:UpdatePlayer(data.playerinfo.dbid, {
			southdoor_injure = injure,
			southdoor_attacktime = lua_app.now() + GuildBattleBaseConfig.n_cd,
		})
		table.insert(attackerName, data.playerinfo.name)
	end

	if self.currhp <= 0 then
		self.bosssurvival = false
		self:BroadcastPlayerDataMsg()
		self:Notice(GuildBattleBaseConfig.gateDieNotice, string.format("[%s]", table.concat(attackerName, "],[")))
	end

	self:BroadcastBossMsg()
end

--检查进入下一关
function SouthDoor:Checkpoint(dbid)
	if not BaseBarrier.Checkpoint(self, dbid) then
		return false
	end
	if self.bosssurvival then
		lua_app.log_info(">>SouthDoor:Checkpoint boss is alive.", self.bosssurvival)
		return false
	end
	return true
end

--减少护盾
function SouthDoor:DropShield(dropval)
	self.shield = math.max(self.shield - dropval, 0)
	if self.shield > 0 then
		self:BroadcastBossMsg()
		return
	end
	if self.shieldtimer then return end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	self.recovertime = lua_app.now() + GuildBattleBaseConfig.n_shieldtime
	self.shieldtimer = lua_app.add_timer(GuildBattleBaseConfig.n_shieldtime * 1000, function()
		self.shieldtimer = nil
		self.shield = self.maxShield
		self:DropShield(0)
	end)
	self:BroadcastBossMsg()
end

--获取战斗配置
function SouthDoor:GetExconfig()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local resetattr = {
		[_bosspos] = {
			[EntityConfig.Attr.atDamageReductionPerc] = GuildBattleBaseConfig.n_reductionvalue * 100
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
function SouthDoor:GetReward(iswin, poshps)
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local rewards
	if poshps[_bosspos] > 0 then
		return server.dropCenter:DropGroup(GuildBattleBaseConfig.n_lossreward), 1
	else
		return server.dropCenter:DropGroup(GuildBattleBaseConfig.n_winreward), 1
	end
end

--Boss数据
function SouthDoor:GetBossMsgData()
	local data = {
		barrierId = self.barrierId,
		shield = math.ceil(self.shield /self.maxShield  * 100),
		hp = math.ceil(self.currhp / self.maxhp * 100),
		recovertime = self.recovertime,
	}
	return data
end

--补充玩家数据
function SouthDoor:AppendPlayerMsgData(data, playerinfo)
	data.attacktime = playerinfo.southdoor_attacktime
end

--补充帮会信息
function SouthDoor:AppendGuildMsgData(data, guildinfo)
	data.rankData = {
		injure = guildinfo.southdoor_injure,
		injureRank = guildinfo.southdoor_injureRank,
	}
end

--广播Boss消息
function SouthDoor:BroadcastBossMsg()
	self:Broadcast("sc_guildwar_boss_info", self:GetBossMsgData())
end

function SouthDoor:PrintDebug(dbid)
	BaseBarrier.PrintDebug(self, dbid)
	table.ptable(self, 1)
end

return SouthDoor

