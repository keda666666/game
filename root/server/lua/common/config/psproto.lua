local server = require "server"
local lua_app = require "lua_app"
local sprotoparser = require "sproto.sprotoparser"
local sprotoloader = require "sproto.sprotoloader"

local function InitProto(baseCfg)
	local path = baseCfg.proto.addr
	local c2stb = {}
	local s2ctb = {}
	local typetb = {}
	for file in io.popen("ls "..path):lines() do
		if string.find(file,"c2s") ~= nil then
			table.insert(c2stb,file)
		end
		if string.find(file,"s2c") ~= nil then
			table.insert(s2ctb,file)
		end
		if string.find(file,"type") ~= nil then
			table.insert(typetb,file)
		end
	end
	local c2sstr = ""
	local s2cstr = ""
	local typestr = ""
	for _,v in pairs(typetb) do
		local f = io.open(path.."/"..v)
		local data = f:read "a"
		f:close()
		typestr = typestr..data.."\r\n"
	end
	for _,v in pairs(c2stb) do
		local f = io.open(path.."/"..v)
		local data = f:read "a"
		f:close()
		c2sstr = c2sstr..data.."\r\n"
	end
	for _,v in pairs(s2ctb) do
		local f = io.open(path.."/"..v)
		local data = f:read "a"
		f:close()
		s2cstr = s2cstr..data.."\r\n"
	end
	c2sstr = typestr .. c2sstr
	s2cstr = typestr .. s2cstr
	local c2sbin = sprotoparser.parse(c2sstr)
	local s2cbin = sprotoparser.parse(s2cstr)
	sprotoloader.save(c2sbin,1)
	sprotoloader.save(s2cbin,2)
end

InitProto(server.cfgCenter)
