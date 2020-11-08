local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local Material = oo.class()


function Material:ctor(player)
	self.player = player
	self.role = player.role
end

function Material:onCreate()
	self.cache = self.player.cache.material
end

function Material:onLoad()
	self.cache = self.player.cache.material
end

function Material:onInitClient()
	--发协议给客户端
	local msg = self:packMaterialInfo()
	server.sendReq(self.player, "sc_fuben_material_info", msg)
end

function Material:packMaterialInfo()
	local data = self.cache
	local msg = {fuben_data={}}
	for k,v in pairs(data.clearanceNum) do
		local fubendata = {
			fubenNo = k,
			clearanceNum = v,
			todayNum = data.todayNum[k] or 0,
			buyNum = data.buyNum[k] or 0,
		}
		table.insert(msg.fuben_data, fubendata)
	end
	return msg
end

function Material:SetValue(data)
	self.cache.clearanceNum = data.clearanceNum
	self.cache.todayNum = data.todayNum
	self.cache.buyNum = data.buyNum
end

function Material:onDayTimer()
	self.cache.todayNum = {}
	self.cache.buyNum = {}
	self:onInitClient()
end

function Material:AddMyBossNum(num)
	num = num or 1
	self.cache.bossNum = self.cache.bossNum + 1
	self.player.shop:onUpdateUnlock()
end

function Material:GetMyBossNum()
	return self.cache.bossNum
end

function Material:AddMaterialNum(num)
	num = num or 1
	self.cache.materialNum = self.cache.materialNum + 1
	self.player.shop:onUpdateUnlock()
end

function Material:GetMaterialNum()
	return self.cache.materialNum
end

server.playerCenter:SetEvent(Material, "material")
return Material