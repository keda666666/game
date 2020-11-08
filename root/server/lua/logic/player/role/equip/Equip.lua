local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "common.resource.ItemConfig"

local Equip = oo.class()

function Equip:ctor(role, slot, equipplug)
	self.equipplug = equipplug
	self.role = role
	self.player = self.role.player
	self.slot = slot			-- 槽位
    self.slotType = ItemConfig.EquipSlotTypeToItemSubType[slot]	-- 槽位类型
end

function Equip:onCreate()
    local data = {
        item = {
            id = 0,
            attrs = {},
        },
        strengthen  = 0,
        gem         = 0,
        refine      = 0,
        anneal      = 0,
        injectcount = 0,
        injectstage = 0,
    }
    self.cache = data
    self.equipplug.cache.equipList[self.slot] = data
end

function Equip:onLoad()
    self.cache = self.equipplug.cache.equipList[self.slot]
    local item = self.cache.item
    if item.id ~= 0 then
        self.role:ChangeEquip({}, item)
    end
    if self.cache.injectstage > 0 then
        self:UpdateAttrs({})
    end
end

function Equip:GetMsdRedData()
    return {
        injectstage = self.cache.injectstage,
        injectcount = self.cache.injectcount,
    }
end

function Equip:GetMsgData()
    local data = {
        strengthen = self.cache.strengthen,
        refine = self.cache.refine,
        anneal = self.cache.anneal,
        gem = self.cache.gem,
        item = self.cache.item,
        reddata = self:GetMsdRedData(),
    }
    return data
end

function Equip:CanEquipItem(id)
    local item_config = server.configCenter.ItemConfig[id]
    if item_config.type ~= ItemConfig.ItemType.TYPE_EQUIP 
        or item_config.subType ~= self.slotType 
        or (item_config.job ~= 0 and item_config.job ~= self.player.cache.job) 
        or item_config.level > self.player.cache.level then
        -- zsLevel不存在，这段屏蔽了or item_config.zsLevel > self.actor:Get(config.zhuansheng_lv) then
        return false
    end
    return true
end

function Equip:GetForgeLevel(forgeType)
    if forgeType == ItemConfig.ForgeType.Enhance then
        return self.cache.strengthen
    elseif forgeType == ItemConfig.ForgeType.Refine then
        return self.cache.refine
    elseif forgeType == ItemConfig.ForgeType.Anneal then
        return self.cache.anneal
    elseif forgeType == ItemConfig.ForgeType.Gem then
        return self.cache.gem
    end
end

function Equip:SetForgeLevel(forgeType,forgeLevel)
    if forgeType == ItemConfig.ForgeType.Enhance then
        self.cache.strengthen = forgeLevel
    elseif forgeType == ItemConfig.ForgeType.Refine then
        self.cache.refine = forgeLevel
    elseif forgeType == ItemConfig.ForgeType.Anneal then
        self.cache.anneal = forgeLevel
    elseif forgeType == ItemConfig.ForgeType.Gem then
        self.cache.gem = forgeLevel
    end
end

--注灵
function Equip:InjectLing(mode)
    if not self:IsReditem() then return end
    local DeitySpiritConfig = server.configCenter.DeitySpiritConfig[self.slot]
    if self.cache.injectstage >= #DeitySpiritConfig then return end
    local injectCfg = DeitySpiritConfig[self.cache.injectstage + 1]
    if not self.player:PayRewardsByShop(injectCfg.cost, server.baseConfig.YuanbaoRecordType.RedEquip, "RedEquip:inject cost", mode) then
        lua_app.log_info("Injectling payrewards faild.")
        return
    end
    --直升一阶
    local rate = 0
    for count, val in pairs(injectCfg.rat) do
        if self.cache.injectcount >= count and rate < val then
            rate = val
        end
    end
    local randomrate = math.random(1, 100)
    if rate >= randomrate then
        self.cache.injectcount = 0
        self:UpInjectLevel()
        return true
    end

    self.cache.injectcount = self.cache.injectcount + 1
    if self.cache.injectcount == injectCfg.upnum then
        self.cache.injectcount = 0
        self:UpInjectLevel()
    end
    return true
end

function Equip:UpInjectLevel()
    self.cache.injectstage = self.cache.injectstage + 1
    self.equipplug:InjectEvent()
    self:UpdateAttrs()
end

function Equip:UpdateAttrs(attrs)
    local stage = self.cache.injectstage
    local DeitySpiritConfig = server.configCenter.DeitySpiritConfig[self.slot]
    local oldattrs = attrs or DeitySpiritConfig[stage - 1] and DeitySpiritConfig[stage - 1].attrpower or {}
    local newattrs = DeitySpiritConfig[stage].attrpower
    self.role:UpdateBaseAttr(oldattrs, newattrs, server.baseConfig.AttrRecord.EquipRedInject)
end

function Equip:GetInjectstage()
    return self.cache.injectstage
end

--觉醒
function Equip:Awaken()
    if not self:IsReditem() then return end
    local old_item = self.cache.item
    local DeityAwakeConfig = server.configCenter.DeityAwakeConfig[old_item.id]
    local ItemCfg = server.configCenter.ItemConfig[DeityAwakeConfig.attrpower or -1]
    if not ItemCfg or ItemCfg.level > self.player.cache.level then 
        lua_app.log_info("player level not awaken.", ItemCfg.level, self.player.cache.level)
        return 
    end
    if not self.player:PayRewards(DeityAwakeConfig.cost, server.baseConfig.YuanbaoRecordType.RedEquip, "RedEquip:Awaken cost") then
        lua_app.log_info("Awaken pay faild.")
        return
    end
    local newitem = {
        id = DeityAwakeConfig.attrpower,
        count = 1,
        attrs = ItemConfig:SetEquipNewAttr(DeityAwakeConfig.attrpower),
    }
    self.role:ChangeEquip(old_item, newitem)
    self.cache.item = newitem
    return true
end

function Equip:IsReditem()
    local item = self.cache.item
    if item.id == 0 then return false end
    local item_config = server.configCenter.ItemConfig[item.id]
    return (item_config.quality == ItemConfig.ItemQuality.Red)
end

function Equip:ChangeItemTable(item)
    local old_item = self.cache.item
    if item.id == 0 then
        self.cache.item = item
        return old_item
    end
    if not self:CanEquipItem(item.id) then
        return {}
    end
    self.cache.item = item
    self.role:ChangeEquip(old_item, item)
    if self:IsReditem() then
        self.equipplug:RedEquipEvent()
    end
    return old_item
end

function Equip:ChangeItem(id, attrs)
    local item = {
        id = id,
        count = 1,
        attrs = attrs,
    }
    local item_config = server.configCenter.ItemConfig[id]
    local old_item = self:ChangeItemTable(item)
    return old_item.id, old_item.attrs
end

function Equip:GetItemId()
    return self.cache.item.id
end

return Equip