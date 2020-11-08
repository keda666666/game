local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local WeightData = require "WeightData"

local SpellsRes = oo.class()

function SpellsRes:ctor(role)
	self.role = role
	self.player = role.player
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.SpellsRes
end

function SpellsRes:onCreate()
	self:onLoad()
end

function SpellsRes:onLoad()
	self.cache = self.role.cache.spells_res
	local num = 0
	for k,v in pairs(self.cache.spellsList) do num = num + 1 end
	self.num = num
	local allattr = self:Allattr()
	self.role:UpdateBaseAttr({}, allattr, server.baseConfig.AttrRecord.SpellsRes)
end

function SpellsRes:Allattr()
	local attrs = {}
	for _,v in pairs(self.cache.useSpells) do
		if v.spellsNo ~= 0 then

			local data = self:GetSpellsResLvproConfig(v.spellsNo, v.lv)
			for _,vv in pairs(data.attrs) do
				table.insert(attrs, vv)
			end
			-- if data.skillid then
			-- 	self.player.role:AddSkill(data.skillid, true, 1)
			-- end
			if v.skillList then
				for _,skillId in pairs(v.skillList) do
					self.role:AddSkill(skillId, true, 1)
				end
			end
		end
	end
	return attrs
end

function SpellsRes:onLevelUp(oldlevel, level)
	local baseConfig = self:GetSpellsResBaseConfig("unlocklv")
	self:IsOpen(oldlevel, level, baseConfig)
end

function SpellsRes:onVipLevelUp(oldlevel, level)
	local baseConfig = self:GetSpellsResBaseConfig("unlockvip")
	self:IsOpen(oldlevel, level, baseConfig)
end

function SpellsRes:IsOpen(oldlevel, level, baseConfig)
	for i = oldlevel + 1, level do
		local open = baseConfig[i]
		if open then
			if open > #self.cache.useSpells then
				for i=1 ,open - #self.cache.useSpells do
					table.insert(self.cache.useSpells,{
										lv = 1,
										lock = 0,
										spellsNo = 0,
									})
					local msg = self:packSpellsData()
					server.sendReq(self.player, "sc_spellsRes_info", msg)
				end
			end
		end
	end
end

function SpellsRes:onInitClient()
	--登录发送协议
	local msg = self:packSpellsData()
	server.sendReq(self.player, "sc_spellsRes_info", msg)
end

-- local configData = {
-- 	server.configCenter.SpellsResMakeConfig
-- }

function SpellsRes:packSpellsData()
	local spellsList = {}
	for k,v in pairs(self.cache.spellsList) do
		self:AssertSkillList(v)
		table.insert(spellsList, {spellsId = k, spellsNo = v.spellsNo, lock = v.lock, skillList = v.skillList or {}})
	end
	for _,v in pairs(self.cache.useSpells) do
		if v.spellsNo ~= 0 then
			self:AssertSkillList(v)
		end
	end
	local msg = {
		useSpells = self.cache.useSpells,
		spellsList = spellsList,
		num = self.num,
		perfectNum = self.cache.perfectNum
	}
	return msg
end

local _spellsResMakeConfig = false
function SpellsRes:GetSpellsResMakeConfig(no)
	if _spellsResMakeConfig then return _spellsResMakeConfig[no] end
	_spellsResMakeConfig = server.configCenter.SpellsResMakeConfig
	return _spellsResMakeConfig[no]
end

local _spellsResBaseConfig = false
function SpellsRes:GetSpellsResBaseConfig(key)
	if _spellsResBaseConfig then return _spellsResBaseConfig[key] end
	_spellsResBaseConfig = server.configCenter.SpellsResBaseConfig
	return _spellsResBaseConfig[key]
end

local _spellsResLvproConfig = false
function SpellsRes:GetSpellsResLvproConfig(key1,key2)
	if _spellsResLvproConfig then return _spellsResLvproConfig[key1][key2] end
	_spellsResLvproConfig = server.configCenter.SpellsResLvproConfig
	return _spellsResLvproConfig[key1][key2]
end

