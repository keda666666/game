local server = require "server"
local lua_app = require "lua_app"
local EntityConfig = require "resource.EntityConfig"

local DataPack = {}

local _GetPlayerBy = {}
function _GetPlayerBy.world(player)
	return {
		protocol		= player.protocol,
		socket			= player.socket,
		dbid			= player.dbid,
		name			= player.cache.name,
		nowserverid		= player.nowserverid,
	}
end
function _GetPlayerBy.war(player)
	return {
		protocol		= player.protocol,
		socket			= player.socket,
		dbid			= player.dbid,
		name			= player.cache.name,
		nowserverid		= player.nowserverid,
	}
end
function DataPack:GetPlayerByServer(servername, player)
	return _GetPlayerBy[servername](player)
end
function DataPack:GetPlayerPacks(player)
	local ret = {}
	for name, func in pairs(_GetPlayerBy) do
		ret[name] = func(player)
	end
	return ret
end
function DataPack:GetUsedPacks(name)
	local func = _GetPlayerBy[name]
	local ret = {}
	local players = server.playerCenter:GetPlayerDBIDs()
	for _, player in pairs(players) do
		ret[player.dbid] = func(player)
	end
	return ret
end

function DataPack:BroadcastDtbAndLocal(...)
	for name, _ in pairs(_GetPlayerBy) do
		server.serverCenter:SendDtbAndLocal(name, ...)
	end
end

function DataPack:onLogin(player)
	for name, func in pairs(_GetPlayerBy) do
		server.serverCenter:SendDtbAndLocal(name, "onRecvPlayerLogin", func(player))
	end
end

function DataPack:UpdateSocket(player)
	for name, func in pairs(_GetPlayerBy) do
		server.serverCenter:SendDtbAndLocal(name, "SendRunModFun", "playerCenter", "recvLogin", func(player))
	end
end

function DataPack:onInitClient(player)
	self:BroadcastDtbAndLocal("onrecvplayerevent", server.event.clientinit, player.dbid)
end

function DataPack:onLogout(player)
	self:BroadcastDtbAndLocal("onrecvplayerevent", server.event.logout, player.dbid)
end


function DataPack:PlayerInfo(player)
	local data = {}
	data.dbid = player.dbid
	data.serverid = player.cache.serverid
	data.name = player.cache.name
	data.level = player.cache.level
	data.job = player.cache.job
	data.sex = player.cache.sex
	data.power = player.cache.totalpower
	return data
end

local _SetOtherShows = {}
_SetOtherShows[EntityConfig.EntityType.Role] = function(shows, entity)
	shows.job = entity.player.cache.job
	shows.sex = entity.player.cache.sex
	shows.name = entity.player.cache.name
	shows.serverid = server.serverid
	shows.guildid = entity.player.cache.guildid
	shows.guildname = entity.player.guild:GetGuildName()
end
_SetOtherShows[EntityConfig.EntityType.Pet] = function(shows, entity, num)
	shows.id = entity.cache.outbound[num]
	shows.name = entity.cache.list[shows.id] and entity.cache.list[shows.id].name or ""
end
_SetOtherShows[EntityConfig.EntityType.Xianlv] = function(shows, entity, num)
	shows.id = entity.cache.outbound[num]
end

_SetOtherShows[EntityConfig.EntityType.Xianjun] = function(shows, entity, num)
	shows.id = entity.cache.outbound[num]
	shows.name = entity.cache.list[shows.id] and entity.cache.list[shows.id].name or ""
end

_SetOtherShows[EntityConfig.EntityType.Tiannv] = function(shows, entity, num)
	-- shows.id = 90001--entity.cache.outbound[num]
end
_SetOtherShows[EntityConfig.EntityType.Tianshen] = function(shows, entity, num)
	shows.id = entity.cache.use
end
_SetOtherShows[EntityConfig.EntityType.Baby] = function(shows, entity, num)
	shows.id = entity.cache.sex
end

