local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local mysql = require "mysql"

local Blob = {}
local savetime = 5 * 60 * 1000
local versionname = "version"
local version = {
	columns = {
		{ "server",		"varchar(128)",	"",	"服务名" },
		{ "version",	"int(11)",		0,	"版本号" },
		{ "beforevs",	"int(11)",		0,	"更新前的版本号" },
	},
	prikey = { "server" },
	comment = "版本号表",
}

function Blob:Init(cfgCenter)
	assert(server.mysqlConfig)
	assert(server.mysqlCenter)
	local db = server.mysqlConfig.keepname and server.mysqlConfig.db or self:GetCorrectDB(server.mysqlConfig.db)
	local cache = cfgCenter.cache
	self:CheckDB(db, server.mysqlConfig, cache.ip, cache.port, cache.user, cache.pass, cache.dbname)
	self:CheckUpdate(server.mysqlConfig.update, db, cache.ip, cache.port, cache.user, cache.pass, cache.dbname)
	self:RefreshDBList(db)
	self.uniquecaches = {}
	self.cachelist = {}
	self.usecachelist = {}
	self.closecachelist = {}
	self:InitDBID(db)
	local function _Save()
		self.savetimer = lua_app.add_timer(savetime, _Save)
		self:Save()
	end
	self.savetimer = lua_app.add_timer(math.random(1, math.ceil(savetime/3))+savetime, _Save)
end

function Blob:GetCorrectDB(dbconfig)
	local db = {}
	for tbname, value in pairs(dbconfig) do
		db[server.GetSqlName(tbname)] = value
	end
	return db
end

function Blob:GetCorrectTB(tbname)
	return server.mysqlConfig.keepname and tbname or server.GetSqlName(tbname)
end

local _sortkeys = {}
local function _GetSortkey(key)
	if _sortkeys[key] then return _sortkeys[key] end
	local sortkey = {}
	for k, v in pairs(key) do
		if type(k) == "string" then
			table.insert(sortkey, k)
		else
			table.insert(sortkey, v)
		end
	end
	table.sort(sortkey)
	_sortkeys[key] = sortkey
	return sortkey
end
local function _GetKeyList(key)
	local keylist = {}
	for k, v in pairs(key) do
		if type(k) == "string" then
			keylist[k] = true
		else
			keylist[v] = true
		end
	end
	return keylist
end
local function _GetPrikeyCond(cache, tbconfig)
	assert(tbconfig.prikey)
	local sortkey = _GetSortkey(tbconfig.prikey)
	local cond = {}
	for _, key in ipairs(sortkey) do
		cond[key] = cache[key]
	end
	return cond
end

local _GetDefault = {}
_GetDefault["table"] = function(value)
	return ""
end
_GetDefault["string"] = function(value, ttype)
	if ttype and string.find(ttype, "CHARSET") then
		return " DEFAULT '" .. value .. "'"
	else
		return " COLLATE utf8mb4_bin DEFAULT '" .. value .. "'"
	end
end
_GetDefault["number"] = function(value)
	return " DEFAULT " .. value .. ""
end
local function _ConcatKeys(key)
	local sortkey = _GetSortkey(key)
	local tmp = {}
	for k, v in pairs(key) do
		if type(k) == "string" then
			table.insert(tmp, "`" .. k .. "`(" .. v .. ")")
		else
			table.insert(tmp, "`" .. v .. "`")
		end
	end
	return table.concat(tmp, ",")
end

function Blob:SetColumnSql(tbname, tb, beforename, settype)
	local def
	local ex = tb[5] and " " .. tb[5] or ""
	if string.find(ex, "AUTO_INCREMENT") then
		def = ""
	else
		local func = _GetDefault[type(tb[3])]
		assert(func, "error type:" .. (tostring(tb[3]) or type(tb[3])) .. "," .. (tb[1] or type(tb[1])) .. "," .. tbname)
		def = func(tb[3], tb[5])
	end
	local cmt = tb[4] and " COMMENT '" .. tb[4] .. "'" or ""
	local pos = beforename and " AFTER `" .. beforename .. "`" or " FIRST"
	return "ALTER TABLE `" .. tbname .. "` " .. settype .. " COLUMN `" .. tb[1] .. "` " .. tb[2] .. ex .. def .. cmt .. pos .. ";"
