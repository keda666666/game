local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"
local WeightData = require "WeightData"

local Pet = oo.class(LogicEntity)
local FLY_SKILL_TAIL = 1

function Pet:ctor(player)
end

function Pet:onCreate()
	self:onLoad()
end

function Pet:onLoad()
	self.cache = self.player.cache.pet
	for id, petinfo in pairs(self.cache.list) do
		local pBCfg = server.configCenter.petBiographyConfig[id]
		self:UpdateBaseAttr({}, pBCfg.attrs, server.baseConfig.AttrRecord.PetBase)
		local attrs = server.configCenter.petLvproConfig[pBCfg.rarity][petinfo.level].attrs
		self:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.PetBase)
		local petGiftproConfig = server.configCenter.petGiftproConfig[id]
		for i = 1, petinfo.giftlv - 1 do
			local cfg = petGiftproConfig[i]
			self:UpdateBaseAttr({}, EntityConfig:MultAttr(cfg.attrs, cfg.upnum), server.baseConfig.AttrRecord.PetGift)
		end
		if petGiftproConfig then
			local cfg = petGiftproConfig[petinfo.giftlv]
			self:UpdateBaseAttr({}, EntityConfig:MultAttr(cfg.attrs, petinfo.giftexp), server.baseConfig.AttrRecord.PetGift)
		end
	end
	self:OutBound(self.cache.outbound[1], self.cache.outbound[2], self.cache.outbound[3], self.cache.outbound[4])
	self:FlypetLoad()
end

function Pet:onInitClient()
	local petlist = {}
	for _, info in pairs(self.cache.list) do
		table.insert(petlist, info)
	end
	server.sendReq(self.player, "sc_pet_init", {
			list		= petlist,
			outbound	= self.cache.outbound,
		})
end

function Pet:onLogout()
end

function Pet:Active(id)
	local pBCfg = server.configCenter.petBiographyConfig[id]
	if not pBCfg or self.cache.list[id] then
		return { ret = false }
	end
	if self.player.bag:DelItemByID(pBCfg.material.id, pBCfg.material.count, server.baseConfig.YuanbaoRecordType.Pet)
		== ItemConfig.ItemChangeResult.DEL_FAILED then
		return { ret = false }
	end
	local buffs, bufftypes = {}, {}
	for _, v in ipairs(pBCfg.buffskill) do
		table.insert(buffs, v.id)
		table.insert(bufftypes, v.type)
	end
	local petinfo = {
		petid	= id,
		exp		= 0,
		level	= 1,
		name	= pBCfg.name,
		buffs	= buffs,
		bufftypes = bufftypes,
		giftexp	= 0,
		giftlv	= 1,
		xilian	= 0,
	}
	self.cache.list[id] = petinfo
	self:UpdateBaseAttr({}, pBCfg.attrs, server.baseConfig.AttrRecord.PetBase)
	local rarity = pBCfg.rarity
	local attrs = server.configCenter.petLvproConfig[rarity][petinfo.level].attrs
	self:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.PetBase)
	self.player.task:onEventCheck(server.taskConfig.ConditionType.PetActive)
	self.player.activityPlug:onDoTarget()
	return { ret = true }
end

function Pet:OutBound(first, second, third, four)
	local petlist = self.cache.list
	local outbound = {
		[1]		= first or 0,
		[2]		= second or 0,
		[3]		= third or 0,
		[4]		= four or 0,
	}
	local checks = {}
	for _, v in pairs(outbound) do
		if v > 0 then
			if checks[v] then
				lua_app.log_error("Pet:OutBound the same outbound", v)
				return
			end
			checks[v] = true
		end
	end
	self.cache.outbound = outbound
	for i = 1, 4 do
		self:ClearEntity(i)
		local id = outbound[i]
		if id and id ~= 0 then
			self:ResetOutbound(id)
		else
			self:ClearSkill(i)
			self:ClearBuff(i)
		end
	end
end

