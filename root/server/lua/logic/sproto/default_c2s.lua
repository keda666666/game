--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 发送GM命令
cs_sene_gm_command 100 {
    request {
        cmd       0 : string
    }
}
]]
function server.cs_sene_gm_command(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.gm:RunCMD(msg.cmd)
end

--[[
# 发送创建子角色
cs_create_new_sub_role 102 {
	request {
		job       0 : integer
		sex       1 : integer
	}
}
]]
function server.cs_create_new_sub_role(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求服务器时间
cs_get_server_time 114 {
    request { }
}
]]
function server.cs_get_server_time(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 查看其它玩家信息
cs_get_other_actor_info 116 {
    request {
        otherid     0 : integer
    }
}
]]
function server.cs_get_other_actor_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        player:sendReq("sc_show_other_player", target:GetMsgData())
    end
end

--[[
# 请求改名
cs_change_player_name 122 {
    request {
        name       0 : string
    }
}
]]
function server.cs_change_player_name(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

    local RoleBaseConfig = server.configCenter.RoleBaseConfig
    if player.cache.renamecount ~= 0 and
        not player:CheckRewards({RoleBaseConfig.changenamecost}) then
        server.sendErr(player, "元宝不足")
        return
    end

    local result = server.CheckPlayerName(msg.name)
    if result ~= 0 then
        server.sendReq(player, "sc_rename_result", { result = result })
        return
    end

    if player.cache.renamecount ~= 0 then
        if not player:PayRewards({RoleBaseConfig.changenamecost}, server.baseConfig.YuanbaoRecordType.Rename, "Rename") then
            server.sendErr(player, "元宝不足")
            return
        end
    end

    player.cache.renamecount = player.cache.renamecount + 1
    player.cache.name = msg.name
    server.UnLockPlayerName(msg.name)
    server.sendReq(player, "sc_rename_result", { result = 0, name = msg.name})
    if player.marry.cache.partnerid > 0 then
        local partner = server.playerCenter:DoGetPlayerByDBID(player.marry.cache.partnerid)
        if partner then
            partner.marry.cache.partnername = msg.name
        end
    end
    player:SendRenameCount()
end

--[[
# 请求功能预告奖励
cs_get_gongnengyugao_reward 123 {
    request {
        index       0 : integer
    }
    response {
        index       0 : integer
    }
}
]]
function server.cs_get_gongnengyugao_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 客户端设置
cs_set_clientvalue 124 {
    request {
        value       0 : integer
        list        1 : *integer
    }
}
]]
function server.cs_set_clientvalue(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.cache.clientvalue = msg.value
    player.cache.clientvaluelist = msg.list or {}
end

--[[
# 发送心跳
cs_send_heart_beat 199 {
    request {}
}
]]
function server.cs_send_heart_beat(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求记录
cs_baserecord_info 125 {
    request {
        type    0 : integer
    }
}
]]
function server.cs_baserecord_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求客服QQ
cs_get_kefu_qq 126 {
    response {
        qq      0 : string
    }
}
]]
function server.cs_get_kefu_qq(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return { qq = server.serverCenter:CallNextMod("mainrecord", "recordCenter", "GetQQ") }
end

--[[
# 发送客服留言
cs_send_kefu_msg 127 {
    request {
        msg     0 : string
    }
}
]]
function server.cs_send_kefu_msg(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.serverCenter:SendDtbMod("httpr", "recordDatas", "SendKefuMessage", {
            serverid = player.cache.serverid,
            playerid = player.dbid,
            account  = player.cache.account,
            name     = player.cache.name,
            vip      = player.cache.vip,
            power    = player.cache.totalpower,
            message  = msg.msg,
            ip       = player.ip,
        })
end

--[[
# 客户端打点
cs_send_client_point 128 {
    request {
        point   0 : integer
    }
}
]]

function server.cs_send_client_point(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 请求升级
cs_change_role_level 107 {}
]]
function server.cs_change_role_level(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player:RequestUpdateLevel()
end

--[[
# 排行榜 查看其它玩家
cs_show_rank_player 129 {
    request {
        otherid     0 : integer
    }
}
]]
function server.cs_show_rank_player(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 跨服组队剩余奖励次数
cs_cross_team_reward_count 130 {
    request { }
}
]]
function server.cs_cross_team_reward_count(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.crossTeam:SendRewardCount()
end


--[[
# 欢迎确认
cs_welcome_confirm 131 {}
]]
function server.cs_welcome_confirm(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player:WelcomeReward()
end

--[[
# 领取十万元宝的
cs_accu_login_get 132 {
    request {
        index     0 : integer
    }
}
]]
function server.cs_accu_login_get(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.activityPlug:GetReward(msg.index)
end

--[[
# 排行榜膜拜
cs_rank_worship 133 {
    request { }
}
]]
function server.cs_rank_worship(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player:DoRankWorship()
end

--[[
# 查看法宝信息
cs_get_other_actor_spellsRes 117 {
    request {
        otherid     0 : integer
        pos         1 : integer #法宝位置
    }
}
]]
function server.cs_get_other_actor_spellsRes(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        local msg = target.role.spellsRes:GetPosData(msg.pos)
        player:sendReq("sc_show_other_spellsRes", msg)
    end
end


--[[
# 查看他人宠物
cs_get_other_actor_pet 118 {
    request {
        otherid     0 : integer
        petid       1 : integer
    }
}
]]
function server.cs_get_other_actor_pet(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        local info = target.pet.cache.list[msg.petid]
        if info then
            player:sendReq("sc_show_other_pet", {pet = info, petid = msg.petid})
        end
    end
end

--[[
#查看其他人装备或物品信息
cs_get_other_actor_item 119 {
    request {
        otherid     0 : integer
        itemhandle  1 : integer     #背包位置
    }
}
]]
function server.cs_get_other_actor_item(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        local item = target.bag:GetItem(msg.itemhandle)
        if item then
            player:sendReq("sc_other_item", {data = item:GetMsgData(), itemhandle = msg.itemhandle})
        end
    end
end

--[[
#查看其他人装备或物品信息
cs_get_other_actor_equip 120 {
    request {
        otherid     0 : integer
        slot        1 : integer     #身上位置
    }
}
]]
function server.cs_get_other_actor_equip(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        local equip = target.role.equip.equipList[msg.slot]
        if equip then
            player:sendReq("sc_other_equip", {data = equip:GetMsgData(), slot = msg.slot})
        end
    end
end

--[[
#查看他人仙侣
cs_get_other_actor_xianlv 121 {
    request {
        otherid     0 : integer
        id          1 : integer     #仙侣id
    }
}
]]
function server.cs_get_other_actor_xianlv(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local target = server.playerCenter:DoGetPlayerByDBID(msg.otherid)
    if target then
        server.sendReq(player, "sc_other_xianlv", target.xianlv:GetShowData(msg.id))
    end
end
