--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
# 请求升级技能
cs_skill_upgrade 304 {
	request {
		skillID	0 : integer
	}
}
]]
function server.cs_skill_upgrade(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.skill:Upgrade(msg.skillID)
end

--[[
# 请求技能一键升级
cs_skill_upgrade_all 305 {
	request {}
}
]]
function server.cs_skill_upgrade_all(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.skill:UpgradeAll()
end

--[[
# 调整技能释放顺序
cs_skill_sort_release 306 {
	request {
		skills 	0 : *integer
	}
}
]]
function server.cs_skill_sort_release(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.role.skill:UpdateSort(msg.skills)
end
