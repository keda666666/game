local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"
local lua_util = require "lua_util"

local Panacea = oo.class()
local _maxPos = 8


function Panacea:ctor(role)
	self.role = role
	self.player = role.player
end

function Panacea:onCreate()
	self:onLoad()
end

function Panacea:Init()
	for posId = 1, _maxPos do
		if not self.lvlist[posId] then
			self.lvlist[posId] = 0
		end
	end
	if lua_util.empty(self.cache.allattrs) then
		for attrType = 1, 8 do
			table.insert(self.cache.allattrs, {
				type = attrType,
				value = 0,
				})
		end
	end
end

function Panacea:onLoad()
	self.cache = self.role.cache.panacea_data
	self.lvlist = self.cache.lvlist
	self:Init()
	self:UpdateAttrs({}, self.cache.allattrs)
end

function Panacea:onInitClient()
	self:SendClientMsg()
end

function Panacea:UsePanacea(pos)
	local oldlv = self.lvlist[pos + 1]
	if not oldlv then
		lua_app.log_info("UsePanacea pod error. pos:"..pos)
		return
	end
	local PanaceaConfig = server.configCenter.PanaceaConfig
	local itemconf = PanaceaConfig[pos + 1]
	if not self.player:PayRewards({itemconf.itemid}, server.baseConfig.YuanbaoRecordType.Panacea) then
		lua_app.log_info("PayRewards fail.", itemconf.itemid.type, itemconf.itemid.id, itemconf.itemid.count)
		return
	end
	self.lvlist[pos + 1] = oldlv + 1
	self:UpdateAttrs({}, itemconf.attrpower)
	self:AddAttrsRecord(itemconf.attrpower)
	self:SendClientMsg()
end

function Panacea:AddAttrsRecord(addAttrs)
	local totalAttrs = self.cache.allattrs
	for _, addAttr in ipairs(addAttrs) do
		local findIndex
		for i, attr in ipairs(totalAttrs) do
			if attr.type == addAttr.type then
				findIndex = i
				break
			end
		end
		if not findIndex then
			local newAttr = table.wcopy(addAttr)
			table.insert(totalAttrs, newAttr)
		else
			totalAttrs[findIndex].value = totalAttrs[findIndex].value + addAttr.value
		end
	end
end

function Panacea:UpdateAttrs(oldattrs, newattrs)
	self.role:UpdateBaseAttr(oldattrs or {}, newattrs, server.baseConfig.AttrRecord.Panacea)
end

function Panacea:SendClientMsg()
	local msg = {}
	msg.lvlist =self.lvlist
	msg.attrs = self.cache.allattrs
	server.sendReq(self.player, "sc_panacea_update", msg)
end

function Panacea:onLogout()
end

function Panacea:Release()
end

server.playerCenter:SetEvent(Panacea, "role.panacea")
return Panacea