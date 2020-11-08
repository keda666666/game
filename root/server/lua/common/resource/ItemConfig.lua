local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = {}

ItemConfig.AwardType = {
	Numeric = 0,
	Item 	= 1,
}

ItemConfig.NumericType = {
	Exp = 0,
	Gold = 1,
	YuanBao = 2,
	BYB = 3,
	GuildContrib = 5,
	GuildFund = 6,
	Medal = 7,	-- 功勋（废弃）
	Friendcoin = 8, --友币
	Recharge = 99,
}

ItemConfig.NumericName = {
	Exp = "经验",
	Gold = "金币",
	YuanBao = "元宝",
	BYB = "绑定元宝",
	GuildContrib = "帮会贡献",
	GuildFund = "帮会基金",
	Medal = "功勋",	-- 功勋
	Recharge = "充值",
}

ItemConfig.NumTypeToCache = {
	[ItemConfig.NumericType.Exp]		= "exp",
	[ItemConfig.NumericType.Gold]		= "gold",
	[ItemConfig.NumericType.YuanBao]	= "yuanbao",
	[ItemConfig.NumericType.BYB]		= "byb",
	[ItemConfig.NumericType.Recharge]	= "recharge",
}

ItemConfig.BagType = {
	BAG_TYPE_OTHTER			= 0,	-- 基本背包
	BAG_TYPE_EQUIP			= 1,	-- 装备背包
	BAG_TYPE_TREASUREHUNT	= 2,	-- 寻宝相关(仓库)
	BAG_TYPE_BABYSTAR		= 3,	-- 灵童命格
}

ItemConfig.ItemType = {
	TYPE_EQUIP				= 0,	-- 装备
	TYPE_MATERIAL			= 1,	-- 材料
	TYPE_RIDE				= 2,	-- 坐骑
	TYPE_WING				= 3,	-- 翅膀
	TYPE_XIANLV_POSITION	= 4,	-- 仙侣仙位
	TYPE_XIANLV_CIRCLE		= 5,	-- 仙侣法阵
	TYPE_PET_SOUL			= 6,	-- 宠物通灵
	TYPE_PET_PSYCHIC		= 7,	-- 宠物兽魂
	TYPE_FAIRY				= 8,	-- 天仙
	TYPE_WEAPON				= 9,	-- 神兵
	TYPE_TIANNV_FLOWER		= 12,	-- 天女花辇
	TYPE_TIANNV_NIMBUS		= 13,	-- 天女灵气
	TYPE_BABY_STAR			= 14,	-- 灵童命格
	

}

ItemConfig.BagByType = {
	[ItemConfig.ItemType.TYPE_EQUIP]			= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_MATERIAL]			= ItemConfig.BagType.BAG_TYPE_OTHTER,
	[ItemConfig.ItemType.TYPE_RIDE]				= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_WING]				= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_FAIRY]			= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_WEAPON]			= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_PET_PSYCHIC]		= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_PET_SOUL]			= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_XIANLV_CIRCLE]	= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_XIANLV_POSITION]	= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_TIANNV_NIMBUS]	= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_TIANNV_FLOWER]	= ItemConfig.BagType.BAG_TYPE_EQUIP,
	[ItemConfig.ItemType.TYPE_BABY_STAR]		= ItemConfig.BagType.BAG_TYPE_BABYSTAR,
}

ItemConfig.StoreType = {			-- 在背包中的储存方式
	StoreBydbid				= 1,	-- 按物品唯一id存(其他装备)
	StoreByid 				= 2,	-- 按物品配置id存(道具材料)
}

ItemConfig.StoreByType = {
	[ItemConfig.ItemType.TYPE_EQUIP]		= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_MATERIAL]		= ItemConfig.StoreType.StoreByid,
	[ItemConfig.ItemType.TYPE_RIDE]				= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_WING]				= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_FAIRY]			= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_WEAPON]			= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_PET_PSYCHIC]		= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_PET_SOUL]			= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_XIANLV_CIRCLE]	= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_XIANLV_POSITION]	= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_TIANNV_NIMBUS]	= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_TIANNV_FLOWER]	= ItemConfig.StoreType.StoreBydbid,
	[ItemConfig.ItemType.TYPE_BABY_STAR]		= ItemConfig.StoreType.StoreByid,
}

ItemConfig.ItemChangeResult = {
	NEW_ITEM		= 1,
	CHANGE_COUNT	= 2,
	INSERT_FAILED	= 3,
	DEL_ITEM		= 4,
	DEL_FAILED		= 5,
}

ItemConfig.ItemQuality = {
	White	= 0,
	Green	= 1,
	Blue	= 2,
	Purple	= 3,
	Orange	= 4,
	Red		= 5,
	Diamond	= 6,
}