function Pet:AddExp(id, autobuy)
	local petinfo = self.cache.list[id]
	local rarity = server.configCenter.petBiographyConfig[id].rarity
	local oldlevel = petinfo.level
	local petLvproConfig = server.configCenter.petLvproConfig[rarity][oldlevel]
	local newcfg = server.configCenter.petLvproConfig[rarity][oldlevel + 1]
	if not newcfg then
		server.sendErr(self.player, "已经满级")
		return { ret = false }
	end
	if not self.player:PayRewardsByShop(petLvproConfig.cost, server.baseConfig.YuanbaoRecordType.Pet, "Pet:AddExp", autobuy) then
		server.sendErr(self.player, autobuy == 1 and "绑元不足" or autobuy == 2 and "元宝不足" or "升级材料不足")
		return { ret = false }
	end
	petinfo.exp = petinfo.exp + 1
	if petinfo.exp >= petLvproConfig.upnum then
		petinfo.exp = petinfo.exp - petLvproConfig.upnum
		petinfo.level = oldlevel + 1
		self:UpdateBaseAttr(petLvproConfig.attrs, newcfg.attrs, server.baseConfig.AttrRecord.PetBase)
	end
	self.player.task:onEventAdd(server.taskConfig.ConditionType.PetUpgrade)
	return {
		ret = true,
		exp = petinfo.exp,
		level = petinfo.level,
	}
end

function Pet:AddGift(id)
	local petinfo = self.cache.list[id]
	local oldlevel = petinfo.giftlv
	local petGiftproConfig = server.configCenter.petGiftproConfig[id][oldlevel]
	local newcfg = server.configCenter.petGiftproConfig[id][oldlevel + 1]
	if not newcfg or not self.player:PayRewards(petGiftproConfig.cost, server.baseConfig.YuanbaoRecordType.Pet) then
		return { ret = false }
	end
	petinfo.giftexp = petinfo.giftexp + 1
	self:UpdateBaseAttr({}, petGiftproConfig.attrs, server.baseConfig.AttrRecord.PetGift)
	if petinfo.giftexp >= petGiftproConfig.upnum then
		petinfo.giftexp = petinfo.giftexp - petGiftproConfig.upnum
		petinfo.giftlv = oldlevel + 1
	end
	return {
		ret = true,
		exp = petinfo.giftexp,
		level = petinfo.giftlv,
	}
end

function Pet:FlypetLoad()
	local petFlyproConfig = server.configCenter.petFlyproConfig
	for petid, petinfo in pairs(self.cache.list) do
		local petCfg = petFlyproConfig[petid]
		if self:IsFlyPet(petid) and petinfo.flydata then
			if petinfo.flydata.level > 0 then
				self:UpdateBaseAttr({}, petCfg[petinfo.flydata.level].attrs, server.baseConfig.AttrRecord.PetFly)
			end

			local level = petinfo.flydata.level
			for lv = 1, level do
				for count = 1, petCfg[level].upnum do
					self:UpdateBaseAttr({}, petCfg[lv].attr, server.baseConfig.AttrRecord.PetFly)
				end
			end

			local exp =  petinfo.flydata.exp
			for count = 1, exp do
				self:UpdateBaseAttr({}, petCfg[level+1].attr, server.baseConfig.AttrRecord.PetFly)
			end
		end
	end
end

--添加飞升经验
function Pet:AddFlyexp(petid, autobuy)
	if not self:CheckFlyAndInitFly(petid) then
		return false
	end
	local flydata = self.cache.list[petid].flydata
	local petFlyproConfig = server.configCenter.petFlyproConfig[petid]
	if flydata.level >= #petFlyproConfig then
		lua_app.log_info("AddFlyexp:Pet reach the maximum level.", flydata.level)
		return false
	end
	
	local flyCfg = server.configCenter.petFlyproConfig[petid][flydata.level+1]
	if not flyCfg or not self.player:PayRewards(flyCfg.cost, server.baseConfig.YuanbaoRecordType.Pet) then
		lua_app.log_info("AddFlyexp:PayRewards faild. autobuy:", autobuy)
		return false 
	end
