local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"
local lua_app = require "lua_app"
local EffectBase = require "player.role.effect.EffectBase"
local TEMPLATE = require "player.template.Template"

local TitleEffect = oo.class(EffectBase)

TitleEffect.id = server.baseConfig.YuanbaoRecordType.Skin
TitleEffect.describe = ""
TitleEffect.conf = "TitleConf"
TitleEffect.attrRecord = 15


function TitleEffect:ctor(role)
end

function TitleEffect:onCreate()
	self:onLoad()
end

function TitleEffect:onLoad()
	self.cache = self.role.cache.title_data
	self:Load()
end

function TitleEffect:ActivatePartHook(id)
	TEMPLATE:AddTitleAttr(self.player, id)
end

function TitleEffect:WearPartHook(partid)
	self.role:SetShow(6, partid)
end

function TitleEffect:Release()
end

function TitleEffect:SendClientMsg()
	local msg = self:GetMsgData()
	server.sendReq(self.player, "sc_effect_title_update", msg)
end

server.playerCenter:SetEvent(TitleEffect, "role.titleeffect")
return TitleEffect