ItemConfig.QualityColor = {
	[ItemConfig.ItemQuality.White]		= "|C:0xFFFFFF&T:",
	[ItemConfig.ItemQuality.Green]		= "|C:0x5AD200&T:",
	[ItemConfig.ItemQuality.Blue]		= "|C:0x00D8FF&T:",
	[ItemConfig.ItemQuality.Purple]		= "|C:0xCE1AF5&T:",
	[ItemConfig.ItemQuality.Orange]		= "|C:0xFFB82A&T:",
	[ItemConfig.ItemQuality.Red]		= "|C:0xFF0000&T:",
	[ItemConfig.ItemQuality.Diamond]	= "|C:0xEFCBFB&T:",
}

ItemConfig.EquipSlotType = {
	--/**武器*/
	WEAPON = 0,
	--/**头盔*/
	HEAD = 1,
	--/**项链*/
	NECKLACE = 2,
	--/**衣服*/
	CLOTHES = 3,
	--/**护肩*/
	PAULDRON = 4,
	--/**腰带*/
	BELT = 5,
	--/**护腕*/
	BRACERS = 6,
	--/**戒指*/
	RING = 7,
	--/**裤子*/
	TROUSERS = 8,
	--/**鞋子*/
	SHOES = 9,
	--/**数量 */
	MAX = 10,
}

-- ItemConfig.SubType = {
-- 	WEAPON			= 0,		-- 武器
-- 	CLOTHES			= 1,		-- 衣服
-- 	SHOULDER		= 2,		-- 护肩
-- 	HEAD			= 3,		-- 头盔
-- 	NECKLACE		= 4,		-- 项链
-- 	BRACER			= 5,		-- 护腕
-- 	BELT			= 6,		-- 腰带
-- 	RING			= 7,		-- 戒指
-- 	TROUSERS		= 8,		-- 裤子
-- 	SHOES			= 9,		-- 鞋子
-- }

ItemConfig.SubType = {
	WEAPON			= 0,		--武器
	HEAD			= 1,		--头盔
	NECKLACE		= 2,		--项链
	CLOTHES			= 3,		--衣服
	PAULDRON		= 4,		--护肩
	BELT			= 5,		--腰带
	BRACERS			= 6,		--护腕
	RING			= 7,		--戒指
	TROUSERS		= 8,		--裤子
	SHOES			= 9,		--鞋子
}

ItemConfig.EquipSubName = {
    [ItemConfig.SubType.WEAPON]		= "武器",
    [ItemConfig.SubType.HEAD]		= "头盔",
    [ItemConfig.SubType.NECKLACE]	= "项链",
    [ItemConfig.SubType.CLOTHES]	= "衣服",
    [ItemConfig.SubType.PAULDRON]	= "护肩",
    [ItemConfig.SubType.BELT]		= "腰带",
    [ItemConfig.SubType.BRACERS]	= "护腕",
    [ItemConfig.SubType.RING]		= "戒指",
    [ItemConfig.SubType.TROUSERS]	= "裤子",
    [ItemConfig.SubType.SHOES]		= "鞋子",
}

ItemConfig.EquipSlotTypeToItemSubType = {
	[ItemConfig.EquipSlotType.WEAPON]		= ItemConfig.SubType.WEAPON,
	[ItemConfig.EquipSlotType.HEAD]			= ItemConfig.SubType.HEAD,
	[ItemConfig.EquipSlotType.NECKLACE]		= ItemConfig.SubType.NECKLACE,
	[ItemConfig.EquipSlotType.CLOTHES]		= ItemConfig.SubType.CLOTHES,
	[ItemConfig.EquipSlotType.PAULDRON]		= ItemConfig.SubType.PAULDRON,
	[ItemConfig.EquipSlotType.BELT]			= ItemConfig.SubType.BELT,
	[ItemConfig.EquipSlotType.BRACERS]		= ItemConfig.SubType.BRACERS,
	[ItemConfig.EquipSlotType.RING]			= ItemConfig.SubType.RING,
	[ItemConfig.EquipSlotType.TROUSERS]		= ItemConfig.SubType.TROUSERS,
	[ItemConfig.EquipSlotType.SHOES]		= ItemConfig.SubType.SHOES,
}

ItemConfig.UseType = {
	GetItems		= 1,		-- 通过掉落组获取物品
	GetTitle		= 2,		-- 获取称号
	GetMarryGift	= 3,		-- 婚姻贺礼
	GetAuction		= 4,		-- 拍卖盒子
	Getbuzhidao		= 5,		-- 我也不知道
}

ItemConfig.UpLevelType = {
	AutoUpgrade		= 1,			--自动升级
	ManualUpgrade	= 2,			--手动升级
}

ItemConfig.WingEquipSlot = {
	SlotBone = 0,
	SlotStone = 1,
	SlotFeather = 2,
	SlotColor = 3,
	Count = 4,
}

