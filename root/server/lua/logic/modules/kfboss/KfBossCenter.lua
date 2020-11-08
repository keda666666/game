local server = require "server"
local lua_app = require "lua_app"
local tbname = "datalist"
local tbcolumn = "kfboss"

local KfBossCenter = {}

function KfBossCenter:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self:InitRanklist(self.cache.ranklist)
end

function KfBossCenter:InitRanklist(ranklist)
	self.playerranks = {}
	self.guildidtoranks = {}
	-- self.guildranks = {}
	local playerranks = {}
	for dbid, v in pairs(ranklist) do
		table.insert(playerranks, v)
		-- if not self.guildidtoranks[v.guildid] then
		-- 	self.guildidtoranks[v.guildid] = {
		-- 		name		= v.guildname,
		-- 		guildid		= v.guildid,
		-- 		serverid	= v.serverid,
		-- 		damage		= v.damage,
		-- 	}
		-- else
		-- 	self.guildidtoranks[v.guildid].damage = self.guildidtoranks[v.guildid].damage + v.damage
		-- end
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
	-- local guildranks = {}
	-- for guildid, v in pairs(self.guildidtoranks) do
	-- 	table.insert(guildranks, v)
	-- end
	-- table.sort(guildranks, function(a, b)
	-- 		return a.damage > b.damage
	-- 	end)
	-- for i, v in ipairs(guildranks) do
	-- 	v.pos = i
	-- 	if i <= 20 then
	-- 		self.guildranks[i] = v
	-- 	end
	-- end
end

function KfBossCenter:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function KfBossCenter:SendRanks(damagelist, sendlist)
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
			server.sendReqByDBID(dbid, "sc_kfboss_rank_now", {
					playerranks = ranks,
					mydamage	= damagelist[dbid] and damagelist[dbid].damage,
					myrank 		= damagelist[dbid] and damagelist[dbid].pos,
				})
		end
	end
end

function KfBossCenter:SendShowRewards(winrewards, inrewards, sendplayers)
	for dbid, info in pairs(sendplayers) do
		if info.serverid == server.serverid then
			if info.iswin == 1 then
				server.sendReqByDBID(dbid, "sc_kfboss_rewards", { result = 1, rewards = winrewards, })
			else
				server.sendReqByDBID(dbid, "sc_kfboss_rewards", { result = 0, rewards = inrewards, })
			end
		end
	end
end

function KfBossCenter:SetRanks(ranklist)
	self.cache.ranklist = ranklist
	self:InitRanklist(ranklist)
	self.cache.first = self.playerranks[1] or {}
end

function KfBossCenter:GetRanks(dbid)
	local rankinfo = self.cache.ranklist[dbid] or {}
	local msg = {
		firstinfo		= self.cache.first,
		playerranks		= self.playerranks,
		mydamage		= rankinfo.damage,
		myrank			= rankinfo.pos,
		-- guildranks		= self.guildranks,
		-- myguilddamage	= self.guildidtoranks[rankinfo.guildid].damage,
		-- myguildrank		= self.guildidtoranks[rankinfo.guildid].pos,
	}
	server.sendReqByDBID(dbid, "sc_kfboss_rank_last", msg)
end

-- 奖励上架拍卖行
function KfBossCenter:DoAuction(firstguildid, mapplayers)
	local guilds = {}
	for _, dbid in ipairs(mapplayers) do
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		if player and player.cache.guildid and player.cache.guildid ~= 0 then
			local guildid = player.cache.guildid
			guilds[guildid] = guilds[guildid] or {}
			table.insert(guilds[guildid], dbid)
		end
	end

	local WinGuilCfg = server.configCenter.KfBossRewardConfig[1]
	local OtherGuildCfg = server.configCenter.KfBossRewardConfig[2]
	local auctionrewards = {}
	for guildid, players in pairs(guilds) do
		local count = #players
		local list
		if guildid == firstguildid then
			list = WinGuilCfg
		else
			list = OtherGuildCfg
		end
		auctionrewards[guildid] = auctionrewards[guildid] or {}
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
						table.insert(auctionrewards[guildid], aucitem)
					end
				end
			end
		end
	end
	server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "SendReport", auctionrewards)
end

function KfBossCenter:Close()
	self.cache.firstopen = false
end

function KfBossCenter:EnterCrossMap(mapid)
	if mapid == server.configCenter.KfBossBaseConfig.mapid then
		return self:IsCrossGames()
	end
	return true
end

function KfBossCenter:ServerInfo()
	return { 
		opencode = self:GetOpenCode() 
	}
end

function KfBossCenter:IsCrossGames()
	return (not self.cache.firstopen)
end

function KfBossCenter:GetOpenCode()
	local unlockOpenDay = server.serverRunDay >= server.configCenter.KfBossBaseConfig.serverday
	if self:IsActivityDay() and unlockOpenDay then
		if self:IsCrossGames() then
			return 2
		else
			return 1
		end
	end
	return 0
end

function KfBossCenter:IsActivityDay()
	local opendays = server.configCenter.KfBossBaseConfig.openday
	local week = lua_app.week()
	for _, v in ipairs(opendays) do
		if v == week then 
			return true 
		end
	end
	return false
end

server.SetCenter(KfBossCenter, "kfBossCenter")
return KfBossCenter
