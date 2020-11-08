--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ChatConfig = require "resource.ChatConfig"
--[[
# 发送聊天信息
cs_chat_send_info 3101 {
	request {
		type 		0 : integer 	#聊天类型 1=世界聊天，2=私聊
		str			1 : string 		#内容
		recId 		2 : integer		#私聊需传入接收方id
	}
}
]]
function server.cs_chat_send_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if player then
    	local ret = server.chatCenter:Chat(player, msg.type, msg.str, msg.recId, msg.pointId or 0)
    	server.sendReq(player, "sc_chat_is_send_success", { success = ret })
    end
end

--[[
#查看在线
cs_chat_check_online 3116 {
	request {
		playerIdArray 		0 : *integer  	 	#查看列表
	}
	response {
		onlineStatus 		0 : *boolean 	#在线状态，位置与列表对应
	}
}
]]
function server.cs_chat_check_online(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local data = {}
    for _,id in ipairs(msg.playerIdArray) do
    	local status = false
    	if type(server.playerCenter:IsOnline(id)) == "number" then
    		status = true
    	end
    	table.insert(data, status)
    end
    return {
    	onlineStatus = data
	}
end

--[[
#私聊初始化
cs_chat_private_send_init 3111 {
	request {
		targetId 		0 : integer  		#目标id
	}
}
]]
function server.cs_chat_private_send_init(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if player then
    	server.chatCenter:PrivateChatStart(player, msg.targetId)
    end
end

--[[
#分享信息
cs_chat_share_info 3120 {
	request {
		shareId 	0 : integer 			#分享Id
		params 		1 : *client_chat_param 	#客户端参数
	}
}
]]
function server.cs_chat_share_info(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    if player then
   		server.chatCenter:ChatLink(msg.shareId, player, true, table.unpack(msg.params or {}))
   	end
end
