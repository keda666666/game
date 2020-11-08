local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"

local AttackSort = {}
local EntitySpeedType = EntityConfig.Attr.atSpeed

function AttackSort.SortBySpeed(playerorder)
	table.sort(playerorder, function(a, b)
			return a:GetAttr(EntitySpeedType) > b:GetAttr(EntitySpeedType)
		end)
end

return AttackSort