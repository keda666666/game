local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"
local WeightData = require "WeightData"

local Formation = oo.class()

function Formation:ctor(player)
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Formation
end

function Formation:onCreate()
	self:onLoad()
end

function Formation:onLoad()
	self.cache = self.player.cache.formation
	if #self.cache.list < 1 then return end
	local no = self.cache.use
	if no ~= 0 then
		local newSkillNo = self.cache.list[no].skillNo
		if newSkillNo ~= 0 then
			self.role:AddSkill(newSkillNo, true, 1)
		end
	end
	-- 计算属性
	local allattr = self:Allattr()
	self.role:UpdateBaseAttr({}, allattr, server.baseConfig.AttrRecord.Formation)
end

function Formation:Allattr()
	--这里计算属性
	local attrs = {}
	for k,v in pairs(self.cache.list) do
		--激活属性
		local listConfig = self:GetFormationListConfig(k)
		for _,vv in pairs(listConfig.attrs) do
			table.insert(attrs, vv)
		end
		--等级属性
		local progressConfig = self:GetFormationProgressConfig(k)
		for _,vv in pairs(progressConfig[v.lv].attrs) do
			table.insert(attrs, vv)
		end
		--升级次数属性
		local lvproConfig = self:GetFormationLvproConfig(listConfig.quality)
		for i = 1,v.lv -1 do
			for _,vv in pairs(lvproConfig[i].attrs) do
				local attr = table.wcopy(vv)
				attr.value = attr.value * v.upnum
				table.insert(attrs,attr)
			end
		end
		for _,vv in pairs(lvproConfig[v.lv].attrs) do
			local attr = table.wcopy(vv)
			attr.value = attr.value * v.upnum
			table.insert(attrs,attr)
		end
		--阵魂升级次数属性
		local soulConfig = self:GetFormationSoulConfig(k)
		for i = 1,v.soulLv -1 do
			for _,vv in pairs(table.wcopy(soulConfig[i].attrs)) do
				vv.value = vv.value * vv.soulUpnum
				table.insert(attrs,vv)
			end
		end
		for _,vv in pairs(table.wcopy(soulConfig[v.soulLv].attrs)) do
			vv.value = vv.value * v.soulUpnum
			table.insert(attrs,vv)
		end
		--属性丹
		local attr = table.wcopy(self:GetFormationbaseConfig("attredata"))
		for _,vv in pairs(attr) do
			vv.value = vv.value * self.cache.useNum
			table.insert(attrs,vv)
		end
	end
	return attrs
end

-- function Formation:onLevelUp(oldlevel,level)
	-- 升级开启
	-- local lv = server.configCenter.FuncOpenConfig[19].conditionnum
	-- if #self.cache.attrdatas.attrs > 0 then return end
	-- if lv <= level then
	-- 	self:Open(1)
	-- end

function Formation:onInitClient()
	--发客户端
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_formation_info", msg)
end

function Formation:packInfo()
	local infoList = {}
	for k,v in pairs(self.cache.list) do
		table.insert(infoList,{
			no = k,
			skillNo = v.skillNo,
			lv = v.lv,
			upNum = v.upNum,
			soulLv = v.soulLv,
			soulUpNum = v.soulUpNum,
		})
	end
	local msg = {
		use = self.cache.use,
		infoList = infoList,
		drugNum = self.cache.drugNum,
	}
	return msg
end


local _formationBaseConfig = false
function Formation:GetFormationBaseConfig(no)
	if _formationBaseConfig then return _formationBaseConfig[no] end
	_formationBaseConfig = server.configCenter.FormationBaseConfig
	return _formationBaseConfig[no]
end

local _formationListConfig = false
function Formation:GetFormationListConfig(no)
	if _formationListConfig then return _formationListConfig[no] end
	_formationListConfig = server.configCenter.FormationListConfig
	return _formationListConfig[no]
end

local _formationLvproConfig = false
function Formation:GetFormationLvproConfig(no)
	if _formationLvproConfig then return _formationLvproConfig[no] end
	_formationLvproConfig = server.configCenter.FormationLvproConfig
	return _formationLvproConfig[no]
end

local _formationProgressConfig = false
function Formation:GetFormationProgressConfig(no)
	if _formationProgressConfig then return _formationProgressConfig[no] end
	_formationProgressConfig = server.configCenter.FormationProgressConfig
	return _formationProgressConfig[no]
end

local _formationSoulConfig = false
function Formation:GetFormationSoulConfig(no)
	if _formationSoulConfig then return _formationSoulConfig[no] end
	_formationSoulConfig = server.configCenter.FormationSoulConfig
	return _formationSoulConfig[no]
end

local _formationSkillConfig = false
function Formation:GetFormationSkillConfig(no)
	if _formationSkillConfig then return _formationSkillConfig[no] end
	_formationSkillConfig = server.configCenter.FormationSkillConfig
	return _formationSkillConfig[no]
end

-- function Formation:Open(pos)
	-- 开启功能,貌似不用开启功能
	-- 发给客户端
	-- msg = self:packInfo()
	-- server.sendReq(self.player, "sc_tiannv_equip", msg)
-- end

