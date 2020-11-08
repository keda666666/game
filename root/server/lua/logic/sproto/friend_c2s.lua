--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#添加关注
cs_friend_add_follow 30001 {
	request {
		targetid 			0 : integer
	}
	response {
		ret 			0 : boolean
	}
}
]]
function server.cs_friend_add_follow(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.friend:AddFriend(msg.targetid)
	}
end

--[[
#移除关注
cs_friend_del_follow 30002 {
	request {
		targetid 			0 : integer
	}
}
]]
function server.cs_friend_del_follow(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:RemoveFriend(msg.targetid)
end

--[[
#添加黑名单
cs_friend_add_blacklist 30005 {
	request {
		targetid 			0 : integer
	}
}
]]
function server.cs_friend_add_blacklist(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:AddBlacklist(msg.targetid)
end

--[[
#移除黑名单
cs_friend_del_blacklist 30006 {
	request {
		targetid 			0 : integer
	}
}
]]
function server.cs_friend_del_blacklist(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:RemoveBlacklist(msg.targetid)
end

--[[
#赠送友情币
cs_friend_gift_friendcoin 30011 {
	request {
		targetid 			0 : integer
	}
}
]]
function server.cs_friend_gift_friendcoin(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:GiveFriendcoin(msg.targetid)
end

--[[
#接收友情币
cs_friend_receive_friendcoin 30012 {
	request {
		targetid 			0 : integer
	}
}
]]
function server.cs_friend_receive_friendcoin(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:GetFriendcoin(msg.targetid)
end

--[[
#关注推荐
cs_friend_follow_nominate 30016 {
	request {}
}
]]
function server.cs_friend_follow_nominate(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.friend:SendNominatefollow()
end
