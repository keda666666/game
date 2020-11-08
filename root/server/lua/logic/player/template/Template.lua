local oo = require "class"
local EntityConfig = require "resource.EntityConfig"
local server = require "server"
local lua_app = require "lua_app"

local TEMPLATE = oo.class()
local _TemplateConfig = {}
--[[

]]--

function TEMPLATE:ctor(entity)
	self.entity = entity
	self.player = entity.player
	self.cache = entity.cache
	self.tmp_attrs = EntityConfig:GetZeroAttr(EntityConfig.Attr.atCount)
end

function TEMPLATE:Init(cache)
	self.cache = cache
	if self.cache.startUp == 0 then return end 
	--得到模块的所有属性 
	local allattr = self:Allattr()
	self:ReCalcAttr({}, allattr)
	self:SetShow(self.cache.useClothes)
end

function TEMPLATE:onLevelUp(oldlevel, level)
	if self.cache.startUp == 1 then return end
	local baseConfig = self:GetBaseConfig()
	if baseConfig.byactive == 1 then return end -- 手动激活
	local open = baseConfig.open
	local data = server.configCenter.FuncOpenConfig[open]
	if data.conditionkind == 1 then
	elseif data.conditionkind == 2 then
		if data.conditionnum <= level then
			self:OpenTemplate()
		end
	elseif data.conditionkind == 3 then
	elseif data.conditionkind == 4 then
	elseif data.conditionkind == 5 then
	elseif data.conditionkind == 6 then
	end
	
end

function TEMPLATE:onVipLevelUp(oldlevel, level)
	if self.cache.startUp == 1 then return end
	local baseConfig = self:GetBaseConfig()
	if baseConfig.byactive == 1 then return end -- 手动激活
	local open = baseConfig.open
	local data = server.configCenter.FuncOpenConfig[open]
	if data.conditionkind2 == 1 then
	elseif data.conditionkind2 == 2 then
	elseif data.conditionkind2 == 3 then
		if data.conditionnum2 <= level then
			self:OpenTemplate()
		end
	elseif data.conditionkind2 == 4 then
	elseif data.conditionkind2 == 5 then
	elseif data.conditionkind2 == 6 then
	end
end

-- upNum = 0,升级次数
-- drugNum = 0,吃了多少药
-- lv = 1,等级
-- clothesList = {},服装列表
-- skillList = {},技能列表
-- equipList = {},装备列表
function TEMPLATE:Allattr()
	local attrsInfo = {}
	-- 称号加成，用于等级和经验
	local addRatio = 1
	if self.cache.attrTitle and self.cache.attrTitle ~= 0 then
		local titleAttrConf = server.configCenter.TitleAttrConf
		addRatio = addRatio + (titleAttrConf[self.cache.attrTitle].attrpower / 100)
	end

	-- 等级属性
	local progressConfig = self:GetProgressConfig()
	if progressConfig[self.cache.lv] then
		for _,v in pairs(progressConfig[self.cache.lv].attrpower) do
			v = table.wcopy(v)
			v.value = math.floor(v.value * addRatio)
			table.insert(attrsInfo, v)
		end
	end
	-- 经验属性
	if self.cache.upNum ~= 0 then
		local attrsConfig = self:GetAttrsConfig()
		local attr = attrsConfig[self.cache.lv]
		for _,v in pairs(attr.attrpower) do
			v = table.wcopy(v)
			v.value = math.floor((v.value * self.cache.upNum) * addRatio)
			table.insert(attrsInfo, v)
		end
	end
	-- 服装属性
	self:AddSkinAttr(attrsInfo)
	-- 装备属性
	self:AddEquipAttr(attrsInfo)
	-- 技能属性
	self:AddSkillAttr(attrsInfo)
	-- 属性丹属性
	self:AddDrugNumAttr(attrsInfo)
	return attrsInfo
end
-- 服装属性
function TEMPLATE:AddSkinAttr(attrsInfo)
	attrsInfo = attrsInfo or {}
	local skinConfig = self:GetSkinConfig()
	for clothesNo,_ in pairs(self.cache.clothesList) do
		local skinData = skinConfig[clothesNo]
		if skinData.attrpower then
			for _,v in pairs(skinData.attrpower) do
				table.insert(attrsInfo, v)
			end
		end
	end
	return attrsInfo
