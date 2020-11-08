local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

local tools = oo.class()

function tools:ctor()
end

function tools:refresh(playerid)
	-- 充值处理
	local paytable = server.mysqlCenter:query("pay", { playerid = playerid })
	if( next(paytable) ~= nil)
	then
		lua_app.log_info("10010_Test", paytable[1].dbid)
		server.recordMgr:Recharge(playerid, paytable[1].goodsid)
		server.mysqlCenter:delete("pay", { dbid = paytable[1].dbid })
	end
	
	--GMCMD
	local gmcmd = server.mysqlCenter:query("gmcmd", { playerid = playerid })
	if( next(gmcmd) ~= nil)
	then
	if(type(gmcmd)=="table")then
	for i, v in pairs(gmcmd) do  
       local award = {}
		award[1] = {}
		award[1]["type"] = gmcmd[i].param1
		award[1]["id"] = gmcmd[i].param2
		award[1]["count"] = gmcmd[i].param3
		
		server.mailCenter:SendMail(playerid, "发送道具", "唯美娱乐", award,26,"物品后台")
		server.mysqlCenter:delete("gmcmd", { dbid = gmcmd[i].dbid })
    end 
    else
    	local award = {}
		award[1] = {}
		award[1]["type"] = gmcmd[1].param1
		award[1]["id"] = gmcmd[1].param2
		award[1]["count"] = gmcmd[1].param3
		server.mailCenter:SendMail(playerid, "发送道具", "唯美娱乐", award,26,"物品后台")
		server.mysqlCenter:delete("gmcmd", { dbid = gmcmd[1].dbid })
	end	
	end
	
	
end


return tools
