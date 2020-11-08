local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local ItemConfig = require "resource.ItemConfig"

-- 拍卖行本地主控文件
local AuctionMgr = {}

function AuctionMgr:Init()
end

-- 返还
function AuctionMgr:PayBack(playerid, price, itemid, count)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if player then
		local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
		price.count = price.count * count
		local itemConf = server.configCenter.ItemConfig[itemid]
		local content = string.format(AuctionBaseConfig.maildes4, itemConf.name)
		server.mailCenter:SendMail(playerid, AuctionBaseConfig.mailtitle4, content, {table.wcopy(price)}, server.baseConfig.YuanbaoRecordType.Auction)
		player.auctionPlug:FreeRatio(price.count)
		lua_app.log_info("AuctionMgr:PayBack ", playerid, price.count, count)
	end
end

-- 成交给钱
function AuctionMgr:PayDeal(playerid, price, count, guildid)
	guildid = guildid or 0
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		return
	end
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	local tax = 0
	local title, content
	if guildid > 0 then
		tax = AuctionBaseConfig.guildtax
		title = AuctionBaseConfig.mailtitle3
		content = string.format(AuctionBaseConfig.maildes3, price.count.."元宝")
	else
		tax = AuctionBaseConfig.alltax
		title = AuctionBaseConfig.mailtitle2
		content = string.format(AuctionBaseConfig.maildes2, price.count.."元宝")
	end
	price.count = math.floor(price.count * (1 - tax / 100) * count)
	server.mailCenter:SendMail(playerid, title, content, {table.wcopy(price)}, server.baseConfig.YuanbaoRecordType.Auction)
	lua_app.log_info("AuctionMgr:PayDeal ", playerid, price.count, count, guildid)

end

function AuctionMgr:PayDealGuild(playerid, price, count, guildid)
	local guild = server.guildCenter:GetGuild(guildid)
	if guild then
		local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
		price.count = math.floor(price.count * (1 - AuctionBaseConfig.guildtax / 100) * count)
		guild:AddAuctionReward(price)
		lua_app.log_info("AuctionMgr:PayDeal ", playerid, price.count, count, guildid)
	end
end

-- 成交给货
function AuctionMgr:GetDealItem(playerid, price, itemid, count, guildid)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		return
	end
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	local reward = {type = ItemConfig.AwardType.Item, id = itemid, count = count}
	player:GiveRewardAsFullMailDefault({reward}, "拍卖行", server.baseConfig.YuanbaoRecordType.Auction)
	local ratio = math.floor(price.count * count)
	player.auctionPlug:DelRatio(ratio)
	player.auctionPlug:FreeRatio(ratio)
	lua_app.log_info("AuctionMgr:GetDealItem ", playerid, itemid, count, guildid)
end

-- 流拍返还
function AuctionMgr:GetFlowItem(playerid, itemid, count)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		return
	end
	local AuctionBaseConfig = server.configCenter.AuctionBaseConfig
	local reward = {type = ItemConfig.AwardType.Item, id = itemid, count = count}
	local itemConf = server.configCenter.ItemConfig[itemid]
	local content = string.format(AuctionBaseConfig.maildes1, itemConf.name)
	server.mailCenter:SendMail(playerid, AuctionBaseConfig.mailtitle1, content, {reward}, server.baseConfig.YuanbaoRecordType.Auction)
	lua_app.log_info("AuctionMgr:GetFlowItem ", playerid, itemid, count)
end

-- 中转上架到全服
function AuctionMgr:ShelfGlobal(playerid, itemid, count, guildid)
	if server.serverCenter:HasDtb("world") then
		self:Notice()
		return server.serverCenter:CallDtbMod("world", "auctionCenter", "Shelf", playerid, itemid, count)
	else
		return false
	end
end

function AuctionMgr:ShelfLocal(playerid, itemid, count, guildid)
	self:Notice(guildid)
	return server.serverCenter:CallLocalMod("world", "auctionCenter", "Shelf", playerid, itemid, count, guildid)
end

function AuctionMgr:CheckOpen()
	return (server.serverRunDay >= server.configCenter.AuctionBaseConfig.serverday)
end

-- 小红点
function AuctionMgr:Notice(guildid)
	if guildid and guildid > 0 then
		local guild = server.guildCenter:GetGuild(guildid)
		if guild then
			guild:Broadcast("sc_aution_notice")
		end
	else
		server.broadcastReq("sc_aution_notice")
	end
end

server.SetCenter(AuctionMgr, "auctionMgr")
return AuctionMgr