end
-- 装备属性
function TEMPLATE:AddEquipAttr(attrsInfo)
	attrsInfo = attrsInfo or {}
	local equipConfig = server.configCenter.EquipConfig
	for _,v in pairs(self.cache.equipList) do
		for _,attr in pairs(v.attrs) do
			if attr.type and attr.value then
				table.insert(attrsInfo, attr)
			end
		end
		if equipConfig[v.id] then
			for _,attr in pairs(equipConfig[v.id].attrs) do
				if attr.type and attr.value then
					table.insert(attrsInfo, attr)
				end
			end
		end
	end
	return attrsInfo
end
-- 技能属性
function TEMPLATE:AddSkillAttr(attrsInfo)
	attrsInfo = attrsInfo or {}
	local skillConfig = self:GetSkillConfig()
	local baseConfig = self:GetBaseConfig()
	if skillConfig and baseConfig then
		for k,v in pairs(self.cache.skillList) do
			local skillId = baseConfig.skilllist[k]
			local attrsData = skillConfig[skillId][v].attrpower
			for _,attr in pairs(attrsData) do
				table.insert(attrsInfo, attr)
			end
		end
	end
	return attrsInfo
end
-- 属性丹属性
function TEMPLATE:AddDrugNumAttr(attrsInfo)
	attrsInfo = attrsInfo or {}
	local baseConfig = self:GetBaseConfig()
	local drugNum = self.cache.drugNum
	if drugNum ~= 0 then
		for _,v in pairs(baseConfig.attredata) do
			v = table.wcopy(v)
			v.value = v.value * drugNum
			table.insert(attrsInfo, v)
		end
	end
	return attrsInfo
end

function TEMPLATE:onInitClient()
	if self.cache.startUp == 0 then return end
	local msg = self:GetData()
	msg.templateType = self.typ
	server.sendReq(self.player, "sc_template_init_data", msg)
end

function TEMPLATE:AddSExp(num, lv)
	if self.cache.startUp == 0 then return false end 
	local progressConfig = self:GetProgressConfig()
	local lvProConfig = self:GetLvproConfig()
	local attrsConfig = self:GetAttrsConfig()

	local proConfig = lvProConfig[self.cache.lv]
	local maxLv = #progressConfig

	if self.cache.lv == maxLv then
		return false
	end
	local oldLv = self.cache.lv
	local oldUpNum = self.cache.upNum
	local changInfo = {}
	if self.cache.lv <= lv then
		--升级
		self.cache.lv = self.cache.lv + 1
		changInfo.lv = self.cache.lv
		self:addLvSkillClothes(changInfo)
	else
		self.cache.upNum = self.cache.upNum + num
		local upLvNum = proConfig.upnum
		while self.cache.upNum >= upLvNum do
			self.cache.lv = self.cache.lv + 1
			changInfo.lv = self.cache.lv
			self:addLvSkillClothes(changInfo)
			self.cache.upNum = self.cache.upNum - upLvNum
			nextConfig = lvProConfig[self.cache.lv]
			if not nextConfig then
				self.cache.upNum = 0
				break
			end
			upLvNum = nextConfig.upnum
			self:OnUpLv()
		end
		changInfo.upNum = self.cache.upNum
	end

	local oldAttrs = {}
	local newAttrs = {}

	for k,v in pairs(attrsConfig[oldLv].attrpower) do
		v = table.wcopy(v)
		v.value = v.value * oldUpNum
		table.insert(oldAttrs, v)
	end
	for k,v in pairs(progressConfig[oldLv].attrpower) do
		table.insert(oldAttrs, v)
	end

	for k,v in pairs(attrsConfig[self.cache.lv].attrpower) do
		v = table.wcopy(v)
		v.value = v.value * self.cache.upNum
		table.insert(newAttrs, v)
	end
	for k,v in pairs(progressConfig[self.cache.lv].attrpower) do
		table.insert(newAttrs, v)
	end

	self:ReCalcAttr(oldAttrs, newAttrs)
	changInfo.templateType = self.typ
	server.sendReq(self.player, "sc_template_update_data", changInfo)
	return true
end