local _spellsResDecomposeConfig = false
function SpellsRes:GetSpellsResDecomposeConfig()
	if _spellsResDecomposeConfig then return _spellsResDecomposeConfig end
	_spellsResDecomposeConfig = server.configCenter.SpellsResDecomposeConfig
	return _spellsResDecomposeConfig
end

local _spellsResListConfig = false
function SpellsRes:GetSpellsResListConfig()
	if _spellsResListConfig then return _spellsResListConfig end
	_spellsResListConfig = server.configCenter.SpellsResListConfig
	return _spellsResListConfig
end

function SpellsRes:AssertSkillList(spellData)
	if not spellData.skillList then
		local spellCfg = self:GetSpellsResLvproConfig(spellData.spellsNo, spellData.lv or 1)
		spellData.skillList = spellCfg and spellCfg.skillid and {spellCfg.skillid} or {}
	end
end

function SpellsRes:Make(makeType, autoBuy)
	if makeType == 3 then return {ret = false} end
	local perfectNum = self.cache.perfectNum
	if makeType == 2 then
		
		if perfectNum == self:GetSpellsResBaseConfig("perfectnum") then
			self.cache.perfectNum = 0
			makeType = 3
		end
	end
	local makeConfig = self:GetSpellsResMakeConfig(makeType)
	if not makeConfig then return {ret = false} end
	if makeType == 1 then 
		if not self.player:PayRewards(makeConfig.cost, self.YuanbaoRecordType) then return {ret = false} end
	else
		if not self.player:PayRewardsByShop(makeConfig.cost, self.YuanbaoRecordType, nil, autoBuy) then return {ret = false} end
		if makeType == 2 then 
			self.cache.perfectNum = perfectNum + 1
		end
	end
	local data = makeConfig

	local rd = math.random(1, 10000)
	for _, vv in ipairs(makeConfig.success) do
		if vv.rate < rd then
			rd = rd - vv.rate
		else
			local key = self.cache.key
			self.cache.spellsList[key] = {spellsNo = vv.id, lock = 0}
			self.num = self.num + 1
			--
			--随机技能
			local skillList = self:GetSkillList(vv.id)
			self.cache.spellsList[key].skillList = skillList
			--
			local msg = {ret = true,
				spellsId = key,
				spellsNo = vv.id,
				num = self.num,
				perfectNum = self.cache.perfectNum,
				skillList = skillList,
			}
			self.cache.key = key + 1

			local SpellsResBaseConfig = server.configCenter.SpellsResBaseConfig
			local skillnum = #skillList
			if skillnum >= SpellsResBaseConfig.skillnum then
				server.chatCenter:ChatLink(42, nil, nil, self.player.cache.name, skillnum, ItemConfig:ConverLinkTextSpells(vv.id, table.unpack(skillList)))
			end
			return msg
		end
	end
	return {ret = false}
end

local _RandomSkillTable = {}
local function _GetRandTables(pools, num)
	local wd = _RandomSkillTable[pools]
	if not wd then
		wd = WeightData.new()
		for _, v in ipairs(pools) do
			wd:Add(v.rate, v)
		end
		_RandomSkillTable[pools] = wd
	end
	return wd:GetRandomCounts(num)
end

function SpellsRes:GetSkillList(id, makeType)
	local listConfig = self:GetSpellsResListConfig()
	-- local makeConfig = self:GetSpellsResMakeConfig(makeType)

	local rand = math.random(100)
	for k,v in pairs(listConfig[id].fbnumrat) do
		if rand > v then
			rand = rand - v
		else
			if k == 0 then return {} end
			local skillList = {}
			local skillConfig = _GetRandTables(listConfig[id].fbskill, k)
			for k,v in pairs(skillConfig) do
				table.insert(skillList, v.id)
			end
			return skillList
		end
	end
	return {}
end

