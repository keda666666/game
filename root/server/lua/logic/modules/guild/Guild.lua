local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local WeightData = require "WeightData"
local ItemConfig = require "common.resource.ItemConfig"
local GuildConfig = require "common.resource.GuildConfig"
local GuildRecord = require "modules.guild.GuildRecord"
local GuildFinancial = require "modules.guild.GuildFinancial"
local tbname = "guild"

local Guild = oo.class()

local _Office = GuildConfig.Office
local _RecordType = GuildConfig.RecordType

function _ConvertOfflinetime(time)
	return ((time == 0) and lua_app.now() or time)
end

function Guild:ctor(dbid)
	self.guildRecord = GuildRecord.new(self)
	self.guildFinancial = GuildFinancial.new(self)
	self.robotlist = {}
end

function Guild:Create(data)
	data.serverid = server.serverID
	self.cache = server.mysqlBlob:CreateDmg(tbname, data)
	self:RefrushData()
	self.guildRecord:Init()
	self.guildFinancial:Init()
end

function Guild:Init(cache)
	self.cache = cache
	self:RefrushData()
	self.guildRecord:Init()
	self.guildFinancial:Init()
end

function Guild:Del()
	server.mysqlBlob:DelDmg(tbname, self.cache)
	self.cache = nil
	self.dbid = nil
end

function Guild:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function Guild:HotFix()
	-- print("Guild:HotFix-----------")
end

function Guild:DelActorInfo(playerinfo)
    self.players[playerinfo.playerid] = nil
    local players = self.cache.players
    table.remove(players, playerinfo.pos)
    for i = playerinfo.pos, #players do
    	players[i].pos = i
    end
    self.summary.playercount = self.summary.playercount - 1
    self.summary.totalpower = self.summary.totalpower - playerinfo.power
    if playerinfo.office >= _Office.AssistLeader then
    	self.admin[playerinfo.playerid] = nil
    	if playerinfo.office == _Office.Leader then
    		self:RankMember()
    		local nextLeader = players[1]
    		if not nextLeader then
    			server.guildCenter:DissolveGuild(self.dbid)
    		else
		    	nextLeader.office = _Office.Leader
	    		self.leader = nextLeader
	    		self.admin[nextLeader.playerid] = nextLeader
	    		self.summary.leaderinfo = nextLeader
			    self:Broadcast("sc_guild_change_office_ret", {
			    		playerid = playerinfo.playerid,
			    		office = nextLeader.office,
			    	})
    		end
    	end
    end
end

function Guild:RefrushData()
	self.dbid = self.cache.dbid
	self.players = {}
	self.admin = {}
	local totalpower = 0
	for _, v in ipairs(self.cache.players) do
		totalpower = totalpower + v.power
		self.players[v.playerid] = v
		if v.office >= _Office.AssistLeader then
			if v.office == _Office.Leader then
				self.leader = self.players[v.playerid]
			end
			self.admin[v.playerid] = v
		end
	end
	local variable = self.cache.variable
	self.summary = {
			id = self.dbid,
			level = variable.level,
			playercount = #self.cache.players,
			name = self.cache.name,
			leaderinfo = self.leader,
			needPower = variable.needPower,
			totalpower = totalpower,
		}
end

function Guild:RankMember()
	local players = self.cache.players
	table.sort(players, function(a, b)
			return a.contribute > b.contribute
		end)

	local totalpower = 0
	for i, playerinfo in ipairs(players) do
		playerinfo.pos = i
		local player = server.playerCenter:GetPlayerByDBID(playerinfo.playerid)
		if player then
			self:UpdatePlayerInfo(player)
		end
		totalpower = totalpower + playerinfo.power
	end
	self.summary.totalpower = totalpower
end

function Guild:GetLeaderid()
	return self.leader.playerid
end

function Guild:GetName()
	if self.cache then
		return self.cache.name
	else
		return ""
	end
end

function Guild:SendData()
	return {
		id = self.dbid,
		name = self.cache.name,
		variable = self.cache.variable,
		summary = self.summary,
	}
