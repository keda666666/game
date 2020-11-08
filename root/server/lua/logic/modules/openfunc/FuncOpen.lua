local server = require "server"
local lua_app = require "lua_app"

local FuncOpen = {}
FuncOpen.OpenType = {
	Bag				= 1,
	Strengthen		= 2,
	Gemstone		= 3,
	Forge			= 4,
	UpStar			= 5,
	Mix				= 6,
	Horse			= 7,
	Wing			= 8,
	AttrDan			= 9,
	Dress			= 10,
	Title			= 11,
	Role			= 12,
}

FuncOpen.CondType = {
	Chapter = 1,
	Lv = 2,
	Task = 3,
}

local _CheckCond = {}
_CheckCond[1] = function(player, value)	-- 通关关卡数
	return player.cache.chapter.chapterlevel >= value
end

_CheckCond[2] = function(player, value)	-- 人物等级
	return player.cache.level >= value
end

_CheckCond[3] = function(player, value)	-- VIP等级
	return player.cache.vip >= value
end

_CheckCond[4] = function(player, value)	-- 开服天数
	return server.serverRunDay >= value
end

-- _CheckCond[5] = function(player, value)	-- 登录天数
-- end

-- _CheckCond[6] = function(player, value)	-- 开服周数
-- end

function FuncOpen:Check(player, id)
	local cfg = server.configCenter.FuncOpenConfig[id]
	local ret = _CheckCond[cfg.conditionkind](player, cfg.conditionnum)
	if cfg.conditionkind2 then
		if cfg.condition ~= 2 then
			ret = ret and _CheckCond[cfg.conditionkind2](player, cfg.conditionnum2)
		else
			ret = ret or _CheckCond[cfg.conditionkind2](player, cfg.conditionnum2)
		end
	end
	return ret
end

function FuncOpen:CheckOpen(day)
	return (server.serverRunDay >= day)
end

server.SetCenter(FuncOpen, "funcOpen")
return FuncOpen