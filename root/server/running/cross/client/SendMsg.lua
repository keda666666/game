local ws = require "lua_ws"
local server = require "server"
local lua_app = require "lua_app"
-- 发送
function server.sendToPlayer(player, name, param)
	if not player then return end
	player:sendReq(name, param)
end

