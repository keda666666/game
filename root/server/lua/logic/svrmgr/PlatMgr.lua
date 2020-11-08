local lua_app = require "lua_app"
local server = require "server"

local PlatMgr = {}

function PlatMgr:Recharge(serverid, account, playerid, order_number, goodsid, recharge, otherinfo)
	lua_app.log_info("============= PlatMgr:Recharge:", serverid, account, playerid, order_number, goodsid, recharge)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("PlatMgr:Recharge: no account:", serverid, account, playerid, order_number)
		return false, 7, "no account"
	end
	local needrecharge = player.recharge:GetRechargeInfo(goodsid)
	if not needrecharge or needrecharge < recharge - 0.0001 or needrecharge > recharge + 0.0001 then
		lua_app.log_error("PlatMgr:Recharge: error recharge amount:", serverid, account, playerid, order_number, goodsid, recharge, needrecharge)
		return false, 8, "error amount: " .. needrecharge, player.cache.name, 0, player.ip
	end
	local yuanbao = player.recharge:Recharge(goodsid)
	if not yuanbao then
		lua_app.log_error("PlatMgr:Recharge: error recharge:", serverid, account, playerid, order_number, goodsid, recharge, needrecharge)
		return false, 9, "error recharge", player.cache.name, yuanbao, player.ip
	end
	return true, 1, "SUCCESS", player.cache.name, yuanbao, player.cache.lastloginip
end

function server.GetLoginPlatParams()
	lua_app.ret({
		serverid = server.serverid,
		addr = server.cfgCenter.login.addr,
	})
end

server.SetCenter(PlatMgr, "platMgr")
return PlatMgr