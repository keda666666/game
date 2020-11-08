local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"
local lua_app = require "lua_app"
local EffectBase = require "player.role.effect.EffectBase"

local SkinEffect = oo.class(EffectBase)

SkinEffect.id = server.baseConfig.YuanbaoRecordType.Skin
SkinEffect.describe = ""
SkinEffect.conf = "FashionSkinConfig"
SkinEffect.attrRecord = 14

function SkinEffect:ctor(role)
end

function SkinEffect:onCreate()
	self:onLoad()
end

function SkinEffect:onLoad()
	self.cache = self.role.cache.skin_data
	self:Load()
end

function SkinEffect:WearPartHook(partid)
	self.role:SetShow(5, partid)
end

function SkinEffect:Release()
end

function SkinEffect:SendClientMsg()
	local msg = self:GetMsgData()
	server.sendReq(self.player, "sc_effect_skin_update", msg)
end

server.playerCenter:SetEvent(SkinEffect, "role.skineffect")
return SkinEffect