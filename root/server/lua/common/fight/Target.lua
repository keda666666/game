local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

local Target = {}

local _TargetGetType = {
	Self				= 1,		-- 自己
	SelfAll				= 2,		-- 己方全体
	SelfRand			= 3,		-- 己方随机
	EnemyAll			= 4,		-- 敌方全体
	EnemyRand			= 5,		-- 敌方随机
	EnemyDamage			= 6,		-- 上一次攻击我的对象
	AllTarget			= 10001,	-- 所有目标
	RoundOne			= 10002,	-- 循环的顺序选取
	ChooseOnce			= 10003,	-- 每个最多选取一次的顺序选取
	RandTarget			= 10004,	-- 随机count个
}
local _GetByConfig = {}
local _CheckByConfig = {}
_GetByConfig[_TargetGetType.Self] = function(caster, config)
	return { caster }
end

_GetByConfig[_TargetGetType.SelfAll] = function(caster, config)
	return caster:GetSelfTargetList()
end

_GetByConfig[_TargetGetType.SelfRand] = function(caster, config)
	local ar = caster:GetSelfTargetList()
	return lua_util.getarray(ar, config.count)
end
_CheckByConfig[_TargetGetType.SelfRand] = function(caster, config, targets)
	local ar = caster:GetSelfTargetList()
	local retar = {}
	for _, entity in ipairs(ar) do
		if targets[entity.handler] then
			table.insert(retar, entity)
		end
	end
	if #retar > config.count then
		return false
	end
	return retar
end

_GetByConfig[_TargetGetType.EnemyAll] = function(caster, config)
	return caster:GetAttackList()
end

_GetByConfig[_TargetGetType.EnemyRand] = function(caster, config)
	local ar = caster:GetAttackList()
	return lua_util.getarray(ar, config.count)
end
_CheckByConfig[_TargetGetType.EnemyRand] = function(caster, config, targets)
	local ar = caster:GetAttackList()
	local retar = {}
	for _, entity in ipairs(ar) do
		if targets[entity.handler] then
			table.insert(retar, entity)
		end
	end
	if #retar > config.count then
		return false
	end
	if #retar < config.count then
		local entitys = lua_util.getarray(ar, config.count)
		for _, entity in pairs(entitys) do
			if not targets[entity.handler] then
				table.insert(retar, entity)
				if #retar == config.count then
					break
				end
			end
		end
	end
	return retar
end
_GetByConfig[_TargetGetType.EnemyDamage] = function(caster, config)
	local ar = caster:GetLastCasterList()
	return lua_util.getarray(ar, config.count)
end

_GetByConfig[_TargetGetType.AllTarget] = function(caster, config, targets)
	return targets
end
_GetByConfig[_TargetGetType.RoundOne] = function(caster, config, targets, last)
	last = (last + 1)%(#targets)
	return { targets[last] }, last
end
_GetByConfig[_TargetGetType.ChooseOnce] = function(caster, config, targets, last)
	last = last + 1
	return { targets[last] }, last
end
_GetByConfig[_TargetGetType.RandTarget] = function(caster, config, targets)
	return lua_util.getarray(targets, config.count)
end

function Target:GetByConfig(caster, ttype, config, targets, last)
	return _GetByConfig[ttype](caster, config, targets, last)
end

function Target:CheckTargets(caster, ttype, config, targets)
	if not _CheckByConfig[ttype] then
		return false
	end
	return _CheckByConfig[ttype](caster, config, targets)
end

return Target