--	local flyCfg = petFlyproConfig[flydata.level + 1]
--	if not self.player:PayRewardsByShop(flyCfg.cost, server.baseConfig.YuanbaoRecordType.Pet, "Pet:AddFlyexp", autobuy) then
--		lua_app.log_info("AddFlyexp:PayRewards faild. autobuy:", autobuy)
--		return false
--	end
	flydata.exp = flydata.exp + 1
	self:UpdateBaseAttr({}, flyCfg.attr, server.baseConfig.AttrRecord.PetFly)
	if flydata.exp == flyCfg.upnum then
		self:UpFlylevel(petid)
	end
	return true
end

function Pet:CheckFlyAndInitFly(petid)
	if not self:IsFlyPet(petid) then
		lua_app.log_info("CheckFlyAndInitFly:Pet the quality not fly.")
		return false
	end
	local pet = self.cache.list[petid]
	if not pet then
		lua_app.log_info("CheckFlyAndInitFly:Player does not have this pet", petid)
		return false
	end
	if pet.level < server.configCenter.petbaseConfig.needlevel then
		lua_app.log_info("CheckFlyAndInitFly:Pet level not enough fly.", pet.level, server.configCenter.petbaseConfig.needlevel)
		return false
	end
	pet.flydata = pet.flydata or {
		level = 0,
		exp = 0,
		flyskills = {},
		flybuffs = {},
	}
	return true
end

function Pet:IsFlyPet(petid)
	local flyCfg = server.configCenter.petFlyproConfig[petid]
	return (flyCfg and true or false)
end

function Pet:UpFlylevel(petid)                                                   
	local flydata = self.cache.list[petid].flydata
	local flylv = flydata.level + 1                                  
	flydata.level = flylv
	flydata.exp = 0

	local petFlyproConfig = server.configCenter.petFlyproConfig[petid]
	local oldattrs = petFlyproConfig[flylv - 1] and petFlyproConfig[flylv - 1].attrs or {}
	local newattrs = petFlyproConfig[flylv].attrs
	self:UpdateBaseAttr(oldattrs, newattrs, server.baseConfig.AttrRecord.PetFly)

	local mixtureCfg = petFlyproConfig[flylv].skill
--暂时注释
--	self:UnlockFlySkill(flydata, self:ExtractSkill(mixtureCfg))
--	self:UnlockFlyBuff(flydata, self:ExtractBuff(mixtureCfg))
	self:ResetOutbound(petid)
	self:SendSinglePetMsg(petid)
end

function Pet:ExtractSkill(skillcfg)
	local skills = {}
	for skillindex = 1, FLY_SKILL_TAIL do
		local skillid = skillcfg[skillindex]
		if skillid then
			table.insert(skills, skillid)
		end
	end
	return skills
end

function Pet:ExtractBuff(skillcfg)
	local buffs = {}
	for skillindex = FLY_SKILL_TAIL + 1, #skillcfg do
		local buffid = skillcfg[skillindex]
		if buffid then
			table.insert(buffs, buffid)
		end
	end
	return buffs
end

function Pet:RestoreFlypet(petid)
	if not self:CheckFlyAndInitFly(petid) then
		return
	end
	self:RestoreFlyExpend(petid)
	self:ResetFlyLevel(petid)
	self:SendSinglePetMsg(petid)
end

function Pet:RestoreFlyExpend(petid)
	local function _MultiplyCost(basecost, rate)
		local tmp = table.wcopy(basecost)
		for __,element in pairs(tmp) do
			element.count = math.floor(element.count*rate)
		end
		return tmp
	end

	local flydata = self.cache.list[petid].flydata
	local level = flydata.level
	local totalcost = {}
	local petFlyproConfig = server.configCenter.petFlyproConfig[petid]
	for lv = 1, level do
		local cost = _MultiplyCost(petFlyproConfig[lv].cost, petFlyproConfig[lv].upnum)
		table.insert(totalcost, cost)
	end

	local exp = flydata.exp
	if exp > 0 and petFlyproConfig[level + 1] then
		local cost = _MultiplyCost(petFlyproConfig[level + 1].cost, exp)
		table.insert(totalcost, cost)
	end

	totalcost = ItemConfig:MergeRewardsList(totalcost)
	local petbaseConfig = server.configCenter.petbaseConfig
	for __,element in pairs(totalcost) do
		if element.type == ItemConfig.AwardType.Numeric then
			element.count = math.floor(element.count * petbaseConfig.petflycoinRestore/100)
		elseif element.type == ItemConfig.AwardType.Item then
			element.count = math.floor(element.count * petbaseConfig.petflyitemRestore/100)
		else
			assert(false, "ItemConfig not have AwardType.")
		end
	end
	self.player:GiveRewardAsFullMailDefault(totalcost, "飞升重置", server.baseConfig.YuanbaoRecordType.Pet, "Flypet:Restore")	