end

function Blob:CreateTableSql(tbname, tb)
	local tmp = {}
	for _, v in ipairs(tb.columns) do
		local def
		local ex = v[5] and " " .. v[5] or ""
		if string.find(ex, "AUTO_INCREMENT") then
			def = ""
		else
			local func = _GetDefault[type(v[3])]
			if not func then
				table.ptable(v, 5)
			end
			assert(func, "error type:" .. (tostring(v[3]) or type(v[3])) .. "," .. (v[1] or type(v[1])) .. "," .. tbname)
			def = func(v[3], v[5])
		end
		local cmt = v[4] and v[4] ~= "" and " COMMENT '" .. v[4] .. "'" or ""
		table.insert(tmp, "`" .. v[1] .. "` " .. v[2] .. ex .. def .. cmt )
	end
	if tb.prikey then
		table.insert(tmp, "PRIMARY KEY (" .. _ConcatKeys(tb.prikey) .. ")")
	end
	if tb.key then
		for k, v in pairs(tb.key) do
			table.insert(tmp, "KEY `" .. k .. "` (" .. _ConcatKeys(v) .. ")")
		end
	end
	local cmt = tb.comment and " COMMENT='" .. tb.comment .. "'" or ""
	return "CREATE TABLE IF NOT EXISTS `" .. tbname .. "` (" .. table.concat(tmp, ",") .. ") ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" .. cmt ..";"
end

function Blob:CheckTb(tbname, tbconfig, gconn, clconn, dbname, existtables)
	if not existtables[tbname] then
		local sql = self:CreateTableSql(tbname, tbconfig)
		lua_app.log_info("Blob:CheckTb::", sql)
		gconn:call_execute(sql)
	else
		local ret = clconn:query("columns", {
				table_schema = dbname,
				table_name = tbname,
			}, { column_name = true,
				column_type = true,
			})
		local columns = {}
		for _, vv in ipairs(ret) do
			columns[vv.column_name] = vv
		end
		local vvv
		for _, vv in ipairs(tbconfig.columns) do
			if not columns[vv[1]] then
				local sql = self:SetColumnSql(tbname, vv, vvv and vvv[1], "ADD")
				lua_app.log_info("Blob:CheckTb::", sql)
				gconn:call_execute(sql)
				gconn:update(tbname, {}, { [vv[1]] = vv[3] })
			elseif columns[vv[1]].column_type ~= vv[2] then
				local sql = self:SetColumnSql(tbname, vv, vvv and vvv[1], "MODIFY")
				lua_app.log_info("Blob:CheckTb::", sql)
				gconn:call_execute(sql)
			end
			vvv = vv
		end
	end
	if tbconfig.uniquevalue then
		if not gconn:query(tbname)[1] then
			local fields = {}
			for _, value in ipairs(tbconfig.columns) do
				fields[value[1]] = value[3]
			end
			gconn:insert_s(tbname, fields)
		end
	end
end

function Blob:CheckDB(dbconfig, config, ip, port, user, pass, dbname)
	-- print("Blob:CheckDB", ip, port, user, pass, dbname)
	local conn = mysql.client(ip, port, user, pass, "information_schema")
	local gconn = mysql.client(ip, port, user, pass, dbname)
	local ret = conn:query("tables", { table_schema = dbname }, { table_name = true })
	local tables = {}
	for _, v in ipairs(ret) do
		tables[v.table_name] = true
	end
	self:CheckTb(versionname, version, gconn, conn, dbname, tables)
	local beforeversion = config.beforeupdate
	local nowvs, bfvs = #config.update, beforeversion and #beforeversion or 0
	ret = gconn:query(versionname, { server = server.wholename }, { beforevs = true })[1]
	if not ret then
		gconn:insert_s(versionname, { server = server.wholename, version = nowvs, beforevs = bfvs })
	else
		for i = ret.beforevs + 1, bfvs do
			lua_app.log_info("Blob:CheckDB:: start update mysql before version", i)
			beforeversion[i](self, gconn)
			gconn:update(versionname, { server = server.wholename }, { beforevs = i })
			lua_app.log_info("Blob:CheckDB:: end update mysql before version", i)
		end
	end
	lua_app.log_info("Blob:CheckDB:: cur beforevs is", bfvs)
	for tbname, v in pairs(dbconfig) do
		self:CheckTb(tbname, v, gconn, conn, dbname, tables)
	end
	gconn:wait_close()
	conn:close()
	-- print("Blob:CheckDB -------------")
