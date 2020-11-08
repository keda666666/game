local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local _PayPlayerNumeric = {}

_PayPlayerNumeric[ItemConfig.NumericType.Gold] = function(player, count, type, log)
    return player:PayGold(count, type, log)
end

_PayPlayerNumeric[ItemConfig.NumericType.YuanBao] = function(player, count, type, log)
    return player:PayYuanBao(count, type, log)
end

_PayPlayerNumeric[ItemConfig.NumericType.BYB] = function(player, count, type, log)
    return player:PayBYB(count, type, log)
end

_PayPlayerNumeric[ItemConfig.NumericType.GuildContrib] = function(player, count, type, log)
	return player:PayContribute(count, type, log)
end

_PayPlayerNumeric[ItemConfig.NumericType.Medal] = function(player, count, type, log)
	return player:PayMedal(count, type, log)
end

return _PayPlayerNumeric
