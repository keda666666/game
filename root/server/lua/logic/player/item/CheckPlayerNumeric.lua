local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local _CheckPlayerNumeric = {}

_CheckPlayerNumeric[ItemConfig.NumericType.Gold] = function(player, count)
	return player.cache.gold >= count
end

_CheckPlayerNumeric[ItemConfig.NumericType.YuanBao] = function(player, count)
	return player.cache.yuanbao >= count
end

_CheckPlayerNumeric[ItemConfig.NumericType.BYB] = function(player, count)
	return player.cache.byb >= count
end

_CheckPlayerNumeric[ItemConfig.NumericType.GuildContrib] = function(player, count)
	return player.cache.contrib >= count
end

_CheckPlayerNumeric[ItemConfig.NumericType.Medal] = function(player, count)
	return player.cache.arena.medal >= count
end

_CheckPlayerNumeric[ItemConfig.NumericType.Friendcoin] = function(player, count)
	return player.cache.friend_data.friedncoin >= count
end

return _CheckPlayerNumeric
