--配置服务 负责配置初始化和更新
local lua_app = require "lua_app"
local server = require "server"
local lua_util = require "lua_util"
local lua_share = require "lua_share"
local lua_shield = require "lua_shield"

local config = {}

local function InitConfig(baseCfg)
	local namePath = baseCfg.randname and baseCfg.randname.addr
	local configPath = baseCfg.valueconfig.addr
	lua_share.init(namePath,configPath)
end

function config:InitAll(baseCfg)
	InitConfig(baseCfg)
end

local function UpdateConfig()
	package.loaded["config.update"] = nil
	local cfg = require "config.update"
	for name,__ in pairs(cfg) do
		lua_share.refresh(name)
	end
end

function config:HotFixAll()
	UpdateConfig()
end

-- function config.Collect()
-- 	lua_app.add_local_timer(5000,config.Collect)
-- 	local startMem = collectgarbage("count")
-- 	collectgarbage("collect")
-- 	local overMem = collectgarbage("count")
-- 	lua_app.log_info("collect memory:",server.wholename,startMem,overMem)
-- end

--------------------------------- 下面是共享配置 ---------------------------------
function config:ShareConfig()
	server.configCenter = {}
	local mt = {}
	mt.__index = function(_,key)
		local cfg = lua_share.query(key)
		if cfg == nil then
			lua_app.log_error("config query failed",key)
			return {}
		end
		return cfg
	end
	mt.__newindex = function(_,key,value)
		lua_app.log_info("error config new")
	end
	setmetatable(server.configCenter,mt)
end

function config:HotFixConfig()
	lua_app.run_after(3000,function()
		lua_share.flush()
	end)
end

function config:ShareConfigCopy()
	server.configCenter = {}
	self.configDict = {}
	local mt = {
		__index = function(_, key)
			local cfg = self.configDict[key]
			if cfg == nil then
				cfg = lua_share.deepcopy(key)
				if cfg == nil then
					lua_app.log_error("config query failed", key)
					return {}
				else
					self.configDict[key] = cfg
				end
			end
			return cfg
		end,
		__newindex = function(_, key, value)
			lua_app.log_info("error config new")
		end,
	}
	setmetatable(server.configCenter, mt)
end

function config:HotFixConfigCopy()
	package.loaded["config.update"] = nil
	local updateCfg = require "config.update"
	lua_share.flush()
	for name, _ in pairs(updateCfg) do
		if self.configDict[name] then
			self.configDict[name] = lua_share.deepcopy(name)
		end
	end
end

function config:Init()
	if server.name == "logic" then
		self:ShareConfigCopy()
		lua_shield:Init(server.configCenter.maskwords)
	else
		self:ShareConfig()
	end
end

function config:HotFix()
	lua_app.run_after(3000, function()
		if server.name == "logic" then
			self:HotFixConfigCopy()
			lua_shield:Init(server.configCenter.maskwords)
		else
			self:HotFixConfig()
		end
	end)
end

if server.SetCenter then
	server.SetCenter(config, "configShareCenter")
end
return config