function DataPack:EntityInfo(etype, entity, num, pos, iswait)
	local skilllist = entity:GetSkill(num)
	if not skilllist then return end
	local skillsort = entity:GetSkillSort(num)
	local data = {}
	data.etype = etype
	data.pos = pos
	data.skilllist = skilllist
	data.skillsort = skillsort
	data.buffinit = entity:GetBuff(num)
	data.shows = {
		shows = entity:GetShows(),
	}
	data.iswait = iswait
	data.power = entity:GetPower()
	_SetOtherShows[etype](data.shows, entity, num)
	return data
end

function DataPack:AddEntityInfo(datas, etype, entity, num, pos, iswait)
	local data = self:EntityInfo(etype, entity, num, pos, iswait)
	if data then
		table.insert(datas, data)
	end
end
function DataPack:FightInfoByDBID(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	return self:FightInfo(player)
end

function DataPack:FightInfo(player)
	local datas = {}
	self:AddEntityInfo(datas, EntityConfig.EntityType.Role, player.role, 1, 8)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 1, 3)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 2, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 3, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 4, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianlv, player.xianlv, 1, 7)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianlv, player.xianlv, 2, 9)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianjun, player.xianjun, 1, 4)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianjun, player.xianjun, 2, 4,true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianjun, player.xianjun, 3, 4,true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Xianjun, player.xianjun, 4, 4,true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Tiannv, player.tiannv, 1, 6)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Tianshen, player.tianshen, 1, 10)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Baby, player.baby, 1, 2)
	local playerinfo = self:PlayerInfo(player)
	playerinfo.attrs = EntityConfig:GetRealAttr(player.attrs, player.exattrs)
	return {
		playerinfo = playerinfo,
		entitydatas = datas,
	}
end

function DataPack:SimpleFightInfoByDBID(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	return self:SimpleFightInfo(player)
end

-- 组队的战斗数据只需要主角和宠物
function DataPack:SimpleFightInfo(player)
	local datas = {}
	self:AddEntityInfo(datas, EntityConfig.EntityType.Role, player.role, 1, 8)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 1, 3)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 2, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 3, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 4, 3, true)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Tiannv, player.tiannv, 1, 4)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Tianshen, player.tianshen, 1, 7)
	self:AddEntityInfo(datas, EntityConfig.EntityType.Baby, player.baby, 1, 2)
	local playerinfo = self:PlayerInfo(player)
	playerinfo.attrs = EntityConfig:GetRealAttr(player.attrs, player.exattrs)
	return {
		playerinfo = playerinfo,
		entitydatas = datas,
	}
end

function server.GetSimpleFightInfo(src, dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	lua_app.ret(server.dataPack:SimpleFightInfo(player))
end

function DataPack:TeamFightInfoByDBID(dbidlist)
	local playerlist = {}
	for __,dbid in ipairs(dbidlist) do
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		if player then
			table.insert(playerlist, player)
		end
	end
	return self:TeamFightInfo(playerlist)
end

function DataPack:TeamFightInfo(playerlist)
	local maxplayer
	local maxpower = 0
	for _, player in pairs(playerlist) do
		if player.cache.totalpower > maxpower then
			maxplayer = player
		end
	end

	local dataslist = {}
	for _, player in pairs(playerlist) do
		if maxplayer and maxplayer.dbid == player.dbid then
			table.insert(dataslist, self:SimpleFightInfo(player))
		else
			local datas = {}
			self:AddEntityInfo(datas, EntityConfig.EntityType.Role, player.role, 1, 8)
			self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 1, 3)
			self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 2, 3, true)
			self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 3, 3, true)
			self:AddEntityInfo(datas, EntityConfig.EntityType.Pet, player.pet, 4, 3, true)
			local playerinfo = self:PlayerInfo(player)
			playerinfo.attrs = EntityConfig:GetRealAttr(player.attrs, player.exattrs)
			table.insert(dataslist,  {playerinfo = playerinfo, entitydatas = datas})
		end
	end
	return dataslist
end

function server.GetPlayerBaseinfoByServer(src, servername, dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		lua_app.ret(false)
		return
	end
	lua_app.ret(_GetPlayerBy[servername](player))
end

server.SetCenter(DataPack, "dataPack")
return DataPack