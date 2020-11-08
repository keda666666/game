local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"
local WeightData = require "WeightData"
local _Boy = 1
local _Girl = 2
local _NotActive = 3

local Baby = oo.class(LogicEntity)

function Baby:ctor(player)
end

function Baby:onCreate()
	self:onLoad()
end

function Baby:onLoad()
	self.cache = self.player.cache.baby
	if self.cache.sex == _Boy or self.cache.sex == _Girl then
		self:Init()
	end
end

function Baby:onLevelUp()--(oldlevel, newlevel)
	if not server.funcOpen:Check(self.player, 116) then
		return
	end
	if self.cache.sex == 0 then
		self:open()
	end
end

function Baby:onInitClient()
	--检测是否能开启
	self:onLevelUp()

	if self.cache.sex > 0 then
		self:SendInfo()
	end
end

function Baby:onLogout()
end

function Baby:Init()
	local babyTalentCfg = server.configCenter.BabyTalentConfig[self.cache.sex]
	for i = 1, self.cache.giftlv - 1 do
		local cfg = babyTalentCfg[i]
		for c = 1, cfg.upnum do
			self:UpdateBaseAttr({}, cfg.attrs, server.baseConfig.AttrRecord.BabyBase)
		end
	end

	for c = 1, self.cache.giftexp do
		self:UpdateBaseAttr({}, babyTalentCfg[self.cache.giftlv].attrs, server.baseConfig.AttrRecord.BabyGift)
	end

	local ActCfg = server.configCenter.BabyActivationConfig[self.cache.sex]
	for _, skillid in ipairs(ActCfg.skill) do
		self:AddSkill(skillid, true)
	end
	for _, buffid in ipairs(self.cache.buffs) do
		self:AddBuff(buffid, true)
	end
end

function Baby:SendInfo()
	server.sendReq(self.player, "sc_baby_init", {
			name = self.cache.name,	
			buffs = self.cache.buffs,
			giftexp = self.cache.giftexp,	
			giftlv = self.cache.giftlv,
			xilian = self.cache.xilian,
			xilianSkills = self.cache.xilianSkills,
			sex = self.cache.sex,
			open = self.cache.open,
		})
end

-- function Baby:Active(sex)
--开启
function Baby:open()
	self.cache.sex = _NotActive
	self.babyPlug:OpenTemplate()
	self:SendInfo()
end

--激活
function Baby:Active(sex)
	if not server.funcOpen:Check(self.player, 116) then
		server.sendErr(self.player, "功能尚未开启")
		return {ret = false}
	end
	if sex ~= _Boy and sex ~= _Girl then
		return {ret = false}
	end

	if self.cache.sex ~= _NotActive then
	self.cache.sex = _NotActive
	self.babyPlug:OpenTemplate()
	self:SendInfo()
	end

	if not self.cache.open or self.cache.open ~= 1 then
		return {ret = false}
	end

	local ActCfg = server.configCenter.BabyActivationConfig[sex]
	-- if self.player.bag:DelItemByID(ActCfg.material.id, ActCfg.material.count, server.baseConfig.YuanbaoRecordType.Baby)
	-- 	== ItemConfig.ItemChangeResult.DEL_FAILED then
	-- 	return { ret = false }
	-- end
	local buffs, bufftypes = {}, {}
	local skillnum = server.configCenter.BabyBasisConfig.openSkill2[self.cache.baby_data.lv]
	for i=1,skillnum do
		local buffskill = ActCfg.buffskill[i]
		table.insert(buffs, buffskill.id)
		table.insert(bufftypes, buffskill.type)
	end

	self.cache.sex = sex
	self.cache.name	= ActCfg.name
	self.cache.buffs = buffs
	self.cache.bufftypes = bufftypes
	self.cache.giftexp = 0
	self.cache.giftlv = 1
	self.cache.xilian = 0

	self:Init()
	self:SendInfo()
	--完成阵位↓
	self.player.position:AddClearNum(4)

	return {ret = true}
end
-- 当进阶的时候
function Baby:OnUpLv()
	if self.cache.sex ~= _Boy and self.cache.sex ~= _Girl then
		return
	end
	local skillnum = server.configCenter.BabyBasisConfig.openSkill2[self.cache.baby_data.lv]
	local currnum = #self.cache.buffs
	if skillnum > currnum then
		local ActCfg = server.configCenter.BabyActivationConfig[self.cache.sex]
		for i=currnum+1,skillnum do
			local buffskill = ActCfg.buffskill[i]
			table.insert(self.cache.buffs, buffskill.id)
			table.insert(self.cache.bufftypes, buffskill.type)
		end
		self:SendInfo()
	end
end

