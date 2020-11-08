local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local BuffArgs = {}
local ActionType = FightConfig.ActionType

local _buffcfg = false
local function _GetBuffcfg(id)
	if not _buffcfg then
		_buffcfg = server.configCenter.EffectsConfig
	end
	return _buffcfg[id]
end

local _SetBuffcfg = {}
function _SetBuffcfg.a(value, id, args)
	if not args.a then
		args.a = value
	else
		lua_app.log_error("_SetBuffcfg.a: reset a", id)
	end
end
function _SetBuffcfg.b(value, id, args)
	if not args.b then
		args.b = value
	else
		lua_app.log_error("_SetBuffcfg.b: reset b", id)
	end
end
function _SetBuffcfg.changea(value, id, args)
	local buffcfg = _GetBuffcfg(id)
	if not args.a then
		args.a = buffcfg.args.a + value
	else
		lua_app.log_error("_SetBuffcfg.changea: reset a", id)
	end
end
function _SetBuffcfg.changeb(value, id, args)
	local buffcfg = _GetBuffcfg(id)
	if not args.b then
		args.b = buffcfg.args.b + value
	else
		lua_app.log_error("_SetBuffcfg.changeb: reset b", id)
	end
end
function _SetBuffcfg.t(value, id, args)
	if not args.t then
		args.t = value
	else
		lua_app.log_error("_SetBuffcfg.t: reset t", id)
	end
end
function _SetBuffcfg.d(value, id, args)
	if not args.d then
		args.d = value
	else
		lua_app.log_error("_SetBuffcfg.d: reset d", id)
	end
end
function _SetBuffcfg.s(value, id, args)
	if not args.s then
		args.s = value
	else
		lua_app.log_error("_SetBuffcfg.s: reset s", id)
	end
end

function _SetBuffcfg.i(value, id, args)
	if not args.i then
		args.i = value
	else
		lua_app.log_error("_SetBuffcfg.i: reset i", id)
	end
end
function _SetBuffcfg.p(value, id, args)
	if not args.p then
		args.p = value
	else
		lua_app.log_error("_SetBuffcfg.p: reset p", id)
	end
end
function _SetBuffcfg.changep(value, id, args)
	local buffcfg = _GetBuffcfg(id)
	if not args.p then
		args.p = buffcfg.args.p + value
	else
		lua_app.log_error("_SetBuffcfg.changep: reset p", id)
	end
end

-- 通过初始args分析拓展开
function BuffArgs.InitArgs(args, config)
	local aargs = args.args or {}
	for k, v in pairs(args) do
		if config[k] then
			config[k] = v
		else
			_SetBuffcfg[k](v, id, aargs)
		end
	end
	for k, v in pairs(config.args) do
		if not aargs[k] then
			aargs[k] = v
		end
	end
	return aargs
end

return BuffArgs