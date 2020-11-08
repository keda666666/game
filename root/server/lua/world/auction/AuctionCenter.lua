local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_timer = require "lua_timer"
local ItemConfig = require "resource.ItemConfig"
local ChatConfig = require "resource.ChatConfig"
local tbname = server.GetSqlName("auctions")
local _StatusShow 	= 1	-- 公示
local _StatusAuc 	= 2 -- 竞拍
local _StatusRob 	= 3 -- 抢拍
local _StatusDeal 	= 4 -- 成交
local _StatusFlow 	= 5 -- 流拍

-- 拍卖行主控文件
local AuctionCenter = {}

function AuctionCenter:Init()
	self.observers = {}
	self.auctions = {}
	self.deals = {}
	self.flows = {}
	local deadline = lua_app.now() - 3600 * 24 * 7
	local caches = server.mysqlBlob:LoadDmg(tbname)
	for _, cache in ipairs(caches) do
		if cache.status == _StatusDeal then
			if cache.createtime < deadline then
				server.mysqlCenter:delete(tbname, { dbid = cache.dbid })
			else
				self.deals[cache.dbid] = cache
			end
		elseif cache.status == _StatusFlow then
			if cache.createtime < deadline then
				server.mysqlCenter:delete(tbname, { dbid = cache.dbid })
			else
				self.flows[cache.dbid] = cache
			end
		else
			self.auctions[cache.dbid] = cache
		end
		
	end

	self.timer = lua_app.add_update_timer(20000, self, "Loop")
end

function AuctionCenter:Release()
	if self.timer then
		lua_app.del_local_timer(self.timer)
	end
	for _, cache in pairs(self.auctions) do
		cache(true)
	end
	self.auctions = {}
end

function AuctionCenter:HotFix()
	print("AuctionCenter:HotFix-----")
end

function AuctionCenter:Loop()
	self.timer = lua_app.add_update_timer(1000, self, "Loop")
	local cfg = server.configCenter.AuctionBaseConfig
	local now = lua_app.now()
	for dbid, auction in pairs(self.auctions) do
		if auction.status == _StatusDeal or auction.status == _StatusFlow then

		end
		if auction.createtime + cfg.showtime + cfg.auctiontime + cfg.robtime <= now then
			self:Timeout(dbid)
		elseif auction.createtime + cfg.showtime + cfg.auctiontime <= now then
			if auction.status == _StatusAuc then
				auction.status = _StatusRob
			end
		elseif auction.createtime + cfg.showtime <= now then
			if auction.status == _StatusShow then
				auction.status = _StatusAuc
			end
		end
	end
end

-- 时间到
function AuctionCenter:Timeout(dbid)
	local auction = self.auctions[dbid]
	if auction.offerid > 0 then
		self:Deal(dbid)
	else
		-- 帮会拍卖转到全服拍卖
		local isflowback = true
		if auction.guildid > 0 then
			local ret = server.serverCenter:CallLogicsMod("auctionMgr", "ShelfGlobal", auction.playerid, auction.itemid, auction.count, 0)
			if ret then
				isflowback = false
			end
		end
		if isflowback and auction.playerid > 0 then
			server.serverCenter:SendLogicsMod("auctionMgr", "GetFlowItem", auction.playerid, auction.itemid, auction.count)
		end
		auction.status = _StatusFlow
		auction(true)
		self.flows[auction.dbid] = auction
		self.auctions[auction.dbid] = nil
	end
	lua_app.log_info("AuctionCenter:Timeout ", auction.dbid, auction.itemid, auction.count, auction.playerid, auction.playername, auction.offerid, auction.offername, lua_app.now())
end


-- 上架
function AuctionCenter:Shelf(playerid, itemid, count, guildid)
	local AuctionItemConfig = server.configCenter.AuctionListConfig[itemid]
	local playername = "系统"
	local player
	if playerid > 0 then
		player = server.playerCenter:GetPlayerByDBID(playerid)
		if not player then return false end
		playername = player.cache.name()
	end
	if not AuctionItemConfig then return false end
	guildid = guildid or 0
	local auction = {
		playerid = playerid,
		playername = playername,
		guildid = guildid,
		itemid = itemid,
		count = count,
		createtime = lua_app.now(),
		status = _StatusShow,
		price = table.wcopy(AuctionItemConfig.startprice),
		offerid = 0,
		offername = "",
		dealprice = AuctionItemConfig.price.count,
		addprice = AuctionItemConfig.addprice.count,
		numerictype = AuctionItemConfig.price.id,
		record = {},
	}
	local cache = server.mysqlBlob:CreateDmg(tbname, auction)
	self.auctions[cache.dbid] = cache
	if playerid > 0 and player then
		local ratioData = player.auctionPlug:GetRatioData()
		self:SendList(playerid, ratioData.aucratio, ratioData.aucratioAct, ratioData.lockratio, guildid)
	end
	
	if server.serverCenter:IsCross() then
		local waittime = ChatConfig:GetWaitInterval(43, server.configCenter.ChatConstConfig.spacetime)
		if waittime <= 0 then
			server.serverCenter:SendLogicsMod("chatCenter", "ChatLink", 43)
		end
	end

	lua_app.log_info("AuctionCenter:Shelf ", cache.dbid, playerid, itemid, guildid, count, auction.createtime)
	return true
