local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "common.resource.ItemConfig"
local Equip = require "player.role.equip.Equip"

local EquipPlug = oo.class()

function EquipPlug:ctor(role)
	self.role = role
	self.player = role.player
	self.equipList = {}
    self.reditemrecord = {}
    self.injectrecord = {}
    self.forgeRecord = {}
end

function EquipPlug:onCreate()
    self.cache = self.role.cache.equips_data
	for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
		local equip = Equip.new(self.role, i, self)
		equip:onCreate()
		self.equipList[i] = equip
	end
end

function EquipPlug:onInitClient()
    server.sendReq(self.player, "sc_equip_update_suitlv", { suitlv = self.cache.suitlv })
end

function EquipPlug:onLoad()
    self.cache = self.role.cache.equips_data
    if not self.cache.equipList then
        lua_app.log_error(string.format("EquipPlug:onLoad not equipList %s", self.role.cache.playerid))
    else
        for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
            local equip = Equip.new(self.role, i, self)
            equip:onLoad()
            self.equipList[i] = equip
            self:AddAttrs(equip, ItemConfig.ForgeType.Enhance)
            self:AddAttrs(equip, ItemConfig.ForgeType.Refine)
            self:AddAttrs(equip, ItemConfig.ForgeType.Anneal)
            self:AddAttrs(equip, ItemConfig.ForgeType.Gem)
        end
    end
    self:UpdateEquipTupoSuit(ItemConfig.ForgeType.Enhance, {})
    self:UpdateEquipTupoSuit(ItemConfig.ForgeType.Refine, {})
    self:UpdateEquipTupoSuit(ItemConfig.ForgeType.Anneal, {})
    self:UpdateEquipTupoSuit(ItemConfig.ForgeType.Gem, {})
    self:UpdateRoleSuit({})
    self:InjectEvent({})
    self:RedEquipEvent({})
end

function EquipPlug:AddAttrs(equip, forgeType)
    local level = equip:GetForgeLevel(forgeType)
    local equipPos = equip.slot
    local Index = equipPos * 200 + level
    local forgecfg = ItemConfig:GetForgeAttrConfig(forgeType)
    local newAttrs = level > 0 and forgecfg[Index].attr or {}
    self.player.role:UpdateBaseAttr({}, newAttrs, server.baseConfig.AttrRecord.EquipForge)
end

function EquipPlug:UpdateAttrs(equip, forgeType)
    local level = equip:GetForgeLevel(forgeType)
    local equipPos = equip.slot
    local Index = equipPos * 200 + level
    local forgecfg = ItemConfig:GetForgeAttrConfig(forgeType)
    local newAttrs = level > 0 and forgecfg[Index].attr or {}
    local oldAttrs = level > 1 and forgecfg[Index - 1].attr or {}
    self.player.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.EquipForge)
end

function EquipPlug:GetMsgData()
	local tmp = {}
	for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
		local equip = self.equipList[i]
		tmp[i + 1] = equip:GetMsgData()
	end
	return tmp
end

--红装注灵
function EquipPlug:InjectEqiup(slot, mode)
    local equip = self.equipList[slot]
    if equip then
        local ret = equip:InjectLing(mode) or false
        if ret then
            self:SendEquipUpdateMsg(slot)
        end
        return ret
    end
    return false
end

--红装觉醒
function EquipPlug:RedUpgrade(slot)
    local equip = self.equipList[slot]
    if equip then
        if equip:Awaken() then
            self:SendEquipUpdateMsg(slot)
            self:CheckRoleSuit()
        end
    end
end

--红装合成
function EquipPlug:RedGenerate(slot)
    local DeityComposeConfig = server.configCenter.DeityComposeConfig[slot]
    local itemCfg = server.configCenter.ItemConfig[DeityComposeConfig.id]
    assert(self.player.cache.level >= itemCfg.level, "EquipPlug:RedGenerate player level not enough.") 
    if not self.player:PayRewards(DeityComposeConfig.cost, server.baseConfig.YuanbaoRecordType.RedEquip, "RedEquip:generate cost") then
        lua_app.log_info("generate red equip pay faild.")
        return
    end
    local _, _, itemhandles = self.player.bag:AddItem(DeityComposeConfig.id, 1, nil, nil, 1)
    self:EquipItem(itemhandles[1], slot)