function TEMPLATE:AddExp(autoBuy)
	if self.cache.startUp == 0 then return end 
	local progressConfig = self:GetProgressConfig()
	local lvProConfig = self:GetLvproConfig()
	local attrsConfig = self:GetAttrsConfig()
	if not lvProConfig or not progressConfig or not attrsConfig then
		return false, -1
	end

	local proConfig = lvProConfig[self.cache.lv]
	local maxLv = #progressConfig

	if not proConfig then
		return false, -2
	end

	if self.cache.lv == maxLv then
		return false, -3
	end

	local cost = proConfig.cost
	if not self.player:PayRewardsByShop(cost, self.YuanbaoRecordType, self:GetType(self.typ).type2..":AddExp", autoBuy) then return false, -4 end
	local changInfo = {} -- 变动的发客户端

	-- self.cache.upNum = self.cache.upNum + 1
	-- self:CheckLv(maxLv, proConfig, changInfo)
	local oldAttrs = {}
	local newAttrs = {}
	local upNum = self.cache.upNum
	if (upNum + 1) >= proConfig.upnum then
		for k,v in pairs(attrsConfig[self.cache.lv].attrpower) do
			v = table.wcopy(v)
			v.value = v.value * upNum
			table.insert(oldAttrs, v)
		end

		for k,v in pairs(progressConfig[self.cache.lv].attrpower) do
			table.insert(oldAttrs, v)
		end
		for k,v in pairs(progressConfig[self.cache.lv + 1].attrpower) do
			table.insert(newAttrs, v)
		end
		self.cache.upNum = (upNum + 1) - proConfig.upnum
		self.cache.lv = self.cache.lv + 1
		changInfo.lv = self.cache.lv
		self:addLvSkillClothes(changInfo)
	else
		for k,v in pairs(attrsConfig[self.cache.lv].attrpower) do
			table.insert(newAttrs, v)
		end
		self.cache.upNum = upNum + 1
	end
	changInfo.upNum = self.cache.upNum
	self:ReCalcAttr(oldAttrs, newAttrs)
	self:OnUpLv()
	return changInfo
end

function TEMPLATE:OnUpLv()
end

function TEMPLATE:packSkillList()
	local skillList={}
	for i=1, 4, 1 do
		skillList[i] = self.cache.skillList[i] or 0
	end
	return skillList
end

function TEMPLATE:packEquipList()
	local equipList = {{},{},{},{}}
	for k,v in pairs(self.cache.equipList) do
		equipList[k] = v
	end
	return equipList
end

function TEMPLATE:packClothesList()
	local ClothesList={}
	for clothesNo,_ in pairs(self.cache.clothesList) do
		table.insert(ClothesList,clothesNo)
	end
	return ClothesList
end

function TEMPLATE:SkillUpLv(skillNo)
	if self.cache.startUp == 0 then return end 
	local skillLv = self.cache.skillList[skillNo]
	if not skillLv then return false, -1 end

	local skillConfig = self:GetSkillConfig()
	local baseConfig = self:GetBaseConfig()
	if not baseConfig then return false, -2 end
	local skillId = baseConfig.skilllist[skillNo]
	if not skillId then return false, -3 end
	if not skillConfig or not skillConfig[skillId] then return false, -4 end
	if not skillConfig[skillId][skillLv + 1] then return false, -5 end
	local cost = skillConfig[skillId][skillLv].cost

	if not self.player:PayReward(cost.type, cost.id, cost.count, self.YuanbaoRecordType) then return false, -6 end
	self.cache.skillList[skillNo] = self.cache.skillList[skillNo] + 1

	local changInfo = {}
	local oldAttrs = skillConfig[skillId][skillLv].attrpower
	local newAttrs = skillConfig[skillId][skillLv + 1].attrpower
	changInfo.skillList = self:packSkillList()
	self:ReCalcAttr(oldAttrs, newAttrs)

	return changInfo
end

function TEMPLATE:ChangeEquip(equipId)
	if self.cache.startUp == 0 then return end 
	local bag = self.player.bag
	local equip = bag:GetItem(equipId)
	if not equip or equip.type ~= self.cache.itemType then return false, -1 end
	local changInfo = {}
	local oldAttrs = {}
	local equipData = equip:GetConfig()
	if equipData.level > self.cache.lv then return false, -2 end
	local oldEquip = self.cache.equipList[equipData.subType + 1]
	local item = {
		id = equip.cache.id,
		attrs = equip.cache.attrs,
	}

	self.cache.equipList[equipData.subType + 1] = item
	changInfo.equipList={{},{},{},{}} --没变动的发空
	changInfo.equipList[equipData.subType + 1] = item
	local bag = self.player.bag
	bag:DelItem(equip.dbid)
	if oldEquip then
		oldAttrs = oldEquip.attrs
		bag:AddItem(oldEquip.id, 1, oldEquip.attrs, nil, 0)
	end
	self:ReCalcAttr(oldAttrs, server.configCenter.EquipConfig[item.id].attrs)
	self:ReCalcAttr(oldAttrs, item.attrs)
	return changInfo
