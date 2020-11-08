local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Advanced = oo.class()

function Advanced:ctor(player)
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Advanced
end

function Advanced:onCreate()
	self:onLoad()
end

function Advanced:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.Advanced
end

function Advanced:onDayTimer()
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local day = server.serverRunDay
	local dayData = baseConfig.initialorder[day]
	if not dayData or self.cache.typ ~= dayData then
		if self.cache.dayAllCharger ~= 0 then
			local rechargeConfig = server.configCenter.ProgressCrazyRechargeConfig
			local baseConfig = server.configCenter.ProgressCrazyBaseConfig
			for k,v in ipairs(rechargeConfig[self.cache.typ]) do
				if self.cache.dayAllCharger < v.money then break end
				if not self.cache.chargerReward[k] then
					local title = baseConfig.mailtitle2
					local msg = baseConfig.maildes2
					server.mailCenter:SendMail(self.player.dbid, title, msg, v.reward, self.YuanbaoRecordType, "累计充值补发")
				end
			end
		end

		self.cache.dayAllCharger = 0
		self.cache.chargerReward = {}
		self.cache.advancedReward = {}
	end

	self.cache.advancedShop = {}
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_advanced_info", msg)
end

function Advanced:onInitClient()
	--登录更新到客户端
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_advanced_info", msg)
end

