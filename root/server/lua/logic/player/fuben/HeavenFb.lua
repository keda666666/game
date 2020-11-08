local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local HeavenFb = oo.class()


function HeavenFb:ctor(player)
	self.player = player
	self.role = player.role
end

function HeavenFb:onCreate()
	self.cache = self.player.cache.heavenFb
end

function HeavenFb:onLoad()
	self.cache = self.player.cache.heavenFb
end

function HeavenFb:onInitClient()
	--发协议给客户端
	local msg = self:packHeavenFbInfo()
	server.sendReq(self.player, "sc_fuben_heavenFb_info", msg)
end

function HeavenFb:packHeavenFbInfo()
	local data = self.cache
	local msg = {
		layer = data.layer,
		todayLayer = data.todayLayer,
		rewardNo = {},
	}
	for k,_ in pairs(data.rewardNo) do
		table.insert(msg.rewardNo, k)
	end
	return msg
end

function HeavenFb:SweepReward()
	local baseConfig = server.configCenter.HeavenFbBaseConfig
	if self.player.cache.vip < baseConfig.viplv then return end
	local heavenFbConfig = server.configCenter.HeavenFbConfig
	local clearNum = 0
	for i = (self.cache.todayLayer + 1), self.cache.layer do
		clearNum = clearNum + 1
		local reward = table.wcopy(heavenFbConfig[i].dayAward)
		if reward then
			self.player:GiveRewardAsFullMailDefault(reward, "勇闯天庭扫荡", server.baseConfig.YuanbaoRecordType.HeavenFb, "勇闯天庭扫荡"..i)
		end
	end
	for i=1, clearNum do
		self.player.task:onEventAdd(server.taskConfig.ConditionType.HeavenFb)
	end
	self.player.enhance:AddPoint(17, clearNum)
	self.cache.todayLayer = self.cache.layer
	self:onInitClient()
end

function HeavenFb:SetValue(data)
	self.cache.layer = data.layer
	self.cache.todayLayer = data.todayLayer
end

function HeavenFb:LayerReward(fubenNo)
	if fubenNo > self.cache.layer then return end
	local heavenFbConfig = server.configCenter.HeavenFbConfig[fubenNo]
	if not heavenFbConfig.firstAward then return end
	if self.cache.rewardNo[fubenNo] then return end
	 self.cache.rewardNo[fubenNo] = 1
	local rewards = table.wcopy(heavenFbConfig.firstAward)
	self.player:GiveRewardAsFullMailDefault(rewards, "勇闯天庭奖励", server.baseConfig.YuanbaoRecordType.TreasureMap, "藏宝图星级奖励"..fubenNo)
	
	local msg = {rewardNo = {}}
	for k,_ in pairs(self.cache.rewardNo) do
		table.insert(msg.rewardNo, k)
	end
	server.sendReq(self.player, "sc_fuben_heavenFb_reward", msg)
end

function HeavenFb:onDayTimer()
	self.cache.todayLayer = 0
	self:onInitClient()
end

server.playerCenter:SetEvent(HeavenFb, "heavenFb")
return HeavenFb