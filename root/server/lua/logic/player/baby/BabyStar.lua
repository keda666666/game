local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local BabyStar = oo.class()

function BabyStar:ctor(baby)
	self.baby = baby
	self.player = baby.player
	self.role = baby.player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.BabyStar
end

function BabyStar:onCreate()
	self:onLoad()
end

function BabyStar:onLoad()
	--加载
	self.cache = self.baby.cache.baby_star
	local attrsConfig = self:GetDestinyAttrsConfig()
	local attrs = {}
	for _,id in pairs(self.cache.data) do
		if id and id ~= 0 then
			for _,attr in pairs(attrsConfig[id].attars or {}) do
				table.insert(attrs, attr)
			end
			local buffId = attrsConfig[id].buffid
			if buffId then
				self.baby:AddSkill(buffId, true, 1)
			end
		end
	end
	if next(attrs) then
		self.baby:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.BabyStar)
	end
end

-- function BabyStar:Fix()
-- 	if self.fix then
-- 		return
-- 	end
-- 	self.cache = self.baby.cache.baby_star
-- 	local attrsConfig = self:GetDestinyAttrsConfig()
-- 	local attrs = {}
-- 	for _,id in pairs(self.cache.data) do
-- 		if id and id ~= 0 then
-- 			for _,attr in pairs(attrsConfig[id].attars or {}) do
-- 				table.insert(attrs, attr)
-- 			end
-- 			local buffId = attrsConfig[id].buffid
-- 			if buffId then
-- 				self.baby:AddSkill(buffId, true, 1)
-- 			end
-- 		end
-- 	end
-- 	if next(attrs) then
-- 		local power = 0
-- 		local AttrPowerConfig = server.configCenter.AttrPowerConfig
-- 		for _, v in pairs(attrs) do
-- 			if AttrPowerConfig[v.type] then
-- 				power = power + v.value * AttrPowerConfig[v.type].power
-- 			end
-- 		end
-- 		power = math.floor(power / 100)
-- 		self.player.changepower = math.max(self.player.changepower - power, 0)
-- 		self.baby:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.BabyStar)
-- 	end

-- 	self.fix = true
-- end

function BabyStar:onInitClient()
	--登录发送
	self:Open()
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_baby_star_init",msg)
end

function BabyStar:onLogout(player)
	--离线
end

function BabyStar:onLogin(player)
	--加载后续处理？？
end

function BabyStar:onDayTimer()
	--登录处理
end

function BabyStar:onLevelUp(oldlevel, newlevel)
	--升级
end

local _destinyBaseConfig = false
function BabyStar:GetDestinyBaseConfig()
	if _destinyBaseConfig then return _destinyBaseConfig end
	_destinyBaseConfig = server.configCenter.DestinyBaseConfig
	return _destinyBaseConfig
end

local _destinyDrawConfig = false
function BabyStar:GetDestinyDrawConfig()
	if _destinyDrawConfig then return _destinyDrawConfig end
	_destinyDrawConfig = server.configCenter.DestinyDrawConfig
	return _destinyDrawConfig
end

local _destinyAttrsConfig = false
function BabyStar:GetDestinyAttrsConfig()
	if _destinyAttrsConfig then return _destinyAttrsConfig end
	_destinyAttrsConfig = server.configCenter.DestinyAttrsConfig
	return _destinyAttrsConfig
end

local _destinyResolveConfig = false
function BabyStar:GetDestinyResolveConfig()
	if _destinyResolveConfig then return _destinyResolveConfig end
	_destinyResolveConfig = server.configCenter.DestinyResolveConfig
	return _destinyResolveConfig
end

local _destinyPromoteConfig = false
function BabyStar:GetDestinyPromoteConfig()
	if _destinyPromoteConfig then return _destinyPromoteConfig end
	_destinyPromoteConfig = server.configCenter.DestinyPromoteConfig
	return _destinyPromoteConfig
end

function BabyStar:GetDestinyDrawConfig()
	if _destinyDrawConfig then return _destinyDrawConfig end
	_destinyDrawConfig = server.configCenter.DestinyDrawConfig
	return _destinyDrawConfig
end