end

function Guild:Broadcast(name, msg)
	for playerid,_ in pairs(self.players) do
		server.sendReqByDBID(playerid, name, msg)
	end
end

function Guild:SendToAdmin(name, msg)
	for playerid, _ in pairs(self.admin) do
		server.sendReqByDBID(playerid, name, msg)
	end
end

function Guild:GetAdmin(playerid)
	return self.admin[playerid]
end

function Guild:GetAdminCount()
	local count = 0
	for _,_ in pairs(self.admin) do
		count = count + 1
	end
	return count
end

function Guild:GetOffice(playerid)
	local playerinfo = self.players[playerid]
	if not playerinfo then
		lua_app.log_error("Guild:GetOffice no playerinfo:: playerid", playerid)
	end
	return self.players[playerid].office
end

function Guild:GetPlayers()
	return self.cache.players
end

function Guild:GetPlayerInfo(playerid)
	return self.players[playerid]
end

function Guild:GetLevel()
	return self.cache.variable.level
end

function Guild:GetPlayerCount()
	return self.summary.playercount
end

function Guild:GetApplyList()
	local list = {}
	for _, v in pairs(self.cache.variable.applyActors) do
		table.insert(list, v)
	end
	return list
end

function Guild:UpdateGuildLevel()
	local variable = self.cache.variable
	local GuildLevelConfig = server.configCenter.GuildLevelConfig
	if variable.level >= #GuildLevelConfig then
		lua_app.log_info("Guild has reached the maximum level.", variable.level)
		return
	end
	local cost = GuildLevelConfig[variable.level].upExp
	if variable.fund >= cost then
		variable.level = variable.level + 1
		self.summary.level = variable.level
		self:ChangeFund(nil, -cost)
		self:Broadcast("sc_guild_info", self:SendData())
		for __, playerinfo in ipairs(self:GetPlayers()) do
			local player = server.playerCenter:GetPlayerByDBID(playerinfo.playerid)
			if not player then return end
			player.shop:onUpdateUnlock()
		end
	end
end

function Guild:GetContribute(player)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		lua_app.log_error("Guild:GetContribute no playerinfo:: playerid", player.dbid, player.cache.account)
	end
	return playerinfo.curcontribute
end

function Guild:ChangeContribute(player, contribute)
	contribute = math.floor(contribute)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		lua_app.log_error("Guild:ChangeContribute no playerinfo:: playerid, contribute", player.dbid, contribute, player.cache.account)
		return
	end
	if contribute > 0 then
		playerinfo.contribute = playerinfo.contribute + contribute
		playerinfo.todayContri = (playerinfo.todayContri or 0) + contribute
	end
	player:ChangeContribute(contribute, ItemConfig.NumericType.GuildContrib)
	player.guild:SendGuildData()
end

function Guild:UpdateFund(fund)
	self:ChangeFund(nil, fund)
	self:UpdateGuildLevel()
end

function Guild:ChangeFund(player, fund)
	local variable = self.cache.variable
	variable.fund = variable.fund + math.floor(fund)
	self:Broadcast("sc_guild_fund", { fund = variable.fund })
end

function Guild:UpdatePlayerInfo(player)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		lua_app.log_info("Guild:UpdateActorInfo no playerinfo:: playerid", player.dbid, player.cache.account)
		return
	end
	playerinfo.power = player.cache.totalpower
end

function Guild:onInitClient(player)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		lua_app.log_error("Guild:onActorLogin no playerinfo:: playerid, cache.account, guildid, guildname", player.dbid, player.cache.account, self.dbid, self.cache.name)
    	player.cache.guildid = 0
		return
	end
	playerinfo.logouttime = 0
end

function Guild:onLogout(player)
	self:UpdatePlayerInfo(player)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		player.guild:onLeaveGuild(self)
		lua_app.log_error("Guild:onActorRelease no playerinfo:: playerid", player.dbid, player.cache.account)
		return
	end
	playerinfo.playername = player.cache.name
	playerinfo.logouttime = player.cache.lastonlinetime
	if playerinfo.office == _Office.Leader then
		self.summary.leaderinfo = playerinfo
	end
	self:GenerateRobot()