end

-- 竞拍
function AuctionCenter:Offer(playerid, id, guildid)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end
	local auction = self.auctions[id]
	if not auction then
		server.sendErr(player, "竞拍已结束")
		print("Offer no auction item", playerid, id, guildid)
		return
	end

	if auction.status ~= _StatusAuc and auction.status ~= _StatusRob then
		server.sendErr(player, "竞拍未开始")
		return
	end

	local AuctionItemConfig = server.configCenter.AuctionListConfig[auction.itemid]
	if not AuctionItemConfig then
		return
	end
	local oldcount = auction.price.count
	local newcount = oldcount + AuctionItemConfig.addprice.count
	if auction.offerid == 0 then
		newcount = oldcount
	end
	-- 判断是否大于一口价
	if newcount > AuctionItemConfig.price.count then
		newcount = AuctionItemConfig.price.count
	end

	if player.auctionPlug:AllRatio() < (newcount * auction.count) then
		server.sendErr(player, "拍卖额度不足")
		return
	end
	local playername = player.cache.name()

	local newprice = {type = auction.price.type, id = auction.price.id, count = newcount * auction.count}
	if not player:PayRewards({newprice}, server.baseConfig.YuanbaoRecordType.Auction, "Auction:Offer") then
		server.sendErr(player, "元宝不足，不能竞拍")
		print("AuctionCenter:Offer money not enough", newprice.type, newprice.id, newprice.count)
		return
	end

	if auction.offerid > 0 then
		local lastoffer = {id = auction.offerid, name = auction.offername, time = auction.offertime}
		table.insert(auction.record, lastoffer)
		if guildid > 0 then
			server.serverCenter:CallLocalMod("logic", "auctionMgr", "PayBack", auction.offerid, auction.price, auction.itemid, auction.count)
		else
			server.serverCenter:SendLogicsMod("auctionMgr", "PayBack", auction.offerid, auction.price, auction.itemid, auction.count)
		end

		local chatData = ChatConfig:PackLinkData(6, nil, playername)
		server.sendReqByDBID(auction.offerid, "sc_chat_new_msg", {chatData = chatData})
	end
	auction.price.count = newcount
	auction.offerid = playerid
	auction.offername = playername
	auction.offertime = lua_app.now()

	player.auctionPlug:LockRatio(math.floor(newcount * auction.count))
	if auction.price.count == AuctionItemConfig.price.count then
		self:Deal(id)
	end
	self:SendUpdate(playerid, guildid, auction)
	lua_app.log_info("AuctionCenter:Offer ", id, playerid, guildid, newcount)
end

-- 一口价买走
function AuctionCenter:Buy(playerid, id, guildid)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end
	local auction = self.auctions[id]
	if not auction then
		server.sendErr(player, "竞拍已结束")
		print("Buy no auction item", playerid, id, guildid)
		return
	end

	if auction.status ~= _StatusAuc and auction.status ~= _StatusRob then
		server.sendErr(player, "竞拍未开始")
		return
	end

	local AuctionItemConfig = server.configCenter.AuctionListConfig[auction.itemid]
	if not AuctionItemConfig then
		return
	end
	local newcount = AuctionItemConfig.price.count

	if player.auctionPlug:AllRatio() < (newcount * auction.count) then
		server.sendErr(player, "拍卖额度不足")
		return
	end

	local newprice = {type = auction.price.type, id = auction.price.id, count = newcount * auction.count}
	if not player:PayRewards({newprice}, server.baseConfig.YuanbaoRecordType.Auction, "Auction:Buy") then
		server.sendErr(player, "元宝不足，不能购买")
		print("AuctionCenter:Buy money not enough", newprice.type, newprice.id, newprice.count)
		return
	end

	if auction.offerid > 0 then
		local lastoffer = {id = auction.offerid, name = auction.offername, time = auction.offertime}
		table.insert(auction.record, lastoffer)
		if guildid > 0 then
			server.serverCenter:CallLocalMod("logic", "auctionMgr", "PayBack", auction.offerid, auction.price, auction.itemid, auction.count)
		else
			server.serverCenter:SendLogicsMod("auctionMgr", "PayBack", auction.offerid, auction.price, auction.itemid, auction.count)
		end
	end
	auction.price.count = newcount
	auction.offerid = playerid
	auction.offername = player.cache.name()
	auction.offertime = lua_app.now()
	auction.isbuy = 1

	player.auctionPlug:LockRatio(math.floor(newcount * auction.count))
	self:Deal(id)
	self:SendUpdate(playerid, guildid, auction)
	lua_app.log_info("AuctionCenter:Buy ", id, playerid, guildid, newcount)
