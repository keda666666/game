local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"

local Xianlv = oo.class(LogicEntity)

function Xianlv:ctor(player)
end

function Xianlv:onCreate()
	self:onLoad()
end

function Xianlv:onLoad()
	self.cache = self.player.cache.xianlv
	local attrs = {}
	self.allLv = 0
	for id, xianLvInfo in pairs(self.cache.list) do
		self.allLv = self.allLv + xianLvInfo.level
		local pBCfg = server.configCenter.partnerBiographyConfig[id]
		for _,v in pairs(pBCfg.attrs) do
			v = table.wcopy(v)
			table.insert(attrs, v)
		end
		if xianLvInfo.exp ~= 0 then
			local attr = server.configCenter.partnerLvproConfig[pBCfg.quality][xianLvInfo.level].attrs
			for _,v in pairs(attr) do
				v = table.wcopy(v)
				v.value = v.value * xianLvInfo.exp
				table.insert(attrs, v)
			end
		end
		local attr = server.configCenter.partnerGiftConfig[pBCfg.quality][xianLvInfo.level].attrs
		for _,v in pairs(attr) do
			v = table.wcopy(v)
			table.insert(attrs, v)
		end
		local starattrs = server.configCenter.partnerAttrsConfig[id][xianLvInfo.star].attrs
		for _, v in pairs(starattrs) do
			v = table.wcopy(v)
			table.insert(attrs, v)
		end
	end
	self.allLvNo = 0
	local skillConfig = server.configCenter.partnerFreshSkillConfig
	for k,v in ipairs(skillConfig) do
		if v.lv <= self.allLv and (not skillConfig[k + 1] or self.allLv < skillConfig[k + 1].lv) then
			self.allLvNo = k
			for _,v in pairs(v.attrs) do
				v = table.wcopy(v)
				table.insert(attrs, v)
			end
			break
		end
	end

	if next(attrs) then
		self:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.Xianlv)
	end
	self:OutBound(self.cache.outbound[1], self.cache.outbound[2])
end

function Xianlv:onInitClient()
	local list = {}
	for _, info in pairs(self.cache.list) do
		table.insert(list, info)
	end
	server.sendReq(self.player, "sc_xianlv_init", {
			list		= list,
			outbound	= self.cache.outbound,
		})
end

function Xianlv:onLogout()
end

function Xianlv:Active(id)
	local pBCfg = server.configCenter.partnerBiographyConfig[id]
	if not pBCfg or self.cache.list[id] then return { ret = false } end
	if self.player.bag:DelItemByID(pBCfg.material.id, pBCfg.material.count, server.baseConfig.YuanbaoRecordType.Xianlv)
		== ItemConfig.ItemChangeResult.DEL_FAILED then
		return { ret = false }
	end
	local xianLvInfo = {
		id 		= id,
		exp		= 0,
		level	= 1,
		star	= 1,
	}
	self.cache.list[id] = xianLvInfo

	local newAttrs = {}
	local oldAttrs = {}
	for _,v in pairs(pBCfg.attrs) do
		v = table.wcopy(v)
		table.insert(newAttrs, v)
	end
	local attr = server.configCenter.partnerGiftConfig[pBCfg.quality][xianLvInfo.level].attrs
	for _,v in pairs(attr) do
		v = table.wcopy(v)
		table.insert(newAttrs, v)
	end
	local starattr = server.configCenter.partnerAttrsConfig[id][xianLvInfo.star].attrs
	for _,v in pairs(starattr) do
		v = table.wcopy(v)
		table.insert(newAttrs, v)
	end
	self.allLv = self.allLv + 1
	self:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Xianlv)
	self:CheckAllLvAttr()
	self.player.task:onEventCheck(server.taskConfig.ConditionType.XianlvActive)
	--完成阵位↓
	self.player.position:AddClearNum(1, id)
	self.player.position:AddClearNum(2, id)
	return { ret = true }
end

function Xianlv:CheckAllLvAttr()
	local oldAttrs = {}
	local newAttrs = {}
	local skillConfig = server.configCenter.partnerFreshSkillConfig
	for k,v in ipairs(skillConfig) do
		if v.lv <= self.allLv and (not skillConfig[k + 1] or self.allLv < skillConfig[k + 1].lv) then
			if self.allLvNo == k then
				break
			else
				if skillConfig[self.allLvNo] then
					oldAttrs = skillConfig[self.allLvNo].attrs
				end
				for _,attr in pairs(v.attrs) do
					table.insert(newAttrs, attr)
				end
				self.allLvNo = k
			end
		end
	end
	if next(newAttrs) then
		self:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Xianlv)
	end
