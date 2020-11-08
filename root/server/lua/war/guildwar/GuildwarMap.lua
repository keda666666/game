local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local MapConfig = require "resource.MapConfig"
local SouthDoor = require "guildwar.SouthDoor"
local SkyHallOut = require "guildwar.SkyHallOut"
local SkyHallInside = require "guildwar.SkyHallInside"
local DragonHall = require "guildwar.DragonHall"
local GuildwarNotice = require "guildwar.GuildwarNotice"
local GuildwarConfig = require "resource.GuildwarConfig"
local GuildwarPlayerCtrl = require "guildwar.GuildwarPlayerCtrl"
local WarReport = require "warReport.WarReport"

local _Barrier = GuildwarConfig.Barrier
--关卡配置
local Barrier = {
	[_Barrier.SouthDoor] = SouthDoor,
	[_Barrier.SkyHallOut] = SkyHallOut,
	[_Barrier.SkyHallInside] = SkyHallInside,
	[_Barrier.DragonHall] = DragonHall,
}

local _RebornBarrier = _Barrier.SkyHallOut
local _ScoreRewardMark = 0xffffffff

-- 帮会战跨服一场地图主控文件
local GuildwarMap = oo.class()

function GuildwarMap:ctor(index, center, servers)
	self.servers = servers
	self.center = center
	self.index = index
end

function GuildwarMap:Release()
end

--活动开启
function GuildwarMap:Init(endtime, level)
	self.worldlv = level
	self.endtime = endtime
	self.isopen = true
	self.barriers = {}
	self.occupyGuild = {}
	self.playerTimer = {}
	self.guildTimer = {}
	self.playerlist = {}
	self.notice = GuildwarNotice.new(self)
	self.playerCtrl = GuildwarPlayerCtrl.new()
	self.warReport = WarReport.new("sc_guildwar_report")
	for i = _Barrier.SouthDoor, _Barrier.DragonHall do
		local barrier = Barrier[i].new(i, self)
		barrier:Init()
		self.barriers[i] = barrier
	end
	self:RegisteFunc(GuildwarConfig.Datakeys.global)
	self:SecondTimer()
	print("GuildwarMap:Init---------------",endtime, level)
end

function GuildwarMap:RegisteFunc(modules)
	--注册功能键
	for __, keydata in ipairs(modules.keys) do
		self.playerCtrl:RegisteEffectKey(table.unpack(keydata))
	end
	--玩家监听
	for noticefunc, monitorkeys in pairs(modules.PlayerEvent) do
		for __, monitorkey in ipairs(monitorkeys) do
			self.playerCtrl:RegistePlayerMonitor(self, monitorkey, noticefunc)
		end
	end
	--帮会
	for noticefunc, monitorkeys in pairs(modules.GuildEvent) do
		for __, monitorkey in ipairs(monitorkeys) do
			self.playerCtrl:RegisteGuildMonitor(self, monitorkey, noticefunc)
		end
	end
end

--每秒定时器
function GuildwarMap:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		local now = lua_app.now()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)

		for _, barrier in pairs(self.barriers) do
			barrier:DoSecond(now)
		end
		self:ScheduleReborn(now)
	end

	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

function GuildwarMap:ScheduleReborn(now)
	for dbid,__ in pairs(self.playerlist) do
		self:SetStatus(dbid)
	end
end

function GuildwarMap:SetStatus(dbid)
	if self:IsAlive(dbid) then
		self:SetAliveStatus(dbid)
	else
		self:SetDeadStatus(dbid)
	end
end

function GuildwarMap:SetAliveStatus(dbid)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	local mapstatus = server.mapCenter:GetStatus(dbid)
	if playerdata.online and mapstatus == MapConfig.status.Dead then
		local barrier = self:GetBarrier(dbid)
		barrier:SendPlayerDataMsg(dbid)
		server.mapCenter:SetStatus(dbid, MapConfig.status.Act)
	end
end

function GuildwarMap:SetDeadStatus(dbid)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	local mapstatus = server.mapCenter:GetStatus(dbid)
	if playerdata.online and mapstatus == MapConfig.status.Act then
		server.mapCenter:SetStatus(dbid, MapConfig.status.Dead)
	end
end

function GuildwarMap:IsReborn(dbid, now)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	local mapstatus = server.mapCenter:GetStatus(dbid)
	if playerdata.reborntime <= now and 
		mapstatus == MapConfig.status.Dead then
		return true
	end
	return false
