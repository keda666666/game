local lua_app = require "lua_app"


function main()
	local handler = lua_app.new_process("LuaProxy","launcher")
	lua_app.regist_name(".launcher",handler)
	if lua_app.new_process("Logger",(lua_app.get_env("logger") or "lua_app")) <= 0 then
		lua_app.log_error("launcher config:Logger fail")
		lua_app.die()
		return
	end
	
	if lua_app.new_lua(lua_app.get_env("start")) <= 0 then
		print("main failed")
		lua_app.log_error("launcher config:main fail")
		lua_app.die()
		return
	end

	lua_app.exit()
	print("client boot sucess")
end
