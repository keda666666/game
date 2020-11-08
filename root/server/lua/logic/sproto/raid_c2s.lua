--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 清完一波请求
cs_raid_wave_complete 201 {
	request {
		killCount 0 : integer
	}
}
]]
function server.cs_raid_wave_complete(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if player then
        player.chapter:ReqNextWave(msg.killCount)
    end
end

--[[
# 请求挑战boss
cs_raid_pk_boss 202 {
	request {}
}
]]
function server.cs_raid_pk_boss(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if not player then
        return
    end
    if player.cache.chapter.nextmap then
        player.chapter:SendChapterInitInfo()
        return
    end
    local data = {
        playerlist = {server.dataPack:FightInfo(player)},
        exinfo = {
            chapterlevel = player.cache.chapter.chapterlevel,
        }
    }
    server.raidMgr:Enter(server.raidConfig.type.ChapterBoss, player.dbid, data)
end

--[[
# 请求领取boss奖励
cs_raid_get_boss_reward 203 {
	request {}
}
]]
function server.cs_raid_get_boss_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:GetReward(player.dbid)
end

--[[
# 退出副本
cs_raid_exit_raid 204 {
	request {}
}
]]
function server.cs_raid_exit_raid(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.raidMgr:Exit(player.dbid)
end

--[[
# # 发送领取关卡奖励
# cs_raid_get_award 205 {
# 	request {}
# }
]]
function server.cs_raid_get_award(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 领取地区奖励
# cs_raid_get_world_award 206 {
# 	request {
# 		pass	0 : integer
# 	}
# }
]]
function server.cs_raid_get_world_award(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 请求挑战副本
# cs_raid_challenget 210 {
# 	request {
# 		fbID 	0 : integer
# 	}
# }
]]
function server.cs_raid_challenget(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 发送添加副本挑战次数
# cs_raid_add_count 211 {
# 	request {
# 		fbID 	0 : integer
# 	}
# }
]]
function server.cs_raid_add_count(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 发送请求召唤boss
# cs_raid_call_boss_play 212 {
# 	request {
# 		id 		0 : integer
# 	}
# }
]]
function server.cs_raid_call_boss_play(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 发送清除cd
# sc_raid_clear_cd 213 {
# 	request {
# 		index	0 : integer # 1转生 2全民 3精英 4跨服boss
# 	}
# }
]]
function server.sc_raid_clear_cd(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# # 发送直达第二关
# cs_raid_goto2 214 {}
]]
function server.cs_raid_goto2(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求关卡配置信息
cs_raid_chapter_config 208 {
	request {
		fbid 		0 : integer
	}
	response {
		fbid 			0 : integer
		manuallymode 	1 : integer
		jbutton 		2 : integer
		type 			3 : integer
		totalTime		4 : integer
		closeTime		5 : integer
		scenes			6 : *integer
		name			7 : string
		desc			8 : string
	}
}
]]
function server.cs_raid_chapter_config(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local cfg = server.configCenter.Instance2SConfig[msg.fbid]
    return cfg
end

--[[
# 进入下一个地图
cs_raid_next_map 215 {}
]]
function server.cs_raid_next_map(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.chapter:ReqNextMap()
end

--[[
# 领取章节奖励
cs_raid_get_chapter_reward 216 {
	request {
		id 		0 : integer
	}
	response {
		ret 	0 : boolean
	}
}
]]
function server.cs_raid_get_chapter_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.chapter:GetChapterReward(msg.id)
end

--[[
# 开启自动挑战
cs_raid_open_auto 217 {
	request {
		auto 	0 : boolean
	}
}
]]
function server.cs_raid_open_auto(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.chapter.cache.autopk = msg.auto
    player.task:onEventCheck(server.taskConfig.ConditionType.AutoPK)
end

--[[
# 协助挑战
cs_raid_assist_pkboss 218 {
	request {
		playerid 		0 : integer		#协助的id
		chapterlevel 	1 : integer 	#章节等级
	}
	response {
		ret 		0 : integer 
	}
}
]]
function server.cs_raid_assist_pkboss(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
        ret = player.chapter:AssistAttack(msg.playerid, msg.chapterlevel)
    }
end