end

--注灵事件
function EquipPlug:InjectEvent(oldattr)
    local DeityResonateConfig = server.configCenter.DeityResonateConfig
    local totalstage = 0
    for __, equip in pairs(self.equipList) do
        totalstage = totalstage + equip:GetInjectstage()
    end
    local upCfg = table.matchValue(DeityResonateConfig, function(data)
        return totalstage - data.level
    end)
    if upCfg and not self.injectrecord[upCfg.skinid] then
        self.injectrecord[upCfg.skinid] = true
        local oldattrs = oldattr or DeityResonateConfig[upCfg.skinid - 1] and DeityResonateConfig[upCfg.skinid - 1].attrpower or {}
        local newattrs = DeityResonateConfig[upCfg.skinid].attrpower
        self.role:UpdateBaseAttr(oldattrs, newattrs, server.baseConfig.AttrRecord.EquipRedInjectSuit)
    end
end

--装备红装
function EquipPlug:RedEquipEvent(oldattr)
    local DeityActConfig = server.configCenter.DeityActConfig
    local redItemNum = 0
    for __, equip in pairs(self.equipList) do
        if equip:IsReditem() then
            redItemNum = redItemNum + 1
        end
    end
    local redCfg = table.matchValue(DeityActConfig, function(data)
        return redItemNum - data.level
    end)
    if redCfg and not self.reditemrecord[redCfg.index] then
        self.reditemrecord[redCfg.index] = true
        local oldattrs = oldattr or DeityActConfig[redCfg.index - 1] and DeityActConfig[redCfg.index - 1].attrpower or {}
        local newattrs = DeityActConfig[redCfg.index].attrpower
        self.role:UpdateBaseAttr(oldattrs, newattrs, server.baseConfig.AttrRecord.EquipRedSuit)
    end
end

function EquipPlug:EquipUp(slot, id, attrs)
	local equip = self.equipList[slot]
	local oldid, oldattr = equip:ChangeItem(id, attrs)
	if oldid then
        self:SendEquipUpdateMsg(slot)
	end
	return oldid, oldattr
end

function EquipPlug:EquipItem(itemhandle, slot)
	local bag = self.player.bag
	local item = bag:GetItem(itemhandle)
	if not item or item.cache.bag_type ~= ItemConfig.BagType.BAG_TYPE_EQUIP then
		lua_app.log_info("Bag:EquipItem error: error item itemhandle =", itemhandle, ", account =", self.player.cache.account)
		return
	end
	-- local equipBag = self.player:GetRole(roleid).equipBag
	local oldconfigID, oldattr = self:EquipUp(slot, item.cache.id, item.cache.attrs)
	if not oldconfigID then
		lua_app.log_error("equipBag:EquipUp error")
		return
	end
	bag:DelItem(itemhandle)
	if oldconfigID ~= 0 then
		bag:AddItem(oldconfigID, 1, oldattr, nil, 0)
	end
    self:CheckRoleSuit()
    -- 增加任务进度
    self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipWearCount)
    self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipWearAssign)
    self.player.activityPlug:onDoTarget()
end

local _SuitConfig = false
local function _GetSuitConfig()
    if not _SuitConfig then
        _SuitConfig = {}
        local RoleSuitConfig = server.configCenter.RoleSuitConfig
        --table.ptable(RoleSuitConfig, 3)
        local maxSuitLv = #RoleSuitConfig

        local function _GetSuitLv(level, quality)
            for i = maxSuitLv, 1, -1 do
                if level >= RoleSuitConfig[i].level and quality >= RoleSuitConfig[i].quality then
                    return RoleSuitConfig[i].suitLv
                end
            end
            return 0
        end
        local maxquality = 0
        for __, cfg in ipairs(RoleSuitConfig) do
            if cfg.quality > maxquality then
                maxquality = cfg.quality
            end
        end
        _SuitConfig.maxquality = maxquality
        for _,v in ipairs(RoleSuitConfig) do
            _SuitConfig[v.level] = {}
            for quality = maxquality, 0, -1 do
                _SuitConfig[v.level][quality] = _GetSuitLv(v.level, quality)
            end
        end
    end
    return _SuitConfig