function BabyStar:Open(isMsg)
	local baseConfig = self:GetDestinyBaseConfig()
	local lv = self.player.baby.babyPlug.cache.lv
	local openNum = baseConfig.openlevel1[lv]

	if not openNum then return end
	local num = #self.cache.data
	if num >= openNum then return end
	for i=1, openNum-num do
		table.insert(self.cache.data, 0)
	end
	if isMsg then
		local msg = self:packInfo()
		server.sendReq(self.player, "sc_baby_star_init",msg) 
	end
end

function BabyStar:GetStar(num)
	if num < 1 then return {ret = false} end
	num =math.min(num, 50)
	local rewards = {}
	local allCost = 0 
	local getNum = 0
	for i = 1, num do
		local drawConfig = self:GetDestinyDrawConfig()
		local cost = drawConfig[self.cache.star].starCoins
		allCost = allCost + cost.count
		if not self.player:PayRewards({cost}, self.YuanbaoRecordType,"baby_star") then
			break
		end
		getNum = getNum + 1
		table.insert(rewards, self:MakeStar())
	end
	local msg = {
		ret = true,
		num = getNum,
		cost = allCost,
		star = self.cache.star,
		data = rewards,
		msgData = server.babyStarCenter:GetData(),
	}
	return msg
end

function BabyStar:MakeStar()
	local promoteConfig = self:GetDestinyPromoteConfig()
	local baseConfig = self:GetDestinyBaseConfig()
	local drawConfig = self:GetDestinyDrawConfig()
	local attrsConfig = self:GetDestinyAttrsConfig()
	local fourdrop
	if self.cache.star == 5 and self.cache.isBuy == 1 then
		fourdrop = baseConfig.fourdrop
	else
		fourdrop = drawConfig[self.cache.star].drawdrop
	end
	--根据掉落组先掉落
	local rewards = server.dropCenter:DropGroup(fourdrop)
	for k,v in pairs(rewards) do
		if attrsConfig[v.id] and attrsConfig[v.id].type >= baseConfig.type then
			--发公告并且存下来
			server.babyStarCenter:SetData({name = self.player.cache.name, id = v.id})
			server.chatCenter:ChatLink(44, nil, nil, self.player.cache.name, ItemConfig:ConverLinkText(v))
		end
	end
	self.player:GiveRewardAsFullMailDefault(rewards, "灵童命格", self.YuanbaoRecordType, "灵童命格")

	local rand = math.random(10000)
	local dataConfig
	if self.cache.star == 5 and self.cache.isBuy == 1 then
		self.cache.isBuy = 0
		dataConfig = drawConfig
	else
		drawConfig = promoteConfig[self.cache.star]
	end

	for k,v in pairs(drawConfig) do
		if rand <= v.probability then
			self.cache.star = k
			break
		end
		rand = rand - v.probability
	end
	return rewards[1]
end

function BabyStar:Use(id, pos)
	local oldNo = self.cache.data[pos]
	if not oldNo then return {ret = false} end
	if oldNo == id then return {ret = false} end
	local item = self.player.bag:GetItemByID(id)
	if not item then return {ret = false} end
	local no = item:GetConfig().id
	local attrsConfig = self:GetDestinyAttrsConfig()
	for k,v in pairs(self.cache.data) do
		if k ~= pos and v ~= 0 then
			if attrsConfig[no].sort == attrsConfig[v].sort then
				server.sendErr(self.player, "同类命格只能装备1个")
				return {ret = false}
			end
		end
	end
	local oldAttrs = {}
	local oldBuff

	self.player.bag:DelItemByID(id, 1, self.YuanbaoRecordType)

	if oldNo ~= 0 then
		oldAttrs = attrsConfig[oldNo].attars or {}
		oldBuff = attrsConfig[oldNo].buffid
		local props = {{type=1, id=oldNo, count=1}}
		self.player:GiveRewardAsFullMailDefault(props, "命格", self.YuanbaoRecordType, "装备返还")
	end
	self.cache.data[pos] = no
	local newAttrs = attrsConfig[no].attars or {}
	local newBuff = attrsConfig[no].buffid
	self.baby:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.BabyStar)
	if oldBuff then
		self.baby:DelSkill(oldBuff, 1)
	end
	if newBuff then
		self.baby:AddSkill(newBuff, true, 1)
	end

	--是否能开启灵童
	if not self.baby.cache.open or self.baby.cache.open == 0 then
		local basisConfig = server.configCenter.BabyBasisConfig
		local num = #self.cache.data
		if num >= basisConfig.material.num then
			local attrsConfig = server.configCenter.DestinyAttrsConfig
			local qualityNum = 0
			for i = 1, num do
				local no = self.cache.data[i]
				if attrsConfig[no] and attrsConfig[no].type >= basisConfig.material.quality then
					qualityNum = qualityNum + 1
				end
			end
			if qualityNum >= basisConfig.material.num then
				self.baby.cache.open = 1
				self.baby:SendInfo()
			end
		end
	end	
	return {ret = true, pos = pos, no = no}