end

-- 成交
function AuctionCenter:Deal(id)
	local auction = self.auctions[id]
	if not auction then
		print("Deal no auction item", id)
		return
	end

	local guildid = auction.guildid or 0
	if guildid > 0 then
		if auction.playerid > 0 then
			server.serverCenter:CallLocalMod("logic", "auctionMgr", "PayDeal", auction.playerid, auction.price, auction.count, guildid)
		else
			server.serverCenter:CallLocalMod("logic", "auctionMgr", "PayDealGuild", auction.playerid, auction.price, auction.count, guildid)
		end
		server.serverCenter:CallLocalMod("logic", "auctionMgr", "GetDealItem", auction.offerid, auction.price, auction.itemid, auction.count, guildid)
	else
		if auction.playerid > 0 then
			server.serverCenter:SendLogicsMod("auctionMgr", "PayDeal", auction.playerid, auction.price, auction.count, guildid)
		end
		server.serverCenter:SendLogicsMod("auctionMgr", "GetDealItem", auction.offerid, auction.price, auction.itemid, auction.count, guildid)
	end
	auction.status = _StatusDeal
	auction.dealtime = lua_app.now()
	auction(true)
	self.deals[auction.dbid] = auction
	self.auctions[auction.dbid] = nil
	lua_app.log_info("AuctionCenter:Deal ", id, auction.playerid, auction.offerid)
end

function AuctionCenter:SendList(playerid, ratio, ratioAct, lockratio, guildid, flag)
	guildid = guildid or 0
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end

	local max = 999
	local list = self.auctions
	local msgname = "sc_auction_list"
	if flag == "record" then
		max = 60
		list = self.deals
		msgname = "sc_auction_record"
	end

	local len = 0
	local msg = {}
	msg.ratio = ratio
	msg.ratioAct = ratioAct
	msg.lockratio = lockratio
	msg.guildid = guildid
	msg.items = {}
	for dbid, auction in pairs(list) do
		if auction.guildid == guildid then
			local info = {
				id = dbid,
				itemid = auction.itemid,
				count = auction.count,
				price = auction.price.count,
				playername = auction.playername,
				offername = auction.offername,
				status = auction.status,
				createtime = auction.createtime,
				dealtime = auction.dealtime,
				isbuy = auction.isbuy,
				dealprice = auction.dealprice,
				addprice = auction.addprice,
				numerictype = auction.numerictype,
			}
			table.insert(msg.items, info)
			len = len + 1
			if len >= max then
				break
			end
		end
	end
	server.sendReqByDBID(player.dbid, msgname, msg)
	self.observers[player.dbid] = true
end

function AuctionCenter:SendUpdateByID(playerid, guildid, auctionid)
	guildid = guildid or 0
	local auction = self.auctions[auctionid] or self.deals[auctionid] or self.flows[auctionid]
	if auction then
		self:SendUpdate(playerid, guildid, auction)
	end
end

function AuctionCenter:SendUpdate(playerid, guildid, auction)
	local msg = {}
	msg.guildid = guildid
	msg.item = {
		id = auction.dbid,
		itemid = auction.itemid,
		count = auction.count,
		price = auction.price.count,
		playername = auction.playername,
		offername = auction.offername,
		status = auction.status,
		createtime = auction.createtime,
		dealtime = auction.dealtime,
		isbuy = auction.isbuy,
		dealprice = auction.dealprice,
		addprice = auction.addprice,
		numerictype = auction.numerictype
	}
	-- server.sendReqByDBID(playerid, "sc_auction_update", msg)
	self.observers[playerid] = true
	server.broadcastList("sc_auction_update", msg, self.observers)
end

function AuctionCenter:onLogout(player)
	if not player then return end
	if self.observers then
		self.observers[player.dbid] = nil
	end
end

server.SetCenter(AuctionCenter, "auctionCenter")
return AuctionCenter
