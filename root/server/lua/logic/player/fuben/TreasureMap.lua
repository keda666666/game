local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local TreasureMap = oo.class()


function TreasureMap:ctor(player)
	self.player = player
	self.role = player.role

end

function TreasureMap:onCreate()
	self.cache = self.player.cache.treasuremap
end

function TreasureMap:onLoad()
	self.cache = self.player.cache.treasuremap
end

function TreasureMap:onInitClient()
	--发协议给客户端
	local msg = self:packTreasureMapInfo()
	server.sendReq(self.player, "sc_fuben_treasuremap_info", msg)
end

function TreasureMap:packTreasureMapInfo()
	local data = self.player.cache.treasuremap
	local msg = {data={}, starReward={}}
	for k,v in pairs(data.clearanceNum) do
		table.insert(msg.data, {
			fubenNo = k,
			todayNum = (data.todayNum[k] or 0),
			star = v,
			})
	end
	for k,v in pairs(self.cache.starReward) do
		table.insert(msg.starReward, {no=k, reward=v})
	end

	return msg
end

function TreasureMap:onDayTimer()
	self.player.cache.treasuremap.todayNum = {}
	self:onInitClient()
end

function TreasureMap:SweepReward()
	local baseConfig = server.configCenter.TreasureMapBaseConfig
	if self.player.cache.vip < baseConfig.viplevel then return end
	local treasureMapConfig = server.configCenter.TreasureMapConfig
	local clearNum = 0
	for fubenNo,_ in pairs(self.cache.clearanceNum) do
		if not self.cache.todayNum[fubenNo] then
			clearNum = clearNum + 1
			self.cache.todayNum[fubenNo] = 1
			local reward = table.wcopy(treasureMapConfig[fubenNo].everydayaward)
			self.player:GiveRewardAsFullMailDefault(reward, "藏宝图扫荡", server.baseConfig.YuanbaoRecordType.TreasureMap, "藏宝图扫荡"..fubenNo)
		end
	end
	for i=1, clearNum do
		self.player.task:onEventAdd(server.taskConfig.ConditionType.Treasuremap)
	end
	self.player.enhance:AddPoint(16, clearNum)
	self:onInitClient()
end

function TreasureMap:SetValue(data)
	for k,v in pairs(data) do
		self.cache[k] = v
	end
	-- self.cache.clearanceNum = data.clearanceNum
	-- self.cache.todayNum = data.todayNum
	-- self.cache.star = data.star
	-- self.cache.starReward = data.starReward
end

function TreasureMap:StarReward(mapNo, rewardNo)
	local star = self.cache.star[mapNo] or 0
	local treasureMapStarConfig = server.configCenter.TreasureMapStarConfig
	local starConfig = treasureMapStarConfig[mapNo]
	if star < starConfig[rewardNo].star then return end
	local receiveData = self.cache.starReward[mapNo] or 0
	if receiveData & (2 ^ rewardNo) ~= 0 then return end
	self.cache.starReward[mapNo] = receiveData | (2 ^ rewardNo)
	local reward = table.wcopy(starConfig[rewardNo].starAward)
	self.player:GiveRewardAsFullMailDefault(reward, "藏宝图星级奖励", server.baseConfig.YuanbaoRecordType.TreasureMap, "藏宝图星级奖励"..mapNo..rewardNo)
	
	local msg = {starReward={},}
	for k,v in pairs(self.cache.starReward) do
		table.insert(msg.starReward, {no=k, reward=v})
	end
	server.sendReq(self.player, "sc_fuben_treasuremap_star_reward", msg)
end

function TreasureMap:MaxClear()
	local clear = 0
	local data = self.player.cache.treasuremap
	for k,v in pairs(data.clearanceNum) do
		if k > clear then
			clear = k
		end
	end
	return clear
end

server.playerCenter:SetEvent(TreasureMap, "treasuremap")
return TreasureMap