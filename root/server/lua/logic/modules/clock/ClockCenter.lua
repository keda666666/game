local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"

local ClockCenter = {}

function ClockCenter:Init()
	-- self:StartCrossTeamTimer()
	self:StartAnswerTimer()
end

function ClockCenter:Release()
end

-- function ClockCenter:StartCrossTeamTimer()
-- 	local CrossTeamConfig = server.configCenter.CrossTeamConfig
-- 	local resetRewardTime = string.format("%02d:%02d:00", CrossTeamConfig.resetRewardTime.hour, CrossTeamConfig.resetRewardTime.minute)
-- 	lua_timer.add_timer_day(resetRewardTime, -1, self.DoCrossTeamTimer, self)
-- end

-- function ClockCenter:DoCrossTeamTimer()
-- 	self.crossTeamResetRewardTime = lua_app.now()
-- 	local players = server.playerCenter:GetOnlinePlayers()
-- 	for _, player in pairs(players) do
-- 		player.crossTeam:ResetRewardCount(self.crossTeamResetRewardTime)
-- 	end
-- end

function ClockCenter:StartAnswerTimer()
	local AnswerBaseConfig = server.configCenter.AnswerBaseConfig
	local startTime = AnswerBaseConfig.opentime
	local messageTime = AnswerBaseConfig.tipstime
	lua_timer.add_timer_day(messageTime, -1, self.DoAnswerMessage, self)
	lua_timer.add_timer_day(startTime, -1, self.DoAnswerTimer, self)
end

function ClockCenter:DoAnswerMessage()
	server.dailyActivityCenter:DoAnswerMessage()
end

function ClockCenter:DoAnswerTimer()
	self.crossTeamResetRewardTime = lua_app.now()
	server.answerCenter:Start()
end

server.SetCenter(ClockCenter, "clockCenter")
return ClockCenter