-- 天赋
function Baby:AddGift()
	if self.cache.sex ~= _Boy and self.cache.sex ~= _Girl then
		return {ret = false}
	end
	local oldlevel = self.cache.giftlv
	local babyTalentCfg = server.configCenter.BabyTalentConfig[self.cache.sex][oldlevel]
	local newcfg = server.configCenter.BabyTalentConfig[self.cache.sex][oldlevel + 1]
	if not newcfg or not self.player:PayRewards(babyTalentCfg.cost, server.baseConfig.YuanbaoRecordType.Baby) then
		return { ret = false }
	end
	self.cache.giftexp = self.cache.giftexp + 1
	self:UpdateBaseAttr({}, babyTalentCfg.attrs, server.baseConfig.AttrRecord.BabyGift)
	if self.cache.giftexp >= babyTalentCfg.upnum then
		self.cache.giftexp = self.cache.giftexp - babyTalentCfg.upnum
		self.cache.giftlv = oldlevel + 1
	end
	return {
		ret = true,
		exp = self.cache.giftexp,
		level = self.cache.giftlv,
	}
end

function Baby:Rename(name)
	if server.CheckName(name) ~= 0 then
		return { ret = false }
	end
	self.cache.name = name
	return { ret = true, name = name }
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
function Baby:RefreshSkill(ttype, locklist, autobuy)
	local babyFreshSkillConfig = server.configCenter.BabyFreshSkillConfig
	local typeconfig = server.configCenter.BabyBasisConfig.freshitemid[ttype+1]
	local newxilian = self.cache.xilian + typeconfig.value
	for _, v in pairs(babyFreshSkillConfig) do
		if v.freshtimes[1] <= newxilian and (not v.freshtimes[2] or v.freshtimes[2] >= newxilian) then
			locklist = locklist or {}
			local locklength = #locklist
			local freshMoney = server.configCenter.BabyBasisConfig.freshMoney
			if locklength > 0 and (not freshMoney[locklength] or not self.player:CheckYuanbao(freshMoney[locklength])) then
				return { ret = false }
			end
			if not self.player:PayRewardByShop(ItemConfig.AwardType.Item, typeconfig.itemId, 1, server.baseConfig.YuanbaoRecordType.Baby, nil, autobuy) then
				return { ret = false }
			end
			if locklength > 0 then
				self.player:PayYuanBao(freshMoney[locklength], server.baseConfig.YuanbaoRecordType.Baby)
			end
			self.cache.xilian = newxilian
			local BabyDropTableConfig = server.configCenter.BabyDropTableConfig
			local bufftypes = {}
			local buffs = {}
			local length = #self.cache.buffs
			local list = _GetRandTables(v.success, #self.cache.buffs)
			for _, i in ipairs(locklist) do
				local btype = self.cache.bufftypes[i+1]
				for ii, vv in ipairs(list) do
					if vv.type == btype then
						table.remove(list, ii)
						break
					end
				end
			end
			for i = 1, length - locklength do
				local stb = BabyDropTableConfig[list[i].id]
				local rd = math.random(1, 10000)
				local right = false
				for _, vv in ipairs(stb.table) do
					if vv.rate < rd then
						rd = rd - vv.rate
					else
						table.insert(bufftypes, list[i].type)
						table.insert(buffs, vv.id)
						right = true
						break
					end
				end
				if not right then
					lua_app.log_error("Baby:RefreshSkill no insert buff", list[i].id, rd)
					-- return { ret = false }
				end
			end
			local locks = {}
			if locklist then
				for _, i in ipairs(locklist) do
					locks[i+1] = true
				end
			end
			local ii = 1
			self.cache.xilianSkills = {}
			self.cache.xiliantypes = {}
			for i = 1, #self.cache.buffs do
				if locks[i] then
					self.cache.xilianSkills[i] = self.cache.buffs[i]
					self.cache.xiliantypes[i] = self.cache.bufftypes[i]
				else
					self.cache.xilianSkills[i] = buffs[ii]
					self.cache.xiliantypes[i] = bufftypes[ii]
					ii = ii + 1
				end
			end
			return {
				ret = true,
				xilian = self.cache.xilian,
				xilianSkills = self.cache.xilianSkills,
			}
		end
	end
	return { ret = false }
end

function Baby:SetSkillIn()
	if not self.cache.xilianSkills then return { ret = false } end
	self.cache.buffs = self.cache.xilianSkills
	self.cache.bufftypes = self.cache.xiliantypes
	self.cache.xilianSkills = nil
	self.cache.xiliantypes = nil
	self:ClearBuff()
	for _, buffid in ipairs(self.cache.buffs) do
		self:AddBuff(buffid, true)
	end
	return {
		ret = true,
		buffs = self.cache.buffs,
	}
end

server.playerCenter:SetEvent(Baby, "baby")
return Baby