ItemConfig.ForgeType = {
	Enhance 	=		0,		--强化
	Refine		=		1,		--精炼
	Anneal		=		2,		--锻炼
	Gem 		=		3,		--宝石
}

ItemConfig.ForgeAttrConfig = {
	[ItemConfig.ForgeType.Enhance] = false,
	[ItemConfig.ForgeType.Refine] = false,
	[ItemConfig.ForgeType.Anneal] = false,
	[ItemConfig.ForgeType.Gem] = false,
}

ItemConfig.ForgeAttrName = {
	[ItemConfig.ForgeType.Enhance] = "EnhanceAttrConfig",
	[ItemConfig.ForgeType.Refine] = "RefineAttrConfig",
	[ItemConfig.ForgeType.Anneal] = "AnnealAttrConfig",
	[ItemConfig.ForgeType.Gem] = "GemAttrConfig",
}

ItemConfig.ForgeCostConfig = {
	[ItemConfig.ForgeType.Enhance] = false,
	[ItemConfig.ForgeType.Refine] = false,
	[ItemConfig.ForgeType.Anneal] = false,
	[ItemConfig.ForgeType.Gem] = false,
}

ItemConfig.ForgeCostName = {
	[ItemConfig.ForgeType.Enhance] = "EnhanceCostConfig",
	[ItemConfig.ForgeType.Refine] = "RefineCostConfig",
	[ItemConfig.ForgeType.Anneal] = "AnnealCostConfig",
	[ItemConfig.ForgeType.Gem] = "GemCostConfig",
}

ItemConfig.ForgeSuitConfig = {
	[ItemConfig.ForgeType.Enhance] = false,
	[ItemConfig.ForgeType.Refine] = false,
	[ItemConfig.ForgeType.Anneal] = false,
	[ItemConfig.ForgeType.Gem] = false,
}

ItemConfig.ForgeSuitName = {
	[ItemConfig.ForgeType.Enhance] = "EnhanceSuitConfig",
	[ItemConfig.ForgeType.Refine] = "RefineSuitConfig",
	[ItemConfig.ForgeType.Anneal] = "AnnealSuitConfig",
	[ItemConfig.ForgeType.Gem] = "GemSuitConfig",
}

function ItemConfig:LogChangeItem(id, count, ttype, log, serverid, playerid)
	if not ttype then
		-- lua_app.log_error("LOG:: ChangeItem:", id, count, ttype, log, serverid, playerid)
		return
	end
	local item_config = server.configCenter.ItemConfig[id]
	if self.StoreByType[item_config.type] == self.StoreType.StoreByid then
		if item_config.quality < self.ItemQuality.Purple then return end
	else
		if item_config.quality < self.ItemQuality.Orange or (item_config.level or 0) < 50 then return end
	end
	-- lua_app.log_info("LOG:: ChangeItem:", id, count, item_config.name, ttype, log, serverid, playerid)
	server.serverCenter:SendDtbMod("httpr", "cacheCenter", "InsertItem", {
			serverid = serverid,
			playerid = playerid,
			type = ttype or 0,
			type_name = log or server.baseConfig.YuanbaoRecordTypeToName[ttype] or "",
			itemid = id,
			count = count or 0,
			-- ip = self.ip,
		})
end

--煅造消耗表
function ItemConfig:GetForgeCostConfig(forgetype)
	if not self.ForgeCostConfig[forgetype] then
		self.ForgeCostConfig[forgetype] = server.configCenter[self.ForgeCostName[forgetype]]
	end
	return self.ForgeCostConfig[forgetype]
end
--煅造属性表
function ItemConfig:GetForgeAttrConfig(forgetype)
	if not self.ForgeAttrConfig[forgetype] then
		self.ForgeAttrConfig[forgetype] = server.configCenter[self.ForgeAttrName[forgetype]]
	end
	return self.ForgeAttrConfig[forgetype]
end
--煅造大师表
function ItemConfig:GetForgeSuitConfig(forgetype)
	if not self.ForgeSuitConfig[forgetype] then
		self.ForgeSuitConfig[forgetype] = server.configCenter[self.ForgeSuitName[forgetype]]
	end
	return self.ForgeSuitConfig[forgetype]
end

function ItemConfig:SetEquipNewAttr(id)
	local EquipConfig = server.configCenter.EquipConfig[id]
	if not EquipConfig or not EquipConfig.addmin or not EquipConfig.addmax then return {} end
	local num
	if EquipConfig.addmax > EquipConfig.addmin then
		num = math.random(EquipConfig.addmin, EquipConfig.addmax)
	else
		num = EquipConfig.addmin
	end
	local addattr = table.wcopy(EquipConfig.addattr)
	local attrs = {}
	for i = 1, num do
		table.insert(attrs, addattr)
	end
	return attrs
end

