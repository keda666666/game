local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local SkillArgs = {}
local ActionType = FightConfig.ActionType

local _actcfg = false
local function _GetActcfg(id)
	if not _actcfg then
		_actcfg = server.configCenter.SkillsExeConfig
	end
	return _actcfg[id] 
end

local function _SetArgs(bargs, i)
	if not bargs[i] then
		bargs[i] = { args = {} }
		return bargs[i].args
	elseif not bargs[i].args then
		local args = {}
		bargs[i].args = args
		return args
	end
	return bargs[i].args
end
local _SetActcfg = {}
function _SetActcfg.a(value, id, args, i)
	local actcfg = _GetActcfg(id)
	if actcfg.type == ActionType.DAMAGE then
		local aargs = _SetArgs(args, i)
		if not aargs.a then
			aargs.a = value
		else
			lua_app.log_error("_SetActcfg.a: reset a", id)
		end
	end
end
function _SetActcfg.b(value, id, args, i)
	local actcfg = _GetActcfg(id)
	if actcfg.type == ActionType.DAMAGE then
		local aargs = _SetArgs(args, i)
		if not aargs.b then
			aargs.b = value
		else
			lua_app.log_error("_SetActcfg.b: reset b", id)
		end
	end
end
function _SetActcfg.changea(value, id, args, i)
	local actcfg = _GetActcfg(id)
	if actcfg.type == ActionType.DAMAGE then
		local aargs = _SetArgs(args, i)
		if not aargs.a then
			aargs.a = actcfg.args.a + value
		else
			lua_app.log_error("_SetActcfg.changea: reset a", id)
		end
	end
end
function _SetActcfg.changeb(value, id, args, i)
	local actcfg = _GetActcfg(id)
	if actcfg.type == ActionType.DAMAGE then
		local aargs = _SetArgs(args, i)
		if not aargs.b then
			aargs.b = actcfg.args.b + value
		else
			lua_app.log_error("_SetActcfg.changeb: reset b", id)
		end
	end
end
function _SetActcfg.buff(value, id, args, i)
	local actcfg = _GetActcfg(id)
	if actcfg.type == ActionType.ADDBUFF then
		if args[i] then
			if not args[i].args then
				args[i].args = value
			else
				lua_app.log_error("_SetActcfg.buff: reset buff", id)
			end
		else
			args[i] = { args = value }
		end
	end
end

-- 通过初始args分析拓展开
function SkillArgs.InitArgs(args, config)
	for k, v in pairs(args) do
		if type(k) == "string" then
			if config[k] then
				config[k] = v
			else
				for i, id in ipairs(config.actions) do
					_SetActcfg[k](v, id, args, i)
				end
			end
		end
	end
end

return SkillArgs