end

function TEMPLATE:changeClothes(clothesId)
	if self.cache.useClothes == clothesId then return false,-1 end
	if not self.cache.clothesList[clothesId] then return false, -2 end

	local changInfo = {}
	self.cache.useClothes = clothesId
	self:SetShow(clothesId)
	changInfo.useClothes = clothesId
	return changInfo
end

function TEMPLATE:BuyClothes(clothesNo)
	local skinConfig = self:GetSkinConfig()
	if not skinConfig or not skinConfig[clothesNo] then return false, -1 end
	if self.cache.clothesList[clothesNo] then return false, -2 end
	local clothesData = skinConfig[clothesNo]
	local propsList = clothesData.itemid
	if not propsList then return false, -3 end
	local bag = self.player.bag

	if not self.player:PayRewards({propsList}, self.YuanbaoRecordType) then return false, -3 end
	local changInfo = {}
	self.cache.clothesList[clothesNo] = 1
	self.cache.useClothes = clothesNo
	changInfo.clothesList = self:packClothesList()
	self:SetShow(clothesNo)
	changInfo.useClothes = self.cache.useClothes
	self:ReCalcAttr({}, clothesData.attrpower)
	self.player.clothes:AddClothes(self.typ, clothesNo)
	return changInfo
end

function TEMPLATE:UseDrug(amount)
	if self.cache.startUp == 0 then return false, 0 end 
	local baseConfig = self:GetBaseConfig()
	if not baseConfig then return false, -1 end
	local propsNo = baseConfig.attreitemid
	local bag = self.player.bag
	if not bag:CheckItem(propsNo, amount) then
		return false, -2
	end
	bag:DelItemByID(propsNo, amount, self.YuanbaoRecordType)
	self.cache.drugNum = self.cache.drugNum + amount
	local AddAttrs = table.wcopy(baseConfig.attredata)
	for _,v in pairs(AddAttrs) do
		v.value =  v.value * amount
	end
	
	local changInfo = {}
	changInfo.drugNum = self.cache.drugNum
	self:ReCalcAttr({}, AddAttrs)
	return changInfo
end