function ItemConfig:GenRewards(ttype, id, count)
	local rewards = {}
	table.insert(rewards, {
			type = ttype,
			id = id,
			count = count,
		})
	return rewards
end

function ItemConfig:GenNumericRewards(id, count)
	return self:GenRewards(ItemConfig.AwardType.Numeric, id, count)
end

function ItemConfig:GenItemRewards(count)
	return self:GenRewards(ItemConfig.AwardType.Numeric, id, count)
end

function ItemConfig:GetAttrsPower(attrs)
	local power = 0
	local AttrPowerConfig = server.configCenter.AttrPowerConfig
	for _, v in pairs(attrs) do
		if AttrPowerConfig[v.type] then
			power = power + v.value * AttrPowerConfig[v.type].power
		end
	end
	return math.floor(power / 100)
end

function ItemConfig:GetEquipPower(itemData)
	local config = server.configCenter.EquipConfig[itemData.id]
	return self:GetAttrsPower(itemData.attrs) + self:GetAttrsPower(config.attrs)
end

-- itemids = { itemid = true }，返回表 { itemid = item_config }
function ItemConfig:GetRewardChoiceItem(reward, itemids)
	local itemList = {}
	for _, v in pairs(reward) do
		if v.type == self.AwardType.Item and itemids[v.id] then
			itemList[v.id] = server.configCenter.ItemConfig[v.id]
		end
	end
	return itemList
end

function ItemConfig:GetRewardSpace(reward)
	local space = 0
	for _, v in pairs(reward) do
		if v.type == self.AwardType.Item
			and self.BagByType[server.configCenter.ItemConfig[v.id].type] == self.BagType.BAG_TYPE_EQUIP then
			space = space + (v.count or 1)
		end
	end
	return space
end

function ItemConfig:MergeRewards(rewards)
	local mergelist = {}
	for _, type in pairs(self.AwardType) do
		mergelist[type] = {}
	end
	for _, v in pairs(rewards) do
		mergelist[v.type][v.id] = (mergelist[v.type][v.id] or 0) + (v.count or 1)
	end
	local ret = {}
	for type, v in pairs(mergelist) do
		for id, count in pairs(v) do
			table.insert(ret, { type = type, id = id, count = count })
		end
	end
	return ret
end

function ItemConfig:ConverLinkText(rewards)
	local flag = "<font color=%s><a href=\"event:itemId:%d\"><u>%s *%d</u></a></font>"
	local converreward = rewards[1] and rewards or {rewards}
	local des = {}
	for __, reward in pairs(converreward) do
		if reward.type == ItemConfig.AwardType.Item then
			local itemcfg = server.configCenter.ItemConfig[reward.id]
			local color = string.match(ItemConfig.QualityColor[itemcfg.quality], ":(.+)&")
			table.insert(des, string.format(flag, color, reward.id, itemcfg.name, reward.count))
		end
	end
	return table.concat(des, "，")
end

function ItemConfig:ConverLinkTextSpells(id, ...)
	local flag = "<font color=%s><a href=\"event:spellsData:%s\"><u>%s</u></a></font>"
	local des = {}
	local spellsCfg = server.configCenter.SpellsResListConfig[id]
	local color = string.match(ItemConfig.QualityColor[spellsCfg.quality], ":(.+)&")
	table.insert(des, string.format(flag, color, table.concat({id, ...}, ","), spellsCfg.name))
	return table.concat(des, "，")
end

function ItemConfig:MergeRewardsList(rewardslist)
	local mergelist = {}
	for _, type in pairs(self.AwardType) do
		mergelist[type] = {}
	end
	for _, rewards in pairs(rewardslist) do
		for _, v in pairs(rewards) do
			mergelist[v.type][v.id] = (mergelist[v.type][v.id] or 0) + (v.count or 1)
		end
	end
	local ret = {}
	for type, v in pairs(mergelist) do
		for id, count in pairs(v) do
			table.insert(ret, { type = type, id = id, count = count })
		end
	end
	return ret
end

function ItemConfig:ItemString(rewards)
	local str = ""
	for _, v in ipairs(rewards) do
		if v.type == ItemConfig.AwardType.Numeric then
			str = (str .. " " .. ItemConfig.AwardType.NumericName[v.id] .. "*" .. v.count)
		elseif v.type == ItemConfig.AwardType.Item then
			local itemConf = server.configCenter.ItemConfig[v.id]
			str = (str .. " " .. ItemConfig.QualityColor[itemConf.quality] .. itemConf.name .. "*" .. v.count .. "|")
		end
	end
	return str
end

function ItemConfig:SingleItemString(id)
	local itemConf = server.configCenter.ItemConfig[id]
	return string.format("%s%s%s", ItemConfig.QualityColor[itemConf.quality], itemConf.name, "|")
end


return ItemConfig
