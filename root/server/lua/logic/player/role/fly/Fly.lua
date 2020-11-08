local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local WeightData = require "WeightData"

local Fly = oo.class()

function Fly:ctor(role)
	self.role = role
	self.player = role.player
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Fly
end

function Fly:onCreate()
	self:onLoad()
end

function Fly:onLoad()
	self.cache = self.role.cache.fly_data
	local allattr = self:Allattr()
	self.role:UpdateBaseAttr({}, allattr, server.baseConfig.AttrRecord.Fly)
end

function Fly:Allattr()
	local attrs = {}
	
	-- 等级属性
	local data = server.configCenter.roleFlyupFlyupproConfig[self.cache.lv]
	for _,v in pairs(data.attrpower) do
		v = table.wcopy(v)
		v.value = math.floor(v.value)
		table.insert(attrs, v)
	end
	-- 技能属性
	self:AddSkillAttr(attrs)
	
	--[[if self.skillList then
		for _,skillId in pairs(self.skillList) do
			self.role:AddSkill(skillId, true)
		end
	end--]]
	return attrs
end

-- 技能属性
function Fly:AddSkillAttr(attrsInfo)
	attrsInfo = attrsInfo or {}
	local skillConfig = server.configCenter.roleFlyupskillconfig
	local baseConfig = server.configCenter.roleFlyupbaseConfig
	if skillConfig and baseConfig then
		for k,v in pairs(self.cache.skillList) do
			local skillId = baseConfig.skilllist[k]
			local attrsData = skillConfig[skillId][v].attrs
			for _,attr in pairs(attrsData) do
				table.insert(attrsInfo, attr)
			end
		end
	end
	return attrsInfo
end

function Fly:GetSkillPower()
    local power = 0
    local SkillPowerConfig = server.configCenter.roleFlyupskillconfig
	local baseConfig = server.configCenter.roleFlyupbaseConfig
    for k,v in pairs(self.cache.skillList) do
		local skillId = baseConfig.skilllist[k]
		power = power + SkillPowerConfig[skillId][v].skillpower
    end
    return power
end

function Fly:onInitClient()
	--登录发送协议
	local msg = self:packSpellsData()
	server.sendReq(self.player, "sc_rolefly_init", msg)
end

function Fly:onDayTimer()
	self.cache.exchangeCount = 0
end

function Fly:packSpellsData()
	local msg = {
		lv = self.cache.lv,
		xiuWei = self.cache.xiuWei,
		skillList = self:packSkillList(),
		equipList = self.cache.equipList
	}
	return msg
end

function Fly:Use(pos, spellsId)
	local data = self.cache.useSpells[pos]
	if not data then return {ret = false} end
	local spellsData = self.cache.spellsList[spellsId]
	if not spellsData then return {ret = false} end
	local oldSpellsNo = data.spellsNo
	local newSpellsNo = spellsData.spellsNo
	local oldSpellsSkill = data.skillList or {}
	local newSpellsSkill = spellsData.skillList or {}

	local listConfig = self:GetFlyListConfig()
	for k,v in pairs(self.cache.useSpells) do
		if v.spellsNo ~=0 then
			local typ = listConfig[v.spellsNo].type
			if k ~= pos and typ == listConfig[spellsData.spellsNo].type then
				return {ret = false}
			end
		end
	end
	
	local lock = data.lock
	data.spellsNo = newSpellsNo
	data.skillList = newSpellsSkill
	spellsData.skillList = {}
	data.lock = spellsData.lock
	local oldAttrs = {}
	-- local oldSkill = 0
	-- local newSkill = self:GetFlyLvproConfig(newSpellsNo, data.lv).skillid or 0
	if oldSpellsNo ~= 0 then
		spellsData.spellsNo = oldSpellsNo
		spellsData.lock = lock
		spellsData.skillList = oldSpellsSkill
		-- oldSkill = self:GetFlyLvproConfig(oldSpellsNo, data.lv).skillid or oldSkill
		-- oldAttrs = self:GetFlyListConfig(oldSpellsNo).attrs or {}
		oldAttrs = self:GetFlyLvproConfig(oldSpellsNo, data.lv).attrs
	else
		self.cache.spellsList[spellsId] = nil
	end
	local newAttrs = self:GetFlyLvproConfig(newSpellsNo, data.lv).attrs

	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Fly)
	-- if oldSkill ~= newSkill then
	-- 	if oldSkill ~= 0 then 
	-- 		self.role:DelSkill(oldSkill, 1)
	-- 	end
	-- 	if newSkill ~= 0 then 
	-- 		self.role:AddSkill(newSkill, true, 1)
	-- 	end
	-- end
	
	for _,skillId in pairs(oldSpellsSkill) do
		self.role:DelSkill(skillId, 1)
	end
	for _,skillId in pairs(newSpellsSkill) do
		self.role:AddSkill(skillId, true, 1)
	end

	local msg = {
		ret = true,
		pos	= pos,
		useSpellsNo = newSpellsNo,
		spellsId = spellsId,
		spellsNo = oldSpellsNo,
		lock = lock,
		num = self.num,
		useSkillList = newSpellsSkill,
		oldSkillList = oldSpellsSkill,
	}

	return msg
end

function Fly:UpLevel()
	local data = self.cache
	local lvproConfig = server.configCenter.roleFlyupFlyupproConfig[data.lv]
	if not lvproConfig or not lvproConfig.cost then return {ret = false} end
	if data.xiuWei < lvproConfig.cost  then return {ret = false} end
	
	local oldAttrs = lvproConfig.attrpower
	
	data.lv = data.lv + 1
	local newSkill = server.configCenter.roleFlyupbaseConfig.openskilllv[data.lv] or 0
	if not newSkill or newSkill ~= 0 then
		data.skillList[#data.skillList + 1] = 1
		local attr = {}
		attr = self:AddSkillAttr(attr)
		self.role:UpdateBaseAttr({}, attr, server.baseConfig.AttrRecord.Fly)
	end
	-- if oldSkill ~= newSkill then
	-- 	if oldSkill ~= 0 then 
	-- 		self.role:DelSkill(oldSkill, 1)
	-- 	end
	-- 	if newSkill ~= 0 then 
	-- 		self.role:AddSkill(newSkill, true, 1)
	-- 	end
	-- end
	local newAttrs = server.configCenter.roleFlyupFlyupproConfig[data.lv].attrpower
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Fly)

	local msg = {
		ret = true,
		xiuWei = data.xiuWei,
		lv = data.lv,
		skillList = data.skillList,
	}
	return msg
end

function Fly:addXiuWei()
	local data = self.cache
	if data.exchangeCount >= 10 then
		return {ret = false}
	end
	data.exchangeCount = data.exchangeCount + 1
	data.xiuWei = data.xiuWei + 1000
	local msg = {
		ret = true,
		xiuWei = data.xiuWei,
	}
	return msg
end

function Fly:getExchangeCount()
	local msg = {
		ret = true,
		number = self.cache.exchangeCount,
	}
	return msg
end

function Fly:packSkillList()
	local skillList={}
	for i=1, 5, 1 do
		skillList[i] = self.cache.skillList[i] or 0
	end
	return skillList
end

server.playerCenter:SetEvent(Fly, "role.fly")
return Fly