end

function Guild:GenerateRobot()
	if not self.cache then return end
	local robotNumber = 0
	local nowtime = lua_app.now()
	for dbid, __ in pairs(self.robotlist) do
		local playerinfo = self.players[dbid]
		if playerinfo then
			if playerinfo.logouttime + 86400 > nowtime then
				robotNumber = robotNumber + 1
			else
				self.robotlist[dbid] = nil
			end
		else
			self.robotlist[dbid] = nil
		end
	end
	--大于10不刷新
	if robotNumber >= 10 then return false end

	local function _PackRobotData(dbid)
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		return player.role:GetEntityShows()
	end

	local offlineData = WeightData.new()
	local offlineNumber = 0
	for dbid, playerdata in pairs(self.players) do
		if playerdata.logouttime + 86400 > nowtime and not self.robotlist[dbid] then
			offlineData:Add(10, dbid)
			offlineNumber = offlineNumber + 1
		end
	end

	local offlineRandomlist = offlineData:GetRandomCounts(offlineNumber)
	for __, dbid in ipairs(offlineRandomlist) do
		if robotNumber >= 10 then break end
		self.robotlist[dbid] = _PackRobotData(dbid)
		robotNumber = robotNumber + 1
	end
	self:Broadcast("sc_guild_robot_datas", {
			robotlist = self:GetRobotMsgData(),
		})
	return true
end

function Guild:GetRobotMsgData()
	local datas = {}
	for __, data in pairs(self.robotlist) do
		table.insert(datas, data)
	end
	return datas
end

function Guild:ChangeNotice(str)
	self.cache.variable.notice = str
end

function Guild:ChangeAutoJoin(auto, power)
	local variable = self.cache.variable
	variable.autoJoin = auto or 0
	variable.needPower = auto == 1 and power or 0
	self.summary.needPower = variable.needPower
end

function Guild:JoinIn(player)
	if self.players[player.dbid] then
		lua_app.log_error("Guild:JoinIn:: rejoin playerid", player.dbid, self.cache.name)
		server.sendReq(player, "sc_guild_notice_apply", { result = 1, id = self.dbid })
		return
	end
	local players = self.cache.players
	local data = {
		playerid = player.dbid,
		playername = player.cache.name,
		office = _Office.Common,
		job = player.cache.job,
		sex = player.cache.sex,
		vip = player.cache.vip,
		contribute = 0,
		curcontribute = player.cache.guildcontribute,
		todayContri = 0,
		power = player.cache.totalpower,
		logouttime = player.isLogin and 0 or player.cache.lastonlinetime,
		jointime = lua_app.now(),
	}
	table.insert(players, data)
	data.pos = #players
	self.players[player.dbid] = data
	self.summary.playercount = self.summary.playercount + 1
	self.summary.totalpower = self.summary.totalpower + data.power
	player.guild:onJoinGuild(self)
	self.guildRecord:AddGuildHistorys(_RecordType.Join, player.cache.name)
	server.sendReq(player, "sc_guild_notice_apply", { result = 1, id = self.dbid })
	self:Broadcast("sc_guild_info", self:SendData())
end

function Guild:IsApplySucess(player)
	if server.guildCenter.stopGuildAction then return end
	local variable = self.cache.variable
	local applyActors = variable.applyActors
	if applyActors[player.dbid] then
		return true
	end
	return false
end