end

--套装达人
function EquipPlug:CheckRoleSuit()
    local RoleSuitConfig = server.configCenter.RoleSuitConfig
    local suitconfig = _GetSuitConfig()
    local bag = self.player.bag
    local suitLvList = {}
    for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
        local equip = self.equipList[i]
        local itemId = equip:GetItemId()
        if itemId ~= 0 then
            local itemConf = bag:GetItemConfig(itemId)
            local matchCfg = table.matchValue(RoleSuitConfig, function(cfg)
                return itemConf.level - cfg.level
            end)
            if matchCfg and suitconfig[matchCfg.level] then
                local quality = itemConf.quality > suitconfig.maxquality and suitconfig.maxquality or itemConf.quality
                local lvTmp = suitconfig[matchCfg.level][quality]
                suitLvList[lvTmp] = suitLvList[lvTmp] and suitLvList[lvTmp] + 1 or 1
            end
        end
    end
    local suitCount = 0
    local suitlv = 0
    for lv = #RoleSuitConfig, 1, -1 do
        local num = suitLvList[lv] or 0
        suitCount = suitCount + num
        if suitCount >= RoleSuitConfig[lv].count then
            suitlv = lv
            break
        end
    end
    if suitlv > self.cache.suitlv then
        for lv = self.cache.suitlv + 1, suitlv do
            self.cache.suitlv = lv
            self:UpdateRoleSuit()
            server.sendReq(self.player, "sc_equip_update_suitlv", { suitlv = self.cache.suitlv })
        end
    end
end

function EquipPlug:UpdateRoleSuit(oldattr)
    local RoleSuitConfig = server.configCenter.RoleSuitConfig
    local suitlv = self.cache.suitlv
    local oldAttrs = oldattr or RoleSuitConfig[suitlv - 1] and RoleSuitConfig[suitlv - 1].attrs or {}
    local newAttrs = RoleSuitConfig[suitlv] and RoleSuitConfig[suitlv].attrs or {}
    self.player.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.EquipSuit)
end

function EquipPlug:UpdateEquipTupoSuit(forgeType, oldattr)
    local ForgeSuitConfig = ItemConfig:GetForgeSuitConfig(forgeType)
    local forgeSuitlv = self:GetTupoSuitLevel(forgeType)
    if not self:NextStepEquipTupoSuit(forgeType, forgeSuitlv) then
        return
    end
    local newAttrs = ForgeSuitConfig[forgeSuitlv].attrs
    local oldAttrs = oldattr or ForgeSuitConfig[forgeSuitlv - 1] and ForgeSuitConfig[forgeSuitlv - 1].attrs or {}
    self.player.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.EquipForgeSuit)
end

function EquipPlug:NextStepEquipTupoSuit(forgeType, suitlv)
    local loadrecord = self.forgeRecord[forgeType]
    if not loadrecord then
        loadrecord = {}
        self.forgeRecord[forgeType] = loadrecord
    end
    if suitlv == 0 then
        return false
    end
    local canUp = loadrecord[suitlv]
    loadrecord[suitlv] = true
    return not canUp
end

