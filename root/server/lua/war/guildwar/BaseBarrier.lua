local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local MapConfig = require "resource.MapConfig"
local EntityConfig = require "resource.EntityConfig"
local GuildwarConfig = require "resource.GuildwarConfig"


local BaseBarrier = oo.class()

function BaseBarrier:ctor(barrierId, guildwarMap)
	self.barrierId = barrierId
	self.guildwarMap = guildwarMap
	self.playerCtrl = guildwarMap.playerCtrl
	self.warReport = guildwarMap.warReport
	self.playerlist = {}
end

function BaseBarrier:Release()
end

function BaseBarrier:Init()
end

--注册功能函数
function BaseBarrier:RegisteFunc(modules)
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

--关卡开启
function BaseBarrier:Start()
	self.opening = true
end

--每秒定时器
function BaseBarrier:DoSecond(now)
end

--进入地图
function BaseBarrier:Enter(dbid)
	if not self.opening then
		self:Start()
	end
	if self.playerlist[dbid] == nil then
		self:GendefaultData(dbid)
	end
	if not self.playerlist[dbid] then
		self:EnterHook(dbid)
	end
	self.playerlist[dbid] = true
	self:SendPlayerDataMsg(dbid)
	self:SendEnterMsg(dbid)
	lua_app.log_info("player enter barrier", self.barrierId, dbid)
end

--进入勾子
function BaseBarrier:EnterHook(dbid)
end

--发送进入场景
function BaseBarrier:SendEnterMsg(dbid)
end

--检查进入下一关
function BaseBarrier:Checkpoint(dbid)
	if not self.playerlist[dbid] then
		lua_app.log_info(">>BaseBarrier:Checkpoint player not exist playerlist", dbid)
		return false
	end
	if not self.guildwarMap:IsAlive(dbid) then
		lua_app.log_info(">>BaseBarrier:Checkpoint player is die.", dbid)
		return false
	end
	return true
end

--进入下一关
function BaseBarrier:NextBarrier(dbid)
	if not self.playerlist[dbid] then
		lua_app.log_info(">>BaseBarrier:NextBarrier dbid not exist playerlist.", dbid)
		return false
	end

	local can, newdatas, playeridlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		server.sendErrByDBID(dbid, "只有队长才能点击")
		return false
	end

	for __, memberid in pairs(playeridlist) do
		if not self:Checkpoint(memberid) then
			local memberdata = self:GetPlayerData(memberid)
			for __, noticeid in pairs(playeridlist) do
				server.sendErrByDBID(noticeid, string.format("队员:%s，不能进入下一层", memberdata.playerinfo.name))
			end
			return false
		end
	end

	for __, memberid in pairs(playeridlist) do
		self:Leave(memberid)
		self.guildwarMap:EnterNextBarrier(memberid)
	end
	return true
end

--返回上一关
function BaseBarrier:LastBarrier(dbid)
	if not self.playerlist[dbid] then
		return false
	end

	local can, newdatas, playeridlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		server.sendErrByDBID(dbid, "只有队长才能点击")
		return false
	end

	for __, memberid in pairs(playeridlist) do
		self:Leave(memberid)
		self.guildwarMap:EnterLastBarrier(memberid)
	end
	return true
end

--产生默认数据
function BaseBarrier:GendefaultData(dbid)
end

--离开
function BaseBarrier:Leave(dbid)
	if self.playerlist[dbid] == true then
		self:LeaveHook(dbid)
	end
	print("BaseBarrier:Leave-------------------------", dbid)
	self.playerlist[dbid] = false
end

--离开
function BaseBarrier:LeaveHook(dbid)
end

--攻击检测
function BaseBarrier:CanAttack(dbid)
	if not self.playerlist[dbid] then
		lua_app.log_info("BaseBarrier:CanAttack Player not inside barrier.", dbid)
		return false
	end
	if not self.opening then
		lua_app.log_info("BaseBarrier:CanAttack barrier not open.")
		return false
	end
	local status = server.mapCenter:GetStatus(dbid)
	if status ~= MapConfig.status.Act and status ~= 0 then
		lua_app.log_info(">>BaseBarrier:CanAttack player status don't attack.", dbid, status)
		return false
	end
	if not self.guildwarMap:IsAlive(dbid) then
		lua_app.log_info("BaseBarrier:CanAttack player is die.", dbid)
		return false
	end
	return true
