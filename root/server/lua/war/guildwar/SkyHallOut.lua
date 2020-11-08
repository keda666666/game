local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local EntityConfig = require "resource.EntityConfig"
local BaseBarrier = require "guildwar.BaseBarrier"
local GuildwarConfig = require "resource.GuildwarConfig"

local SkyHallOut = oo.class(BaseBarrier)

function SkyHallOut:ctor(barrierId, guildwarMap)
end

function SkyHallOut:Release()
end

function SkyHallOut:Init()
	self.throughplayers = {}
	self.throughMonitor = {}
	self:RegisteFunc(GuildwarConfig.Datakeys[self.barrierId])
end

local function _NewBossInfo()
	local data = {
		bossinfo = {
			[1001] = 0,
			[1002] = 0,
			[1003] = 0,
			[1004] = 0,
		},
		score = 0,
	}
	return data
end

function SkyHallOut:SendEnterMsg(dbid)
	self:SendBossDataMsg(dbid)
	self:SendGuildDataMsg(dbid)
	self:SendGuildRankDataMsg(dbid, "scoreRank")
end

--加入排行
function SkyHallOut:GendefaultData(dbid)
	self:UpdatePlayer(dbid, _NewBossInfo())
end

--每秒定时器
function SkyHallOut:DoSecond(now)
	if not self.opening then return end

	for dbid, inside in pairs(self.playerlist) do
		if inside then
			self:UpdatePlayer(dbid, {
					skyhallout_staytime = 1,
				})
		end
	end
end

--进攻
function SkyHallOut:AttackHook(fightexinfo, bossid)
	local bossConf = server.configCenter.GuildBattleKingConfig[bossid]
	if not bossConf then return false end
	if not self.fblv then
		self.fblv = self:GetFbLevel(bossConf)
	end
	fightexinfo.bossid = bossid
	fightexinfo.fbid = bossConf[self.fblv].fbid
	return true
end

--攻击检测
function SkyHallOut:CanAttack(dbid, bossid)
	if not BaseBarrier.CanAttack(self, dbid) then
		return false
	end

	local playerdata = self:GetPlayerData(dbid)

	if not playerdata.bossinfo[bossid] then
		table.ptable(playerdata.bossinfo, 3)
		lua_app.log_error("SkyHallOut Attack ---", bossid, dbid)
		return false
	end
	
	if playerdata.bossinfo[bossid] > lua_app.now() then
		return false
	end
	return true
end

--战斗结果
function SkyHallOut:AttackResult(iswin, dbid, attackers, poshps, bossid)
	local playerdata = self:GetPlayerData(dbid)
	local GuildBattleKingConfig = server.configCenter.GuildBattleKingConfig
	--处理玩家伤害
	for _, data in ipairs(attackers) do
		if iswin then
			self:UpdatePlayer(data.playerinfo.dbid, {
				score = GuildBattleKingConfig[bossid][self.fblv].points,
			})
		end
		self:UpdatePlayer(data.playerinfo.dbid, {
				bossinfo = {
					[bossid] = iswin and lua_app.now() + GuildBattleKingConfig[bossid][self.fblv].revivecd or 0
				}
			})
		self:SendBossDataMsg(data.playerinfo.dbid)
	end
end

--检查进入下一关
function SkyHallOut:Checkpoint(dbid)
	if not BaseBarrier.Checkpoint(self, dbid) then
		return false
	end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	--特殊处理
	local guilddata = self:GetGuildDataByDBID(dbid)
	if guilddata.skyhallout_through and guilddata.skyhallout_through >= GuildBattleBaseConfig.t_count then
		return true
	end

	local playerdata = self:GetPlayerData(dbid)
	if playerdata.skyhallout_staytime and playerdata.skyhallout_staytime >= GuildBattleBaseConfig.t_opentime*60 then
		return true
	end

	if playerdata.score < GuildBattleBaseConfig.t_points then
		lua_app.log_info(">>SkyHallOut:Checkpoint enter next barrier score not enough.", playerdata.score, GuildBattleBaseConfig.t_points)
		return false
	end
	return true
end

--进入下一关
function SkyHallOut:NextBarrier(dbid)
	if BaseBarrier.NextBarrier(self, dbid) then
		if not self.throughplayers[dbid] then
			local playerdata = self:GetPlayerData(dbid)
			self:UpdateGuild(playerdata.guildid, {
				skyhallout_through = 1,
			})
			self.throughplayers[dbid] = true
		end
	end
end

--补充帮会信息
function SkyHallOut:AppendGuildMsgData(data, guildinfo)
	data.throughNum = guildinfo.skyhallout_through or 0
	data.rankData = {
		score = guildinfo.score,
		scoreRank = guildinfo.scoreRank,
	}
end

--补充排行数据
function SkyHallOut:AppendGuildRankData(adddata, guildinfo)
	adddata.throughNum = guildinfo.skyhallout_through or 0
end

function SkyHallOut:GetBossMsgData(dbid)
	local playerdata = self:GetPlayerData(dbid)
	local data = {}
	for id, reborntime in pairs(playerdata.bossinfo) do
		table.insert(data, {
			bossid = id,
			reborntime = reborntime,
		})
	end
	return data
end

--战斗奖励
function SkyHallOut:GetReward(iswin, poshps, bossid)
	local GuildBattleKingConfig = server.configCenter.GuildBattleKingConfig
	local rewards
	if iswin then
		return server.dropCenter:DropGroup(GuildBattleKingConfig[bossid][self.fblv].windropid), 1
	else
		return server.dropCenter:DropGroup(GuildBattleKingConfig[bossid][self.fblv].lossdropId), 2
	end
end

--发送Boss数据
function SkyHallOut:SendBossDataMsg(dbid)
	self:SendReqByInside(dbid, "sc_guildwar_four_king_info", {
			bossinfos = self:GetBossMsgData(dbid),
		})
end

function SkyHallOut:onStayEvent(dbid, monitorkey, olddatas)
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local playerdata = self:GetPlayerData(dbid)
	if playerdata.skyhallout_staytime == GuildBattleBaseConfig.t_opentime * 60 then
		self:SendPlayerDataMsg(dbid)
	end
end

return SkyHallOut
