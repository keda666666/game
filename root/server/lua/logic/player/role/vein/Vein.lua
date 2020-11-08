local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"

local Vein = oo.class()

local _totalAttrsBylv = false

local function _GetAttrsBylevel(level)
	if not _totalAttrsBylv then
		_totalAttrsBylv = {}
		local JingMaiLevelConfig = server.configCenter.JingMaiLevelConfig
		local maxLevel = #JingMaiLevelConfig
		local attrs = {}

		local function _RecordAttrs(newattrs)
			for _, v in pairs(newattrs) do
				attrs[v.type] = attrs[v.type] and attrs[v.type] + v.value or 0
			end
			local attrsdata = {}
			for k, v in pairs(attrs) do
				table.insert(attrsdata, {type = k, value = v})
			end
			return attrsdata
		end

		for lv = 0, maxLevel do
			_totalAttrsBylv[lv] = _RecordAttrs(JingMaiLevelConfig[lv].attr)
		end
	end

	return _totalAttrsBylv[level]
end

function Vein:ctor(role)
	self.role = role
	self.player = role.player
	
end

function Vein:onCreate()
	self:onLoad()
end

function Vein:onLoad()
	self.cache = self.role.cache.vein_data
	local level = self.cache.level
	if level == 0 then return end
	local attrs = _GetAttrsBylevel(level)
	self:UpdateAttrs(attrs)
end

function Vein:onInitClient()
	self:SendClientMsg()
end

function Vein:Breakthrough()
	local JingMaiLevelConfig = server.configCenter.JingMaiLevelConfig
	local maxLevel = #JingMaiLevelConfig
	local oldlv = self.cache.level
	if oldlv >= maxLevel then
		lua_app.log_error("Has reached the maximum level.")
		return
	end
	local JingMaiLevelConfig = server.configCenter.JingMaiLevelConfig
	local itemconf = JingMaiLevelConfig[oldlv]
	if not self.player:PayRewards({itemconf.itemid}, server.baseConfig.YuanbaoRecordType.Vein, "经脉突破") then
		lua_app.log_info("PayRewards fail.",itemconf.type, itemconf.id, itemconf.count)
		return
	end
	self:UpdateLevel(oldlv + 1)
	self:SendClientMsg()
end

function Vein:UpdateLevel(level)
	local JingMaiLevelConfig = server.configCenter.JingMaiLevelConfig
	local itemconf = JingMaiLevelConfig[level]
	local attrs = itemconf.attr
	self.cache.level = level
	self:UpdateAttrs(attrs)
end

function Vein:UpdateAttrs(attrs)
	self.role:UpdateBaseAttr({}, attrs, server.baseConfig.AttrRecord.Vein)
end

function Vein:SendClientMsg()
	local msg = {}
	msg.level = self.cache.level
	msg.totalattr = _GetAttrsBylevel(self.cache.level)
	server.sendReq(self.player, "sc_vein_update", msg)
end

function Vein:onLogout()
end

function Vein:Release()
end

server.playerCenter:SetEvent(Vein, "role.vein")
return Vein