function Advanced:GetTyp(num, dataConfig)
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local day = server.serverRunDay
	if day <= #baseConfig.initialorder then
		return baseConfig.initialorder[day]
	end
	local Nnum = day - #baseConfig.initialorder
	local no = (Nnum % #dataConfig)
	if no == 0 then no = #dataConfig end
	return dataConfig[no]
end

function Advanced:AddCharge(num)
	self.cache.dayAllCharger = self.cache.dayAllCharger + num
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	self.cache.typ = self:GetTyp(#baseConfig.rechargeorder, baseConfig.rechargeorder)
	local msg = self:upPackInfo("dayAllCharger")
	server.sendReq(self.player, "sc_advanced_update", msg)
end

function Advanced:GetChargerReward(id)
	local rechargeConfig = server.configCenter.ProgressCrazyRechargeConfig
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local num = self:GetTyp(#baseConfig.rechargeorder, baseConfig.rechargeorder)
	local data = rechargeConfig[num][id]
	if not data then return end
	if self.cache.dayAllCharger < data.money then return end
	if self.cache.chargerReward[id] then return end
	self.cache.chargerReward[id] = 1
	self.player:GiveRewardAsFullMailDefault(data.reward, "累计充值奖励", self.YuanbaoRecordType, "累计充值奖励")
	
	local msg = self:upPackInfo("chargerReward")
	server.sendReq(self.player, "sc_advanced_update", msg)
end

local _Check = {}

_Check[1] = function(player, lv)
	return player.role.ride.cache.lv >= lv
end

_Check[2] = function(player, lv)
	return player.role.wing.cache.lv >= lv
end

_Check[3] = function(player, lv)
	return player.role.fairy.cache.lv >= lv
end

_Check[4] = function(player, lv)
	return player.role.weapon.cache.lv >= lv
end

_Check[5] = function(player, lv)
	return player.pet.soul.cache.lv >= lv
end

_Check[6] = function(player, lv)
	return player.pet.psychic.cache.lv >= lv
	
end

_Check[7] = function(player, lv)
	return player.xianlv.position.cache.lv >= lv
end

_Check[8] = function(player, lv)
	return player.xianlv.circle.cache.lv >= lv
end

_Check[9] = function(player, lv)
	return player.tiannv.cache.lv >= lv
end

_Check[10] = function(player, lv)
	return player.tiannv.nimbus.cache.lv >= lv
end

_Check[11] = function(player, lv)
	return player.tiannv.flower.cache.lv >= lv
end

_Check[12] = function(player, lv)
	return player.baby.babyPlug.cache.lv >= lv
end

--Vip
_Check[100] = function(player, lv)
	return player.cache.vip >= lv
end

function Advanced:GetAdvancedLvReward(typ, id)
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local data = self:GetTyp(#baseConfig.progressorder, baseConfig.progressorder)
	if type(data) == "number" then
		if data ~= typ then return end
	else
		local tag = true
		for _,v in pairs(data) do
			if v == typ then
				tag = false
				break
			end
		end
		if tag then return end
	end
	local rewardConfig = server.configCenter.ProgressCrazyRewardConfig
	if not _Check[typ](self.player, rewardConfig[typ][id].value) then return end
	local rewardInfo = (self.cache.advancedReward[typ] or {})
	if rewardInfo[id] then return end
	rewardInfo[id] = 1
	self.cache.advancedReward[typ] = rewardInfo
	self.player:GiveRewardAsFullMailDefault(rewardConfig[typ][id].reward, "进阶奖励", self.YuanbaoRecordType, "进阶奖励"..typ.."|"..id)
	
	local msg = self:upPackInfo("advancedReward")
	server.sendReq(self.player, "sc_advanced_update", msg)
end

local rankList = {5,6,7,8,14,13,12,11,9,16,15,20}

local _GetPower = {}

_GetPower[1] = function(player)
	return player.role.ride.cache.totalpower
end

_GetPower[2] = function(player)
	return player.role.wing.cache.totalpower
end

_GetPower[3] = function(player)
	return player.role.fairy.cache.totalpower
end

_GetPower[4] = function(player)
	return player.role.weapon.cache.totalpower
end

_GetPower[5] = function(player)
	return player.pet.soul.cache.totalpower
end

_GetPower[6] = function(player)
	return player.pet.psychic.cache.totalpower
	
end

_GetPower[7] = function(player)
	return player.xianlv.position.cache.totalpower
end

_GetPower[8] = function(player)
	return player.xianlv.circle.cache.totalpower
end

_GetPower[9] = function(player)
	return player.tiannv.cache.totalpower
end

_GetPower[10] = function(player)
	return player.tiannv.nimbus.cache.totalpower
end

_GetPower[11] = function(player)
	return player.tiannv.flower.cache.totalpower
end

_GetPower[12] = function(player)
	return player.baby.babyPlug.cache.totalpower
end
------

function Advanced:GetRank()
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local day = server.serverRunDay
	if day > #baseConfig.initialorder then return end
	local rankNo = baseConfig.initialorder[day]
	local rankData = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas", rankList[rankNo], 1, 20)
	local selfRank = server.serverCenter:CallLocalMod("world", "rankCenter", "GetMyRank", rankList[rankNo], self.player.dbid)

	local msg = {
		typ = rankNo,
		datas = rankData,
		selfRank = selfRank or 0,
		selfPower = _GetPower[rankNo](self.player)
	}
	server.sendReq(self.player, "sc_advanced_rank", msg)
end

function Advanced:Buy(id, num, typ)
	print("Advanced:Buy--------------", id, num, typ)
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local cTyp = self:GetTyp(#baseConfig.shoporder, baseConfig.shoporder)
	local shopConfig = server.configCenter.ProgressCrazyShopConfig
	if cTyp ~= typ then
		print("Advanced:Buy-------------- cTyp ~= typ", id, num, typ, cTyp)
		return 
	end

	local data = shopConfig[typ][id]
	if not _Check[data.value.type](self.player, data.value.value) then
		print("Advanced:Buy-------------- _Check", id, num, typ, data.value.type, data.value.value)
		return
	end
	local bNum = self.cache.advancedShop[id] or 0
	if data.type.type == 3 then
		if (bNum + num) > data.type.value then
			print("Advanced:Buy-------------- (bNum + num) > data.type.value", id, num, typ, bNum, data.type.value)
			return
		end
	end
	local cash = table.wcopy(data.gold)
	cash.count = cash.count * num
	if not self.player:PayRewards({cash}, self.YuanbaoRecordType, "折扣商店购买") then return end
	if data.type.type == 3 then
		self.cache.advancedShop[id] = bNum + num
	end
	local props = {type=1, id=data.itemid, count=data.count*num}
	self.player:GiveRewardAsFullMailDefault({props}, "折扣商店购买", self.YuanbaoRecordType, "折扣商店购买"..data.itemid.."|"..num)
	
	local msg = self:upPackInfo("shop")
	server.sendReq(self.player, "sc_advanced_update", msg)
end

function Advanced:packInfo()
	local msg = {
		dayCharger = self.cache.dayAllCharger,
		chargerReward = {},
		shop = {},
		advancedReward = {},
	}
	for k,_ in pairs(self.cache.chargerReward) do
		table.insert(msg.chargerReward, k)
	end
	for k,v in pairs(self.cache.advancedShop) do
		table.insert(msg.shop, {id=k, num=v})
	end
	for k,v in pairs(self.cache.advancedReward) do
		local data = {}
		for no,_ in pairs(v) do
			table.insert(data, no)
		end
		table.insert(msg.advancedReward, {typ=k, reward=data})
	end
	return msg
end

function Advanced:upPackInfo(...)
	local args = {...}
	local msg = {}
	for _,v in pairs(args) do
		if v == "shop" then
			msg.shop = {}
			for k,v in pairs(self.cache.advancedShop) do
				table.insert(msg.shop, {id=k, num=v})
			end
		elseif v == "advancedReward" then
			msg.advancedReward = {}

			for k,v in pairs(self.cache.advancedReward) do
				local data = {}
				for no,_ in pairs(v) do
					table.insert(data, no)
				end
				table.insert(msg.advancedReward, {typ=k, reward=data})
			end
		elseif v == "chargerReward" then
			msg.chargerReward = {}
			for k,_ in pairs(self.cache.chargerReward) do
				table.insert(msg.chargerReward, k)
			end
		elseif v == "dayAllCharger" then
			msg.dayCharger = self.cache.dayAllCharger
		end
	end
	return msg
end

server.playerCenter:SetEvent(Advanced, "advanced")
return Advanced