function TEMPLATE:addLvSkillClothes(changInfo)
	local baseConfig = self:GetBaseConfig()
	if not baseConfig then return end
	local skillConfig = self:GetSkillConfig()
	if not skillConfig then return end

	local skill = baseConfig.openskilllv[self.cache.lv]
	local pictureId = baseConfig.pictureid[self.cache.lv]

	if skill then
		self.cache.skillList[#self.cache.skillList + 1] = 1
		changInfo.skillList = self:packSkillList()
		local skillId = baseConfig.skilllist[#self.cache.skillList]
		self:ReCalcAttr({}, skillConfig[skillId][1].attrpower)
	end
	if pictureId then
		self.cache.clothesList[pictureId] = 1
		self.cache.useClothes = pictureId
		self:SetShow(pictureId)
		changInfo.useClothes = pictureId
		changInfo.clothesList = self:packClothesList()
	end
end

function TEMPLATE:OpenTemplate()
	local changInfo = {}
	self.cache.startUp = 1
	self:addLvSkillClothes(changInfo)

	local msg = self:GetData()
	msg.templateType = self.typ
	server.sendReq(self.player, "sc_template_init_data", msg)
	self:SetShow(self.cache.useClothes)
	local attrs = self:Allattr()
	self:ReCalcAttr({}, attrs)
	self:OnOpenTemplate()
end

function TEMPLATE:OnOpenTemplate()
end

function TEMPLATE:GetData()
	local data={
		startUp = self.cache.startUp,
		upNum = self.cache.upNum,
		lv = self.cache.lv,
		useClothes = self.cache.useClothes,
		clothesList = self:packClothesList(),
		skillList = self:packSkillList(),
		equipList = self:packEquipList(),
		drugNum = self.cache.drugNum,
		reward = self.cache.rewards,
	}
	return data
end

function TEMPLATE:GetReward(no)
	local rewardConfig = server.configCenter.ProgressRewardConfig
	local configData = rewardConfig[self.typ][no]
	if not configData then return false, -1 end
	if self.cache.lv < configData.progress then return false, -2 end
	local rewards = self.cache.rewards
	if rewards & (2 ^ no) ~= 0 then return false, -3 end
	
	self.cache.rewards = rewards | (2 ^ no)
	self.player:GiveRewardAsFullMailDefault(configData.reward, "进阶奖励", self.YuanbaoRecordType, "进阶奖励"..self.typ.."|"..no)
	local changInfo = {}
	changInfo.reward = self.cache.rewards
	return changInfo
end

function TEMPLATE:GetClothesList()
	return self.cache.clothesList
end

function TEMPLATE:ToReCalcPower()
	if not self.powertimer and self.cache then
		local function _RunReCalcPower()
			if self.powertimer then
				lua_app.del_timer(self.powertimer)
				self.powertimer = nil
			end
			self:ReCalcPower()
		end
		self.powertimer = lua_app.add_timer(800, _RunReCalcPower)
	end
end

function TEMPLATE:ReCalcPower()
	local power = 0
	local attrs = self.tmp_attrs
	local AttrPowerConfig = server.configCenter.AttrPowerConfig
	for k, v in pairs(attrs) do
		if AttrPowerConfig[k] then
			power = power + v * AttrPowerConfig[k].power
		end
	end
	self.cache.totalpower = math.floor(power / 100)
end

function TEMPLATE:ReCalcAttr(oldAttrs, newAttrs)
	local baseAttr = self.tmp_attrs
	local function _ChangeBaseAttr(baseAttrType, changeValue)
		baseAttr[baseAttrType] = baseAttr[baseAttrType] + changeValue
		if baseAttrType == EntityConfig.Attr.atMaxHP then
			baseAttr[EntityConfig.Attr.atHP] = baseAttr[baseAttrType]
		end
	end
	
	for _, v in pairs(oldAttrs) do
		_ChangeBaseAttr(v.type, -v.value)
	end
	for _, v in pairs(newAttrs) do
		_ChangeBaseAttr(v.type, v.value)
	end
	self.entity:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Template * 100 + self.typ)
	self:ToReCalcPower()
end

function TEMPLATE:SetShow(useClothes)
	self.entity:SetShow(_TemplateConfig[self.typ].shownum, useClothes)
end

------------------------------------------
--[[ 
ride 坐骑 1 
wing 翅膀 2 
fairy 天仙 3 
weapon 神兵 4
pet_soul 宠物兽魂 5
pet_psychic 宠物通灵 6 
xianlv_position 仙侣仙位 7
xianlv_circle 仙侣法阵 8 
tiannv 天女 9 
tiannv_nimbus 天女灵气 10 
tiannv_flower 天女花辇 11
baby 灵童 12
]]--

function TEMPLATE:GetPlayerData(player, typeid)
	local typeData = TEMPLATE:GetType(typeid)
	return player[typeData.type1][typeData.type2]
end

function TEMPLATE:AddTitleAttr(player, titleId)
	local titleAttrConf = server.configCenter.TitleAttrConf
	local newTitleData = titleAttrConf[titleId]
	if not newTitleData then return end
	local templateInfo = TEMPLATE:GetPlayerData(player, newTitleData.type)
	local addRatio = newTitleData.attrpower / 100
	if templateInfo.cache.attrTitle and templateInfo.cache.attrTitle ~= 0 then
		local oldTitleData = titleAttrConf[templateInfo.cache.attrTitle]
		if oldTitleData.attrpower >= newTitleData.attrpower then return end
		addRatio = (addRatio - oldTitleData.attrpower) / 100
	end
	templateInfo.cache.attrTitle = titleId

	if templateInfo.cache.startUp == 0 then return end 

	--增加属性
	local allattr = {}
	local progressConfig = templateInfo:GetProgressConfig()
	if progressConfig[templateInfo.cache.lv] then
		for _,v in pairs(progressConfig[templateInfo.cache.lv].attrpower) do
			v = table.wcopy(v)
			v.value = math.floor(v.value * addRatio)
			table.insert(allattr, v)
		end
	end

	-- 经验属性
	if templateInfo.cache.upNum ~= 0 then
		local attrsConfig = templateInfo:GetAttrsConfig()
		local attr = attrsConfig[templateInfo.cache.lv]
		for _,v in pairs(attr.attrpower) do
			v = table.wcopy(v)
			v.value = math.floor((v.value * templateInfo.cache.upNum) * addRatio)
			table.insert(allattr, v)
		end
	end
	templateInfo:ReCalcAttr({}, allattr)
end

function TEMPLATE:SetType(typeid, type)
	_TemplateConfig[typeid] = type
end

function TEMPLATE:GetType(typeid)
	return _TemplateConfig[typeid]
end

return TEMPLATE