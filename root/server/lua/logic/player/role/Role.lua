local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local LogicEntity = require "modules.LogicEntity"
local tbname = "roles"

local Role = oo.class(LogicEntity)

function Role:ctor(player)
end

function Role:onCreate()
	self.cache = server.mysqlBlob:CreateDmg(tbname, { playerid = self.player.dbid })
	self:onLevelUp(0, self.player.cache.level)
end

function Role:onLoad()
    self.cache = server.mysqlBlob:LoadOneDmg(tbname, { playerid = self.player.dbid })
    if not self.cache then
        lua_app.log_error(string.format("Role:onLoad error playerid => %s", self.player.dbid))
		return
	end
	self:onLevelUp(0, self.player.cache.level)
end

function Role:onRelease()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

function Role:onInitClient()
    local cache = self.cache
	local msg = {
		power           = cache.totalpower,
		skillDatas      = self.skill:GetMsgData(),
		skillSortDatas  = self.skill:GetSortMsgData(),
		equipsData      = self.equip:GetMsgData(),
		attributeData   = lua_util.ConverToArray(self.attrs, 0, EntityConfig.Attr.atCount),
		attributeExData = lua_util.ConverToArray(self.exattrs, 0, EntityConfig.ExAttr.eatCount),
	}
	server.sendReq(self.player, "sub_roles", { roleList = msg })
end

function Role:onLogout()
	self.cache()
end

function Role:onLevelUp(oldlevel, newlevel)
	local job = self.player.cache.job
	local defaultBaseAttr = server.configCenter.RoleConfig
	if not defaultBaseAttr[newlevel] then
		lua_app.log_error(string.format( "Role:onLevelUp not role level => %s", newlevel))
		return
	end
	local oldBaseAttr = defaultBaseAttr[oldlevel] and defaultBaseAttr[oldlevel][job].attrs or {}
	local newBaseAttr = defaultBaseAttr[newlevel][job].attrs
	self:UpdateBaseAttr(oldBaseAttr, newBaseAttr, server.baseConfig.AttrRecord.LevelUp)
	self.player:CheckOpenFunc({type = server.funcOpen.CondType.Lv, value = newlevel})
end

server.playerCenter:SetEvent(Role, "role")
return Role