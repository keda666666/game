local server = require "server"
local lua_app = require "lua_app"
local tbname = "datalist"
local tbcolumn = "guildboss"

local GuildBossMgr = {}

function GuildBossMgr:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self:InitRanklist(self.cache.ranklist)
end

function GuildBossMgr:InitRanklist(ranklist)
	self.playerranks = {}
	self.guildidtoranks = {}
	local playerranks = {}
	for dbid, v in pairs(ranklist) do
		table.insert(playerranks, v)
	end
	table.sort(playerranks, function(a, b)
			return a.damage > b.damage
		end)
	for i, v in ipairs(playerranks) do
		v.pos = i
		if i <= 50 then
			self.playerranks[i] = v
		end
	end
end

function GuildBossMgr:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function GuildBossMgr:SendRanks(damagelist, sendlist)
	local ranks = {}
	for _, v in pairs(damagelist) do
		table.insert(ranks, v)
	end
	table.sort(ranks, function(a, b)
			return a.damage > b.damage
		end)
	for i, v in ipairs(ranks) do
		v.pos = i
	end
	for dbid, serverid in pairs(sendlist) do
		if serverid == server.serverid then
			server.sendReqByDBID(dbid, "sc_guildboss_rank_now", {
					playerranks = ranks,
					mydamage	= damagelist[dbid] and damagelist[dbid].damage,
					myrank 		= damagelist[dbid] and damagelist[dbid].pos,
				})
		end
	end
end

function GuildBossMgr:SendShowRewards(ranks)
	for __, info in pairs(ranks) do
		server.sendReqByDBID(info.dbid, "sc_guildboss_rewards", { result = 1, rewards = info.rewards, })
	end
end

function GuildBossMgr:SetRanks(ranklist)
	self.cache.ranklist = ranklist
	self:InitRanklist(ranklist)
	self.cache.first = self.playerranks[1] or {}
end

function GuildBossMgr:GetRanks(dbid)
	local rankinfo = self.cache.ranklist[dbid] or {}
	local msg = {
		firstinfo		= self.cache.first,
		playerranks		= self.playerranks,
		mydamage		= rankinfo.damage,
		myrank			= rankinfo.pos,
	}
	server.sendReqByDBID(dbid, "sc_guildboss_rank_last", msg)
end

-- 奖励上架拍卖行
function GuildBossMgr:DoAuction(firstguildid, mapplayers)
	local guilds = {}
	for _, dbid in ipairs(mapplayers) do
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		if player and player.cache.guildid and player.cache.guildid ~= 0 then
			local guildid = player.cache.guildid
			guilds[guildid] = guilds[guildid] or {}
			table.insert(guilds[guildid], dbid)
		end
	end

	local WinGuilCfg = server.configCenter.GuildBossRewardConfig[1]
	local OtherGuildCfg = server.configCenter.GuildBossRewardConfig[2]
	for guildid, players in pairs(guilds) do
		local count = #players
		local list
		if guildid == firstguildid then
			list = WinGuilCfg
		else
			list = OtherGuildCfg
		end
		for _, cfg in pairs(list) do
			local min = cfg.num[1] or 1
			local max = cfg.num[2] or 999999
			if min <= count and count <= max then
				local times = math.random(cfg.rewardtime[1], cfg.rewardtime[2])
				for i=1,times do
					local rewards = server.dropCenter:DropGroup(cfg.reward)
					local _, aucitem = next(rewards)
					if aucitem then
						server.auctionMgr:ShelfLocal(0, aucitem.id, aucitem.count, guildid)
					end
				end
			end
		end
	end
end

function GuildBossMgr:Close()
end

function GuildBossMgr:EnterCrossMap(mapid)
	if mapid == server.configCenter.GuildBossBaseConfig.mapid then
		return self:IsCrossGames()
	end
	return true
end

function GuildBossMgr:ServerInfo()
	return {
		opencode = self:GetOpenCode(),
	}
end

function GuildBossMgr:IsCrossGames()
	return false
end

function GuildBossMgr:GetOpenCode()
	local unlockOpenDay = server.serverRunDay >= server.configCenter.GuildBossBaseConfig.serverday
	if self:IsActivityDay() and unlockOpenDay then
		if self:IsCrossGames() then
			return 2
		else
			return 1
		end
	end
	return 0
end

function GuildBossMgr:IsActivityDay()
	local opendays = server.configCenter.GuildBossBaseConfig.openday
	local week = lua_app.week()
	for _, v in ipairs(opendays) do
		if v == week then 
			return true 
		end
	end
	return false
end


server.SetCenter(GuildBossMgr, "guildBossMgr")
return GuildBossMgr