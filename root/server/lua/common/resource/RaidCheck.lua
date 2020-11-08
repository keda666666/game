local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local RaidConfig = require "resource.RaidConfig"
local _RaidType = RaidConfig.type

local RaidCheck = {}

----------------检查是否可以打副本 用于组队检查------------------
local _Check = {}

_Check[_RaidType.CrossTeamFb] = function(player, raidtype, level)
	return player.cache.level >= level
end

_Check[_RaidType.GuildFb] = function(player, raidtype, level)
	if player.cache.guildid == 0 then return false end
	return player.guild.guildDungeon:CheckEnter(level)
end

_Check[_RaidType.EightyOneHard] = function(player, raidtype, level)
	return player.eightyOneHard:Check(level)
end

_Check[_RaidType.Guildwar] = function(player, raidtype, level)
	return player.eightyOneHard:Check(level)
end

function RaidCheck:Check(dbid, raidtype, level)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then return false end

	if _Check[raidtype] then
		return _Check[raidtype](player, raidtype, level)
	else
		return true
	end
end

local _CheckExistMap = setmetatable({}, {
		__index = function()
			return function() return true end 
		end
	})
_CheckExistMap[_RaidType.Guildwar] = function(dbid, leaderid)
	return server.guildwarCenter:CanJoinTeam(dbid, leaderid)
end

_CheckExistMap[_RaidType.GuildwarPk] = function(dbid, leaderid)
	return server.guildwarCenter:CanJoinTeam(dbid, leaderid)
end

-----------------------检查是否在同一地图内-----------------------
function RaidCheck:CheckExistMap(raidtype, dbid, leaderid)
	if not _CheckExistMap[raidtype](dbid, leaderid) then
		server.sendErrByDBID(dbid, "队长不在同一地图内，不能加入")
		return false
	end
	return true
end

----------------检查是否可以加入队伍 用于组队检查------------------
local _CheckOnWar = {}

_CheckOnWar[_RaidType.KingCity] = function(dbid, raidtype, level)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if not player then return false end

	return server.kingCenter:CanTeam(dbid)
end

function RaidCheck:CheckCanTeam(dbid, raidtype, level)
	if _CheckOnWar[raidtype] then
		return _CheckOnWar[raidtype](dbid, raidtype, level)
	else
		return true
	end
end

------------------检查玩家镜像是否可以加副本入队伍--------------------
local _CheckRobot = {}

_CheckRobot[_RaidType.CrossTeamFb] = function(player, target, raidtype, level)
	return player.cache.level >= level
end

_CheckRobot[_RaidType.GuildFb] = function(player, target, raidtype, level)
	return player.cache.guildid == target.guildid
end

function RaidCheck:CheckRobot(dbid, target, raidtype, level)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then return false end

	if _CheckRobot[raidtype] then
		return _CheckRobot[raidtype](player, target, raidtype, level)
	else
		return true
	end
end

---------------------拥有多种玩法的副本-------------------------
local MixRaidType = {}
MixRaidType[_RaidType.KFBoss] = function()
	return server.kfBossCenter:IsCrossGames()
end

---------------------检查副本类型是否为跨服副本-------------------------
function RaidCheck:CheckCross(raidtype)
	if raidtype == _RaidType.CrossTeamFb or
		raidtype == _RaidType.KingCity or
		raidtype == _RaidType.KingPK or
		raidtype == _RaidType.GuildMine or
		raidtype == _RaidType.ClimbPK or
		raidtype == _RaidType.EightyOneHard or
		raidtype == _RaidType.Guildwar or
		raidtype == _RaidType.GuildwarPk or
		raidtype == _RaidType.KingArena then
		return true
	elseif MixRaidType[raidtype] then
		return MixRaidType[raidtype]()
	else
		return false
	end
end

---------------------检查副本类型是否需要机器人-------------------------
function RaidCheck:CheckNeedRobot(raidtype)
	if raidtype == _RaidType.CrossTeamFb or
		raidtype == _RaidType.GuildFb then
		return true
	else
		return false
	end
end

---------------------检查副本类型是否需要地图广播-------------------------
function RaidCheck:CheckMapBroadcast(raidtype)
	if raidtype == _RaidType.KingCity then
		return true
	else
		return false
	end
end

return RaidCheck