end

function Blob:CheckUpdate(updateconfig, dbconfig, ip, port, user, pass, dbname)
	local nowvs = #updateconfig
	-- print("Blob:CheckUpdate", nowvs, ip, port, user, pass, dbname)
	local gconn = mysql.client(ip, port, user, pass, dbname)
	local ret = gconn:query(versionname, { server = server.wholename }, { version = true })[1]
	for i = ret.version + 1, nowvs do
		lua_app.log_info("Blob:CheckUpdate:: start update mysql version", i)
		local ttype = type(updateconfig[i])
		if ttype == "table" then
			for tbname, upinfo in pairs(updateconfig[i]) do
				assert(dbconfig[tbname].prikey, tbname .. " no prikey")
				tbname = self:GetCorrectTB(tbname)
				local _, _, datas = gconn:call_execute("select count(*) as count from " .. tbname .. ";")
				local count = datas[1].count
				local fields
				if type(upinfo) == "table" then
					fields = _GetKeyList(dbconfig[tbname].prikey)
					for clname, _ in pairs(upinfo) do
						fields[clname] = true
					end
				end
				for j = 1, math.ceil(count/5000) do
					local oldvalues = gconn:query(tbname, nil, fields, (j - 1)*5000, 5000)
					for jj, oldvalue in ipairs(oldvalues) do
						local newvalue
						if type(upinfo) == "table" then
							newvalue = {}
							for clname, upfunc in pairs(upinfo) do
								newvalue[clname] = upfunc(self, gconn, oldvalue[clname])
							end
						else
							newvalue = upinfo(self, gconn, oldvalue)
						end
						local sql = gconn:get_update(tbname, _GetPrikeyCond(oldvalue, dbconfig[tbname]), newvalue)
						lua_app.log_info("  || update", tbname, (j - 1)*5000 + jj, sql)
						gconn:send_execute(sql)
						-- gconn:update(tbname, _GetPrikeyCond(oldvalue, dbconfig[tbname]), newvalue)
					end
				end
			end
		else
			updateconfig[i](self, gconn)
		end
		gconn:update(versionname, { server = server.wholename }, { version = i })
		lua_app.log_info("Blob:CheckUpdate:: end update mysql version", i)
	end
	lua_app.log_info("Blob:CheckUpdate:: cur version is", nowvs)
	gconn:wait_close()
	-- print("Blob:CheckUpdate -------------")
end

function Blob:RefreshDBList(db)
	self.dbconfig = db
	self.dblist = {}
	for name, v in pairs(db) do
		local tmp = {}
		for _, value in ipairs(v.columns) do
			tmp[value[1]] = value[3]
		end
		self.dblist[name] = tmp
	end
end
------------------------------ 数据库缓存 ------------------------------
local _DataType = {
	Normal	= 1,
	New 	= 2,
	Change	= 3,
	Del 	= 4,
}

function Blob:CreateCache(tbname, datas)
	local cache = table.wcopy(self.dblist[tbname])
	for k, v in pairs(datas) do
		if cache[k] then
			cache[k] = v
		end
	end
	if self.dbidtype[tbname] and not datas.dbid then
		cache.dbid = self:GetUID(tbname)
	end
	return self:AddCache(tbname, cache, _DataType.New)
end

function Blob:LoadCache(tbname, cond)
	local datas = server.mysqlCenter:query(tbname, cond)
	for _, cache in ipairs(datas) do
		self:AddCache(tbname, cache, _DataType.Normal)
	end
	return datas
end

