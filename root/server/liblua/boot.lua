local xml = require "xml"
local lua_app = require "lua_app"


function main()
	local handler = lua_app.new_process("LuaProxy","launcher")
	local config = xml.parse_xml(lua_app.get_env("configure"))
	lua_app.regist_name(".launcher",handler)
	if lua_app.new_process("Logger",(lua_app.get_env("logger") or "lua_app")) <= 0 then
		lua_app.log_error("launcher config:Logger fail")
		lua_app.die()
		return
	end

	local center = config.center
	if center ~= nil and center.value ~= "" and lua_app.new_process("Center",center.value) <=0 then
		lua_app.log_error("launcher config:center fail")
		lua_app.die()
		return
	end

	local router = config.router
	if router ~= nil and router.value ~= "" and lua_app.new_process("Router",router.value) <= 0 then
		lua_app.log_error("launcher config:router fail")
		lua_app.die()
		return
	end

	if center ~= nil and router ~= nil then
		lua_app.raw_send(lua_app.self(),lua_app.get_router(),0,lua_app.MSG_ROUTER_TEXT,"connect",center.value)
	end

	--lua_app.raw_send(lua_app.self(),lua_app.get_router(),0,lua_app.MSG_ROUTER_TEXT,"connect",v.addr)
	local start = config.start.value
	if start ~= "" and lua_app.new_lua(lua_app.get_env("start")) <= 0 then
		lua_app.log_error("launcher config:main fail")
		lua_app.die()
		return
	end

	lua_app.exit()
end