end

--玩家进入
function GuildwarMap:Enter(dbid)
	if not self.playerlist[dbid] then
		self:InitPlayer(dbid)
	end
	self:UpdatePlayer(dbid, {
		online = true,
	})
	--进入关卡
	local barrier = self:GetBarrier(dbid)
	barrier:Enter(dbid)
	self.warReport:AddPlayer(dbid)
	return true
end

--初始化玩家
function GuildwarMap:InitPlayer(dbid)
	self.playerCtrl:InitPlayer(dbid)
	self:UpdatePlayer(dbid, {
		score = 0,
		kill = 0,
		reborntime = 0,
		rewardMark = _ScoreRewardMark,
	})
	self.playerlist[dbid] = _Barrier.SouthDoor
end

--获得关卡
function GuildwarMap:GetBarrier(dbid)
	local barrierid = self.playerlist[dbid]
	local barrier = self.barriers[barrierid]
	if not barrier then
		lua_app.log_error(">> GuildwarMap:GetBarrier not exist barrier.", dbid, barrierid)
		return
	end
	return barrier
end

--进入下一关
function GuildwarMap:EnterNextBarrier(dbid)
	local barrierid = self.playerlist[dbid]
	barrierid = math.min(barrierid + 1, _Barrier.DragonHall)
	local barrier = self.barriers[barrierid]
	barrier:Enter(dbid)
	self.playerlist[dbid] = barrierid
	return true
end

--返回上一关
function GuildwarMap:EnterLastBarrier(dbid)
	local barrierid = self.playerlist[dbid]
	barrierid = math.max( _Barrier.SkyHallOut, barrierid - 1)
	local barrier = self.barriers[barrierid]
	barrier:Enter(dbid)
	self.playerlist[dbid] = barrierid
	return true
end

--战斗
function GuildwarMap:Attack(dbid, ...)
	local barrier = self:GetBarrier(dbid)
	barrier:Attack(dbid, ...)
end

--检查重生状态
function GuildwarMap:IsAlive(dbid)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	return (lua_app.now() > playerdata.reborntime)
end

