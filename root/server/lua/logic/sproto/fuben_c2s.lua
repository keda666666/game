--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local DailyTaskConfig = require "resource.DailyTaskConfig"

--[[
#客户端->服务端
#进入副本
cs_fuben_join 5201 {
	request {
		fubenType	0 : integer #1材料副本,2藏宝图,3大雁塔,4勇闯天庭
		fubenNo		1 : integer #大雁塔不用发,勇闯天庭不用发
	}
}
]]
function server.cs_fuben_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local packinfo = server.dataPack:FightInfo(player)
        packinfo.exinfo = {
            fubenNo = msg.fubenNo,
        }
    local ret
    if msg.fubenType == 1 then
        ret = server.raidMgr:Enter(server.raidConfig.type.Material, player.dbid, packinfo)
    elseif msg.fubenType == 2 then
        ret = server.raidMgr:Enter(server.raidConfig.type.TreasureMap, player.dbid, packinfo)
    elseif msg.fubenType == 3 then
        ret = server.raidMgr:Enter(server.raidConfig.type.WildgeeseFb, player.dbid, packinfo)
    elseif msg.fubenType == 4 then
        ret = server.raidMgr:Enter(server.raidConfig.type.HeavenFb, player.dbid, packinfo)
    end

    -- 任务事件
    if ret then
        if msg.fubenType == 1 then
            local dailyFubenConfig = server.configCenter.DailyFubenConfig[msg.fubenNo]
            local InstanceCofnig = server.configCenter.InstanceConfig[dailyFubenConfig.fbid]
            if InstanceCofnig then
                if InstanceCofnig.type == server.raidConfig.type.MyBoss then
                    player.material:AddMyBossNum()
                    player.task:onEventAdd(server.taskConfig.ConditionType.MyBoss)
                    player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.MyBoss)
                    server.teachersCenter:AddNum(player.dbid, 5)
                    player.enhance:AddPoint(20, 1)
                elseif InstanceCofnig.type == server.raidConfig.type.Material then
                    player.material:AddMaterialNum()
                    player.task:onEventAdd(server.taskConfig.ConditionType.MaterialFb)
                    player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.MaterialFb)
                    server.teachersCenter:AddNum(player.dbid, 8)
                    player.enhance:AddPoint(19, 1)
                end
            end
        elseif msg.fubenType == 2 then
            player.task:onEventAdd(server.taskConfig.ConditionType.Treasuremap)
            player.enhance:AddPoint(16, 1)
        elseif msg.fubenType == 3 then
            player.task:onEventAdd(server.taskConfig.ConditionType.WildgeeseFb)
        elseif msg.fubenType == 4 then
            player.task:onEventAdd(server.taskConfig.ConditionType.HeavenFb)
            player.enhance:AddPoint(17, 1)
        end
    end
end

--[[
#扫荡
cs_fuben_sweep 5202 {
	request {
		fubenType	0 : integer #1藏宝图,2勇闯天庭
	}
}
]]
function server.cs_fuben_sweep(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if msg.fubenType == 1 then
    	player.treasuremap:SweepReward()
    elseif msg.fubenType == 2 then
    	player.heavenFb:SweepReward()
    end
end

--[[
#领取藏宝图星级奖励
cs_fuben_star_reward 5203 {
	request {
		mapNo		0 : integer #哪页
		reward		1 : integer #第几个奖励(1,2,3)
	}
}
]]
function server.cs_fuben_star_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.treasuremap:StarReward(msg.mapNo, msg.reward)
end

--[[
#大雁塔进入困难模式
cs_fuben_wildgeeseFb_hard 5204 {
	request {
	}
}
]]
function server.cs_fuben_wildgeeseFb_hard(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local wildgeeseFb = player.cache.wildgeeseFb
    local oldFbData = server.configCenter.WildgeeseFbConfig[wildgeeseFb.layer]
  	local newFbData = server.configCenter.WildgeeseFbConfig[wildgeeseFb.layer + 1]
  	if newFbData and oldFbData.degree < newFbData.degree and wildgeeseFb.hard == oldFbData.degree then
  		wildgeeseFb.hard = newFbData.degree
  	end
  	player.cache.wildgeeseFb = wildgeeseFb
  	server.sendReq(player, "sc_fuben_wildgeeseFb_info", newFbData)
end

--[[
#领取勇闯天庭关卡奖励
cs_fuben_heaven_reward 5205 {
	request {
		fubenNo		0 : integer #哪个副本的
	}
}
]]
function server.cs_fuben_heaven_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.heavenFb:LayerReward(msg.fubenNo)
end
