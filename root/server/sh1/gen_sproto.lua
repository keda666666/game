local path = "./../../config/sproto/"


local cmd = string.format("find %s -name *.sproto",path)


local head = [[
--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
]]


local clientinclude = {}
local maxstrlength = 0
-- local serverinclude = ""

local function handleClientSproto(filename, clientdir)
	local file = io.open(filename)
	local str = ""
	local tb = {}
	local TT = {}
	local tfilename = filename:match(".*sproto%/(.*%_*%a%d%a)%.sproto")
	filename = string.format(clientdir .. "%s.lua",tfilename)
	local outfile = io.open(filename,"r")
	local outdata = ""
	if outfile ~= nil then
		outdata = outfile:read("a")
	end
	file:seek("set")
	local indata = file:read("a")
	indata = indata:gsub("(\r\n)","\n")
	local tid = tonumber(string.match(indata, "[%w_]+ -(%d+) -%b{}"))
	if not tid then
		tid = -1
	else
		tid = math.floor(tid/100)
	end
	local strtmp = string.format("	\"sproto.%s\",", tfilename)
	maxstrlength = math.max(maxstrlength, #strtmp)
	table.insert(clientinclude, { tid, strtmp, string.format("-- %s\n", tid) })
	--for str1,str2 in string.gmatch(indata,"(([%a%d_]+)%s+%d+%s+{.-[\n]-}[\n]-)") do
	for str1,str2,str3 in string.gmatch(indata,"(([%a%d_]+)%s+%d+%s+(%b{}))") do
		tb[str2] = tb[str2] or {}
		tb[str2][1] = str2
		tb[str2][2] = true
		if outdata:find(str2) ~= nil then
			tb[str2][2] = false
		end
		tb[str2][3] = ""
		tb[str2][4] = str1
		table.insert(TT,tb[str2])
	end
	for str0,str1,str2,str3 in string.gmatch(indata,"(#[^{}_%d]-[\r\n]-)(([%a%d_]+)%s+%d+%s+(%b{}))") do
		if str0 ~= nil then
			tb[str2][3] = str0
		end
	end
	for i = 1,#TT do
		local tab = TT[i]
		local key = tab[1]
		local status = tab[2]
		local strpre = tab[3]
		local strtotal = tab[4]
		if strpre == "" then
			outdata = outdata:gsub(key.."%s+%d+%s+(%b{})",strtotal)
		else
			outdata = outdata:gsub("(#[^{}_%d]+\n)"..key.."%s+%d+%s+(%b{})",strpre..strtotal)
		end
		if status then
			str = str.."\n--[[\n"..strpre..""
			str = str..strtotal.."\n]]\n"
			str = str.."function server."..key.."(socketid, msg)"
			str = str.."\n    local player = server.playerCenter:GetPlayerBySocket(socketid)"
			str = str.."\n\n"
			str = str.."end\n"
		end
	end
	outfile = io.open(filename,"w+")
	outfile:write(outdata)
	if outdata:find("head") == nil then
		local pos = outfile:seek("set",0)
		outfile:write(head)
	end
	outfile:write(str)
	file:flush()
	file:close()
	outfile:flush()
	outfile:close()
end


-- local function handleServerSproto(filename)
-- 	local file = io.open(filename)
-- 	local str = ""
-- 	local tb = {}
-- 	local TT = {}
-- 	filename = filename:match(".*sproto%/(.*%_*%a%d%a)%.sproto")
-- 	serverinclude = string.format("%s\nrequire 'logic.handler.serversproto.%s'",serverinclude,filename)
-- 	filename = string.format("./../lua/svr_game/logic/handler/serversproto/%s.lua",filename)
-- 	local outfile = io.open(filename,"r")
-- 	local outdata = ""
-- 	if outfile ~= nil then
-- 		outdata = outfile:read("a")
-- 	end
-- 	file:seek("set")
-- 	local indata = file:read("a")
-- 	indata = indata:gsub("(\r\n)","\n")
-- 	--for str1,str2 in string.gmatch(indata,"(([%a%d_]+)%s+%d+%s+{.-[\n]-}[\n]-)") do
-- 	for str1,str2,str3 in string.gmatch(indata,"(([%a%d_]+)%s+%d+%s+(%b{}))") do
-- 		tb[str2] = tb[str2] or {}
-- 		tb[str2][1] = str2
-- 		tb[str2][2] = true
-- 		if outdata:find(str2) ~= nil then
-- 			tb[str2][2] = false
-- 		end
-- 		tb[str2][3] = ""
-- 		tb[str2][4] = str1
-- 		table.insert(TT,tb[str2])
-- 	end
-- 	for str0,str1,str2,str3 in string.gmatch(indata,"(#[^{}_%d]-[\r\n]-)(([%a%d_]+)%s+%d+%s+(%b{}))") do
-- 		if str0 ~= nil then
-- 			tb[str2][3] = str0
-- 		end
-- 	end
-- 	for i = 1,#TT do
-- 		local tab = TT[i]
-- 		local key = tab[1]
-- 		local status = tab[2]
-- 		local strpre = tab[3]
-- 		local strtotal = tab[4]
-- 		if strpre == "" then
-- 			outdata = outdata:gsub(key.."%s+%d+%s+(%b{})",strtotal)
-- 		else
-- 			outdata = outdata:gsub("(#[^{}_%d]+\n)"..key.."%s+%d+%s+(%b{})",strpre..strtotal)
-- 		end
-- 		if status then
-- 			str = str.."--[[\n"..strpre..""
-- 			str = str..strtotal.."\n]]\n"
-- 			str = str.."function server."..key.."(actor)\n"
-- 			str = str.."\tlocal data = {}\n\n"
-- 			str = str.."\tserver.sendReq(actor,\""..key.."\",data)\n"
-- 			str = str.."end\n\n"
-- 		end
-- 	end
-- 	outfile = io.open(filename,"w+")
-- 	outfile:write(outdata)
-- 	if outdata:find("head") == nil then
-- 		local pos = outfile:seek("set",0)
-- 		outfile:write(head)
-- 		outfile:write("\n\n")
-- 	end
-- 	outfile:write(str)
-- 	file:flush()
-- 	file:close()
-- 	outfile:flush()
-- 	outfile:close()
-- end


-- serverdir = "./../lua/logic/sproto/"
clientdir = "./../lua/logic/sproto/"
-- os.execute("mkdir -p "..serverdir)
os.execute("mkdir -p "..clientdir)
for filename in io.popen(cmd):lines() do
	if filename:find("c2s") then
		handleClientSproto(filename, clientdir)
	end
	-- if filename:find("s2c") then
	-- 	handleServerSproto(filename)
	-- end
end

local filename = "./../lua/logic/sproto/SprotoMgr.lua"
local outfile = io.open(filename,"w+")
-- outfile:write(serverinclude)
-- outfile:write("\n\n")
-- outfile:write("\n\n")
table.sort(clientinclude, function(a, b)
		return a[1] < b[1]
	end)
maxstrlength = maxstrlength + 3
local ttmpinclude = {
[[local oo = require "class"

local handlers = 
{
]]
}
for _, v in ipairs(clientinclude) do
	table.insert(ttmpinclude,  string.sub(v[2] .. string.rep(" ", maxstrlength), 1, maxstrlength) .. v[3])
end
table.insert(ttmpinclude, 
[[}

oo.require_handler(handlers)
]])
clientinclude = table.concat(ttmpinclude)
outfile:write(clientinclude)
-- outfile:write("\n\n")
-- outfile:write("\n\n")
outfile:close()

