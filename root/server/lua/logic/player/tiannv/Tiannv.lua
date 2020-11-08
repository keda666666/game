local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"
local WeightData = require "WeightData"

local Tiannv = oo.class(LogicEntity)

function Tiannv:ctor(player)
	local femaleDevaBaseConfig = server.configCenter.FemaleDevaBaseConfig
	-- FightConfig.FightStatus.Running
	-- self.skilllist = {{[3] = {11001}}}
	-- self:AddSkill(11001, true, 1)
	self.hskillNo = femaleDevaBaseConfig.hskill
	self.player = player
end

function Tiannv:onCreate()
	self:onLoad()
end

function Tiannv:onLoad()
	self.cache = self.player.cache.tiannv
	if #self.cache.attrdatas.attrs < 1 then return end
	local baseConfig = server.configCenter.FemaleDevaBaseConfig
	self:AddSkill(baseConfig.skill, true, 1)
	self:AddSkill(baseConfig.hskill, true, 1)
	local allattr = self:Allattr()
	self:UpdateBaseAttr({}, allattr, server.baseConfig.AttrRecord.Tiannv)
end

function Tiannv:Allattr()
	local attrs = {}
	local attrsConfig = server.configCenter.FemaleDevaSkillAttrsConfig
	
	for _,v in pairs(self.cache.attrdatas.attrs) do
		for k1,v1 in pairs(v.attrs) do
			if v1.type == 1 then
				local attr = attrsConfig[v1.attrs]
				if attr then
					table.insert(attrs,attr.attrs)
				end
			elseif v1.type == 2 then
				self:AddBuff(v1.skillNo, true, 1)
			end
		end
	end
	return attrs
end

function Tiannv:onLevelUp(oldlevel,level)
	local lv = server.configCenter.FuncOpenConfig[19].conditionnum
	if #self.cache.attrdatas.attrs > 0 then return end
	if lv <= level then
		self:Open(1)
	end
end

function Tiannv:onVipLevelUp(oldlevel, level)
	local lv = server.configCenter.FuncOpenConfig[19].conditionnum2
	if #self.cache.attrdatas.attrs > 0 then return end
	if lv <= level then
		self:Open(1)
	end
end

function Tiannv:onInitClient()
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_tiannv_equip", msg)
end

function Tiannv:onLogout()
end

function Tiannv:Open(pos)
	local femaleDevaMagicConfig = server.configCenter.FemaleDevaMagicConfig[pos]
	if not femaleDevaMagicConfig then return end
	local data = {attrs={}}
	for _,v in pairs(femaleDevaMagicConfig.attrs) do
		if v < 10000 then
			table.insert(data.attrs, {type = 1, quality = 1, attrs = v})
			-- data={type = 1, attrs = v.value}
		else
			table.insert(data.attrs,{type = 2, quality = 1, skillNo = v})--v.skill})
			-- data={type = 2, skillNo = v.value}
		end
	end
	data.washNum = 0
	self.cache.attrdatas.attrs[pos] = data
	self.cache.refreshattr[pos] = {}
	
	if pos == 1 then
		local baseConfig = server.configCenter.FemaleDevaBaseConfig
		self:AddSkill(baseConfig.skill, true, 1)
		self:AddSkill(baseConfig.hskill, true, 1)
	end
	local newAttrs, newSkillNo = self:ProcessingAttr(data.attrs)
	if newSkillNo ~= 0 then
		self:AddSkill(newSkillNo, true, 1)
	end
	self:UpdateBaseAttr({}, newAttrs, server.baseConfig.AttrRecord.Tiannv)

	--完成阵位↓
	self.player.position:AddClearNum(3)

	local msg = self:packInfo()
	server.sendReq(self.player, "sc_tiannv_equip", msg)
end

function Tiannv:Wash(pos, washType, locklist)
	local data = self.cache.attrdatas.attrs[pos]
	local locklist = locklist or {}
	if not data then return end
	local props = server.configCenter.FemaleDevaBaseConfig.freshitemid[washType]
	local freshMoney = server.configCenter.FemaleDevaBaseConfig.freshMoney

	local cash = freshMoney[#locklist] or 0
	if not cash or ( cash < 0 or not self.player:CheckYuanbao(cash)) then
		return
	end
	if not self.player:PayRewardByShop(ItemConfig.AwardType.Item, props.itemId, 1, server.baseConfig.YuanbaoRecordType.TianNv, "tiannv wash"..washType) then
		return
	end
	if cash > 0 then
		self.player:PayYuanBao(cash, server.baseConfig.YuanbaoRecordType.TianNv)
	end
	local washNum = (data.washNum or 0) + props.value
	self.cache.attrdatas.attrs[pos].washNum = washNum
	-- if not self.player:PayRewards(propsList, server.baseConfig.YuanbaoRecordType.TianNv) then return end
	local femaleDevaDropConfig = server.configCenter.FemaleDevaDropConfig
	local data1
	local data2
	for _,v in pairs(femaleDevaDropConfig[1]) do
		if v.freshtimes[1] <= washNum and (not v.freshtimes[2] or v.freshtimes[2] >= washNum) then
			data1 = v.success
			break
		end
	end
	local femaleDevaDropData
	if props.value == 10 then
		femaleDevaDropData = femaleDevaDropConfig[2]
	else
		femaleDevaDropData = femaleDevaDropConfig[3]
	end
	for _,v in pairs(femaleDevaDropData) do
		if v.freshtimes[1] <= washNum and (not v.freshtimes[2] or v.freshtimes[2] >= washNum) then
			data2 = v.success

			break
		end
	end
	if not data1 or not data2 then return end
	local attrsData = self:RandomAttrs(data1, data2)
	if #attrsData ~= 4 then return end
	local newAttrs={}
	local attrsConfig = server.configCenter.FemaleDevaSkillAttrsConfig
	for k,v in pairs(attrsData) do
		if v < 10000 then
			table.insert(newAttrs,{type = 1, quality = attrsConfig[v].quality, attrs =v })--attrsConfig[v].attrs})
		else
			local data = server.configCenter.EffectsConfig[v]
			table.insert(newAttrs,{type = 2, quality = data.quality, skillNo = v})
			
		end
	end

	for _,v in pairs(locklist) do
		newAttrs[v] = data.attrs[v]
	end
	self.cache.refreshattr[pos] = newAttrs
	self:newEquip(pos, 2)
	local msg = self:packEquip(pos)
	server.sendReq(self.player, "sc_tiannv_wash_res", msg)
