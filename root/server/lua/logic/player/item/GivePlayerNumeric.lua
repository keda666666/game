local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local _GivePlayerNumeric = {}

_GivePlayerNumeric[ItemConfig.NumericType.Exp] = function(player, count)
	player:AddExp(count)
end

_GivePlayerNumeric[ItemConfig.NumericType.Gold] = function(player, count, type, log)
	player:ChangeGold(count, type, log)
end

_GivePlayerNumeric[ItemConfig.NumericType.YuanBao] = function(player, count, type, log)
	player:ChangeYuanBao(count, type, log)
end

_GivePlayerNumeric[ItemConfig.NumericType.BYB] = function(player, count, type, log)
	player:ChangeByb(count, type, log)
end

_GivePlayerNumeric[ItemConfig.NumericType.GuildContrib] = function(player, count, type, log)
	local guild = server.guildCenter:GetGuild(player.cache.guildid)
	if not guild then
		player:ChangeContribute(count, type, log)
		return
	end
	guild:ChangeContribute(player, count)
end

_GivePlayerNumeric[ItemConfig.NumericType.GuildFund] = function(player, count)
	local guild = server.guildCenter:GetGuild(player.cache.guildid)
	if not guild then
		lua_app.log_error("_GivePlayerNumeric[ItemConfig.NumericType.GuildFund]: no guild. (" .. player.cache.name .. "," .. count .. ")")
		return
	end
	guild:UpdateFund(count)
end

_GivePlayerNumeric[ItemConfig.NumericType.Medal] = function(player, count)
	player:ChangeMedal(count, type, log)
end

_GivePlayerNumeric[ItemConfig.NumericType.Friendcoin] = function(player, count)
	player:ChangeFriendcoin(count, type, log)
end


_GivePlayerNumeric[ItemConfig.NumericType.Recharge] = function(player, count)
	player:Recharge(count)
end

return _GivePlayerNumeric