end

function Xianlv:OutBound(first, second)
	local list = self.cache.list
	local outbound = {
		[1]		= first or 0,
		[2]		= second or 0,
	}
	for i = 1, 2 do
		self:ClearEntity(i)
		local id = outbound[i]
		if id and id ~= 0 then
			local info = list[id]
			local cfg = server.configCenter.partnerAttrsConfig[id][info.star]
			for _, skillid in ipairs(cfg.skillid) do
				self:AddSkill(skillid, true, i)
			end
		end
	end
	self.cache.outbound = outbound
end

function Xianlv:AddExp(id, autobuy)
	local info = self.cache.list[id]
	if not info then return { ret = false } end
	local quality = server.configCenter.partnerBiographyConfig[id].quality
	local level = info.level
	local lvproConfig = server.configCenter.partnerLvproConfig[quality]
	if (info.exp + 1) > lvproConfig[level].upnum or not lvproConfig[level + 1] then
		return {ret = false}
	end
	if not self.player:PayRewardsByShop(lvproConfig[level].cost, server.baseConfig.YuanbaoRecordType.Xianlv, "Xianlv:AddExp", autobuy) then
		return {ret = false }
	end

	local oldAttrs = {}
	local newAttrs = {}
	-- local nextExp = info.exp + 1
	if (info.exp + 1 ) >= lvproConfig[level].upnum then
		--计算旧等级属性
		local giftConfig = server.configCenter.partnerGiftConfig[quality]
		for _,v in pairs(giftConfig[level].attrs) do
			v = table.wcopy(v)
			table.insert(oldAttrs, v)
		end
		--计算旧经验属性
		for _,v in pairs(lvproConfig[level].attrs) do
			v = table.wcopy(v)
			v.value = v.value * info.exp
			table.insert(oldAttrs, v)
		end
		--增加新等级属性
		for _,v in pairs(giftConfig[level + 1].attrs) do
			v = table.wcopy(v)
			table.insert(newAttrs, v)
		end
		--修改经验和等级
		info.exp = (info.exp + 1 )- lvproConfig[level].upnum
		info.level = level + 1
		self.allLv = self.allLv + 1
	else
		--增加1次经验属性
		for _,v in pairs(lvproConfig[level].attrs) do
			v = table.wcopy(v)
			table.insert(newAttrs, v)
		end
		info.exp = info.exp + 1
	end
	self:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Xianlv)
	
	--判断一次仙侣仙缘是否增加
	self:CheckAllLvAttr()

	self.player.task:onEventAdd(server.taskConfig.ConditionType.XianlvUpgrade)
	return {
		ret = true,
		exp = info.exp,
		level = info.level,
	}
end

function Xianlv:UpStar(id)
	local info = self.cache.list[id]
	if not info then return { ret = false } end
	local oldstar = info.star
	local partnerAttrsConfig = server.configCenter.partnerAttrsConfig[id][oldstar]
	local newcfg = server.configCenter.partnerAttrsConfig[id][oldstar + 1]
	if not newcfg or not self.player:PayRewards(partnerAttrsConfig.cost, server.baseConfig.YuanbaoRecordType.Xianlv) then
		return { ret = false }
	end
	info.star = oldstar + 1
	local oi
	local outbound = self.cache.outbound
	for i = 1, 2 do
		if outbound[i] == id then
			oi = i
			break
		end
	end
	if oi then
		self:ClearEntity(oi)
		for _, skillid in ipairs(newcfg.skillid) do
			self:AddSkill(skillid, true, oi)
		end
	end
	local oldAttrs = partnerAttrsConfig.attrs
	local newAttrs = newcfg.attrs
	self:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.Xianlv)
	return {
		ret = true,
		star = info.star,
	}
end

function Xianlv:GetShowData(id)
	local xianlv = self.cache.list[id]
	local data = {}
	if xianlv then
		data = {
			id = id,
			level = xianlv.level,
			star = xianlv.star,
		}
	end
	return data
end

server.playerCenter:SetEvent(Xianlv, "xianlv")
return Xianlv