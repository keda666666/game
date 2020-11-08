local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"

local TianshenSpells = oo.class()

function TianshenSpells:ctor(tianshen)
	self.tianshen = tianshen
	self.player = tianshen.player
	self.role = tianshen.player.role
	--配置要改
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.TianShen
end

function TianshenSpells:onCreate()
	self:onLoad()
end

function TianshenSpells:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.tianshen.tianshen_spells
	self.allLv = 0
	for _,v in pairs(self.cache) do
		self.allLv = self.allLv + v.lv
	end
	self.resonance = 0
	local resonateConfig = self:GetAirMarshalResonateConfig()
	for i=1, #resonateConfig do
		if self.allLv >= resonateConfig[i].lv and (not resonateConfig[i] or self.allLv <= resonateConfig[i].lv) then
			self.resonance = i
		end
	end
	--算属性
	local attrs = {}
	for k,v in pairs(self.cache) do
                                                                                                            print(k)  print(v.lv)
		local attr = self:GetAirMarshalTreasureAttrsConfig(k)[v.lv].attrs
		for _,vv in pairs(attr) do
			table.insert(attrs, vv)
		end
	end
	--算共鸣属性
	if self.resonance ~= 0 then
		for _,v in pairs(resonateConfig[self.resonance].attrs) do
			table.insert(attrs, v)
		end
	end
                                                                                                              self:onInitClient()
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.TianshenSpells)
end

function TianshenSpells:onLevelUp(oldlevel, level)                                                                                                    
	
	local newPos = false
	for i = oldlevel + 1, level do
		local unlockConfig = self:GetAirMarshalBaseConfig("unlock")
		local pos = unlockConfig[i]  
		if pos then  
			if not self.cache[pos] then  
				self.cache[pos] = {
					lv = 1,
					upNum = 0,
				}
				newPos = true

				local treasureAttrsConfig = self:GetAirMarshalTreasureAttrsConfig(pos)
				local attrs = treasureAttrsConfig[1].attrs
				self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.TianshenSpells)
			end
		end
	end
	if newPos then
		local msg = self:packInfo()
		server.sendReq(self.player, "sc_tianshen_spells_info", msg)
	end
	--重算共鸣属性
	local resonateConfig = self:GetAirMarshalResonateConfig()
	local resonance = 0
	for i=1, #resonateConfig do
		if self.allLv >= resonateConfig[i].lv and (not resonateConfig[i+1] or self.allLv <= resonateConfig[i+1].lv) then
			resonance = i
			break
		end
	end
	if resonance ~= self.resonance then
		local attrs = {}
		if self.resonance ~= 0 then
			attrs = resonateConfig[self.resonance].attrs
		end
		self.role:UpdateBaseAttr(attrs, resonateConfig[resonance].attrs, server.baseConfig.AttrRecord.TianshenSpells)
		self.resonance = resonance
	end
end

function TianshenSpells:packInfo()
	local msg = {}
	msg.data = self.cache
	return msg
end

local _airMarshalBaseConfig = false
function TianshenSpells:GetAirMarshalBaseConfig(no)
	if _airMarshalBaseConfig then return _airMarshalBaseConfig[no] end
	_airMarshalBaseConfig = server.configCenter.AirMarshalBaseConfig
	return _airMarshalBaseConfig[no]
end

local _airMarshalTreasureAttrsConfig = false
function TianshenSpells:GetAirMarshalTreasureAttrsConfig(no)
	if _airMarshalTreasureAttrsConfig then return _airMarshalTreasureAttrsConfig[no] end
	_airMarshalTreasureAttrsConfig = server.configCenter.AirMarshalTreasureAttrsConfig
	return _airMarshalTreasureAttrsConfig[no]
end

local _airMarshalResonateConfig = false
function TianshenSpells:GetAirMarshalResonateConfig()
	if _airMarshalResonateConfig then return _airMarshalResonateConfig end
	_airMarshalResonateConfig = server.configCenter.AirMarshalResonateConfig
	return _airMarshalResonateConfig
end

function TianshenSpells:AddExp(pos, autoBuy)
	local data = self.cache[pos]
	if not data then return end
	local treasureAttrsConfig = self:GetAirMarshalTreasureAttrsConfig(pos)
	if data.lv == #treasureAttrsConfig and data.upNum >= treasureAttrsConfig[data.lv].upnum then return {ret = false} end
	local cost = treasureAttrsConfig[data.lv].cost
	if not cost then return end
	if not self.player:PayRewardsByShop(cost, self.YuanbaoRecordType, nil, autoBuy) then return {ret = false} end
	data.upNum = data.upNum + 1
	if data.upNum >= treasureAttrsConfig[data.lv].upnum then
		data.upNum = data.upNum - treasureAttrsConfig[data.lv].upnum
		local oldAttrs = treasureAttrsConfig[data.lv].attrs
		data.lv = data.lv + 1
		self.allLv = self.allLv + 1
		local newAttrs = treasureAttrsConfig[data.lv].attrs
		self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.TianshenSpells)

		local resonateConfig = self:GetAirMarshalResonateConfig()
		local resonance = 0
		for i=1, #resonateConfig do
			if self.allLv >= resonateConfig[i].lv and (not resonateConfig[i+1] or self.allLv <= resonateConfig[i+1].lv) then
				resonance = i
				break
			end
		end
		if resonance ~= self.resonance then
			local attrs = {}
			if self.resonance ~= 0 then
				attrs = resonateConfig[self.resonance].attrs
			end
			self.role:UpdateBaseAttr(attrs, resonateConfig[resonance].attrs, server.baseConfig.AttrRecord.TianshenSpells)
			self.resonance = resonance
		end
	end
	local msg = {
		ret = true,
		pos = pos,
		upNum = data.upNum,
		lv = data.lv,
	}
	return msg
end

function TianshenSpells:onInitClient()
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_tianshen_spells_info", msg)
end

server.playerCenter:SetEvent(TianshenSpells, "tianshen.spells")
return TianshenSpells