function Formation:Activation(no)
	local open = self:GetFormationBaseConfig("open")
	local lv = server.configCenter.FuncOpenConfig[open].conditionnum
	if lv > self.player.cache.level then return {ret = false} end

	if self.cache.list[no] then return {ret = false} end
	local listConfig = self:GetFormationListConfig(no)
	if not listConfig then return {ret = false} end
	if not self.player:PayRewardsByShop({listConfig.material}, self.YuanbaoRecordType) then return {ret = false} end
	self.cache.list[no] = {
		skillNo = listConfig.buffskill or 0,
		upNum = 0,
		lv = 1,
		soulUpNum = 0,
		soulLv = 1,
	}
	local attrs = listConfig.attrs
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.Formation)
	if listConfig.buffskill then
		self.role:AddSkill(listConfig.buffskill, true, 1)
	end
	local msg = table.wcopy(self.cache.list[no])
	msg.no = no
	return msg
end

function Formation:AddExp(no, autoBuy)
	local data = self.cache.list[no]
	if not data then return {ret = false} end
	local listConfig = self:GetFormationListConfig(no)
	local lvproConfig = self:GetFormationLvproConfig(listConfig.quality)
	if data.lv >= #lvproConfig and data.upNum >= lvproConfig[data.lv].upnum then return {ret = false} end
	if not self.player:PayRewardsByShop(lvproConfig[data.lv].cost, self.YuanbaoRecordType, nil, autoBuy) then return {ret = false} end
	data.upNum = data.upNum + 1
	local newAttrs = table.wcopy(lvproConfig[data.lv].attrs or {})
	local oldAttrs = {}
	if data.upNum >= lvproConfig[data.lv].upnum then
		if lvproConfig[data.lv + 1] then
			local oldLv = data.lv
			data.upNum = data.upNum - lvproConfig[data.lv].upnum
			data.lv = data.lv + 1

			local attrsConfig = self:GetFormationProgressConfig(no)
			oldAttrs = attrsConfig[oldLv].attrs
			local newAttrsConfig = attrsConfig[data.lv]
			for _,v in pairs(newAttrsConfig.attrs) do
				table.insert(newAttrs, v)
			end
		end
	end
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Formation)
	local msg = {
		ret = true,
		no = no,
		lv = data.lv,
		upNum = data.upNum,
	}
	return msg
end

function Formation:SoulAddExp(no, autoBuy)
	local data = self.cache.list[no]
	if not data then return {ret = false} end
	local soulConfig = self:GetFormationSoulConfig(no)
	if data.soulLv >= #soulConfig and data.soulUpNum >= soulConfig[data.soulLv].upnum then return {ret = false} end
	if not self.player:PayRewardsByShop({soulConfig[data.soulLv].cost}, self.YuanbaoRecordType, nil, autoBuy) then return {ret = false} end
	data.soulUpNum = data.soulUpNum + 1
	local attrs = soulConfig[data.soulLv].attrs
	if data.soulUpNum >= soulConfig[data.soulLv].upnum then
		if soulConfig[data.soulLv + 1] then
			data.soulUpNum = data.soulUpNum - soulConfig[data.soulLv].upnum
			data.soulLv = data.soulLv + 1
		end
	end
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.Formation)
	local msg = {
		ret = true,
		no = no,
		soulLv = data.soulLv,
		soulUpNum = data.soulUpNum,
	}
	return msg
end

function Formation:SkillUp(no)
	local data = self.cache.list[no]
	if not data then return {ret = false} end
	if data.skillNo == 0 then return {ret = false} end
	local skillConfig = self:GetFormationSkillConfig(data.skillNo)
	if not skillConfig.nextid then return {ret = false} end
	if not self.player:PayRewardsByShop({skillConfig.cost}, self.YuanbaoRecordType) then return {ret = false} end
	local oldSkillNo = data.skillNo
	data.skillNo = skillConfig.nextid
	if self.cache.use == no then
		self.role:DelSkill(oldSkillNo, 1)
		self.role:AddSkill(data.skillNo, true, 1)
	end
	return {ret = true, skillNo = data.skillNo}
end

function Formation:Use(no)
	local data = self.cache.list[no]
	if not data then return {ret = false} end
	local oldUse = self.cache.use
	self.cache.use = no
	local oldSkillNo = 0
	if oldUse ~= 0 then
		local oldSkillNo = self.cache.list[oldUse].skillNo
	end
	if oldSkillNo ~= 0 then
		self.role:DelSkill(oldSkillNo, 1)
	end
	local newSkillNo = self.cache.list[no].skillNo
	if newSkillNo ~= 0 then
		self.role:AddSkill(newSkillNo, true, 1)
	end
	return {ret = true, use = no, disuse = oldUse}
end

function Formation:UseDrug(useNum)
	local open = self:GetFormationBaseConfig("open")
	local lv = server.configCenter.FuncOpenConfig[open].conditionnum
	if lv > self.player.cache.level then return {ret = false} end
	local propsNo = self:GetFormationBaseConfig("attreitemid")
	local bag = self.player.bag
	if not self.player.bag:CheckItem(propsNo, useNum) then return {ret = false} end
	bag:DelItemByID(propsNo, useNum, self.YuanbaoRecordType)
	self.cache.drugNum = (self.cache.drugNum or 0) + useNum
	local attrs = table.wcopy(self:GetFormationBaseConfig("attredata"))
	for _,v in pairs(attrs) do
		v.value = v.value * useNum
	end
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.Formation)
	return {ret = true, drugNum = self.cache.drugNum}
end

server.playerCenter:SetEvent(Formation, "formation")
return Formation