function SpellsRes:Use(pos, spellsId)
	local data = self.cache.useSpells[pos]
	if not data then return {ret = false} end
	local spellsData = self.cache.spellsList[spellsId]
	if not spellsData then return {ret = false} end
	local oldSpellsNo = data.spellsNo
	local newSpellsNo = spellsData.spellsNo
	local oldSpellsSkill = data.skillList or {}
	local newSpellsSkill = spellsData.skillList or {}

	local listConfig = self:GetSpellsResListConfig()
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
	-- local newSkill = self:GetSpellsResLvproConfig(newSpellsNo, data.lv).skillid or 0
	if oldSpellsNo ~= 0 then
		spellsData.spellsNo = oldSpellsNo
		spellsData.lock = lock
		spellsData.skillList = oldSpellsSkill
		-- oldSkill = self:GetSpellsResLvproConfig(oldSpellsNo, data.lv).skillid or oldSkill
		-- oldAttrs = self:GetSpellsResListConfig(oldSpellsNo).attrs or {}
		oldAttrs = self:GetSpellsResLvproConfig(oldSpellsNo, data.lv).attrs
	else
		self.cache.spellsList[spellsId] = nil
	end
	local newAttrs = self:GetSpellsResLvproConfig(newSpellsNo, data.lv).attrs

	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.SpellsRes)
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

function SpellsRes:UpLevel(pos, autoBuy)
	local data = self.cache.useSpells[pos]
	if not data then return {ret = false} end
	local spellsNo = data.spellsNo
	if not data or spellsNo == 0 then return {ret = false} end
	local lvproConfig = self:GetSpellsResLvproConfig(spellsNo, data.lv)
	if not lvproConfig or not lvproConfig.cost then return {ret = false} end
	if not self.player:PayRewardsByShop({lvproConfig.cost}, self.YuanbaoRecordType, nil, autoBuy) then return {ret = false} end
	
	-- local oldSkill = lvproConfig.skillid or 0
	local oldAttrs = self:GetSpellsResLvproConfig(spellsNo, data.lv).attrs
	
	data.lv = data.lv + 1
	-- local newSkill = self:GetSpellsResLvproConfig(spellsNo, data.lv).skillid or 0
	-- if oldSkill ~= newSkill then
	-- 	if oldSkill ~= 0 then 
	-- 		self.role:DelSkill(oldSkill, 1)
	-- 	end
	-- 	if newSkill ~= 0 then 
	-- 		self.role:AddSkill(newSkill, true, 1)
	-- 	end
	-- end
	local newAttrs = self:GetSpellsResLvproConfig(spellsNo, data.lv).attrs
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.SpellsRes)

	local msg = {
		ret = true,
		pos = pos,
		lv = data.lv,
	}
	return msg
end

function SpellsRes:Lock(spellsId, lock)
	local data = self.cache.spellsList[spellsId]
	if not data then return {ret = false} end
	if lock == 0 then
		data.lock = 0
	else
		data.lock = 1
	end
	return {ret = true, spellsId = spellsId, lock = data.lock}
end

function SpellsRes:Smelt(spellsIdList)
	if not spellsIdList then return {ret = false} end
	local decomposeConfig = self:GetSpellsResDecomposeConfig()
	local count = 0
	local num = 0
	local smeltList = {}
	for _,spellsId in pairs(spellsIdList) do
		local data = self.cache.spellsList[spellsId]
		if data and data.lock == 0 then
			num = num + 1
			self.cache.spellsList[spellsId] = nil
			count = count + decomposeConfig[data.spellsNo].count
			 table.insert(smeltList,spellsId)
		end
	end
	if num ~=0 then
		self.num = self.num - num
	end
	if count ~= 0 then 
		local itemId = self:GetSpellsResBaseConfig("itemid")
		self.player:GiveReward(ItemConfig.AwardType.Item, itemId, count, 1, self.YuanbaoRecordType)
	end

	return {num = self.num, spellsIdList = smeltList}
end

function SpellsRes:GetPosData(pos)
	local data = self.cache.useSpells[pos]
	if not data then return {} end
	return {lv = data.lv, spellsNo = data.spellsNo}
end

function SpellsRes:GetSkillPower()
	local power = 0
	for _,v in pairs(self.cache.useSpells) do
		if v.spellsNo ~= 0 then
			if v.skillList then
				for _, skillId in pairs(v.skillList) do
					local SkillsConfig = server.configCenter.SkillsConfig[skillId]
					if SkillsConfig and SkillsConfig.skillpower then
						power = power + SkillsConfig.skillpower
					end
				end
			end
		end
	end
	return power
end

server.playerCenter:SetEvent(SpellsRes, "role.spellsRes")
return SpellsRes