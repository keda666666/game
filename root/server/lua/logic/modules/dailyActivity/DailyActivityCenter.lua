local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local DailyActivityConfig = require "resource.DailyActivityConfig"
local DailyActivityCenter = {}
local _ActivityType = DailyActivityConfig.type
local RankConfig = require "resource.RankConfig"

function DailyActivityCenter:Init()
	self.answer = ""
	self.avgLv = 0
	self.rankData = {}
	self.activityRecord = {}
end

function DailyActivityCenter:onDayTimer()
	self:GetAvgLv()
end

function DailyActivityCenter:DoAnswerMessage()
	local players = server.playerCenter:GetOnlinePlayers()
	local msg = {activity = 1}
	for _, player in pairs(players) do
		self:Msg(player, msg)
	end
end

function DailyActivityCenter:BroadcastMessage(activityid)
	local players = server.playerCenter:GetOnlinePlayers()
	local msg = {activity = activityid}
	for _, player in pairs(players) do
		self:Msg(player, msg)
	end
end

function DailyActivityCenter:ActData(dbid)
	local msg = {
			answer = self.answer,
		}
	server.sendReqByDBID(dbid, "sc_activity_info_res", msg)
end

function DailyActivityCenter:updateData(key, data)
	self[key] = data
end

function DailyActivityCenter:Msg(player, msg)
	
	server.sendReq(player, "sc_activity_msg", msg)
end

function DailyActivityCenter:onInitClient(player)
	self:Hall(player)
end

-- 进入活动
local _Enter = {}
_Enter[_ActivityType.Answer] = function(player)
end

_Enter[_ActivityType.Escort] = function(player)
end

_Enter[_ActivityType.GuildBoss] = function(player)
end

_Enter[_ActivityType.King] = function(player)
	server.kingMgr:Join(player)
end

_Enter[_ActivityType.Climb] = function(player)
	server.climbMgr:Enter(player)
end

local _OpenCheck = {}

_OpenCheck[1] = function(palyer, req)
	return false
end

_OpenCheck[2] = function(palyer, req)
	return palyer.cache.level >= req
end

_OpenCheck[3] = function(palyer, req)
	return palyer.cache.Vip >= req
end

_OpenCheck[4] = function(palyer, req)
	return false
end

_OpenCheck[5] = function(palyer, req)
	return false
end

_OpenCheck[6] = function(palyer, req)
end

function DailyActivityCenter:Enter(player, activity)
	local data = server.configCenter.ActivityListConfig[activity]
	local openConfig = server.configCenter.FuncOpenConfig[data.openlv]
	if not _OpenCheck[openConfig.conditionkind](player, openConfig.conditionnum) then return end 
	if _Enter[activity] then
		_Enter[activity](player)
	end
end


local _IsOpen = {}
_IsOpen[_ActivityType.Answer] = function(player)
	return server.dailyActivityCenter.answerOpen or false
end

_IsOpen[_ActivityType.Escort] = function(player)
	return true
end

_IsOpen[_ActivityType.GuildBoss] = function(player)
	return server.dailyActivityCenter.guildBossOpen or false
end

_IsOpen[_ActivityType.King] = function(player)
	return server.kingMgr:IsOpen()
end

_IsOpen[_ActivityType.Climb] = function(player)
	return server.climbMgr:IsOpen()
end

_IsOpen[_ActivityType.GuildWar] = function(player)
	return server.guildwarMgr:IsOpen()
end

_IsOpen[_ActivityType.GuildMine] = function(player)
	return server.guildMinewarMgr:IsOpen()
end

-- 大厅数据
function DailyActivityCenter:Hall(player)
	local msg = {}
	msg.activitys = {}
	local ActList = server.configCenter.ActivityListConfig
	for activityid, data in pairs(ActList) do
		local isopen = false
		local openConfig = server.configCenter.FuncOpenConfig[data.openlv]
		if not _OpenCheck[openConfig.conditionkind](player, openConfig.conditionnum) then 
			isopen = false
		else
			if _IsOpen[activityid] then
				isopen = _IsOpen[activityid](player)
			end
		end
		table.insert(msg.activitys, {activity = activityid, isopen = isopen})
	end
	player:sendReq("sc_activity_hall", msg)
end

function DailyActivityCenter:Brodcast()
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		self:Hall(player)
	end
end

function DailyActivityCenter:AvgLv()
	if self.avgLv == 0 then
		self:GetAvgLv()
	end
	return self.avgLv
end

function DailyActivityCenter:RankData()
	if not next(self.rankData) then
		self:GetAvgLv()
	end
	return self.avgLv, self.rankData
end

function DailyActivityCenter:GetAvgLv()
	local num = 0
	local lv = 0
	local baseConfig = server.configCenter.WelfareBaseConfig
	self.rankData = {}
	local data = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas", RankConfig.RankType.LEVEL, 1, baseConfig.worldlv)
	for k,v in pairs(data) do
		lv = lv + v.level
		num = num + 1

		local player = server.playerCenter:DoGetPlayerByDBID(v.id)
		table.insert(self.rankData, player.role:GetEntityShows())
	end
	if lv ~= 0 then
		self.avgLv = math.floor((lv / num) + 1)
	end

end

function DailyActivityCenter:SetGuildBoss(isopen)
	self.guildBossOpen = isopen
	self:Brodcast()
end

function DailyActivityCenter:SetAnswer(isopen)
	self.answerOpen = isopen
	self:Brodcast()
end

function DailyActivityCenter:SendJoinActivity(activityname, playerid)
	self.activityRecord[server.serverRunDay] = self.activityRecord[server.serverRunDay] or {}
	self.activityRecord[server.serverRunDay][activityname] = self.activityRecord[server.serverRunDay][activityname] or {}
	if self.activityRecord[server.serverRunDay][activityname][playerid] then
		return
	end
	self.activityRecord[server.serverRunDay][activityname][playerid] = true
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
    server.serverCenter:SendDtbMod("httpr", "recordDatas", "SendJoinActivity", {
            serverid = player.cache.serverid,
            serverrunday = server.serverRunDay,
            playerid = player.dbid,
           	activityname = activityname,
        })
end

server.SetCenter(DailyActivityCenter, "dailyActivityCenter")
return DailyActivityCenter