function Guild:JoinGuild(player)
	if server.guildCenter.stopGuildAction then return end
	local variable = self.cache.variable
	local applyActors = variable.applyActors
	if applyActors[player.dbid] then
		return
	end
	local guildMaxMember = server.configCenter.GuildLevelConfig[self:GetLevel()].people
	if self.summary.playercount >= guildMaxMember then
		server.sendErr(player, server.configCenter.GuildConfig.notice6)
		return
	end
	if player.cache.guildid ~= 0 then
		server.sendReq(player, "sc_guild_notice_apply", { result = 0, id = self.dbid })
		return
	end
	if variable.applyCount > 99 then
		return
	end
	if variable.autoJoin == 1 then
		if player.cache.totalpower >= variable.needPower then
			self:JoinIn(player)
		end
		return
	end
	variable.applyCount = variable.applyCount + 1
	applyActors[player.dbid] = {
		playerid = player.dbid,
		vip = player.cache.vip,
		job = player.cache.job,
		sex = player.cache.sex,
		power = player.cache.totalpower,
		playername = player.cache.name,
		applytime = lua_app.now(),
		level = player.cache.level,
		logouttime = 0,
	}
	self:SendToAdmin("sc_guild_join_info")
end

function Guild:SetJoin(playerid, result, admin)
	if server.guildCenter.stopGuildAction then return end
	local variable = self.cache.variable
	local applyActors = variable.applyActors
	if not applyActors[playerid] then
		server.sendErr(admin, "用户没有申请加入帮会")
		return
	end
	local guildMaxMember = server.configCenter.GuildLevelConfig[self:GetLevel()].people
	if self.summary.playercount >= guildMaxMember then
		server.sendErr(admin, server.configCenter.GuildConfig.notice6)		--人数已满
		return
	end
	variable.applyCount = variable.applyCount - 1
	applyActors[playerid] = nil
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("Guild:SetJoin:: playerid", playerid, self.cache.name)
		return
	end
	player.guild:ApplyUndo(self.dbid)
	if result == 1 then
		if player.cache.guildid ~= 0 then
			server.sendReq(player, "sc_guild_notice_apply", { result = 0, id = self.dbid })
			server.sendErr(admin, server.configCenter.GuildConfig.notice7) 		--加入了其它帮会
			return
		end
		self:JoinIn(player)
	else
		server.sendReq(player, "sc_guild_notice_apply", { result = result, id = self.dbid })
	end
end

function Guild:Quit(player)
	if server.guildCenter.stopGuildAction then return end
    local playerinfo = self.players[player.dbid]
    if not playerinfo then
    	lua_app.log_error("Guild:Quit: no playerinfo in guild", player.cache.account, guild.cache.name)
    	return
    end

    self:Broadcast("sc_guild_kick_ret", { playerid = player.dbid })
    self:DelActorInfo(playerinfo)
	player.guild:onLeaveGuild(self)
    if self.cache then
		self.guildRecord:AddGuildHistorys(_RecordType.Quit, player.cache.name)
		self:Broadcast("sc_guild_info", self:SendData())
	end
end

function Guild:SetOffice(playerid, office)
	if server.guildCenter.stopGuildAction then return end
	local playerinfo = self.players[playerid]
	if not playerinfo then
    	lua_app.log_error("Guild:SetOffice: no playerinfo in guild", playerid, self.cache.name)
    	return
    end
    local officeMaxCounts = server.configCenter.GuildConfig.management
    if playerinfo.office < _Office.AssistLeader then
    	if office ~= _Office.AssistLeader then return end
    	if self:GetAdminCount() - 1 >= officeMaxCounts then
    		lua_app.log_error("Guild:SetOffice: AssistLeader count enough", self:GetAdminCount(), officeMaxCounts)
    		return
    	end
    	playerinfo.office = _Office.AssistLeader
    	self.admin[playerid] = playerinfo
		self.guildRecord:AddGuildHistorys(_RecordType.AssistLeader, playerinfo.playername)
    else
    	if playerinfo.office ~= _Office.AssistLeader then
    		lua_app.log_error("Guild:SetOffice: old office:", playerinfo.office)
    		return
    	end
    	if office < _Office.AssistLeader then
    		playerinfo.office = _Office.Common
    		self.admin[playerid] = nil
    	else
    		if office ~= _Office.Leader then
    			lua_app.log_error("Guild:SetOffice: old office, office:", playerinfo.office, office)
    			return
    		end
    		local oldleader = self.leader
    		if oldleader then
	    		oldleader.office = _Office.AssistLeader
			    self:Broadcast("sc_guild_change_office_ret", {
			    		playerid = oldleader.playerid,
			    		office = oldleader.office,
			    	})
			end
    		self.leader = playerinfo
    		self.summary.leaderinfo = playerinfo
	    	playerinfo.office = office
			self.guildRecord:AddGuildHistorys(_RecordType.Leader, playerinfo.playername)
    	end
    end
    self:Broadcast("sc_guild_change_office_ret", {
    		playerid = playerid,
    		office = office,
    	})
