local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local AdvancedrCenter = {}

function AdvancedrCenter:Init()
	self.done = {}
	self.timer = lua_timer.add_timer_day("23:58:00", -1, self.DoReward, self)
end

local rankList = {5,6,7,8,14,13,12,11,9,16,15,20}

local rankName = {}
rankName[5] = "坐骑"
rankName[6] = "翅膀"
rankName[7] = "守护"
rankName[8] = "神兵"
rankName[14] = "宠物兽魂"
rankName[13] = "宠物通灵"
rankName[12] = "仙侣仙位"
rankName[11] = "仙侣法阵"
rankName[9] = "天女"
rankName[16] = "天女灵气"
rankName[15] = "天女花辇"
rankName[20] = "灵童"
local _Check = {}

_Check[5] = function(player, lv)
	return player.role.ride.cache.lv >= lv
end

_Check[6] = function(player, lv)
	return player.role.wing.cache.lv >= lv
end

_Check[7] = function(player, lv)
	return player.role.fairy.cache.lv >= lv
end

_Check[8] = function(player, lv)
	return player.role.weapon.cache.lv >= lv
end

_Check[14] = function(player, lv)
	return player.pet.psychic.cache.lv >= lv
end

_Check[13] = function(player, lv)
	return player.pet.soul.cache.lv >= lv
end

_Check[12] = function(player, lv)
	return player.xianlv.position.cache.lv >= lv
end

_Check[11] = function(player, lv)
	return player.xianlv.circle.cache.lv >= lv
end

_Check[9] = function(player, lv)
	return player.tiannv.cache.lv >= lv
end

_Check[16] = function(player, lv)
	return player.tiannv.nimbus.cache.lv >= lv
end

_Check[15] = function(player, lv)
	return player.tiannv.flower.cache.lv >= lv
end

_Check[20] = function(player, lv)
	return player.baby.babyPlug.cache.lv >= lv
end


function AdvancedrCenter:HotFix()
	print("AdvancedrCenter:HotFix-----", self.timer)
	table.ptable(self.done, 3)
end

function AdvancedrCenter:ResetServer()
	self.done = {}
end

function AdvancedrCenter:onDayTimer()
	
end

function AdvancedrCenter:DoReward()
	local day = server.serverRunDay
	if self.done[day] then
		return
	end
	self.done[day] = true
	local baseConfig = server.configCenter.ProgressCrazyBaseConfig
	local no = baseConfig.initialorder[day]
	if not no then return end
	local nextNo = baseConfig.initialorder[day + 1]
	if nextNo and nextNo == no then return end
	local rankNo = rankList[no]
	local randConfig = server.configCenter.ProgressCrazyRandConfig
	server.serverCenter:SendLocalMod("world", "rankCenter", "RefreshRank", rankNo)
	local rankData = server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas", rankNo, 1, 20)
	local title = baseConfig.mailtitle1

	lua_app.log_info("AdvancedrCenter:DoReward------", day, no, rankNo)
	for k,v in pairs(rankData) do
		lua_app.log_info("AdvancedrReward----", day, no, rankNo, v.id, k)
		local msg = string.format(baseConfig.maildes1, rankName[rankNo], k)
		local fourdrop1 = randConfig[no][k].reward
		local fourdrop2 = randConfig[no][k].reward2
		local rewards = server.dropCenter:DropGroup(fourdrop1)
		local player = server.playerCenter:DoGetPlayerByDBID(v.id)
		if _Check[rankNo](player, randConfig[no][k].value) then 
			local rewards1 = server.dropCenter:DropGroup(fourdrop2)
			for _,v in pairs(rewards1) do
				table.insert(rewards, v)
			end
		end
		server.mailCenter:SendMail(v.id, title, msg, rewards, server.baseConfig.YuanbaoRecordType.Advanced, "进阶排行榜")
	end
end

server.SetCenter(AdvancedrCenter, "advancedrCenter")
return AdvancedrCenter
