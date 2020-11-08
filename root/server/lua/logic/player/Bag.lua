local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"
local Item = require "player.item.Item"
local tbname = "items"

local Bag = oo.class()

function Bag:ctor(player)
	self.player = player
	self.itemList = {}
	self.bagList = {
		[ItemConfig.BagType.BAG_TYPE_OTHTER] = { false, {}, },
		[ItemConfig.BagType.BAG_TYPE_EQUIP] = { {}, false, },
		[ItemConfig.BagType.BAG_TYPE_TREASUREHUNT] = { {}, {}, },
		[ItemConfig.BagType.BAG_TYPE_BABYSTAR] = { false, {}, },
	}
	self.bagEquipCount = 0
end

function Bag:ResetMaxEquipCount()
	self.bagMaxEquipCount = server.configCenter.BagBaseConfig.baseSize
		+ self.player.cache.bagnum * server.configCenter.BagBaseConfig.rowSize
end

function Bag:GetLeftEquipCount()
	return self.bagMaxEquipCount - self.bagEquipCount + self.player.welfare:IsVipBag() + self.player.welfare:IsForeverBag()
end

function Bag:GetItemConfig(id)
	return server.configCenter.ItemConfig[id]
end

function Bag:GetItemStoreType(id)
	return ItemConfig.StoreByType[self:GetItemConfig(id).type]
end

function Bag:GetItemBaseBagType(id)
	return ItemConfig.BagByType[self:GetItemConfig(id).type]
end

function Bag:onCreate()
	self:ResetMaxEquipCount()
end

function Bag:onLoad()
	self:ResetMaxEquipCount()
	local caches = server.mysqlBlob:LoadDmg(tbname, {playerid = self.player.dbid})
	for _, cache in ipairs(caches) do
		local item = Item.new()
		item:Init(cache)
		self.itemList[item.dbid] = item
		local bagtype = item.cache.bag_type
		local itemid = item.cache.id
		local storeType = self:GetItemStoreType(itemid)
		local abag = self.bagList[bagtype]
		if abag and abag[storeType] then
			if storeType == ItemConfig.StoreType.StoreByid then
				if abag[storeType][itemid] then
					lua_app.log_error("StoreByid Bag:ReLoad item: items dbid:", item.dbid,
						abag[storeType][itemid].dbid)
				end
				abag[storeType][itemid] = item
			else--if storeType == ItemConfig.StoreType.StoreBydbid then
				abag[storeType][item.dbid] = item
				if bagtype == ItemConfig.BagType.BAG_TYPE_EQUIP then
					self.bagEquipCount = self.bagEquipCount + 1
				end
			end
		else
			lua_app.log_error("Bag:Load error: undefine bagtype = "
				.. bagtype .. " storeType =" .. storeType .. " itemid = " .. itemid)
			server.mysqlBlob:IgnoreDmg(tbname, cache)
		end
	end
end

function Bag:onRelease()
	for _, item in pairs(self.itemList) do
		item:Release()
	end
end

function Bag:Clear()
	for _, item in pairs(self.itemList) do
		item:Del()
	end
end

