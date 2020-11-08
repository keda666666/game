local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local Material = {}

function Material:Init()
	self.type = server.raidConfig.type.Material
	self.playerlist = {}
	server.raidMgr:SetRaid(self.type, Material)
end

function Material:Enter(dbid, packinfo)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	local fubenNo = packinfo.exinfo.fubenNo
	local materialData = server.configCenter.DailyFubenConfig[fubenNo]
	if not materialData then return end

	if player.cache.level() < materialData.levelLimit then return end
	local material = player.cache.material()
	local todayFubenNum = material.todayNum[fubenNo] or 0
	local clearanceNum = material.clearanceNum[fubenNo] or 0
	local needsuccess = materialData.needsuccess
	local freeCount = materialData.freeCount
	local vipBuyCount
	if not materialData.vipBuyCount then
		vipBuyCount = 0
	else
		vipBuyCount = materialData.vipBuyCount[player.cache.vip()] or 0
	end
	-- local vipBuyCount = 5
	local autoClear = true
	if clearanceNum < needsuccess then--是否扫荡
		autoClear = false
	end
	if todayFubenNum >= freeCount then
		local maxNum = freeCount + vipBuyCount
		local buyNum = material.buyNum[fubenNo] or 0
		if buyNum >= vipBuyCount then return end
		if todayFubenNum >= maxNum then return end
		local cash = materialData.buyPrice[buyNum]
		if not cash then return end
		if not player:PayReward(0, 2, cash, server.baseConfig.YuanbaoRecordType.FubenClear, "material:buy") then return end
		material.buyNum[fubenNo] = buyNum + 1
		autoClear = true
	end
	
	if not autoClear then
		player.material:SetValue(material)
		-- player.cache.material = material
		self:start(dbid, packinfo)
		return 1
	end

	local rewards = server.dropCenter:DropGroup(materialData.dropId)
	player:GiveRewardAsFullMailDefault(rewards, "材料副本", server.baseConfig.YuanbaoRecordType.Material, "材料副本扫荡"..fubenNo)
	-- 副本次数增加了
	material.todayNum[fubenNo] = todayFubenNum + 1
	material.clearanceNum[fubenNo] = clearanceNum + 1
	player.material:SetValue(material)
	-- player.cache.material = material
	--更新玩家的副本数据
	
	local msg = {
		result = 1,
		rewards = rewards,
	}
	server.sendReqByDBID(dbid, "sc_raid_sweep_reward", msg)
	self:upMsg(player.dbid, material)
	return
end
function Material:start(dbid, datas)
	local fubenNo = datas.exinfo.fubenNo
	local dailyFubenConfig = server.configCenter.DailyFubenConfig[fubenNo]
	local info = self.playerlist[dbid]
	if not info then
		info = {}
		self.playerlist[dbid] = info
	end
	-- if 	info.fighting then
	-- 	lua_app.log_error("Material:Enter player is in fighting", dbid)
	-- 	return false
	-- end
	info.fubenNo = fubenNo
	local fighting = server.NewFighting()
	
	fighting:Init(dailyFubenConfig.fbid, self, nil, server.configCenter.InstanceConfig[dailyFubenConfig.fbid].initmonsters)
	fighting:AddPlayer(FightConfig.Side.Attack, dbid, datas)
	info.fighting = fighting
	info.rewards = info.rewards or server.dropCenter:DropGroup(dailyFubenConfig.dropId)
	fighting:StartRunAll()
	return
end

function Material:Exit(dbid)--强行退出 ，没奖励 当失败
	local info = self.playerlist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	end
	return true
end

function Material:FightResult(retlist)--round 回合数战斗结束后吧奖励列表显示给玩家看 
	for dbid, iswin in pairs(retlist) do
		local info = self.playerlist[dbid]
		info.fighting:BroadcastFighting()
		info.fighting:Release()
		info.fighting = nil
		local msg = {}
		if iswin then
			msg.result = 1
			msg.rewards = info.rewards
		else
			msg.result = 0
			msg.rewards = {}
		end

		info.iswin = iswin
		server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)
	end
end

function Material:GetReward(dbid)
	local info = self.playerlist[dbid]
	local rewards = info.rewards
	if rewards and info.iswin then
		info.rewards = nil
		info.iswin = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		local fubenNo = info.fubenNo
		-- 增加挑战材料副本的次数
		local material = player.cache.material()
		material.todayNum[fubenNo] = (material.todayNum[fubenNo] or 0) + 1
		material.clearanceNum[fubenNo] = (material.clearanceNum[fubenNo] or 0) + 1
		-- player.cache.material = material
		player.material:SetValue(material)
		-- player.cache.material.todayNum[fubenNo] = (player.cache.material.todayNum[fubenNo] or 0) + 1
		-- player.cache.material.clearanceNum[fubenNo] = (player.cache.material.clearanceNum[fubenNo] or 0) + 1
		-- 发放奖励
		self:upMsg(player.dbid, material)
		player:GiveRewardAsFullMailDefault(rewards, "材料副本", server.baseConfig.YuanbaoRecordType.Material, "材料副本"..fubenNo)
	end
end

function Material:upMsg(dbid, material)
	local msg = {fuben_data={}}
	for k,v in pairs(material.clearanceNum) do
		local data = {
			fubenNo = k,
			clearanceNum = v,
			todayNum = material.todayNum[k] or 0,
			buyNum = material.buyNum[k] or 0,
		}
		table.insert(msg.fuben_data, data)
	end
	server.sendReqByDBID(dbid, "sc_fuben_material_info", msg)
end

server.SetCenter(Material, "material")
return Material