function Blob:AddCache(tbname, cache, datatype, savenow)
	if not self.cachelist[tbname] then
		self.cachelist[tbname] = {}
	end
	self.cachelist[tbname][cache] = datatype
	if not self.usecachelist[tbname] then
		self.usecachelist[tbname] = {}
	end
	if datatype ~= _DataType.Normal then
		self.usecachelist[tbname][cache] = datatype
	end
	if not self.closecachelist[tbname] then
		self.closecachelist[tbname] = {}
	end
	self.closecachelist[tbname][cache] = nil
	if savenow then
		self:SaveOne(tbname, cache)
	end
	return cache
end

function Blob:CloseCache(tbname, cache)
	self:UpdateCache(tbname, cache)
	self.closecachelist[tbname][cache] = true
end

function Blob:DelCache(tbname, cache)
	if not self.cachelist[tbname] or not self.cachelist[tbname][cache] or self.cachelist[tbname][cache] == _DataType.Del then
		lua_app.log_error("Blob:SetCacheType:: no cache", tbname, cache)
		table.ptable(cache)
		return
	end
	if self.cachelist[tbname][cache] == _DataType.New then
		self.cachelist[tbname][cache] = nil
		self.usecachelist[tbname][cache] = nil
		self.closecachelist[tbname][cache] = nil
	else
		self.cachelist[tbname][cache] = _DataType.Del
		self.usecachelist[tbname][cache] = _DataType.Del
	end
end

function Blob:UpdateCache(tbname, cache)
	-- if not self.cachelist[tbname] or not self.cachelist[tbname][cache] or self.cachelist[tbname][cache] == _DataType.Del then
	-- 	lua_app.log_error("Blob:SetCacheType:: no cache", tbname, cache, datatype)
	-- 	table.ptable(cache)
	-- 	return
	-- end
	if self.cachelist[tbname][cache] == _DataType.Normal then
		self.cachelist[tbname][cache] = _DataType.Change
		self.usecachelist[tbname][cache] = _DataType.Change
	end
end

function Blob:IgnoreCache(tbname, cache)
	self.cachelist[tbname][cache] = nil
	self.usecachelist[tbname][cache] = nil
	self.closecachelist[tbname][cache] = nil
end

function Blob:GetDmg(tbname, cache)
	local _mt = {
		__index = function(tb, key)
			self:UpdateCache(tbname, cache)
			return cache[key]
		end,
		__newindex = function(tb, key, value)
			if cache[key] == nil or value == nil then
				lua_app.log_error("no cache key or value", key, value, tbname)
				return
			end
			cache[key] = value
			self:UpdateCache(tbname, cache)
		end,
		__bnot = function(tb)
			return cache
		end,
		__call = function(tb, isclose)
			if isclose then
				self:CloseCache(tbname, cache)
			else
				self:UpdateCache(tbname, cache)
			end
		end,
	}
	local dmg = {}
	setmetatable(dmg, _mt)
	return dmg
end

function Blob:NewDmg(tbname, cache, datatype, savenow)
	self:AddCache(tbname, cache, datatype, savenow)
	return self:GetDmg(tbname, cache)
end

function Blob:CreateDmg(tbname, datas, savenow)
	local cache = table.wcopy(self.dblist[tbname])
	if datas == nil then return end -- add wupeng
	for k, v in pairs(datas) do
		if cache[k] then
			cache[k] = v
		end
	end
	if self.dbidtype[tbname] and not datas.dbid then
		cache.dbid = self:GetUID(tbname)
	end
	return self:NewDmg(tbname, cache, _DataType.New, savenow)
end

function Blob:LoadDmg(tbname, cond)
	local datas = server.mysqlCenter:query(tbname, cond)
	local dmgs = {}
	for _, cache in ipairs(datas) do
		table.insert(dmgs, self:NewDmg(tbname, cache, _DataType.Normal))
	end
	return dmgs
end

function Blob:LoadOneDmg(tbname, cond)
	local datas = server.mysqlCenter:query(tbname, cond)
	if #datas ~= 1 then return end
	return self:NewDmg(tbname, datas[1], _DataType.Normal)
end

