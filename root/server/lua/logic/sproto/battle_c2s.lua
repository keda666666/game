--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 对目标使用技能
cs_battle_use_skill 7000 {
	request {
		use_skill_list		0 : *use_skill_data
	}	
}
]]
function server.cs_battle_use_skill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.fightMgr:UseSkill(player.dbid, msg)
end

--[[
# 战斗动画播放结束
cs_battle_play_finish 7001 {
	request { }	
}
]]
function server.cs_battle_play_finish(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.fightMgr:PlayFinish(player.dbid)
end

--[[
# 设置手动或自动
cs_battle_set_auto 7002 {
	request {
		isauto		0 : integer		#是否自动
	}	
}
]]
function server.cs_battle_set_auto(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.fightMgr:SetAuto(player.dbid, msg.isauto)
end