end

function Guild:Kick(playerid)
	if server.guildCenter.stopGuildAction then return end
	local guild_config = server.configCenter.GuildConfig
	local playerinfo = self.players[playerid]
	if not playerinfo then
    	lua_app.log_error("Guild:Kick: no playerinfo in guild", playerid, self.cache.name)
    	return
    end
    if self.admin[playerid] then
    	lua_app.log_error("Guild:Kick: can not kick admin", playerid, self.cache.name)
    	return
    end
    if not self.players[playerid] then
    	lua_app.log_error("Guild:Kick: no guildplayer", playerid, self.cache.name)
    	return
    end
    self:DelActorInfo(playerinfo)
	self.guildRecord:AddGuildHistorys(_RecordType.ForceQuit, playerinfo.playername)
    self:SendToAdmin("sc_guild_kick_ret", { playerid = playerid })

    server.mailCenter:SendMail(playerid, guild_config.kickMailTitle, guild_config.kickMailContext)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
    	lua_app.log_error("Guild:Kick: no player: playerid, self.dbid", playerid, self.dbid)
    	return
	end
	if player.cache.guildid ~= self.dbid then
		lua_app.log_error("Guild:Kick: not the same guildid: playerid, player.cache.guildid, self.dbid", playerid, player.cache.guildid, self.dbid)
		return
	end
	player.guild:onLeaveGuild(self)
    server.sendReq(player, "sc_guild_kick_ret", { playerid = playerid })
    self:Broadcast("sc_guild_info", self:SendData())
end

function Guild:AddAuctionReward(rewards)
	local variable = self.cache.variable
	local auctionreward = table.GetTbPlus("count")
	auctionreward = auctionreward + rewards + (variable.auctionreward or {})
	variable.auctionreward = auctionreward
end