end

function Pet:ResetFlyLevel(petid)
	local petCfg = server.configCenter.petFlyproConfig[petid]
	local flydata = self.cache.list[petid].flydata
	local level = flydata.level
	local levelattrs = petCfg[level] and petCfg[level].attr or {}
	self:UpdateBaseAttr(levelattrs, {}, server.baseConfig.AttrRecord.PetFly)

	for lv = 1, level do
		for count = 1, petCfg[lv].upnum do
			self:UpdateBaseAttr(petCfg[lv].attr, {}, server.baseConfig.AttrRecord.PetFly)
		end
	end

	local exp = flydata.exp
	if petCfg[level + 1] then
		for count = 1, exp do
			self:UpdateBaseAttr(petCfg[level + 1].attr, {}, server.baseConfig.AttrRecord.PetFly)
		end
	end
	flydata.level = 0
	flydata.exp = 0
	flydata.skills = {}
	flydata.buffs = {}
	self:ResetOutbound(petid)
end

function Pet:UnlockFlySkill(flydata, skilllist)
	for __, skillid in ipairs(skilllist) do
		if not flydata.skills[skillid] then
			table.insert(flydata.skills, skillid)
			flydata.skills[skillid] = #flydata.skills
		end
	end
end

function Pet:UnlockFlyBuff(flydata, bufflist)
	for __, buffid in ipairs(bufflist) do
		if not flydata.buffs[buffid] then
			table.insert(flydata.buffs, buffid)
			flydata.buffs[buffid] = #flydata.buffs
		end
	end
end

function Pet:ResetOutbound(petid)
	local pet = self.cache.list[petid]
	for i, outid in ipairs(self.cache.outbound) do
		if outid == petid then
			self:ClearBuff(i)
			self:ClearSkill(i)
			for _, buffid in ipairs(pet.buffs) do
				self:AddBuff(buffid, true, i)
			end

			local cfg = server.configCenter.petBiographyConfig[petid]
			for _, skillid in ipairs(cfg.skill) do
				self:AddSkill(skillid, true, i)
			end

			local flydata = pet.flydata or {}
			if flydata.buffs then
				for _, buffid in ipairs(flydata.buffs) do
					self:AddBuff(buffid, true, i)
				end
			end

			if flydata.skills and #flydata.skills > 0 then
				self:ClearSkill(i)
				for _, skillid in ipairs(flydata.skills) do
					self:AddSkill(skillid, true, i)
				end
			end
		end
	end
end

function Pet:SendSinglePetMsg(petid)
	local pet = self.cache.list[petid]
	server.sendReq(self.player, "sc_pet_update", {
			petinfo = pet
		})
end


function Pet:PackFlyAddexpReply(petid, ret)
	local flydata = self.cache.list[petid].flydata
	return {
		ret = ret,
		flyexp = flydata and flydata.exp or 0,
		flylevel = flydata and flydata.level or 0,
	}
end