end

function Tiannv:WashCover(pos)
	local data = {attrs={}}
	data.attrs = self.cache.refreshattr[pos]
	if #data.attrs == 0 then return end
	local oldattrs = self.cache.attrdatas.attrs[pos]
	data.washNum = oldattrs.washNum
	self.cache.attrdatas.attrs[pos] = data
	self.cache.refreshattr[pos] = {}
	local oldAttrs, oldSkillNo = self:ProcessingAttr(oldattrs.attrs)
	local newAttrs, newSkillNo = self:ProcessingAttr(data.attrs)
	self:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Tiannv)
	if oldAttrs ~= newAttrs then
		if oldSkillNo ~= 0 then
			self:DelBuff(oldSkillNo, 1)
		end
		if newSkillNo ~= 0 then
			self:AddBuff(newSkillNo, true, 1)
		end
	end
	self:newEquip(pos, 1)
	local msg = self:packEquip(pos)
	server.sendReq(self.player, "sc_tiannv_wash_replace_res", msg)
end

function Tiannv:newEquip(pos, typ)
	if self.cache.attrdatas.attrs[pos+1] then return end
	local femaleDevaMagicConfig = server.configCenter.FemaleDevaMagicConfig[pos]
	local unlock = femaleDevaMagicConfig.unlock

	if not unlock then return end
	if unlock.type ~= typ then return end
	local mark = 0
	if typ == 1 then
		for _,v in pairs(self.cache.attrdatas.attrs[pos].attrs) do
			if v.quality >= unlock.quality then 
				mark = mark + 1
			end
		end
	elseif typ == 2 then
		mark = self.cache.attrdatas.attrs[pos].washNum
	end
	if mark >= unlock.count then
		self:Open(pos + 1)
	end
end

function Tiannv:ProcessingAttr(attrData)
	local data = {}
	local skillNo = 0
	local quality = 0
	local attrsConfig = server.configCenter.FemaleDevaSkillAttrsConfig
	for _,v in pairs(attrData) do
		if type(v) == "table" then
			if v.type == 1 then
				if attrsConfig[v.attrs] then
					local attrs = table.wcopy(attrsConfig[v.attrs].attrs)
					table.insert(data, attrs)
				end
			else
				skillNo = v.skillNo
			end
		end
	end
	return data, skillNo
end

function Tiannv:packEquip(pos)
	local msg = {
		pos = pos,
		washNum = self.cache.attrdatas.attrs[pos].washNum,
		attrData = self.cache.attrdatas.attrs[pos].attrs,
		washData = self.cache.refreshattr[pos],
	}
	return msg
end

function Tiannv:packInfo()
	local msg = {data = {}}
	for k,v in pairs(self.cache.attrdatas.attrs) do
		table.insert(msg.data, {
			washNum = v.washNum,
			attrData = v.attrs,
			washData = self.cache.refreshattr[k],
		})

	end
	return msg
end

-- function Tiannv:packAttrs(data)
-- 	local msg = {}
-- 	for k,v in pairs(data) do
-- 		if 
-- 		table.insert(msg,{})
-- 	end

-- end

-- function Tiannv:packWash(data)
-- end


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

function Tiannv:RandomAttrs(data1, data2)
	local list = {}
	for i=1, 3 do
		table.insert(list ,_GetRandTables(data1, 1)[1])
	end
	table.insert(list ,_GetRandTables(data2, 1)[1])
	local attrsList = {}
	local data3 = server.configCenter.FreshSkillConfig
	for i = 1, 4 do
		local stb = data3[list[i].id]
		local rd = math.random(1, 10000)
		for _, vv in ipairs(stb.table) do
			if vv.rate < rd then
				rd = rd - vv.rate
			else
				table.insert(attrsList,vv.id)
				break
			end
		end
	end
	return attrsList

end

server.playerCenter:SetEvent(Tiannv, "tiannv")
return Tiannv