end

--进攻
function BaseBarrier:Attack(dbid, ...)
	local can, datas, idlist = server.teamCenter:GetTeamDataByDBID(dbid, true)
	if not can then
		server.sendErrByDBID(dbid, "只有队长才能点击")
		lua_app.log_info("SkyHallOut:Attack no dbid", dbid)
		return false
	end

	for _, id in ipairs(idlist) do
		if not self:CanAttack(id, ...) then
			local playerdata = self:GetPlayerData(id)
			server.sendErrByDBID(dbid, string.format("%s，不能进入战斗。", playerdata.playerinfo.name))
			print("have player not attack.", id)
			return false
		end
	end
	datas.exinfo = {
		barrier = self,
	}
	local success = self:AttackHook(datas.exinfo, ...)
	if not success then
		return false
	end

	server.raidMgr:Enter(server.raidConfig.type.Guildwar, dbid, datas, idlist)
	return true
end

function BaseBarrier:AttackHook(fightexinfo, ...)
	return true
end

--战斗结果
function BaseBarrier:AttackResult(iswin, dbid, attackers, poshps)
end

--获取战斗配置
function BaseBarrier:GetExconfig()
end

--获取玩家消息数据
function BaseBarrier:GetPlayerMsgData(dbid)
	local playerdata = self:GetPlayerData(dbid)
	local data = {
		barrierId = self.barrierId,
		through = self:Checkpoint(dbid),
	}
	self:AppendPlayerMsgData(data, playerdata)
	return data
end

--补充玩家数据
function BaseBarrier:AppendPlayerMsgData(data, playerinfo)
end

--获取帮会排行信息
function BaseBarrier:GetPlayerRankMsgData(rankname, position)
	local senddescribe = string.match(rankname, "(%a-)Rank")
	local typedescribe = string.match(rankname, "(.-)Rank")
	local datas = {}
	local rankdatas = self:GetPlayerRankdata(rankname)
	position = position or #rankdatas
	for rank, playerdata in ipairs(rankdatas) do
		local data = {
			dbid = playerdata.dbid,
			name = playerdata.playerinfo.name,
			job = playerdata.playerinfo.job,
			sex = playerdata.playerinfo.sex,
			guildName = playerdata.playerinfo.guildname,
			serverId = playerdata.serverid,
			rankData = {
				[senddescribe] = playerdata[typedescribe],
				[senddescribe.."Rank"] = playerdata[rankname],
			},
		}
		self:AppendPlayerRankData(data, playerdata)
		table.insert(datas, data)
		if rank == position then break end
	end
	return datas
end

--补充排行数据
function BaseBarrier:AppendPlayerRankData(adddata, playerinfo)
end


--获取玩家帮会信息
function BaseBarrier:GetGuildMsgData(guildid)
	local guilddata = self:GetGuildData(guildid)
	local data = {
		barrierId = self.barrierId,
	}
	self:AppendGuildMsgData(data, guilddata)
	return data
end

--补充帮会信息
function BaseBarrier:AppendGuildMsgData(data, guildinfo)
end

--获取帮会排行信息
function BaseBarrier:GetGuildRankMsgData(rankname, position)
	local senddescribe = string.match(rankname, "(%a-)Rank")
	local typedescribe = string.match(rankname, "(.-)Rank")
	local datas = {}
	local rankdatas = self:GetGuildRankdata(rankname)
	position = position or #rankdatas
	for rank, guilddata in ipairs(rankdatas) do
		local data = {
			guildId = guilddata.guildid,
			guildName = guilddata.guildname,
			serverId = guilddata.serverid,
			rankData = {
				[senddescribe] = guilddata[typedescribe],
				[senddescribe.."Rank"] = guilddata[rankname],
			},
		}
		self:AppendGuildRankData(data, guilddata)
		table.insert(datas, data)
		if rank == position then break end
	end
	return datas
end

--补充排行数据
function BaseBarrier:AppendGuildRankData(adddata, guildinfo)
end