end

function BabyStar:Smelt(idList)
	if not idList then return {ret = false} end
	local num = 0
	local resolveConfig = self:GetDestinyResolveConfig()
	local attrsConfig = self:GetDestinyAttrsConfig()
	for _,data in pairs(idList) do
		local cost = {{type=1,id=data.id,count=data.num}}
		if self.player:PayRewards(cost, self.YuanbaoRecordType,"灵童命格分解") then
			if attrsConfig[data.id] then
				local typ = attrsConfig[data.id].type
				local lv = attrsConfig[data.id].level
				num = num + (resolveConfig[typ][lv].resolvestar * data.num)
			end
		end
		-- local item = self.player.bag:GetItem(data.id)
		-- if item then
		-- 	local no = item:GetConfig().id
		-- 	if attrsConfig[no] then
		-- 		local typ = attrsConfig[no].type
		-- 		local lv = attrsConfig[no].level
		-- 		num = num + resolveConfig[typ][lv].resolvestar
		-- 	end
		-- end
	end
	if num == 0 then return {ret = false} end
	local baseConfig = self:GetDestinyBaseConfig()
	local reward = {{type=1, id=baseConfig.fenjieitemid, count=num}}
	self.player:GiveRewardAsFullMailDefault(reward, "灵童命格分解", self.YuanbaoRecordType, "灵童命格分解")
	return  {ret = true}
end

function BabyStar:UpLv(pos)
	local oldNo = self.cache.data[pos]
	if not oldNo or oldNo == 0 then return {ret = false} end
	local attrsConfig = self:GetDestinyAttrsConfig()
	local typ = attrsConfig[oldNo].type
	local lv = attrsConfig[oldNo].level
	local resolveConfig = self:GetDestinyResolveConfig()
	local num = resolveConfig[typ][lv].promotestar
	if not num then return {ret = false} end
	local baseConfig = self:GetDestinyBaseConfig()
	local cost = {{type=1, id=baseConfig.uplevelitemid, count=num}}
	if not self.player:PayRewardsByShop(cost, self.YuanbaoRecordType) then
		return {ret = false}
	end
	local id = attrsConfig[oldNo].id
	local oldAttrs = {}
	local oldBuff
	oldAttrs = attrsConfig[oldNo].attars or {}
	oldBuff = attrsConfig[oldNo].buffid

	local newAttrs = attrsConfig[id].attars or {}
	local newBuff = attrsConfig[id].buffid
	self.baby:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.BabyStar)
	if oldBuff then
		self.baby:DelSkill(oldBuff, 1)
	end
	if newBuff then
		self.baby:AddSkill(newBuff, true, 1)
	end
	self.cache.data[pos] = id
	return {ret = true, pos = pos, no = id}
end

function BabyStar:Light()
	local baseConfig = self:GetDestinyBaseConfig()
	if self.cache.star == 5 then return {ret = false} end
	if not self.player:PayRewardsByShop(baseConfig.fourpay, self.YuanbaoRecordType) then return {ret = false} end
	self.cache.star = 5
	self.cache.isBuy = 1
	server.noticeCenter:Notice(baseConfig.rwnotice, self.player.cache.name)
	return {ret = true}
end

function BabyStar:packInfo()
	local msg = {
		star = self.cache.star,
		data = self.cache.data,
		msgData = server.babyStarCenter:GetData(),
	}
	return msg
end

server.playerCenter:SetEvent(BabyStar, "baby.babyStar")
return BabyStar