function Guild:DivideAuctionRewards()
	local variable = self.cache.variable
	local auctionreward = variable.auctionreward or {}
	local memberlist = self:GetActiveMember()
	local dividerewards = self:GetAverageReward(auctionreward, #memberlist)
	if not next(dividerewards) then return end

	local mailinfo = server.configCenter.GuildConfig.auctionmail
	for __, playerinfo in ipairs(memberlist) do
		server.mailCenter:SendMail(playerinfo.playerid, mailinfo.mailtitle, mailinfo.maildes, dividerewards, server.baseConfig.YuanbaoRecordType.Guilddividend, "帮会拍卖分红")
	end

	variable.auctionreward = {}
end

function Guild:GetAverageReward(rewards, count)
	local averagereward = {}
	if count > 0 then
		for __, reward in ipairs(rewards) do
			reward.count = math.ceil(reward.count / count)
			table.insert(averagereward, reward)
		end
	end
	return averagereward
end

function Guild:GetActiveMember()
	local activelist = {}
	for __, playerinfo in pairs(self.players) do
		if os.intervalDays(_ConvertOfflinetime(playerinfo.logouttime)) <= server.configCenter.GuildConfig.leavetime then
			table.insert(activelist, playerinfo)
		end
	end
	return activelist
end

--给成员奖励
function Guild:GiveMemberReward(rewards, sourceName, type, log)
	for playerid,_ in pairs(self.players) do
		server.mailCenter:GiveRewardAsFullMailDefault(playerid, rewards, sourceName, type, log)
	end
end

function Guild:GiveMemberRewardByMail(title, contexts, rewards, type, log)
	for playerid,_ in pairs(self.players) do
		server.mailCenter:SendMail(playerid, title, contexts, rewards, type, log)
	end
end

function Guild:Rename(name, player)
	if self.leader.playerid ~= player.dbid then return 1 end
	local GuildConfig = server.configCenter.GuildConfig
	local nameCheckRet = server.CheckGuildName(name)
	if nameCheckRet ~= 0 then
		server.sendReq(player, "sc_guild_rename_ret", { errorInfo = "该公会名不可使用" })
		return
	end
	if not player:PayRewards({GuildConfig.renamecost}, server.baseConfig.YuanbaoRecordType.GuildRename, "Guild:Rename") then
		server.sendReq(player, "sc_guild_rename_ret", { errorInfo = "改名费用不足" })
		return
	end
	self.summary.name = name
	self.cache.name = name
	server.UnLockGuildName(name)
	self.cache.changename_count = self.cache.changename_count - 1
	server.sendReq(player, "sc_guild_rename_ret", { newGuildName = name })
end

function Guild:Demise()
	if server.guildCenter.stopGuildAction then return end
	local GuildConfig = server.configCenter.GuildConfig
    if os.intervalDays(_ConvertOfflinetime(self.leader.logouttime)) < GuildConfig.retiretime then
    	return
    end
    local oldleader = self.leader
    self:RankMember()
    
    local nextleader = false
    for __, playerinfo in ipairs(self:GetPlayers()) do
    	if playerinfo.playerid ~= oldleader.playerid and 
    	 os.intervalDays(_ConvertOfflinetime(playerinfo.logouttime)) <= GuildConfig.retiretime then
    		playerinfo.office = _Office.Leader
    		self.leader = playerinfo
    		self.admin[playerinfo.playerid] = playerinfo
    		nextleader = true
    		break
    	end
    end

    if not nextleader then return end

    self.admin[oldleader.playerid] = nil
    oldleader.office = _Office.Common

    self:Broadcast("sc_guild_change_office_ret", {
    		playerid = oldleader.playerid,
    		office = oldleader.office,
    	})

    self.guildRecord:AddGuildHistorys(_RecordType.Leader, self.leader.playername)
    self.summary.leaderinfo = self.leader
    self:Broadcast("sc_guild_change_office_ret", {
    		playerid = self.leader.playerid,
    		office = self.leader.office,
    	})
end

function Guild:ClearApply()
	local variable = self.cache.variable
	local applyActors = variable.applyActors
	local GuildConfig = server.configCenter.GuildConfig
	for dbid, playerinfo in pairs(applyActors) do
		if os.intervalDays(playerinfo.applytime) >= GuildConfig.applytime then
			local player = server.playerCenter:DoGetPlayerByDBID(dbid)
			applyActors[dbid] = nil
			player.guild:ApplyUndo(self.dbid)
		end
	end
end

function Guild:onLogin(player)
	local playerinfo = self.players[player.dbid]
	if not playerinfo then
		player.guild:onLeaveGuild(self)
		lua_app.log_error("Guild:onActorRelease no playerinfo:: playerid", player.dbid, player.cache.account)
		return
	end
	playerinfo.logouttime = 0
	self.guildFinancial:onLogin(player)
	self.guildRecord:onLogin(player)
	server.sendReq(player,"sc_guild_info", self:SendData())
	if not self:GenerateRobot() then
		server.sendReq(player, "sc_guild_robot_datas", {
				robotlist = self:GetRobotMsgData(),
			})
	end
end

function Guild:UpdateApplyInfo(player, offline)
	local variable = self.cache.variable
	local applyActors = variable.applyActors
	if not applyActors[player.dbid] then
		return
	end
	local data = applyActors[player.dbid]
	if offline then
		data.logouttime = player.cache.lastonlinetime
	else
		data.logouttime = 0
	end
end

function Guild:onDayTimer()
	self:ClearApply()
	self:Demise()
	self.guildFinancial:onDayTimer()
end

function Guild:ServerOpen()
	self:GenerateRobot()
end

return Guild
