--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
checkAccount 1 {
	request {
		accountname 0 : string
		password 1 : string
		platformuid 2 : string
		token 3 : string
		serverid 4 : integer
		lid 5 : string
	}
	response {
		result 0 : integer
	}
}
]]
function server.checkAccount(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
QueryList 2 {
	request { }

	response {
		code 0 : boolean
		actorid 1 : integer		# >0 有一个角色， 0 无角色， -1 多个角色,看actorlist
		actorlist 2 : *actorlist
	}
}
]]
function server.QueryList(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
EnterGame 3 {
	request {
		actorid 0 : integer
	}
	response {
		result	0 : integer
		QQ		1 : string
	}
}
]]
function server.EnterGame(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
CreateActor 4 {
	request {
		actorname 0 : string
		sex 1 : integer
		job 2 : integer
		icon 3 : integer
		pf 4 : string
	}
	response {
		result 0 : integer
		actorid 1 : integer
	}
}
]]
function server.CreateActor(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
RandName 5 {
	request {
		sex 0 : integer
	}
	response {
		result 0 : integer
		actorname 1 : string
	}
}
]]
function server.RandName(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)

end

--[[
cs_base_get_game_time 6 {}
]]
function server.cs_base_get_game_time(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.sendReq(player, "sc_base_game_time", { time = lua_app.now(), serverRunDay = server.serverRunDay})
end
