local args = {}



for word in string.gmatch(...,"%S+") do
	table.insert(args,word)
end

local file_code,pattern

local err = {}

for pat in string.gmatch(LUA_PROGRAM,"([^;]+);*") do
	local filename = string.gsub(pat,"?",args[1])
	local f,msg = loadfile(filename)
	if not f then
		table.insert(err,msg)
	else
		pattern = pat
		file_code = f
		break
	end
end

if not file_code then
	error(table.concat(err,"\n"))
end

LUA_PROGRAM = nil
package.path,LUA_PATH = LUA_PATH
package.cpath,LUA_CPATH = LUA_CPATH

local service_path = string.match(pattern,"(.*/)[^/?]+$")
if service_path then
	package.path = service_path .. ";" .. package.path
end

if LUA_RPRELOAD then
	local f = assert(loadfile(LUA_PRELOAD))
	f(table.unpack(args))
	LUA_PRELOAD = nil
end

file_code(select(2,table.unpack(args)))