function EquipPlug:GetTupoSuitLevel(forgeType)
    local ForgeSuitConfig = ItemConfig:GetForgeSuitConfig(forgeType)
    local forgeLevel = ForgeSuitConfig[#ForgeSuitConfig].level
    for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
        forgeLevel = math.min(forgeLevel, self.equipList[i]:GetForgeLevel(forgeType))
    end
    local fitCfg = table.matchValue(ForgeSuitConfig, function(Cfg)
        return forgeLevel - Cfg.level  
    end)
    return (fitCfg and fitCfg.suitLv or 0)
end

function EquipPlug:CheckForgeValid(forgeType, preEquip, curEquip)
	if preEquip:GetForgeLevel(forgeType) >= curEquip:GetForgeLevel(forgeType) then
		return true
	end
	return false
end

function EquipPlug:ForgeUpGrade(forgeType)
    local equip = self.equipList[ItemConfig.EquipSlotType.WEAPON]
    local equipPos = ItemConfig.EquipSlotType.WEAPON
    --找出最小锻造等级的装备
    for i = 1, ItemConfig.EquipSlotType.MAX - 1 do
    	if not self:CheckForgeValid(forgeType, self.equipList[i - 1], self.equipList[i]) then
    		return
    	end
        if equip:GetForgeLevel(forgeType) > self.equipList[i]:GetForgeLevel(forgeType) then
            equip = self.equipList[i]
            equipPos = i
        end
    end
    --找出对应的配置表
    local ForgeConfig = ItemConfig:GetForgeCostConfig(forgeType)
    local forgeLevel = equip:GetForgeLevel(forgeType) + 1
    local equipCfg = ForgeConfig[forgeLevel]

    if not equipCfg then
        lua_app.log_error("EquipPlug:ForgeUpGrade: actor(", self.player.accountname, ") no equipCfg:",forgeType," equipCfg:" ,forgeLevel)
        return
    end
    --计算升级所需的资源
    local pay = 0
    local isChange = false
    local function _PayResult()
    	--扣除资源
    	self.player:PayReward(equipCfg.cost.type, equipCfg.cost.id, pay, equipCfg.cost.id)
        server.sendReq(self.player,"sc_equip_forge", {
                forgeType = forgeType,
                forgeLevel = self:GetForgeLevelList(forgeType)
            })
        if isChange then
            self:UpdateEquipTupoSuit(forgeType)
            -- 任务事件
            if forgeType == ItemConfig.ForgeType.Enhance then
                self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipEnhanceAll)
                self.player.task:onEventAdd(server.taskConfig.ConditionType.EquipEnhanceAcc)
            elseif forgeType == ItemConfig.ForgeType.Refine then
                self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipRefineAll)
                self.player.task:onEventAdd(server.taskConfig.ConditionType.EquipRefineAcc)
            elseif forgeType == ItemConfig.ForgeType.Anneal then
                self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipAnnealAll)
                self.player.task:onEventAdd(server.taskConfig.ConditionType.EquipAnnealAcc)
            elseif forgeType == ItemConfig.ForgeType.Gem then
                self.player.task:onEventCheck(server.taskConfig.ConditionType.EquipGemAll)
                self.player.task:onEventAdd(server.taskConfig.ConditionType.EquipGemAcc)
            end
            self.player.activityPlug:onDoTarget()
        end
    end
    for i = equipPos, ItemConfig.EquipSlotType.MAX - 1 do
        if not self.player:CheckReward(equipCfg.cost.type, equipCfg.cost.id, pay + equipCfg.cost.count) then
            _PayResult()
            return 
        end
        self.equipList[i]:SetForgeLevel(forgeType, forgeLevel)
        self:UpdateAttrs(self.equipList[i], forgeType)
        pay = pay + equipCfg.cost.count
        isChange = true
    end
    _PayResult()
end

function EquipPlug:GetForgeLevelList(forgeType)
    local data = {}
    for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
        table.insert(data, self.equipList[i]:GetForgeLevel(forgeType))
    end
    return data
end

-- 获取每个品质身上穿了多少装备
function EquipPlug:GetQuantityCount()
    local list = {}
    local equiplist = self.equipList
    for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
        local equip = equiplist[i]
        local itemId = equip:GetItemId()
        if itemId ~= 0 then
            local itemConf = self.player.bag:GetItemConfig(itemId)
            local quality = itemConf.quality
            list[quality] = list[quality] or 0
            list[quality] = list[quality] + 1
        end
    end
    return list
end

-- 强化 精炼 锻炼 宝石 总等级
function EquipPlug:GetForgeLevels(forgeType)
    local alllevel = 0
    local levellist = self.player.role.equip:GetForgeLevelList(forgeType)
    for _, level in ipairs(levellist) do
        alllevel = alllevel + level
    end
    return alllevel
end

function EquipPlug:SendEquipUpdateMsg(slot)
    local equip = self.equipList[slot]
    if equip then
        server.sendReq(self.player, "sc_equip_update_data", {
                    equipPos = slot,
                    data =  equip.cache.item,
                    reddata = equip:GetMsdRedData(),
                })
    end
end

function EquipPlug:Test(...)
table.ptable(self.cache.equipList, 3)
end

server.playerCenter:SetEvent(EquipPlug, "role.equip")

return EquipPlug