--获取奖励
function BaseBarrier:GetReward(iswin, poshps, bossid)
	local result = iswin and 1 or 0
	return {}, result
end

--获取副本等级
function BaseBarrier:GetFbLevel(fbconf)
	local levelCfg = table.packKeyArray(fbconf)
	table.sort(levelCfg, function(a, b)
		return a < b
	end)
	local worldlv = self.guildwarMap.worldlv
	local fblv = table.matchValue(levelCfg, function(level)
		return worldlv - level
	end, 1)
	return fblv
end

--发送玩家数据
function BaseBarrier:SendPlayerDataMsg(dbid)
	self:SendReqByInside(dbid, "sc_guildwar_player_info", self:GetPlayerMsgData(dbid))
end

--广播玩家数据
function BaseBarrier:BroadcastPlayerDataMsg()
	for dbid, __ in pairs(self.playerlist) do
		self:SendReqByInside(dbid, "sc_guildwar_player_info", self:GetPlayerMsgData(dbid))
	end
end

--发送帮会数据
function BaseBarrier:SendGuildDataMsg(dbid)
	local playerdata = self:GetPlayerData(dbid)
	local guildid = playerdata.guildid
	local data = self:GetGuildMsgData(guildid)
	self:SendReqByInside(dbid, "sc_guildwar_guild_info", data)
end


--广播帮会数据
function BaseBarrier:BroadcastGuildDataMsg(guildid)
	local data = self:GetGuildMsgData(guildid)
	self:BroadcastGuild(guildid, "sc_guildwar_guild_info", data)
end

--广播关卡所有玩家
function BaseBarrier:Broadcast(name, msg)
	for dbid, __ in pairs(self.playerlist) do
		self:SendReqByInside(dbid, name, msg)
	end
end

--广播帮会
function BaseBarrier:BroadcastGuild(guildid, name, msg)
	local playerlist = self.playerCtrl:GetPlayerlist()
	for dbid, playerdata in pairs(playerlist) do
		if playerdata.guildid == guildid then
			self:SendReqByInside(dbid, name, msg)
		end
	end
end

--发送消息
function BaseBarrier:SendReqByInside(dbid, name, msg)
	if not self.playerlist[dbid] then return end
	server.sendReqByDBID(dbid, name, msg)
end

--发送玩家排行
function BaseBarrier:SendPlayerRankDataMsg(dbid, rankname)
	if dbid then
		self:SendReqByInside(dbid, "sc_guildwar_player_rank", {
				barrierId = self.barrierId,
				rankInfos = self:GetPlayerRankMsgData(rankname, self:GetSendPlayerRankNumber()),
			})
	else
		self:Broadcast("sc_guildwar_player_rank", {
				barrierId = self.barrierId,
				rankInfos = self:GetPlayerRankMsgData(rankname, self:GetSendPlayerRankNumber()),
			})
	end
end

--发送玩家排行数
function BaseBarrier:GetSendPlayerRankNumber()
	return 3
end

--发送帮会排行
function BaseBarrier:SendGuildRankDataMsg(dbid, rankname)
	if dbid then
		self:SendReqByInside(dbid, "sc_guildwar_guild_rank", {
				barrierId = self.barrierId,
				guildinfos = self:GetGuildRankMsgData(rankname, self:GetSendGuildRankNumber()),
			})
	else
		self:Broadcast("sc_guildwar_guild_rank", {
				barrierId = self.barrierId,
				guildinfos = self:GetGuildRankMsgData(rankname, self:GetSendGuildRankNumber()),
			})
	end
end

--发送帮会排行数
function BaseBarrier:GetSendGuildRankNumber()
	return 3
end

--发送mail
function BaseBarrier:SendMail(dbid, title, context, rewards, ttype)
	local playerinfo = self:GetPlayerData(dbid)
	server.serverCenter:SendOneMod("logic", playerinfo.serverid, "mailCenter", "SendMail", dbid, title, context, rewards, ttype)
end

--活动关闭
function BaseBarrier:Shut()
end

--通知接口
function BaseBarrier:Notice(...)
	self.guildwarMap:Notice(...)
end