--花钱清除复活时间
function GuildwarMap:PayReborn(dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local cost = {
		table.wcopy(GuildBattleBaseConfig.revivecost),
	}
	if not player:PayRewards(cost, server.baseConfig.YuanbaoRecordType.Guildwar, "Guildwar:reborn") then
		lua_app.log_info(">>GuildwarMap:PayReborn buy reborn fail")
		return false
	end
	self:UpdatePlayer(dbid, {
			reborntime = 0,
		})
end

--玩家死亡 需要复活
function GuildwarMap:Reborn(dbid)
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local barrier = self:GetBarrier(dbid)
	barrier:Leave(dbid)
	self.playerlist[dbid] = _RebornBarrier
	self:UpdatePlayer(dbid, {
			reborntime = lua_app.now() + GuildBattleBaseConfig.revivecd,
		})
	local newbarrier = self:GetBarrier(dbid)
	newbarrier:Enter(dbid)
end

--开启最终的战斗
function GuildwarMap:UltimateFight(time)
	local barrier = self.barriers[_Barrier.DragonHall]
	barrier:SetFightStarttime(time)
end

--自由Pk
function GuildwarMap:Pk(dbid, targetid)
	-- 攻方组队
	local can, newdatas, playeridlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		return 3
	end

	if not self:CheckGuildmember(playeridlist) then
		return 1
	end

	-- 守方组队
	local can2, targetdatas, targetidlist = server.teamCenter:GetTeamDataByDBID(targetid)
	if not can2 then
		print("KingMap:PK no target ", targetid)
		return 3
	end

	if not self:CheckGuildmember(targetidlist) then
		return 1
	end

	for _, id in ipairs(targetidlist) do
		table.insert(playeridlist, id)
	end

	if self:CheckGuildmember(playeridlist) then
		return 1
	end

	-- 判断能否战斗
	for _, playerid in ipairs(playeridlist) do
		if not self:CanFight(playerid) then
			return 2
		end
	end
	

	newdatas.exinfo = {
		guildwarMap = self,
		target = targetdatas,
	}
	server.raidMgr:Enter(server.raidConfig.type.GuildwarPk, dbid, newdatas, playeridlist)
	return 0
end

--检测帮会成员
function GuildwarMap:CheckGuildmember(idlist)
	local guildid = false
	for __, dbid in ipairs(idlist) do
		local playerdata = self.playerCtrl:GetPlayerData(dbid)
		guildid = guildid or playerdata.guildid
		if guildid ~= playerdata.guildid then
			return false
		end
	end
	return true
end

--战斗检测
function GuildwarMap:CanFight(id)
	local playerdata = self.playerCtrl:GetPlayerData(id)
	local now = lua_app.now()
	local status = server.mapCenter:GetStatus(id)
	if status ~= MapConfig.status.Act then
		return false
	end
	if playerdata.reborntime > now then
		return false
	end 
	return true
end

--Pk结果
function GuildwarMap:PkResult(iswin, playerlist, targets)
	local winlist = {}
	local lostlist = {}
	if iswin then
		winlist = playerlist
		lostlist = targets
	else
		winlist = targets
		lostlist = playerlist
	end

	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local terminator = {}
	for _, dbid in pairs(winlist) do
		local playerdata = self.playerCtrl:GetPlayerData(dbid)
		self:UpdatePlayer(dbid, {
				score = GuildBattleBaseConfig.pkwinpoints,
				kill = #lostlist,
				multikill = #lostlist,
		})
		table.insert(terminator, playerdata.playerinfo.name)
	end
	-- 失败者踢回出生点
	for _, dbid in pairs(lostlist) do
		self:Reborn(dbid)
		self:UpdatePlayer(dbid, {
				score = GuildBattleBaseConfig.pklosspoints,
				multikill = math.huge,
				terminator = string.format("[%s]", table.concat(terminator, "] [")),
		})
	end
end

--设置胜利帮会
function GuildwarMap:SetWinerGuild(guildid)
	if guildid then
		local guilddata = self.playerCtrl:GetGuildData(guildid)
		self.occupyGuild = {
			guildName = guilddata.guildname,
			serverId = guilddata.serverid,
			leaderName = guilddata.leaderName,
		}
	end
end

function GuildwarMap:GetWinerGuild()
	return table.wcopy(self.occupyGuild)
end

--领取奖励
function GuildwarMap:GetWarScoreReward(dbid, index)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	local rewardMark = playerdata.rewardMark
	if not lua_util.bit_status(rewardMark, index) then
		return
	end

	local GuildBattleRewardsConfig = server.configCenter.GuildBattleRewardsConfig[index]
	local fblv = self:GetFbLevel()
	local rewardCfg = GuildBattleRewardsConfig[fblv]
	if playerdata.score < rewardCfg.needpoints then
		lua_app.log_info("score not enough.", playerdata.score)
		return
	end

	local rewards = server.dropCenter:DropGroup(rewardCfg.rewards)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	player:GiveRewardAsFullMailDefault(rewards, "帮会战积分奖励", server.baseConfig.YuanbaoRecordType.Guildwar)
	rewardMark = lua_util.bit_shut(rewardMark, index)

	self:UpdatePlayer(dbid, {
			rewardMark = rewardMark,
		})
	print(fblv, self.worldlv)
end

function GuildwarMap:GetFbLevel()
	if not self.fblv then
		local pointCfg = server.configCenter.GuildBattleRewardsConfig[1]
		local levelCfg = table.packKeyArray(pointCfg)
		table.sort(levelCfg)

		self.fblv = table.matchValue(levelCfg, function(level)
			return self.worldlv - level 
		end, 1)
	end
	return self.fblv
end

function GuildwarMap:TeamRecruit(dbid)
	local chatConfig = server.chatConfig
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	self:BroadcastGuild(playerdata.guildid, "sc_chat_new_msg", {
			chatData = chatConfig:PackLinkData(38, dbid, playerdata.playerinfo.name, {chatConfig.CollectType.Fb, 1, server.raidConfig.type.Guildwar})
		})
end

function GuildwarMap:CanJoinTeam(dbid, leaderid)
	local leaderbarrier = self.playerlist[leaderid] or 0
	local playerbarrier = self.playerlist[dbid] or 1
	return (leaderbarrier == playerbarrier)
end

--通知接口
function GuildwarMap:Notice(id, ...)
	self.notice:Notice(id, ...)
end

--玩家占据时间过长结束活动
function GuildwarMap:EarlyShut()
	self:Shut()
end

--活动关闭
function GuildwarMap:Shut()
	if not self.isopen then return end

	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	for _, barrier in ipairs(self.barriers) do
		barrier:Shut()
	end

	self:PersonScoreRankRewards()

	self.playerCtrl:Release()

	for __, serverid in ipairs(self.servers) do
		self.center:CallOne(serverid, "SetChampionGuildData", self:GetWinerGuild())
	end 
	self.isopen = false
	self.warReport:BroadcastReport()
end

--个人积分排行奖励
function GuildwarMap:PersonScoreRankRewards()
	local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	local scoreRanks = self.playerCtrl:GetPlayerRankdata("scoreRank")
	local socreCfg = server.configCenter.GuildPointRewardsConfig
	local title = GuildBattleBaseConfig.mailtitle_1
	for rank, rankdata in ipairs(scoreRanks) do
		local matchCfg = table.matchValue(socreCfg, function(cfg)
			return rank - cfg.rank
		end)
		local rewards = table.wcopy(matchCfg.showitem)

		local context = string.format(GuildBattleBaseConfig.maildes_1, rank)
		server.serverCenter:SendOneMod("logic", rankdata.serverid, "mailCenter", "SendMail", rankdata.dbid, title, context, rewards, server.baseConfig.YuanbaoRecordType.Guildwar)

		if matchCfg.trewards then
			server.serverCenter:SendOneMod("logic", rankdata.serverid, "guildwarMgr", "DressCouture", rankdata.dbid, matchCfg.trewards)
		end
		self.warReport:AddRewards(rankdata.dbid, rewards)
	end
end

--发送玩家数据
function GuildwarMap:SendPlayerDataMsg(dbid)
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	server.sendReqByDBID(dbid, "sc_guildwar_player_global_info", {
		reborntime = playerdata.reborntime,
		score = playerdata.score,
		scoreRank = playerdata.scoreRank,
		kill = playerdata.kill,
		killRank = playerdata.killRank,
		rewardMark = playerdata.rewardMark,
		endtime = self.endtime,
		worldlevel = self.worldlv,
	})
end

--发送帮会消息
function GuildwarMap:BroadcastGuildDataMsg(guildid)
	local guilddata = self.playerCtrl:GetGuildData(guildid)
	local msg = {
		playerNum = guilddata.enternumber,
		score = guilddata.score,
		scoreRank = guilddata.scoreRank,
	}
	self:BroadcastGuild(guildid, "sc_guildwar_myguild_global_info", msg)
end

--广播帮会消息
function GuildwarMap:BroadcastGuild(guildid, name, msg)
	local playerlist = self.playerCtrl:GetPlayerlist()
	for dbid, playerdata in pairs(playerlist) do
		if playerdata.guildid == guildid then
			server.sendReqByDBID(dbid, name, msg)
		end
	end
end

--广播在线玩家
function GuildwarMap:BroadcastOnline(name, msg)
	local playerlist = self.playerCtrl:GetPlayerlist()
	for dbid, playerdata in pairs(playerlist) do
		if playerdata.online then
			server.sendReqByDBID(dbid, name, msg)
		end
	end
end

--发送个人排行
function GuildwarMap:SendPersonRank(dbid)
	local barrier = self.barriers[_Barrier.SkyHallInside]
	barrier:SendPersonRank(dbid)
end

--发送公会排行
function GuildwarMap:SendGuildRank(dbid)
	local barrier = self.barriers[_Barrier.SkyHallInside]
	barrier:SendGuildRank(dbid)
end

--登入
function GuildwarMap:Login(dbid)
	if not self.playerlist[dbid] then return end
	self:UpdatePlayer(dbid, {
			online = true,
		})
	--广播消息
	self.notice:onInitClient(dbid)
end

--登出
function GuildwarMap:Logout(dbid)
	if not self.playerlist[dbid] then return end
	self:UpdatePlayer(dbid, {
			online = false,
		})
	server.mapCenter:Leave(dbid)
	self:Leave(dbid)
end

function GuildwarMap:Leave(dbid)
	local barrier = self:GetBarrier(dbid)
	barrier:Leave(dbid)
end

--[[playerCtrl相关--]]
--更新玩家数据
function GuildwarMap:UpdatePlayer(dbid, datas)
	self.playerCtrl:UpdatePlayer(dbid, datas)
end

--更新帮会数据
function GuildwarMap:UpdateGuild(guildid, datas)
	self.playerCtrl:UpdateGuild(guildid, datas)
end

--玩家状态变更
function GuildwarMap:onUpdatePlayer(dbid, monitorkey, olddatas)
	self:SendPlayerDataMsg(dbid)
end

--玩家排名
function GuildwarMap:onPlayerRank(dbid, rankname, status)
	local rankdata = self.playerCtrl:GetPlayerRankdata(rankname)
	for index = status.beginindex + 1, status.endindex do
		if rankdata[index].dbid ~= dbid then
			self:SendPlayerDataMsg(rankdata[index].dbid)
		end
	end
end

--帮会数据变更
function GuildwarMap:onUpdateGuild(guildid, monitorkey, olddatas)
	self:BroadcastGuildDataMsg(guildid)
end

--连杀事件
function GuildwarMap:onMultikill(dbid, monitorkey, olddatas)
	--连杀公告
	local GuildBattleMultiKill = server.configCenter.GuildBattleMultiKill
	local playerdata = self.playerCtrl:GetPlayerData(dbid)
	local multikill = olddatas.multikill or 0
	for killnumber = multikill + 1, playerdata.multikill do
		local multikillCfg = GuildBattleMultiKill[killnumber]
		if multikillCfg and multikillCfg.notice ~= 0 then
			self:Notice(multikillCfg.notice, string.format("[%s]", playerdata.playerinfo.name), killnumber)
		end
	end
	--终结公告
	if multikill > playerdata.multikill and multikill >= 3 then
		local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
		self:Notice(GuildBattleBaseConfig.finalMultikillNotice, playerdata.terminator, playerdata.playerinfo.name, multikill)
	end
end

--帮会排名
function GuildwarMap:onGuildRank(guildid, rankname, status)
	local rankdata = self.playerCtrl:GetGuildRankdata(rankname)
	for index = status.beginindex, status.endindex do
		if rankdata[index].guildid ~= guildid then
			self:BroadcastGuild(rankdata[index].guildid)
		end
	end
end

--测试用 重置关卡数据
function GuildwarMap:ResetBarrier(barrierId)
	self.barriers[barrierId] = Barrier[barrierId].new(barrierId, self)
	for _,v in pairs(self.playerlist) do
		if v.barrier.barrierId == barrierId then
			v.barrier = self.barriers[barrierId]
		end
	end
end

function GuildwarMap:Debug(dbid)
	--self:EarlyShut()
	--print(self.worldlv, self.index, self, self.endtime, self.pppppp,"==========================")
	--self.playerCtrl:Debug(dbid)
	-- local playerdata = self.playerCtrl:GetPlayerData(dbid)
	self:UpdatePlayer(dbid, {
			score = 100,
		})
	-- -- self:UpdateGuild(playerdata.guildid, {
	-- -- 		skyhallinside_injure = 1,
	-- -- 		dragonhall_holdtracks = 1,
	-- -- 		skyhallout_through = 1,
	-- -- 		score = 1,
	-- -- 	})
	-- -- table.ptable(playerdata, 3)
	-- -- local guilddata = self.playerCtrl:GetGuildData(playerdata.guildid)
	-- -- table.ptable(guilddata, 3)

	-- -- local GuildBattleRewardConfig = server.configCenter.GuildBattleRewardConfig
	-- -- local GuildBattleBaseConfig = server.configCenter.GuildBattleBaseConfig
	-- -- local title = GuildBattleBaseConfig.personalIntegralHead
	-- -- local context = GuildBattleBaseConfig.personalIntegralContext
	-- -- local rewards = server.dropCenter:DropGroup(GuildBattleRewardConfig[1].rewards)
	-- -- server.serverCenter:SendOneMod("logic", playerdata.serverid, "mailCenter", "SendMail", dbid, title, context, rewards, server.baseConfig.YuanbaoRecordType.Guildwar)
	-- -- self.playerCtrl:UpdatePlayer(dbid, {
	-- -- 		--multikill = 1,
	-- -- 		multikill = math.huge,
	-- -- 		terminator = "Kmmmm",
	-- -- 	})
	-- -- table.ptable(playerdata, 3)
	-- local GuildBattleAuctionConfig = server.configCenter.GuildBattleAuctionConfig[1]
	-- local rewards = server.dropCenter:DropGroup(GuildBattleAuctionConfig[1].reward)
	-- server.serverCenter:SendOneMod("logic", playerdata.serverid, "auctionMgr", "ShelfLocal", 0, rewards[1].id, rewards[1].count, playerdata.guildid)
end

return GuildwarMap

