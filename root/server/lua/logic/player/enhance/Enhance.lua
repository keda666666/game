local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"


local Enhance = oo.class()

function Enhance:ctor(player)
	self.player = player
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Enhance
end

function Enhance:onCreate()
	self:onLoad()
end

function Enhance:onLoad()
	--加载,计算属性
	self.cache = self.player.cache.enhance
end

function Enhance:onInitClient()
	--登录发送
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_enhance_info",msg)
end

function Enhance:onLogout(player)
	--离线
end

function Enhance:onLogin(player)
	--加载后续处理？？
end

function Enhance:onLevelUp(oldlevel, newlevel)
	--升级
end

function Enhance:onDayTimer()
	--每天第一次登录或者跨天数据处理
	local wday = lua_app.week()
	local day = server.serverRunDay - wday
	--每周清空积分和积分奖励
	if self.cache.day ~= day then
		self.cache.day = day
		self.cache.point = 0
		self.cache.rewards ={}
	end
	self.cache.data = {}
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_enhance_info",msg)
end

function Enhance:AddPoint(no, val)
	local methodConfig = server.configCenter.BianQiangMethodConfig[no]
	if not methodConfig then return end
	if (self.cache.data[no] or 0) >= methodConfig.time then return end
	self.cache.data[no] = (self.cache.data[no] or 0) + val
	if self.cache.data[no] >= methodConfig.time then
		self.cache.data[no] = methodConfig.time
		local point = methodConfig.points
		if point then
			self.cache.point = self.cache.point + point
		end
	end

	local msg = {
		no = no,
		val = self.cache.data[no],
		point = self.cache.point,
	}
	server.sendReq(self.player, "sc_enhance_add_info",msg)
end

function Enhance:GetReward(no)
	if self.cache.rewards[no] then return {ret = false} end
	local rewardConfig = server.configCenter.BianQiangRewardConfig
	if not rewardConfig[no] then return {ret = false} end
	if self.cache.point < rewardConfig[no].points then return {ret = false} end
	self.cache.rewards[no] = 1
	local rewards = rewardConfig[no].rewards
	self.player:GiveRewardAsFullMailDefault(rewards, "我要变强", self.YuanbaoRecordType, "我要变强"..no)
	
	local msg = {
		ret = true,
		no = no,
	}
	return msg
end

function Enhance:packInfo()
	local data = {}
	for k,v in pairs(self.cache.data) do
		table.insert(data, {no = k, val = v})
	end

	local rewards = {}
	for k,_ in pairs(self.cache.rewards) do
		table.insert(rewards, k)
	end
	local msg = {
		data = data,
		point = self.cache.point,
		rewards = rewards,
	}
	return msg
end

server.playerCenter:SetEvent(Enhance, "enhance")
return Enhance