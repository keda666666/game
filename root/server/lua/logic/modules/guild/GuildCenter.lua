local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local GuildConfig = require "common.resource.GuildConfig"
local Guild = require "modules.guild.Guild"
local tbname = "guild"

local GuildCenter = {}

local _Office = GuildConfig.Office

function GuildCenter:Init()
	self.guildList = {}
	self.guildSummary = {}
	self.stopGuildAction = false
	self.receiveCount = 0
	self.receiveRecord = {}

	local caches = server.mysqlBlob:LoadDmg(tbname)
	for _, cache in ipairs(caches) do
		local guild = Guild.new()
		guild:Init(cache)
		self:AddGuild(guild)
		self.receiveRecord[guild:GetLeaderid()] = true
		self.receiveCount = self.receiveCount + 1
	end
	local GuildConfig = server.configCenter.GuildConfig
	self.divideTimer = lua_timer.add_timer_day(GuildConfig.auctionmail.time, -1, self.DivideAuctionRewards, self)
end

function GuildCenter:HotFix()
	print("GuildCenter:HotFix------------")
	for k, guild in pairs(self.guildList) do
		guild:HotFix()
	end
end

function GuildCenter:Release()
	for __, guild in pairs(self.guildList) do
		guild:Release()
	end
	if self.divideTimer then
		lua_timer.del_timer_day(self.divideTimer)
		self.divideTimer = nil
	end
end

function GuildCenter:GetGuild(guildid)
	return self.guildList[guildid]
end

function GuildCenter:GetGuildIdList()
	local idlist = {}
	for guildid, _ in pairs(self.guildList) do
		table.insert(idlist, guildid)
	end
	return idlist
end

function GuildCenter:GetGuildLevelList()
	local list = {}
	for guildid, guild in pairs(self.guildList) do
		list[guildid] = guild:GetLevel()
	end
	return list
end

function GuildCenter:GetGuildSummary()
	return self.guildSummary
end

function GuildCenter:AddGuild(guild)
	self.guildList[guild.dbid] = guild
	table.insert(self.guildSummary, guild.summary)
end

function GuildCenter:DelGuild(guild)
	self.guildList[guild.dbid] = nil
	for i, v in ipairs(self.guildSummary) do
		if v.id == guild.dbid then
			table.remove(self.guildSummary, i)
			return
		end
	end
end

function GuildCenter:onInitClient(player)
	local guildid = player.cache.guildid
	local guild = self:GetGuild(guildid)
    if not guild then
    	if guildid > 0 then
    		lua_app.log_error("GuildCenter:onLogin no guild:: guildid", guildid, player.cache.account, player.cache.name)
    		player.cache.guildid = 0
    	end
    	return
    end
    guild:onLogin(player)
end

function GuildCenter:onLogout(player)
	local guild = self:GetGuild(player.cache.guildid)
    if not guild then return end
    guild:onLogout(player)
end

local function _GenerateGuildData(player, level, name)
	local data = {
		name = name,
		variable = {
			level = level,
			fund = 0,
			notice = server.configCenter.GuildConfig.defaultdes,
			autoJoin = 0,
			needPower = 0,
			applyCount = 0,
			applyActors = {},
		},
		players = {}
	}
	local playerinfo = {
		playerid = player.dbid,
		playername = player.cache.name,
		office = _Office.Leader,
		job = player.cache.job,
		sex = player.cache.sex,
		vip = player.cache.vip,
		contribute = 0,
		todayContri = 0,
		power = player.cache.totalpower,
		logouttime = 0,
		jointime = lua_app.now(),
		pos = 1,
	}
	table.insert(data.players, playerinfo)
	return data
end

