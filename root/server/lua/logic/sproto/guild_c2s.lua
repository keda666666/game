--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local lua_shield = require "lua_shield"
local GuildConfig = require "common.resource.GuildConfig"

--[[
# 获取公会信息
cs_guild_getinfo 3801 {}
]]
function server.cs_guild_getinfo(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	server.guildCenter:SendGuildInfo(player)
end

--[[
# 获取公会成员
cs_guild_getmembers 3802 {}
]]
function server.cs_guild_getmembers(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	if not guild then return end
    server.sendReq(player, "sc_guild_members", { members = guild:GetPlayers() })
end

--[[
# 获取公会列表
cs_guild_getlist 3803 {}
]]
function server.cs_guild_getlist(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.sendReq(player, "sc_guild_list", { 
    	guilds = server.guildCenter:GetGuildSummary(),
    	receiveCount = server.guildCenter.receiveCount,
    })
end

--[[
# 创建公会
cs_guild_create 3804 {
	request {
		id		0 : integer
		name	1 : string
	}
}
]]
function server.cs_guild_create(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	if not player or player.cache.guildid ~= 0 then
		lua_app.log_error("server.cs_guild_create: failed", player and player.cache.account, player and player.cache.guildid)
		return
	end
    local result, guildid = server.guildCenter:CreateGuild(player, msg.id, msg.name)
    server.sendReq(player, "sc_guild_create_ret", { result = result, id = guildid })
end

--[[
# 退出公会
cs_guild_quit 3805 {}
]]
function server.cs_guild_quit(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
    guild:Quit(player)
end

--[[
# 申请加入公会
cs_guild_join 3806 {
	request {
		id		0 : integer
	}
}
]]
function server.cs_guild_join(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if not player or player.cache.guildid ~= 0 then
    	lua_app.log_error("server.cs_guild_join: failed", player and player.cache.account, player and player.cache.guildid)
    	return
    end
    local guild = server.guildCenter:GetGuild(msg.id)
    if not guild then
    	server.sendErr(player, "申请加入的帮会已经解散了")
    	return
    end
    player.guild:ApplyJoin(guild)
end

--[[
# 获取申请加入列表
cs_guild_getapply 3807 {}
]]
function server.cs_guild_getapply(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = server.guildCenter:GetGuild(player.cache.guildid)
    if not guild then
    	lua_app.log_error("server.cs_guild_getapply: no guild", player and player.cache.account)
    	return
    end
    if not guild:GetAdmin(player.dbid) then
    	-- lua_app.log_error("server.cs_guild_getapply: not admin", player.accountname, guild:Get(config.name))
    	return
    end
    server.sendReq(player, "sc_guild_apply", { applyinfo = guild:GetApplyList() })
end

--[[
# 处理申请
cs_guild_setapply 3808 {
	request {
		playerid	0 : integer
		result		1 : integer
	}
}
]]
function server.cs_guild_setapply(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	if not guild then
		lua_app.log_error("server.cs_guild_setapply: no guild", player and player.cache.account)
		return
	end
	if not guild:GetAdmin(player.dbid) then
		lua_app.log_error("server.cs_guild_setapply: not admin", player.cache.account, guild.cache.name)
		return
	end
	guild:SetJoin(msg.playerid, msg.result, player)
end

--[[
# 改变职位
cs_guild_change_office 3809 {
	request {
		playerid	0 : integer
		office 		1 : integer
	}
}
]]
function server.cs_guild_change_office(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	if not guild then
		lua_app.log_error("server.cs_guild_change_office: no guild", player and player.cache.account)
		return
	end
	if guild:GetOffice(player.dbid) ~= GuildConfig.Office.Leader then
		lua_app.log_error("server.cs_guild_change_office: not leader", player.cache.account, guild.cache.name)
		return
	end
	guild:SetOffice(msg.playerid, msg.office)
end

--[[
# 弹劾
cs_guild_demise 3810 {}
]]
function server.cs_guild_demise(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	guild:Demise(player)
end

--[[
# 踢出公会
cs_guild_kick 3811 {
	request {
		playerid	0 : integer
	}
}
]]
function server.cs_guild_kick(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
    if not guild then
    	lua_app.log_error("server.cs_guild_kick: no guild", player and player.cache.account)
    	return
    end
    if not guild:GetAdmin(player.dbid) then
    	lua_app.log_error("server.cs_guild_kick: not admin", player.cache.account, guild.cache.name)
    	return
    end
    guild:Kick(msg.playerid)
end

--[[
# 捐献
cs_guild_contribute 3813 {
	request {
		type 		0 : integer
	}
}
]]
function server.cs_guild_contribute(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    -- player.guild:Contribute(msg.type)
end

--[[
# 修改公告
cs_guild_change_notice 3814 {
	request {
		text		0 : string
	}
}
]]
function server.cs_guild_change_notice(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
    if not guild then
    	lua_app.log_error("server.cs_guild_change_notice: no guild", player and player.cache.account)
    	return
    end
    if not guild:GetAdmin(player.dbid) then
    	lua_app.log_error("server.cs_guild_change_notice: not admin", player.cache.account, guild.cache.name)
    	return
    end
    if #msg.text > 500 then
    	lua_app.log_error("server.cs_guild_change_notice: text too long:", #msg.text, player.cache.account, guild.cache.name)
    	return
    end
    if lua_shield:check(msg.text) then
    	server.sendErr(player , "存在敏感字符")
    	return
    end
    guild:ChangeNotice(msg.text)
    msg.result = 0
    server.sendReq(player, "sc_guild_change_notice_ret", msg)
end

--[[
# 升级建筑
cs_guild_upbuilding 3817 {
	request {
		buildtype	0 : integer
	}
}
]]
function server.cs_guild_upbuilding(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 获取公会事件
cs_guild_gethistory 3822 {}
]]
function server.cs_guild_gethistory(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
# 获取玩家公会信息
cs_guild_getplayerinfo 3825 {}
]]
function server.cs_guild_getplayerinfo(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.guild:SendGuildData()
end

--[[
# 发送公会聊天信息
cs_guild_sendchat 3826 {
	request {
		str 	0 : string
	}
}
]]
function server.cs_guild_sendchat(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild:Chat(msg.str)
end

--[[
# 设置自动加入公会
cs_guild_setautoadd 3828 {
	request {
		auto	0 : integer
		power	1 : integer
	}
}
]]
function server.cs_guild_setautoadd(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	if not guild then
		lua_app.log_error("server.cs_guild_kick: no guild", player and player.cache.account)
		return
	end
	if not guild:GetAdmin(player.dbid) then
		lua_app.log_error("server.cs_guild_kick: not admin", player.cache.account, guild.cache.name)
		return
	end
	guild:ChangeAutoJoin(msg.auto, msg.power)
	server.sendReq(player, "sc_guild_autoadd_ret", { autoJoin = msg.auto, needPower = msg.power })
end

--[[
cs_guild_rename 3829 {
	request {
		guildName 0 : string 
	}
}
]]
function server.cs_guild_rename(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	local guild = server.guildCenter:GetGuild(player and player.cache.guildid or 0)
	guild:Rename(msg.guildName, player)
end

--[[
#玩家申请帮会的列表
cs_guild_apply_list 3831 {
	request {}
}
]]
function server.cs_guild_apply_list(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild:SendApplyInfo()
end


--[[
#捐献
cs_guild_donate 3842 {
	request {
		id		0 : integer			#索引ID
	}
}
]]
function server.cs_guild_donate(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildDonate:DonateWood(msg.id)
end

--[[
#蟠桃会信息
cs_guild_peach_info 3846 {
	request {}
}
]]
function server.cs_guild_peach_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildPeach:SendClient()
end

--[[
cs_guild_peach_eat 3847 {
	request {
		id		0 : integer			#索引ID
	}
}
]]
function server.cs_guild_peach_eat(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildPeach:EatPeach(msg.id)
end
--[[
cs_guild_peach_reward 3848 {
	request {
		id		0 : integer			#奖励ID
	}
}
]]
function server.cs_guild_peach_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildPeach:GetPeachReward(msg.id)
end

--[[
#帮派守护信息
cs_guild_protector_info 3851 {
	request {}
}
]]
function server.cs_guild_protector_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildProtector:SendClient()
end

--[[
cs_guild_protector_uplevel 3852 {
	request {}
}
]]
function server.cs_guild_protector_uplevel(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildProtector:UpProtectorLevel()
end

--[[
cs_guild_protector_everyday_reward 3853 {
	request {
		rewardId 	0 : integer
	}
}
]]
function server.cs_guild_protector_everyday_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildProtector:EveryDayReward(msg.rewardId)
end

--[[
#帮派技能信息
cs_guild_skill_info 3856 {
	request {}
}
]]
function server.cs_guild_skill_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildSkill:SendClientInfo()
end

--[[
cs_guild_skill_learn 3857 {
	request {}
}
]]
function server.cs_guild_skill_learn(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
	player.guild.guildSkill:LearnSkill()
end

--[[
#帮会地图任务信息
cs_guild_map_task_info 3861 {
	request {

	}
	response {
		taskInfo 		0 : *task_info 		#任务信息
	}
}
]]
function server.cs_guild_map_task_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	taskInfo = player.guild.guildMap:GetTaskInfo(),
	}
end

--[[
#帮会地图任务完成
cs_guild_map_task_complete 3862 {
	request {
		taskId 		0 : integer			#任务id
	}
}
]]
function server.cs_guild_map_task_complete(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild.guildMap:PerformTask(msg.taskId)
end

--[[
#帮会地图任务重置
cs_guild_map_task_reset 3863 {
	request {
		taskId 		0 : integer			#任务id
	}
	response {
		ret 		0 : boolean
		taskInfo 	1 : task_info 		#任务信息
	}
}
]]
function server.cs_guild_map_task_reset(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildMap = player.guild.guildMap
    return {
    	ret = guildMap:PerformReset(msg.taskId),
    	taskInfo = guildMap:GetTaskInfoById(msg.taskId),
	}
end

--[[
#帮会地图任务一键完成
cs_guild_map_task_quick 3864 {
	request {
		taskId 		0 : integer			#任务id
	}
	response {
		ret 		0 : boolean
		taskInfo 	1 : task_info 		#任务信息
	}
}
]]
function server.cs_guild_map_task_quick(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
 	local guildMap = player.guild.guildMap
    return {
    	ret = guildMap:QuickComplete(msg.taskId),
    	taskInfo = guildMap:GetTaskInfoById(msg.taskId),
	}
end

--[[
#帮会地图任务奖励
cs_guild_map_reward 3865 {
	request {
		taskId 		0 : integer			#任务Id
	}
	response {
		ret 		0 : boolean
	}
}
]]
function server.cs_guild_map_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
     	ret = player.guild.guildMap:GetTaskReward(msg.taskId),
 	}
end

--[[
#帮会地图换购信息
cs_guild_map_exchange_info 3866 {
	request {

	}
	response {
		exchangeInfo 	0 : exchange_info
	}
}
]]
function server.cs_guild_map_exchange_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildMap = player.guild.guildMap
    return {
    	exchangeInfo = guildMap:GetExchangeInfo(),
	}
end

--[[
#帮会地图换购刷新
cs_guild_map_exchange_refresh 3867 {
	request {

	}
	response {
		ret 				0 : boolean
		exchangeInfo 		1 : exchange_info
	}
}
]]
function server.cs_guild_map_exchange_refresh(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildMap = player.guild.guildMap
    return {
    	ret = guildMap:RefreshManual(),
    	exchangeInfo = guildMap:GetExchangeInfo(),
	}
end

--[[
#帮会换购
cs_guild_map_exchange_pay 3868 {
	request {
		id 			0 : integer				#换购Id
	}
	response {
		ret 				0 : boolean
		exchangeInfo 		1 : exchange_info
	}
}
]]
function server.cs_guild_map_exchange_pay(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildMap = player.guild.guildMap
    return {
    	ret = guildMap:Purchase(msg.id),
    	exchangeInfo = guildMap:GetExchangeInfo(),
	}
end

--[[
#帮会副本
cs_guild_dungeon_info 3871 {
	request {

	}
	response {
		profitCount 		0 : integer 		#收益次数
		assistCount 		1 : integer 		#协助次数
		firstReach 			2 : *integer		#完成首通副本id
	}
}
]]
function server.cs_guild_dungeon_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.guild.guildDungeon:GetMsgData()
end

--[[
#请求帮会boss信息
cs_guild_boss_info 3872 {
	request { }
}
]]
function server.cs_guild_boss_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildid = player.cache.guildid
end

--[[
#请求挑战帮会boss
cs_guild_boss_pk 3873 {
	request { }
}
]]
function server.cs_guild_boss_pk(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildid = player.cache.guildid
end

--[[
#请求领取帮会boss奖励
cs_guild_boss_reward 3874 {
	request { }
}
]]
function server.cs_guild_boss_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guildid = player.cache.guildid
end

--[[
# 发送公会分享信息
cs_guild_sendshare 3827 {
	request {
		shareId 		0 : integer 		#分享Id
		params 			1 : *client_chat_param 
	}
}
]]
function server.cs_guild_sendshare(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.guild:ChatLink(msg.shareId, nil, table.unpack(msg.params or {}))
end

--[[
#帮会招募
cs_guild_member_recruit 3875 {
	request { }
}
]]
function server.cs_guild_member_recruit(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local guild = player.guild:GetGuild()
    if not guild then
    	return
    end
     if not guild:GetAdmin(player.dbid) then
    	lua_app.log_error("server.cs_guild_member_recruit: not admin", player.cache.account, guild.cache.name)
    	return
    end
	server.chatCenter:ChatLink(9, player, true, {server.chatConfig.CollectType.Player, player.dbid}, player.cache.name, guild:GetName())
end