local _AddItemInBag = {}
_AddItemInBag[ItemConfig.StoreType.StoreBydbid] = function(self, bagtype, id, count, attrs, showTip, ttype, log)
	if count <= 0 then
		return ItemConfig.ItemChangeResult.INSERT_FAILED, 0
	end
	local bagSlots = self.bagList[bagtype][ItemConfig.StoreType.StoreBydbid]
	if bagtype == ItemConfig.BagType.BAG_TYPE_EQUIP then
		self.bagEquipCount = self.bagEquipCount + count
	end
	local idlist = {}
	for i = 1, count do
		local newAttr = attrs or ItemConfig:SetEquipNewAttr(id)
		local item = Item.new()
		item:Create {
			id = id,
			playerid = self.player.dbid,
			attrs = newAttr,
			bag_type = bagtype,
			count = 1,
		}
		self.itemList[item.dbid] = item
		bagSlots[item.dbid] = item
		server.sendReq(self.player, "sc_bag_deal_add_item", {
				type	= bagtype,
				data 	= item:GetMsgData(),
				showTip = showTip or 1,
			})
		idlist[#idlist + 1] = item.dbid
	end
	-- local item_config = self:GetItemConfig(id)
	-- if item_config.quality >= ItemConfig.ItemQuality.Orange and ((item_config.zsLevel or 0) >= 1 or item_config.subType == 4 or item_config.type == 8) then
	ItemConfig:LogChangeItem(id, count, ttype, log, self.player.cache.serverid, self.player.dbid)
	-- end
	return ItemConfig.ItemChangeResult.NEW_ITEM, count, idlist
end

local _TimeStrToTime = {}
local function _GetSecTime(timestr)
	if not _TimeStrToTime[timestr] then
		local timetable = {}
		timetable.year, timetable.month, timetable.day, timetable.hour, timetable.min = string.match(timestr, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
		_TimeStrToTime[timestr] = os.time(timetable)
	end
	return _TimeStrToTime[timestr]
end

_AddItemInBag[ItemConfig.StoreType.StoreByid] = function(self, bagtype, id, count, attrs, showTip, ttype, log)
	if count <= 0 then
		return ItemConfig.ItemChangeResult.INSERT_FAILED, 0
	end
	local function AddItemCount(item)
		item.cache.count = count + item.cache.count
		server.sendReq(self.player, "sc_bag_update_item_data", {
				type	= bagtype,
				handle	= item.dbid,
				num 	= item.cache.count,
				showTip = showTip or 1,
			})
		ItemConfig:LogChangeItem(id, count, ttype, log, self.player.cache.serverid, self.player.dbid)
	end
	local bagSlots = self.bagList[bagtype][ItemConfig.StoreType.StoreByid]
	local item = bagSlots[id]
	if item then
		AddItemCount(item)
		return ItemConfig.ItemChangeResult.CHANGE_COUNT, count, {item.dbid}
	end
	item = Item.new()
	local data = {
		id = id,
		playerid = self.player.dbid,
		bag_type = bagtype,
		count = count,
	}
	local invalidtime = self:GetItemConfig(id).invalidtime
	if invalidtime then
		local ittype = type(invalidtime)
		if ittype == "number" and invalidtime > 0 then
			data[config.invalidtime] = invalidtime + lua_app.now()
		elseif ittype == "string" then
			data[config.invalidtime] = _GetSecTime(invalidtime)
		else
			lua_app.log_error("_AddItemInBag[ItemConfig.StoreType.StoreByid]:: not right config", id, self:GetItemConfig(id).name, invalidtime)
		end
	end
	item:Create(data)
	-- if bagSlots[id] then
	-- 	item:Del()
	-- 	AddItemCount(bagSlots[id])
	-- 	return ItemConfig.ItemChangeResult.CHANGE_COUNT, count
	-- end
	self.itemList[item.dbid] = item
	bagSlots[id] = item
	server.sendReq(self.player,"sc_bag_deal_add_item", {
			type	= bagtype,
			data 	= item:GetMsgData(),
			showTip = showTip or 1,
		})
	ItemConfig:LogChangeItem(id, count, ttype, log, self.player.cache.serverid, self.player.dbid)
	return ItemConfig.ItemChangeResult.NEW_ITEM, count, {item.dbid}
end

function Bag:AddItem(id, count, attrs, bagtype, showTip, ttype, log)
	bagtype = bagtype or self:GetItemBaseBagType(id)
	local storeType = self:GetItemStoreType(id)
	--print("AddItem:", id, self.player.dbid, count, bagtype)
	if not _AddItemInBag[storeType] then
		lua_app.log_error("Bag:AddItem error itemid", id)
		return id, 0
	end
	return _AddItemInBag[storeType](self, bagtype, id, count or 1, attrs, showTip, ttype, log)
end

local _DelItemInBag = {}
_DelItemInBag[ItemConfig.StoreType.StoreBydbid] = function(self, bagtype, item, count, ttype, log)
	if count <= 0 then
		return ItemConfig.ItemChangeResult.DEL_FAILED
	end
	local bagSlots = self.bagList[bagtype][ItemConfig.StoreType.StoreBydbid]
	self.itemList[item.dbid] = nil
	bagSlots[item.dbid] = nil
	if bagtype == ItemConfig.BagType.BAG_TYPE_EQUIP then
		self.bagEquipCount = self.bagEquipCount - 1
	end
	server.sendReq(self.player,"sc_bag_deal_delete_item", {
			type	= bagtype,
			handle 	= item.dbid,
		})
	ItemConfig:LogChangeItem(item.cache.id, -count, ttype, log, self.player.cache.serverid, self.player.dbid)
	item:Del()
	return ItemConfig.ItemChangeResult.DEL_ITEM
end

_DelItemInBag[ItemConfig.StoreType.StoreByid] = function(self, bagtype, item, count, ttype, log)
	if count <= 0 then
		return ItemConfig.ItemChangeResult.DEL_FAILED
	end
	if item.cache.count < count then
		return ItemConfig.ItemChangeResult.DEL_FAILED
	end
	local bagSlots = self.bagList[bagtype][ItemConfig.StoreType.StoreByid]
	local leftcount = item.cache.count - count
	if leftcount > 0 then
		item.cache.count = leftcount
		server.sendReq(self.player,"sc_bag_update_item_data", {
				type	= bagtype,
				handle	= item.dbid,
				num 	= leftcount,
				showTip = 0,
			})
		ItemConfig:LogChangeItem(item.cache.id, -count, ttype, log, self.player.cache.serverid, self.player.dbid)
		return ItemConfig.ItemChangeResult.CHANGE_COUNT, item
	elseif leftcount < 0 then
		return ItemConfig.ItemChangeResult.DEL_FAILED
	end
	self.itemList[item.dbid] = nil
	bagSlots[item.cache.id] = nil
	server.sendReq(self.player,"sc_bag_deal_delete_item", {
			type	= bagtype,
			handle 	= item.dbid,
		})
	ItemConfig:LogChangeItem(item.cache.id, -count, ttype, log, self.player.cache.serverid, self.player.dbid)
	item:Del()
	return ItemConfig.ItemChangeResult.DEL_ITEM
end

-- 仅删除通过id储存的物品
function Bag:DelItemByID(id, count, ttype, log, bagtype)
	bagtype = bagtype or self:GetItemBaseBagType(id)
	local item = self.bagList[bagtype][ItemConfig.StoreType.StoreByid][id]
	if not item then return ItemConfig.ItemChangeResult.DEL_FAILED end
	return _DelItemInBag[ItemConfig.StoreType.StoreByid](self, bagtype, item, count or 1, ttype, log)
end

function Bag:DelItem(item_dbid, count, ttype, log)
	local item = self.itemList[item_dbid]
	local storeType = self:GetItemStoreType(item.cache.id)
	return _DelItemInBag[storeType](self, item.cache.bag_type, item, count or 1, ttype, log)
end

-- 获取物品个数，仅基本背包的以id储存的物品
function Bag:GetItemCount(id)
	local item = self.bagList[self:GetItemBaseBagType(id)][ItemConfig.StoreType.StoreByid][id]
	return item and item.cache.count or 0
end

-- 检测物品是否足够，仅检测基本背包的以id储存的物品
function Bag:CheckItem(id, count)
	local item = self.bagList[self:GetItemBaseBagType(id)][ItemConfig.StoreType.StoreByid][id]
	return item ~= nil and item.cache.count >= (count or 1)
end

-- 获取物品数据
-- @number item_dbid 物品唯一ID
function Bag:GetItem(item_dbid)
	return self.itemList[item_dbid]
end

-- 通过物品id获取物品，仅获取按id索引的物品(材料、秘籍)
function Bag:GetItemByID(itemid, bagtype)
	bagtype = bagtype or self:GetItemBaseBagType(itemid)
	return self.bagList[bagtype][ItemConfig.StoreType.StoreByid][itemid]
end

-- 如果是装备就判断装备空间是否足够，其他都返回足够
function Bag:CheckSpaceEnough(itemid, count)
	if ItemConfig.BagByType[server.configCenter.ItemConfig[itemid].type] == ItemConfig.BagType.BAG_TYPE_EQUIP then
		return count <= self:GetLeftEquipCount()
	end
	return true
end

function Bag:CheckRewardCanGive(reward)
	return ItemConfig:GetRewardSpace(reward) <= self:GetLeftEquipCount()
end

local _UseItemAnnoLimit = {}
local function _GetUseItemAnnoLimitIDs(itemid)
	local ItemAnnoConf = server.configCenter.ItemAnnoConf[itemid]
	if not ItemAnnoConf then return end
	if _UseItemAnnoLimit[itemid] then
		return _UseItemAnnoLimit[itemid].annoId, _UseItemAnnoLimit[itemid].itemids
	end
	local itemids = {}
	for _, id in pairs(ItemAnnoConf.limit) do
		itemids[id] = true
	end
	_UseItemAnnoLimit[itemid] = {
		annoId = ItemAnnoConf.annoId,
		itemids = itemids,
	}
	return ItemAnnoConf.annoId, itemids
end

local _UseItem = {}
_UseItem[ItemConfig.UseType.GetItems] = function(self, id, count, args, isDel, name)
	local needspace = args.useGrid * count
	if needspace > self:GetLeftEquipCount() then
		return 1
	end
	if args.starttime then
		local startTime = _GetSecTime(args.starttime)
		if lua_app.now() < startTime then
			return 2
		end
	end
	if isDel then
		self:DelItemByID(id, count, server.baseConfig.YuanbaoRecordType.UseItem)
	end
	local mailcontext = "使用物品" .. (name or "")
	local uselog = "UseItem:" .. id
	local rewardList = {}
	for i = 1, count do
		local reward = server.dropCenter:DropGroup(args.dropId)
		table.insert(rewardList, reward)
		self.player:GiveRewardAsFullMailDefault(reward, "使用物品", server.baseConfig.YuanbaoRecordType.UseItem, uselog)
		local annoid, itemids = _GetUseItemAnnoLimitIDs(id)
		if annoid then
			local itemList = ItemConfig:GetRewardChoiceItem(reward, itemids)
			for _, item_config in pairs(itemList) do
				server.noticeCenter:Notice(annoid, self.player.cache.name, item_config.name)
			end
		end
	end
	return 0, rewardList
end

_UseItem[ItemConfig.UseType.GetTitle] = function(self, id, count, args, isDel)
	if isDel then
		self:DelItemByID(id, count, server.baseConfig.YuanbaoRecordType.UseItem)
	end
	-- self.player.title:AddTitle(args)
	return 0
end

_UseItem[ItemConfig.UseType.GetMarryGift] = function(self, id, count, args, isDel)
	if isDel then
		self:DelItemByID(id, count, server.baseConfig.YuanbaoRecordType.UseItem)
	end
	self.player.marry:AddIntimacy(count * args)
	self.player.marry:GetMarryInfo()
	return 0
end

_UseItem[ItemConfig.UseType.GetAuction] = function(self, id, count, args, isDel, name)
	count = 1
	if isDel then
		self:DelItemByID(id, count, server.baseConfig.YuanbaoRecordType.UseItem)
	end
	local rewards = server.dropCenter:DropGroup(args.dropId)
	self.player.auctionPlug:OpenItem(rewards)
	return 0
end

_UseItem[ItemConfig.UseType.Getbuzhidao] = function(self, id, count, args, isDel)
	assert(false)
	return 0
end

-- 添加并立马使用掉物品，无法使用的物品也不会添加
function Bag:AddUseItem(id, count, isDel)
	local item_config = self:GetItemConfig(id)
	if not _UseItem[item_config.useType] then
		lua_app.log_error("Bag:AddUseItem: id(", id, ") ItemConfig.useType(", item_config.useType, ")")
		return 3
	end
	if item_config.level > self.player.cache.level then
		return 4
	end
	count = count or 1
	if item_config.needyuanbao and item_config.needyuanbao > 0
		and not self.player:PayYuanBao(item_config.needyuanbao * count, server.baseConfig.YuanbaoRecordType.UseItem, "UseItem:" .. id) then
		return 7
	end
	return _UseItem[item_config.useType](self, id, count, item_config.useArg, isDel, item_config.name)
end

function Bag:UseItem(id, count)
	local item = self:GetItemByID(id)
	if not item or item.cache.count < count then
		server.sendReq(self.player, "sc_bag_user_item_back", { tipIndex = 5 })
		return
	end
	if item:IsInvalid() then
		server.sendReq(self.player, "sc_bag_user_item_back", { tipIndex = 6 })
		return
	end
	local tipIndex = self:AddUseItem(id, count, true)
	server.sendReq(self.player, "sc_bag_user_item_back", { tipIndex = tipIndex })
end

function Bag:onBeforeLogin()
	self:ResetMaxEquipCount()
	local delItems = {}
	for dbid, item in pairs(self.itemList) do
		if item:IsInvalid() then
			delItems[dbid] = item.cache.count
		end
	end
	for dbid, count in pairs(delItems) do
		self:DelItem(dbid, count, server.baseConfig.YuanbaoRecordType.Invalid)
	end
end

function Bag:onInitClient()
	for bagtype, bag in pairs(self.bagList) do
		local datas = {}
		local code = 0
		for _, slots in pairs(bag) do
			if slots then
				for _, item in pairs(slots) do
					table.insert(datas, item:GetMsgData())
					if #datas >= 200 then
						server.sendReq(self.player, "sc_bag_init_data", { code = code, type = bagtype, datas = datas, })
						datas = {}
						code = code + 1
					end
				end
			end
		end
		server.sendReq(self.player, "sc_bag_init_data", { code = code, type = bagtype, datas = datas, })
	end
end

function Bag:AddMaxEquipCount(rows)
	if rows < 1 then
		lua_app.log_error("Bag:AddMaxEquipCount: rows(", rows, ") < 1")
		return
	end
	local beginrow = self.player.cache.bagnum
	local BagExpandConfig = server.configCenter.BagExpandConfig
	local isVipBag = self.player.welfare:IsVipBag()
	local isForeverBag = self.player.welfare:IsForeverBag()
	if beginrow + rows > (#BagExpandConfig + isVipBag + isForeverBag) then
		lua_app.log_error("Bag:AddMaxEquipCount: rows(", rows, ") > max BagExpandConfig(", #BagExpandConfig, ")")
		return
	end
	local pay = 0
	for i = beginrow + 1, beginrow + rows do
		pay = pay + BagExpandConfig[i].cost
	end
	if self.player:PayYuanBao(pay, server.baseConfig.YuanbaoRecordType.BagAddMaxEquipCount, "Bag:AddMaxEquipCount") then
		self.player.cache.bagnum = beginrow + rows
		self:ResetMaxEquipCount()
		server.sendReq(self.player,"sc_bag_deal_valumn_add", { bagNum = beginrow + rows})
	end
end

function Bag:GetItemsByTreasure(handle)
	local handleList = {}
	local isget = false
	local function _MoveToBaseBag(item)
		local id, count = item.cache.id, item.cache.count
		if ItemConfig.BagByType[server.configCenter.ItemConfig[id].type] ~= ItemConfig.BagType.BAG_TYPE_EQUIP then
			self:DelItem(item.dbid, count)
			self:AddItem(id, count, item.cache.attrs, nil, 0)
			isget = true
			return true
		end
		if count > self:GetLeftEquipCount() then
			return false
		end
		self.bagList[ItemConfig.BagType.BAG_TYPE_TREASUREHUNT][ItemConfig.StoreType.StoreBydbid][item.dbid] = nil
		self.bagList[ItemConfig.BagType.BAG_TYPE_EQUIP][ItemConfig.StoreType.StoreBydbid][item.dbid] = item
		item.cache.bag_type = ItemConfig.BagType.BAG_TYPE_EQUIP
		self.bagEquipCount = self.bagEquipCount + count
		table.insert(handleList, item.dbid)
		isget = true
		return true
	end
	if handle ~= 0 then
		local item = self:GetItem(handle)
		if not item or item.cache.bag_type ~= ItemConfig.BagType.BAG_TYPE_TREASUREHUNT then
			lua_app.log_info("Bag:GetItemsByTreasure: id(", item.cache.id, ") handle(", handle, ")")
			return
		end
		_MoveToBaseBag(item)
	else
		local bag = self.bagList[ItemConfig.BagType.BAG_TYPE_TREASUREHUNT]
		local _, item = next(bag[ItemConfig.StoreType.StoreByid])
		while item do
			_MoveToBaseBag(item)
			_, item = next(bag[ItemConfig.StoreType.StoreByid])
		end
		_, item = next(bag[ItemConfig.StoreType.StoreBydbid])
		while item do
			if not _MoveToBaseBag(item) then break end
			_, item = next(bag[ItemConfig.StoreType.StoreBydbid])
		end
	end
	if isget then
		server.sendReq(self.player, "sc_bag_get_treasure_equip", { handle = handleList })
	else
		server.sendReq(self.player, "show_server_tip", { type = 2 })
	end
end

function Bag:SmeltEquip(itemHandles)
	local costlist = {}
	local num = 0
	for _, dbid in pairs(itemHandles) do
		num = num + 1
		local item = self.itemList[dbid]
		if not item or item.cache.bag_type ~= ItemConfig.BagType.BAG_TYPE_EQUIP then
			lua_app.log_info("Bag:SmeltEquip error: item dbid =", dbid, ", accountname =", self.player.cache.name)
		else
			local id = item.cache.id
			local item_config = self:GetItemConfig(id)
			-- key=等级*10000+类型 *100+品质,目前这条公式的表还没配会报错
			local key = item_config.level * 10000 + item_config.type * 100 + item_config.quality
			local SmeltConfig = server.configCenter.SmeltConfig[key]
			if not SmeltConfig then
				lua_app.log_error("SmeltConfig not exist item(dbid:", dbid,")id =", id, ", key =", key)
			else
				self:DelItem(dbid, nil, server.baseConfig.YuanbaoRecordType.Smelt)
				table.insert(costlist, SmeltConfig.cost)
				if item_config.quality >= ItemConfig.ItemQuality.Orange and (item_config.level or 0) >= 80 then
					lua_app.log_info("LOG:: Bag:SmeltEquip", self.player.cache.name, id, item_config.name)
				end
			end
		end
	end
	self.player.task:onEventAdd(server.taskConfig.ConditionType.EquipSmelt)
	self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.EquipSmelt, num)
	server.teachersCenter:AddNum(self.player.dbid, 2, num)
	self.player:GiveRewardAsFullMailDefault(ItemConfig:MergeRewardsList(costlist), "熔炼", server.baseConfig.YuanbaoRecordType.Smelt)
	server.sendReq(self.player, "sc_bag_deal_smelt_result", { state = 1, len = 1 })
end

function Bag:GiveRewardAsFullSmelt(reward, showTip, type, log)
	local costrewards = {}
	for _, v in ipairs(reward) do
		if v.type == ItemConfig.AwardType.Item and not self:CheckSpaceEnough(v.id, v.count) then
			local item_config = server.configCenter.ItemConfig[v.id]
			local key = item_config.level * 10000 + item_config.type * 100 + item_config.quality
			local SmeltConfig = server.configCenter.SmeltConfig[key]
	        if SmeltConfig then
	            for _, vv in ipairs(SmeltConfig.cost) do
	            	if vv.type == ItemConfig.AwardType.Numeric then
	            		table.insert(costrewards, vv)
	            	end
	            end
	        else
	            lua_app.log_error("SmeltConfig not exist itemid =", v.id, ", key =", key)
	        end
		else
			self.player:GiveReward(v.type, v.id, v.count, showTip, type, log)
	    end
	end
	self.player:GiveRewardAsFullMailDefault(ItemConfig:MergeRewards(costrewards), "熔炼", server.baseConfig.YuanbaoRecordType.Smelt)
end

server.playerCenter:SetEvent(Bag, "bag")
return Bag