function GuildCenter:CreateGuild(player, level, name)
	local createCode = self:CheckCreateGuildAndPay(player, level, name)
	if createCode ~= 0 then return createCode end

	local guild = Guild.new()
	guild:Create(_GenerateGuildData(player, level, name))
	self:AddGuild(guild)
	self:CreateGuildGift(player)
	server.UnLockGuildName(name)
	player.guild:onJoinGuild(guild)
	server.chatCenter:ChatLink(10, player, nil, {server.chatConfig.CollectType.Player, player.dbid}, player.cache.name, guild:GetLevel(), name) 
	return createCode, guild.dbid
end

function GuildCenter:CheckCreateGuildAndPay(player, level, name)
	if self.stopGuildAction then return 5 end

	local GuildCreateConfig = server.configCenter.GuildCreateConfig[level]
	if not GuildCreateConfig then
		lua_app.log_error("GuildCenter:CreateGuild: no GuildCreateConfig level", player.cache.account, level)
		return 1
	end

	local vip = player.cache.vip
	if player.cache.level < GuildCreateConfig.level or vip < GuildCreateConfig.vipLv then
		lua_app.log_error("GuildCenter:CreateGuild: error:: level, vip", player.cache.level, vip, player.cache.account)
		return 2
	end

	local nameCheckRet = server.CheckGuildName(name)
	if nameCheckRet ~= 0 then
		local GuildConfig = server.configCenter.GuildConfig
		local errormsg
		if nameCheckRet == 6 or nameCheckRet == 8 then
			errormsg = GuildConfig.notice9
		else
			errormsg = GuildConfig.notice8
		end
		server.sendErr(player, errormsg)
		return nameCheckRet
	end

	if not player:PayRewards({GuildCreateConfig.cost}, server.baseConfig.YuanbaoRecordType.CreateGuild, string.format("GuildCenter:Create %d level", level)) then
		lua_app.log_info("PayRewards faild.")
		server.UnLockGuildName(name)
		return 4
	end
	return 0	
end

function GuildCenter:CreateGuildGift(player)
	local GuildConfig = server.configCenter.GuildConfig
	local receiveGift = self.receiveCount < GuildConfig.creatrewardcount and not self.receiveRecord[player.dbid]
	if receiveGift then
		player:GiveRewardAsFullMailDefault(GuildConfig.creatreward, "创建帮会奖励", server.baseConfig.YuanbaoRecordType.CreateGuild)
		self.receiveRecord[player.dbid] = true
		self.receiveCount = self.receiveCount + 1
	end
end

function GuildCenter:DivideAuctionRewards()
	for __, guild in pairs(self.guildList) do
		guild:DivideAuctionRewards()
	end
end

function GuildCenter:DissolveGuild(guildid)
    local guild = self:GetGuild(guildid)
    if not guild then
    	lua_app.log_error("GuildCenter:DissolveGuild: no guild", guildid)
    	return
    end
	if #guild:GetPlayers() ~= 0 then
		lua_app.log_error("GuildCenter:DissolveGuild:: #guild:GetPlayers() =", #guild:GetPlayers())
		return
	end
	self:DelGuild(guild)
	guild:Del()
end

function GuildCenter:SendGuildInfo(player)
    local guild = self:GetGuild(player.cache.guildid)
    if not guild then
    	server.sendReq(player, "sc_guild_info", { id = 0 })
    	return
    end
    server.sendReq(player,"sc_guild_info", guild:SendData())
end

function GuildCenter:onDayTimer()
	for _,guild in pairs(self.guildList) do
		guild:onDayTimer()
	end
end

function GuildCenter:ServerOpen()
	for _, guild in pairs(self.guildList) do
		guild:ServerOpen()
	end
end

function GuildCenter:Broadcast(guildid, name, msg)
	local guild = self.guildList[guildid]
	if guild then
		guild:Broadcast(name, msg)
	end
end

function server.GuildCall(src, funcname, ...)
	return lua_app.ret(server.guildCenter[funcname](server.guildCenter, ...))
end

function server.GuildSend(src, funcname, ...)
	server.guildCenter[funcname](server.guildCenter, ...)
end

server.SetCenter(GuildCenter, "guildCenter")
return GuildCenter