--[[消息接收--]]
function BaseBarrier:onUpdatePlayer(dbid, monitorkey, olddatas)
	if not self.opening then return end

	self.playertimer = self.playertimer or {}
	if self.playertimer[dbid] then return end
	self.playertimer[dbid] = lua_app.add_timer(500, function()
		self.playertimer[dbid] = nil
		self:SendPlayerDataMsg(dbid)
	end)
end

function BaseBarrier:onPlayerRank(dbid, rankname, status)
	if not self.opening then return end

	local PlayerEvent = GuildwarConfig.Datakeys[self.barrierId].PlayerEvent
	local dependrank = PlayerEvent.onPlayerRank[1]

	if status.top3 ~= nil then
		local rankdatas = self:GetPlayerRankdata(dependrank)
		for i = status.beginindex + 1, status.endindex do
			self:BroadcastPlayerDataMsg(rankdatas[i].dbid)
		end
		if status.top3 then
			self.playerrankRecord = {}
			for rank, playerdata in ipairs(rankdatas) do
				self.playerrankRecord[playerdata.dbid] = true
				if rank == self:GetSendPlayerRankNumber() then break end
			end
		end
	end
	if self:CheckSendPlayerRank(dbid) then
		self:SendPlayerRankDataMsg(nil, dependrank)
	end
end

--玩家排行发送检查
function BaseBarrier:CheckSendPlayerRank(dbid)
	return self.playerrankRecord and self.playerrankRecord[dbid]
end

function BaseBarrier:onUpdateGuild(guildid, monitorkey, olddatas)
	if not self.opening then return end
	self.guildtimer = self.guildtimer or {}
	if self.guildtimer[guildid] then return end

	self.guildtimer[guildid] = lua_app.add_timer(500, function()
		self.guildtimer[guildid] = nil
		self:BroadcastGuildDataMsg(guildid)
	end)
end

function BaseBarrier:onGuildRank(guildid, rankname, status)
	if not self.opening then return end
	local GuildEvent = GuildwarConfig.Datakeys[self.barrierId].GuildEvent
	local dependrank = GuildEvent.onGuildRank[1]

	if status.top3 ~= nil then
		local rankdatas = self:GetGuildRankdata(dependrank)
		for i = status.beginindex + 1, status.endindex do
			self:BroadcastGuildDataMsg(rankdatas[i].guildid)
		end
		if status.top3 then
			self.guildrankRecord = {}
			for rank, guilddata in ipairs(rankdatas) do
				self.guildrankRecord[guilddata.guildid] = true
				if rank == self:GetSendGuildRankNumber() then break end
			end
		end
	end
	if self:CheckSendGuildRank(guildid) then
		self:SendGuildRankDataMsg(nil, dependrank)
	end
end

--帮会排行发送检查
function BaseBarrier:CheckSendGuildRank(guildid)
	return self.guildrankRecord and self.guildrankRecord[guildid]
end

--[[playerCtrl---------------接口--]]
--更新数据
function BaseBarrier:UpdatePlayer(dbid, datas)
	self.playerCtrl:UpdatePlayer(dbid, datas)
end

--更新数据
function BaseBarrier:UpdateGuild(guildid, datas)
	self.playerCtrl:UpdateGuild(guildid, datas)
end


--获取玩家数据
function BaseBarrier:GetPlayerData(dbid)
	return self.playerCtrl:GetPlayerData(dbid)
end

--获取玩家列表
function BaseBarrier:GetPlayerlist()
	return self.playerCtrl:GetPlayerlist()
end

--获取玩家排行
function BaseBarrier:GetPlayerRankdata(rankname)
	return self.playerCtrl:GetPlayerRankdata(rankname)
end

--获取帮会数据
function BaseBarrier:GetGuildData(guildid)
	return self.playerCtrl:GetGuildData(guildid)
end

--获取帮会数据
function BaseBarrier:GetGuildDataByDBID(dbid)
	return self.playerCtrl:GetGuildDataByDBID(dbid)
end

--获取帮会排行
function BaseBarrier:GetGuildRankdata(rankname)
	return self.playerCtrl:GetGuildRankdata(rankname)
end

--测试用
function BaseBarrier:PrintDebug(dbid)
	local player = self:GetPlayerData(dbid)
	server.mapCenter:Leave(dbid)
end

return BaseBarrier

