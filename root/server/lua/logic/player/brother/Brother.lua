local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local Brother = oo.class()

function Brother:ctor(player)
	self.player = player
	self.role = player.role
end

function Brother:onCreate()
	self:onLoad()
end

function Brother:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.brother
	local fateConfig = server.configCenter.FateConfig
	for k,_ in pairs(self.cache.data) do
		self.role:UpdateBaseAttr({}, fateConfig[k].attrs, server.baseConfig.AttrRecord.Brother)
	end
end

function Brother:onInitClient()
	-- 登陆
	local msg = {data = {}}
	for k,_ in pairs(self.cache.data) do
		table.insert(msg.data, k)
	end
	server.sendReq(self.player, "sc_brother_info", msg)
end

local _Check = {}

_Check[1] = function(player, id)
	--宠物
	return player.cache.pet.list[id]
end
_Check[2] = function(player, id)
	--天将
	return player.cache.tianshen.list[id]
end
_Check[3] = function(player, id)
	--仙侣
	return player.cache.xianlv.list[id]
end

function Brother:activation(no)
	local fateConfig = server.configCenter.FateConfig[no]
	if not fateConfig then return {ret = false} end
	if self.cache.data[no] then return {ret =true} end

	for k,v in pairs(fateConfig.group) do
		if not _Check[v.type](self.player, v.id) then
			return {ret = false}
		end
	end
	self.cache.data[no] = 1
	self.role:UpdateBaseAttr({}, fateConfig.attrs, server.baseConfig.AttrRecord.Brother)
	return {ret = true, no = no}
end

server.playerCenter:SetEvent(Brother, "brother")
return Brother