function Blob:GetUniqueCaches(tbname)
	if not self.uniquecaches[tbname] then
		lua_app.waitlockrun(self.uniquecaches, function()
				if self.uniquecaches[tbname] then return end
				local datas = server.mysqlCenter:query(tbname)
				assert(#datas == 1)
				self.uniquecaches[tbname] = datas[1]
				self:AddCache(tbname, datas[1], _DataType.Normal)
			end, 5)
		assert(self.uniquecaches[tbname])
	end
	return self.uniquecaches[tbname]
end

function Blob:LoadUniqueDmg(tbname, tbcolumn)
	local cache = self:GetUniqueCaches(tbname)
	local column = cache[tbcolumn]
	local _mt = {
		__index = function(tb, key)
			self:UpdateCache(tbname, cache)
			return column[key]
		end,
		__newindex = function(tb, key, value)
			-- if column[key] == nil or value == nil then
			-- 	lua_app.log_error("no cache key or value", key, value, tbname, tbcolumn)
			-- 	return
			-- end
			column[key] = value
			self:UpdateCache(tbname, cache)
		end,
		__bnot = function(tb)
			return cache
		end,
		__call = function(tb)
			self:UpdateCache(tbname, cache)
		end,
	}
	local dmg = {}
	setmetatable(dmg, _mt)
	return dmg
end

function Blob:LoadUniqueDmgAll(tbname)
	local cache = self:GetUniqueCaches(tbname)
	return self:GetDmg(tbname, cache)
end

function Blob:DelDmg(tbname, dmg)
	self:DelCache(tbname, ~dmg)
end

function Blob:DelDmgs(tbname, dmgs)
	for _, dmg in pairs(dmgs) do
		self:DelCache(tbname, ~dmg)
	end
end

function Blob:IgnoreDmg(tbname, dmg)
	self:IgnoreCache(tbname, ~dmg)
end
------------------------------ 各种数据唯一ID的生成 ------------------------------
function Blob:InitDBID(db)
	self.dbidlist = {}
	self.dbidtype = {}
	local function _GetMaxDbid(tbs)
		local maxid = 0
		for tbname, _ in pairs(tbs) do
			local a,b,data = server.mysqlCenter:call_execute("select max(`dbid`) as maxid from `"..tbname.."`;")
			maxid = math.max(maxid, math.ceil(data[1].maxid))
		end
		return maxid
	end
	local serveronly, platonly = {}, {}
	for tbname, v in pairs(db) do
		if self.dblist[tbname].dbid then
			self.dbidtype[tbname] = v.initdbid or "tableonly"
			if v.initdbid == "platonly" then
				platonly[tbname] = true
			elseif v.initdbid == "serveronly" then
				serveronly[tbname] = true
			else
				self.dbidlist[tbname] = _GetMaxDbid({ [tbname] = true })
				print("Blob:InitDBID:", tbname, self.dbidlist[tbname])
			end
		end
	end
	self.serverdbid = _GetMaxDbid(serveronly)
	self.platdbid = _GetMaxDbid(platonly)
	if self.platdbid < 1 then
		self.platdbid = (server.serverid or 0) << 34
	end
	print("Blob:InitDBID: serverdbid, platdbid", self.serverdbid, self.platdbid)
end

local _GetUID = {}
function _GetUID:tableonly(tbname)
	self.dbidlist[tbname] = self.dbidlist[tbname] + 1
	return self.dbidlist[tbname]
end
function _GetUID:serveronly()
	self.serverdbid = self.serverdbid + 1
	return self.serverdbid
end
function _GetUID:platonly()
	self.platdbid = self.platdbid + 1
	return self.platdbid
end
function Blob:GetUID(tbname)
	return _GetUID[self.dbidtype[tbname]](self, tbname)
end
------------------------------ 自动保存所有数据 ------------------------------
local function _GetPoolIndex(cache, tbname, tbconfig)
	if not tbconfig.prikey then return tbname end
	local sortkey = _GetSortkey(tbconfig.prikey)
	local index = cache[sortkey[1]]
	for i = 2, #sortkey do
		index = index .. cache[sortkey[i]]
	end
	return index
end
local _CacheSaveFunc = {}
_CacheSaveFunc[_DataType.New] = function(self, cache, tbname, tbconfig, index)
	server.mysqlCenter:insert_s(tbname, cache, index)
	self.cachelist[tbname][cache] = _DataType.Normal
end
_CacheSaveFunc[_DataType.Change] = function(self, cache, tbname, tbconfig, index)
	server.mysqlCenter:update(tbname, _GetPrikeyCond(cache, tbconfig), cache, index)
	self.cachelist[tbname][cache] = _DataType.Normal
end
_CacheSaveFunc[_DataType.Del] = function(self, cache, tbname, tbconfig, index)
	server.mysqlCenter:delete(tbname, _GetPrikeyCond(cache, tbconfig), index)
	self.cachelist[tbname][cache] = nil
	self.closecachelist[tbname][cache] = nil
end
function Blob:SaveOne(tbname, cache)
	local tbconfig = self.dbconfig[tbname]
	local datatype = self.cachelist[tbname][cache]
	local index = _GetPoolIndex(cache, tbname, tbconfig)
	_CacheSaveFunc[datatype](self, cache, tbname, tbconfig, index)
	self.usecachelist[tbname][cache] = nil
end

function Blob:Save()
	if self.isinsave then
		lua_app.log_error("Blob:Save isinsave", self.isinsave)
		return
	end
	self.isinsave = lua_app.now()
	for tbname, v in pairs(self.usecachelist) do
		local tbconfig = self.dbconfig[tbname]
		local delcache, othercache = {}, {}
		for cache, datatype in pairs(v) do
			if datatype == _DataType.Del then
				delcache[cache] = datatype
			else
				othercache[cache] = datatype
			end
		end
		for cache, datatype in pairs(delcache) do
			local index = _GetPoolIndex(cache, tbname, tbconfig)
			_CacheSaveFunc[datatype](self, cache, tbname, tbconfig, index)
		end
		for cache, datatype in pairs(othercache) do
			local index = _GetPoolIndex(cache, tbname, tbconfig)
			_CacheSaveFunc[datatype](self, cache, tbname, tbconfig, index)
		end
		self.usecachelist[tbname] = {}
	end
	for tbname, v in pairs(self.closecachelist) do
		for cache, _ in pairs(v) do
			self.cachelist[tbname][cache] = nil
		end
		self.closecachelist[tbname] = {}
	end
	self.isinsave = nil
end

function Blob:Release()
	if self.savetimer and self.savetimer ~= 0 then
		lua_app.del_timer(self.savetimer)
		self.savetimer = nil
	end
	local waitcount = 0
	while self.isinsave do
		lua_app.sleep(100)
		waitcount = waitcount + 1
		if waitcount % 50 then
			lua_app.log_info("Blob:Release isinsave, waitcount", self.isinsave, waitcount)
		end
	end
	-- -- 关服强制全部存一次
	-- for tbname, v in pairs(self.cachelist) do
	-- 	for cache, _ in pairs(v) do
	-- 		self:UpdateCache(tbname, cache)
	-- 	end
	-- end
	self:Save()
end

--add wupeng
function Blob:SaveTbname(name)

	for tbname, v in pairs(self.usecachelist) do
		if tbname == name then
			local tbconfig = self.dbconfig[tbname]
			local delcache, othercache = {}, {}
			for cache, datatype in pairs(v) do
				if datatype == _DataType.Del then
					delcache[cache] = datatype
				else
					othercache[cache] = datatype
				end
			end
			for cache, datatype in pairs(delcache) do
				local index = _GetPoolIndex(cache, tbname, tbconfig)
				_CacheSaveFunc[datatype](self, cache, tbname, tbconfig, index)
			end
			for cache, datatype in pairs(othercache) do
				local index = _GetPoolIndex(cache, tbname, tbconfig)
				_CacheSaveFunc[datatype](self, cache, tbname, tbconfig, index)
			end
			self.usecachelist[tbname] = {}
		end		
	end
	for tbname, v in pairs(self.closecachelist) do
		if tbname == name then
			for cache, _ in pairs(v) do
				self.cachelist[tbname][cache] = nil
			end
			self.closecachelist[tbname] = {}
		end		
	end
end

server.SetCenter(Blob, "mysqlBlob")
return Blob