function Pet:Rename(id, name)
	local petinfo = self.cache.list[id]
	if server.CheckName(name) ~= 0 then
		return { ret = false }
	end
	petinfo.name = name
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
function Pet:RefreshSkill(id, ttype, locklist, autobuy)
	local petinfo = self.cache.list[id]
	local quality = server.configCenter.petBiographyConfig[id].quality
	local petFreshSkillConfig = server.configCenter.petFreshSkillConfig[quality]
	local typeconfig = server.configCenter.petbaseConfig.freshitemid[ttype+1]
	local newxilian = petinfo.xilian + typeconfig.value
	for _, v in pairs(petFreshSkillConfig) do
		if v.freshtimes[1] <= newxilian and (not v.freshtimes[2] or v.freshtimes[2] >= newxilian) then
			locklist = locklist or {}
			local locklength = #locklist
			local freshMoney = server.configCenter.petbaseConfig.freshMoney
			if locklength > 0 and (not freshMoney[locklength] or not self.player:CheckYuanbao(freshMoney[locklength])) then
				return { ret = false }
			end
			if not self.player:PayRewardByShop(ItemConfig.AwardType.Item, typeconfig.itemId, 1, server.baseConfig.YuanbaoRecordType.Pet, "Pet:RefreshSkill:" .. ttype, autobuy) then
				return { ret = false }
			end
			if locklength > 0 then
				self.player:PayYuanBao(freshMoney[locklength], server.baseConfig.YuanbaoRecordType.Pet)
			end
			petinfo.xilian = newxilian
			local PetDropTableConfig = server.configCenter.PetDropTableConfig
			local bufftypes = {}
			local buffs = {}
			local length = #petinfo.buffs
			local list = _GetRandTables(v.success, #petinfo.buffs)
			for _, i in ipairs(locklist) do
				local btype = petinfo.bufftypes[i+1]
				for ii, vv in ipairs(list) do
					if vv.type == btype then
						table.remove(list, ii)
						break
					end
				end
			end
			for i = 1, length - locklength do
				local stb = PetDropTableConfig[list[i].id]
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
					lua_app.log_error("Pet:RefreshSkill no insert buff", list[i].id, rd)
					-- return { ret = false }
				end
			end
			-- petinfo.xilianSkills = buffs
			-- petinfo.xiliantypes = bufftypes
			-- petinfo.xilianlocks = locklist
			local locks = {}
			if locklist then
				for _, i in ipairs(locklist) do
					locks[i+1] = true
				end
			end
			local ii = 1
			petinfo.xilianSkills = {}
			petinfo.xiliantypes = {}
			for i = 1, #petinfo.buffs do
				if locks[i] then
					petinfo.xilianSkills[i] = petinfo.buffs[i]
					petinfo.xiliantypes[i] = petinfo.bufftypes[i]
				else
					petinfo.xilianSkills[i] = buffs[ii]
					petinfo.xiliantypes[i] = bufftypes[ii]
					ii = ii + 1
				end
			end
			return {
				ret = true,
				xilian = petinfo.xilian,
				xilianSkills = petinfo.xilianSkills,
			}
		end
	end
	return { ret = false }
end

function Pet:SetSkillIn(id)
	local petinfo = self.cache.list[id]
	if not petinfo.xilianSkills then return { ret = false } end
	-- local locks = {}
	-- if petinfo.xilianlocks then
	-- 	for _, i in ipairs(petinfo.xilianlocks) do
	-- 		locks[i] = true
	-- 	end
	-- end
	-- local ii = 1
	-- for i = 1, #petinfo.buffs do
	-- 	if not locks[i] then
	-- 		petinfo.buffs[i] = petinfo.xilianSkills[ii]
	-- 		petinfo.bufftypes[i] = petinfo.xiliantypes[ii]
	-- 		ii = ii + 1
	-- 	end
	-- end
	petinfo.buffs = petinfo.xilianSkills
	petinfo.bufftypes = petinfo.xiliantypes
	petinfo.xilianSkills = nil
	petinfo.xiliantypes = nil
	-- petinfo.xilianlocks = nil

	for i, outid in ipairs(self.cache.outbound) do
		-- 如果洗的是出战的宠物需要重置一下buff
		if outid == id then
			self:ClearBuff(i)
			for _, buffid in ipairs(petinfo.buffs) do
				self:AddBuff(buffid, true, i)
			end
		end
	end

	return {
		ret = true,
		buffs = petinfo.buffs,
	}
end

function Pet:PetCount()
	local count = 0
	for k,v in pairs(self.cache.list) do
		count = count + 1
	end
	return count
end

server.playerCenter:SetEvent(Pet, "pet")
return Pet