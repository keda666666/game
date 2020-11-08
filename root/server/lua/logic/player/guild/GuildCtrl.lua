local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_shield = require "lua_shield"
local GuildConfig = require "common.resource.GuildConfig"
local GuildDonate = require "player.guild.GuildDonate"
local GuildSkill = require "player.guild.GuildSkill"
local GuildPeach = require "player.guild.GuildPeach"
local GuildProtector = require "player.guild.GuildProtector"
local GuildMap = require "player.guild.GuildMap"
local GuildDungeon = require "player.guild.GuildDungeon"
local ChatConfig = require "resource.ChatConfig"

local GuildCtrl = oo.class()

function GuildCtrl:ctor(player)
	self.player = player
	self.guildSkill = GuildSkill.new(player, self)
	self.guildPeach = GuildPeach.new(player, self)
	self.guildDonate = GuildDonate.new(player, self)
	self.guildProtector = GuildProtector.new(player, self)
	self.guildMap = GuildMap.new(player, self)
	self.guildDungeon = GuildDungeon.new(player, self)
end

function GuildCtrl:onCreate()
	self:onLoad()
end

function GuildCtrl:onLoad()
	self.cache = self.player.cache.guild_data
	self:Init(self.cache.guilddata)
end

function GuildCtrl:onInitClient()
	for guildId,_ in pairs(self.cache.applyrecord) do
		local guild = server.guildCenter:GetGuild(guildId)
		if guild then
			guild:UpdateApplyInfo(self.player)
		end
	end
	if self.player.cache.guildid ~= 0 then
		self.guildProtector:onLogin()
		self.guildDonate:onLogin()
	end
end

function GuildCtrl:Init(datas)
	self.guildSkill:Init(datas)
	self.guildPeach:Init(datas)
	self.guildDonate:Init(datas)
	self.guildProtector:Init(datas)
	self.guildMap:Init(datas)
	self.guildDungeon:Init(datas)
end

function GuildCtrl:GetGuild()
	return server.guildCenter:GetGuild(self.player.cache.guildid)
end

function GuildCtrl:GetGuildLevel()
	local guild = server.guildCenter:GetGuild(self.player.cache.guildid)
	if not guild then
		return
	end
	return guild:GetLevel()
end

local _emptyGuildplayerInfo = {
	contribute 		= 0,
	curcontribute	= 0,
	office 			= GuildConfig.Office.Common,
}

function GuildCtrl:SendGuildData()
    local guild = self:GetGuild()
    if not guild then
    	server.sendReq(self.player, "sc_guild_playerinfo", _emptyGuildplayerInfo)
    	return
    end
    server.sendReq(self.player, "sc_guild_playerinfo", guild:GetPlayerInfo(self.player.dbid))
end

function GuildCtrl:GetGuildName()
	local guild = self:GetGuild()
    if not guild then
    	return
    end
    return guild:GetName()
end

function GuildCtrl:GetLeaderName()
	local guild = self:GetGuild()
    if not guild then
    	return
    end
    return guild.leader.playername
end

function GuildCtrl:Chat(str)
    local guild = self:GetGuild()
    if not guild then
    	lua_app.log_error("GuildCtrl:Chat: no guild", self.player.cache.name)
    	return
    end
    local chatMsg = lua_shield:string(str)
    guild.guildRecord:AddGuildChat(chatMsg, self.player.dbid)
end

function GuildCtrl:ChatLink(shareid, ttype, ...)
    local guild = self:GetGuild()
    if not guild then
    	lua_app.log_error("GuildCtrl:Chat: no guild", self.player.cache.name)
    	return
    end
   	local chatdata = ChatConfig:PackLinkData(shareid, self.player, ...)
    guild.guildRecord:AddGuildChat(chatdata.str, self.player.dbid, chatdata.share, ttype)
end

function GuildCtrl:GetPlayers()
	local guild = self:GetGuild()
    if not guild then
    	return {}
    end
    return guild:GetPlayers()
end

function GuildCtrl:onJoinGuild(guild)
	self:SetGuildChange(guild.dbid)
end

function GuildCtrl:SetGuildChange(guildid)
	self.player.cache.guildid = guildid
	self:SendGuildChange()
	self.player.shop:onUpdateUnlock()
end

function GuildCtrl:SendGuildChange()
    local guild = self:GetGuild()
    if not guild then
    	server.sendReq(self.player, "player_guild_change", { guildID = 0 })
    	return
    end
    server.sendReq(self.player,"player_guild_change", {
    		guildID = self.player.cache.guildid,
    		guildName = guild.cache.name,
    	})
end

function GuildCtrl:onLeaveGuild(guild)
    self:SetGuildChange(0)
end

function GuildCtrl:UpdateActive(...)
	self.guildProtector:UpdateActive(...)
end

function GuildCtrl:ApplyUndo(guildId)
	self.cache.applyrecord[guildId] = nil
	self:SendApplyInfo()
end

function GuildCtrl:ApplyJoin(guild)
	local GuildConfig = server.configCenter.GuildConfig
	local applyMaxNum = GuildConfig.applycount
	if self:ApplyCount() >= applyMaxNum then
		lua_app.log_info("ApplyJoin faild. player applyCount("..self:ApplyCount()..") >= applyMaxNum("..applyMaxNum..")")
		return
	end
	guild:JoinGuild(self.player)
	if guild:IsApplySucess(self.player) then
		self.cache.applyrecord[guild.dbid] = true
	end
	self:SendApplyInfo()
end

function GuildCtrl:onLevelUp()
	self:UpdatePlayerInfo()
end

function GuildCtrl:UpdatePlayerInfo()
	local guild = self:GetGuild()
    if not guild then
    	return
    end
    guild:UpdatePlayerInfo(self.player)
end

function GuildCtrl:ApplyCount()
	return lua_util.length(self.cache.applyrecord)
end

function GuildCtrl:SendApplyInfo()
	local datas = {}
	for guildId,_ in pairs(self.cache.applyrecord) do
		local guild = server.guildCenter:GetGuild(guildId)
		table.insert(datas, guild.summary)
	end
	server.sendReq(self.player, "sc_guild_apply_list", { guilds = datas })
end

function GuildCtrl:onDayTimer()
	self.guildPeach:onDayTimer()
	self.guildDonate:onDayTimer()
	self.guildProtector:onDayTimer()
	self.guildDungeon:onDayTimer()
	self.guildMap:onDayTimer()
end

function GuildCtrl:onLogout()
	for guildId,_ in pairs(self.cache.applyrecord) do
		local guild = server.guildCenter:GetGuild(guildId)
		if guild then
			guild:UpdateApplyInfo(self.player, true)
		end
	end
end

server.playerCenter:SetEvent(GuildCtrl, "guild")

return GuildCtrl
