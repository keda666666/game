local server = require "server"
local lua_app = require "lua_app"
local oo = require "class"
require "modules.Event"

local _EventFunc = {
	Main			= { server.event.main },
	Init			= { server.event.init },
	ServerOpen		= { server.event.open },
	HotFix			= { server.event.hotfix },
	Release			= { server.event.release, true },
	onBeforeLogin	= { server.event.beforelogin },
	onLogin			= { server.event.login },
	onInitClient	= { server.event.clientinit },
	onBeforeLogout	= { server.event.beforelogout, true },
	onLogout		= { server.event.logout, true },
	onDayTimer		= { server.event.daytimer },
	onHalfHour		= { server.event.halfhourtimer },
	onLeaveMap		= { server.event.leavemap },
	onEnterMap		= { server.event.entermap },
	ResetServer		= { server.event.resetserver },
}

function server.UpdateCenter(ct, name)
	if not server[name] then
		lua_app.log_info("server.UpdateCenter not exist", name)
		return
	end
	for funcname, v in pairs(_EventFunc) do
		if ct[funcname] and not server.isreglocalfunc(v[1], name, funcname) then
			print("server.UpdateCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

function server.SetCenter(ct, name)
	if server[name] then
		server.UpdateCenter(ct, name)
		-- lua_app.log_info("server.SetCenter exist", name)
		return
	end
	server[name] = ct
	for funcname, v in pairs(_EventFunc) do
		if server[name][funcname] then
			-- print("server.SetCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

function server.NewCenter(ct, name)
	if server[name] then
		server.UpdateCenter(ct, name)
		-- lua_app.log_info("server.NewCenter exist", name)
		return
	end
	server[name] = ct.new()
	for funcname, v in pairs(_EventFunc) do
		if server[name][funcname] then
			-- print("server.NewCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

server.__unique_id = server.__unique_id or 0
function server.GetUID()
	server.__unique_id = server.__unique_id + 1
	return server.__unique_id
end
---------------------- 调用模块函数 ---------------------------
function server.SendRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	mod[funcname](mod, ...)
end
function server.CallRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	-- print("CallRunModFun", modname, funcname, ...)
	lua_app.ret(mod[funcname](mod, ...))
end