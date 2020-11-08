--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#升级
cs_dailyTask_up_level 5701 {
	request {
	}
	response {
		ret				0 : boolean #
		lv 				1 : integer #
		exp 			2 : integer #
	}
}
]]
function server.cs_dailyTask_up_level(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.dailyTask:upLevel()
end

--[[
#活跃奖励
cs_dailyTask_activity_reward 5702 {
	request {
		rewardNo 		0 : integer #奖励编号1,2...
	}
	response {
		ret				0 : boolean #
		activityReward 	1 : integer #领取奖励情况
	}
}
]]
function server.cs_dailyTask_activity_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.dailyTask:ActivityReward(msg.rewardNo)
end

--[[
#材料找回
cs_dailyTask_activity_find 5703 {
	request {
		activityNo 		0 : integer #找回哪个
		cashtype		1 : integer #货币类型
		findType		2 : integer #找回类型 1物品2历练经验
		num 			3 : integer #找回数量
	}
	response {
		ret				0 : boolean #
		exp 			1 : integer #经验
		activityNo		2 : integer #活动No
		num 			3 : integer #更新昨天完成的量
		findType		4 : integer #找回类型 1物品2历练经验
		findExpNum		5 : integer #找回了多少经验，只有在找回经验的时候才有
	}
}
]]
function server.cs_dailyTask_activity_find(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
 	return player.dailyTask:Find(msg.activityNo, msg.cashtype, msg.findType, msg.num)
end

--[[
#一键完成进度
cs_dailyTask_otherActivity_complete 5705 {
	request {
		otherActivity 	0 : integer #1->师门,2->300,3->组队副本
	}
}
]]
function server.cs_dailyTask_otherActivity_complete(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.dailyTask:OtherComplete(msg.otherActivity)
end

--[[
#领取额外奖励
cs_dailyTask_otherActivity_reward 5706 {
	request {
		otherActivity 	0 : integer #1->师门,#领取哪个2->300,3->组队副本
		reward 			1 : integer #领取哪个奖励
	}
}
]]
function server.cs_dailyTask_otherActivity_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.dailyTask:OtherReward(msg.otherActivity, msg.reward)
end

--[[
#一键找回经验
cs_dailyTask_activity_find_all_exp 5704 {
	request {
	}
	response {
		ret				0 : boolean #
		findExpNum		1 : integer #找回了多少经验，只有在找回经验的时候才有
	}
}
]]
function server.cs_dailyTask_activity_find_all_exp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.dailyTask:FindAllExp()
end

--[[
#师门打怪
cs_dailyTask_otherActivity_monster 5707 {
	request {
		no 	0 : integer #列表的key
	}
}
]]
function server.cs_dailyTask_otherActivity_monster(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.dailyTask:FightMonster(msg.no)
end

--[[
#师门升星
cs_dailyTask_up_monster 5708 {
	request {
		no 	0 : integer #列表的key
	}
}
]]
function server.cs_dailyTask_up_monster(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
     player.dailyTask:UpMonster(msg.no)
end