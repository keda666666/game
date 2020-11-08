--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求匹配玩家
cs_ladder_get_some_one 3502 {
	request {
		ladderType		0 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_get_some_one(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:Match(player.dbid)
end

--[[
# 开始挑战
cs_ladder_start_play 3503 {
	request {
		type 		0 : integer
		ladderType	1 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_start_play(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:Enter(player.dbid)
end

--[[
# 领取上周奖励
cs_ladder_get_week_reward 3504 {
	request {
		ladderType		0 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_get_week_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:ReceiveReward(player.dbid)
end

--[[
# 获取排行榜数据 
cs_ladder_get_rank_info 3505 {
	request {
		ladderType		0 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_get_rank_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:SendRankMsg(player.dbid)
end

--[[
# 购买次数
cs_ladder_buy_count 3506 {
	request {
		ladderType		0 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_buy_count(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:BuyPkCount(player)
end

--[[
# 获取跨服王者信息
cs_ladder_get_winner_info 3508 {}
]]
function server.cs_ladder_get_winner_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:SendKinginfoMsg(player.dbid)
end

--[[
# 获取跨服王者记录
cs_ladder_get_winner_records 3509 {}
]]
function server.cs_ladder_get_winner_records(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:SendKingRecordMsg(player.dbid)
end

--[[
#跨服王者争霸

# 跨服王者信息
cs_ladder_info 3501 {
	request {}
}
]]
function server.cs_ladder_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:SendClientMsg(player.dbid)
end

--[[
cs_ladder_worship 3507 {
	request {
		ladderType		0 : integer 	# 0、本服	1、跨服
	}
}
]]
function server.cs_ladder_worship(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.kingArenaMgr:Worship(player)
end
