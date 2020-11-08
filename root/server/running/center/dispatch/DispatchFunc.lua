local lua_app = require "lua_app"
local server = require "server"

local DispatchFunc = {}

local function _GetNodeDtb(nnames, onesvrdtb)
	local svrdtb = {}
	for svrname, nodename in pairs(server.serverConfig.svrNameToNodeName) do
		if nnames[nodename] then
			svrdtb[svrname] = table.wcopy(onesvrdtb) or true
		end
	end
	return svrdtb
end
-- 测试用的
function DispatchFunc.DtbByTest(svrlist)
	local onesvrdtb = {}
	local i = 0
	for serverid, _ in pairs(svrlist) do
		i = i + 1
		onesvrdtb[serverid] = math.ceil(i/16)
	end
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end
-- 根据服务器ID判断
function DispatchFunc.DtbByServerid(svrlist)
	local onesvrdtb = {}
	local maxserverid = 0
	for serverid, _ in pairs(svrlist) do
		maxserverid = math.max(maxserverid, serverid)
	end
	for i = 1, maxserverid do
		onesvrdtb[i] = math.ceil(i/16)
	end
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end
-- 手动分配跨服
function DispatchFunc.DtbOneByOne(svrlist, onesvrdtb)
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end
--------------------------- 自动分配登录服和后台的 ---------------------------
local _autoDtbNames = {
	plat 		= true,
	record 		= true,
	--add wupeng
	cross		= true,
}
function DispatchFunc.AutoDtbByNum(svrlist, count)
	local cc = 0
	local onesvrdtb = {}
	for serverid, _ in pairs(svrlist) do
		cc = cc % count + 1
		onesvrdtb[serverid] = cc
	end
	return _GetNodeDtb(_autoDtbNames, onesvrdtb)
end
-- 增加服务器的分配
function DispatchFunc.AutoDtbAdd(svrlist, count, svrdtb)
	count = count or 1
	assert(count > 0, count)
	local function _GetMin(list)
		local min, minid = math.huge
		for id, count in pairs(list) do
			if min > count then
				minid = id
				min = count
			end
		end
		return minid
	end
	local newsvrdtb = {}
	for name, _ in pairs(_GetNodeDtb(_autoDtbNames)) do
		local onesvrdtb = svrdtb[name] or {}
		newsvrdtb[name] = {}
		local cc = {}
		local limitcount = server.GetServerNum()[name]
		--！！ ??
		for i = 1, limitcount or count do
			cc[i] = 0
		end
		for serverid, info in pairs(onesvrdtb) do
			cc[info.index] = cc[info.index] + 1
		end
		for serverid, _ in pairs(svrlist) do
			if not onesvrdtb[serverid] then
				local minid = _GetMin(cc)
				newsvrdtb[name][serverid] = minid
				cc[minid] = cc[minid] + 1
			end
		end
	end
	return newsvrdtb
end

return DispatchFunc