local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"

local Answer = oo.class()

function Answer:ctor(player)
	-- local femaleDevaBaseConfig = server.configCenter.FemaleDevaBaseConfig
	-- FightConfig.FightStatus.Running
	-- self.skilllist = {{[3] = {11001}}}
	-- self:AddSkill(11001, true, 1)
	-- self.hskillNo = femaleDevaBaseConfig.hskill
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.TianShenSpells
end

function Answer:onDayTimer()
	--每天登录是否要处理数据
end

function Answer:onCreate()
	self:onLoad()
end

function Answer:onLoad()
	--登录相关数据加载
	self.cache = self.player.cache.answer
end

function Answer:packInfo()
	local msg = {}
	return msg
end



function Answer:Allattr()
	--登录初始化数据
	local attrsList = {}
	return attrsList
end

function Answer:onInitClient()
	-- 登陆
	server.answerCenter:PlayerLogin(self.player.dbid)
	-- local msg = self:packInfo()
	-- server.sendReq(self.player, "sc_activity_info", msg)
end



-- local _airMarshalBreachConfig = false
-- function Answer:GetAirMarshalBreachConfig(no)
-- 	if _airMarshalBreachConfig then return _airMarshalBreachConfig[no] end
-- 	_airMarshalBreachConfig = server.configCenter.AirMarshalBreachConfig
-- 	return _airMarshalBreachConfig[no]
-- end

function Answer:AddAnswer()
	self.cache.answerNum = self.cache.answerNum + 1
	--发给客户端
	-- server.AnswerCenter:Answer(self.player.id, answerNo, answer)
	self.player.shop:onUpdateUnlock()
end

function Answer:GetNum()
	return self.cache.answerNum
end


server.playerCenter:SetEvent(Answer, "answer")
return Answer