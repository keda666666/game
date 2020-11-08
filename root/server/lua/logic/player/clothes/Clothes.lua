local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local Clothes = oo.class()

function Clothes:ctor(player)
	self.player = player
	self.role = player.role
end
local _clothesList = {}
_clothesList[1] =function(self) return self.role.ride:GetClothesList() end
_clothesList[2] =function(self) return self.role.wing:GetClothesList() end
_clothesList[3] =function(self) return self.role.fairy:GetClothesList() end
_clothesList[4] =function(self) return self.role.weapon:GetClothesList() end
_clothesList[9] =function(self) return self.player.tiannv.tianNvPlug:GetClothesList() end
_clothesList[100] =function(self) return self.role.skineffect:GetOwnlistData() end
_clothesList[101] =function(self) return self.role.titleeffect:GetOwnlistData() end
	-- 1,	--坐骑1
	-- 2		-- 翅膀2
	-- 3		-- 天仙3
	-- 4		-- 神兵4
	-- 		-- 宠物兽魂5
	-- 		-- 宠物通灵6
	-- 		-- 仙侣仙位7
	-- 		-- 仙侣法阵8
	-- 9		-- -- 天女9
	-- 		-- 天女灵气10
	-- 		-- 天女花辇11
	-- 100 	-- 角色时装
	-- 101		--称号

local _suitConfig = false
function Clothes:GetSuitConfig()
	if _suitConfig then return _suitConfig end
	_suitConfig = server.configCenter.SuitConfig
	return _suitConfig
end

function Clothes:onCreate()
	self:onLoad()
end

function Clothes:onLoad()
	lua_app.add_update_timer(100, self, "_onLoad")
end

function Clothes:_onLoad()
	self.closeList = {}
	self.suite = {}
	for k,v in pairs(_clothesList) do
		self.closeList[k] = table.wcopy(v(self))
	end
	local suitConfig = self:GetSuitConfig()
	for k,v in pairs(suitConfig) do
		for _,vv in pairs(v.activation) do
			if self.closeList[vv.type][vv.id] then
				self.suite[k] = (self.suite[k] or 0) + 1
			end
		end
	end

	local addAttrs = {} 
	for k,v in pairs(self.suite) do
		for i = 1, v do
			local attr = suitConfig[k]["attrpower_"..(i - 1)]
			if attr then
				for _,vv in pairs(attr) do
					table.insert(addAttrs,vv)
				end
			end
		end
	end
	self.role:UpdateBaseAttr({}, addAttrs, server.baseConfig.AttrRecord.Clothes)
end

function Clothes:AddClothes(typ, clothesNo)
	if not typ or not clothesNo then return end
	if not self.closeList[typ] then return end
	if self.closeList[typ][clothesNo] then return end
	self.closeList[typ][clothesNo] = 1
	--计算self.closeList[typ] 的属性
	local suitConfig = self:GetSuitConfig()
	for k,v in pairs(suitConfig) do
		for _,vv in pairs(v.activation) do
			if vv.type == typ and vv.id == clothesNo then
				self.suite[k] = (self.suite[k] or 0) + 1
				
				local attr = v["attrpower_"..(self.suite[k] - 1)]
				if attr then
					self.role:UpdateBaseAttr({}, attr, server.baseConfig.AttrRecord.Clothes)
					break
				end
			end
		end
	end
end
-- player.clothes:AddClothes(typ, clothesNo)
server.playerCenter:SetEvent(Clothes, "clothes")
return Clothes