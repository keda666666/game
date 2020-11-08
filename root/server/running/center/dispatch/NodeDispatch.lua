local lua_app = require "lua_app"
local server = require "server"
local tbname = "nodelist"

local NodeDispatch = {}

function NodeDispatch:Init()
	self.nodes = {}
	self.nodelist = {}
	self.nodecounts = {}
	self.servicelist = {}
	local values = server.mysqlCenter:query(tbname)
	for _, value in ipairs(values) do
		self:SetNode(value.node, value.name, value.area)
	end
	self:SetNodeNumServer()
end

function NodeDispatch:Release()
end

function NodeDispatch:NodeConnect(nname, node)
	if not self.nodes[nname] then self.nodes[nname] = {} end
	self.nodes[nname][node] = true
	local infos = {}
	for name, nodelist in pairs(self.nodelist) do
		infos[name] = nodelist[node]
	end
	server.nodeCenter:Send(nname, node, "SetMultServer", infos)
end

function NodeDispatch:SetNode(node, name, index)
	if not self.servicelist[name] then
		self.servicelist[name] = {}
	end
	self.servicelist[name][index] = node
	if not self.nodelist[name] then
		self.nodelist[name] = {}
	end
	if not self.nodelist[name][node] then
		self.nodelist[name][node] = {}
	end
	self.nodelist[name][node][index] = true
	if not self.nodecounts[name] then
		self.nodecounts[name] = {}
	end
	self.nodecounts[name][node] = (self.nodecounts[name][node] or 0) + 1
	lua_app.log_info("NodeDispatch:SetNode::", node, name, index)
end

function NodeDispatch:RemoveNode(node)
	for name, nodelist in pairs(self.nodelist) do
		local indexs = nodelist[node]
		if indexs then
			nodelist[node] = nil
			self.nodecounts[name][node] = nil
			local servicelist = self.servicelist[name]
			for index, _ in pairs(indexs) do
				servicelist[index] = nil
				lua_app.log_info("NodeDispatch:RemoveNode::", node, name, index)
			end
		end
	end
	server.mysqlCenter:delete(tbname, { node = node })
end

function NodeDispatch:MoveNode(node, tonode)
	if node == tonode then return end
	for name, nodelist in pairs(self.nodelist) do
		local indexs = nodelist[node]
		if indexs then
			nodelist[node] = nil
			self.nodecounts[name][node] = nil
			local servicelist = self.servicelist[name]
			for index, _ in pairs(indexs) do
				servicelist[index] = nil
				lua_app.log_info("NodeDispatch:MoveNode::", node, name, index, tonode)
				self:SetNode(tonode, name, index)
			end
		end
	end
	server.mysqlCenter:update(tbname, { node = node }, { node = tonode })
end

function NodeDispatch:RemoveOneNodeIndex(node, name, index)
	self.servicelist[name][index] = nil
	self.nodelist[name][node][index] = nil
	if not next(self.nodelist[name][node]) then
		self.nodelist[name][node] = nil
	end
	self.nodecounts[name][node] = self.nodecounts[name][node] - 1
	if self.nodecounts[name][node] == 0 then
		self.nodecounts[name][node] = nil
	end
	server.mysqlCenter:delete(tbname, { node = node, name = name, area = index })
	lua_app.log_info("NodeDispatch:RemoveOneNodeIndex::", node, name, index)
end

function NodeDispatch:MoveOneNodeIndex(node, tonode, name, index)
	if node == tonode then return end
	self:RemoveOneNodeIndex(node, name, index)
	self:SetNode(tonode, name, index)
	server.mysqlCenter:update(tbname, { name = name, area = index }, { node = tonode })
end

function NodeDispatch:ClearDtb()
	self.nodelist = {}
	self.nodecounts = {}
	self.servicelist = {}
	server.mysqlCenter:delete(tbname)
	lua_app.log_info("NodeDispatch:ClearDtb")
end

function NodeDispatch:GetIdleNode(name)
	local mincount, node = math.huge
	local nname = server.serverConfig.svrNameToNodeName[name]
	for n, _ in pairs(self.nodes[nname]) do
		if not self.nodecounts[name] then
			self.nodecounts[name] = {}
		end
		local count = self.nodecounts[name][n] or 0
		if mincount > count then
			mincount = count
			node = n
		end
	end
	assert(node)
	local nodesvrlist = server.nodeCenter.svrlist[name] or {}
	if not nodesvrlist[node] then
		local mincount, anode = math.huge
		for n, _ in pairs(self.nodes[nname]) do
			local count = self.nodecounts[name][n] or 0
			if nodesvrlist[n] and mincount > count then
				mincount = count
				anode = n
			end
		end
		return anode or node
	end
	return node
end

function NodeDispatch:CheckNodeEnough(_, waitcheck)	
	local nodes = {}
	local tmpcrossdtbnode = {}	-- 保证index相同的情况下分配在同一个cross
	if self.checkNodeTimer then
		lua_app.del_local_timer(self.checkNodeTimer)
		self.checkNodeTimer = nil
	end
	if waitcheck then
		for name, _ in pairs(server.dispatchCenter.dtblist) do
			--因为没有后台所以这里只判断war 和 world
			if name == "war" or name == "world" then
				if not self.nodes[server.serverConfig.svrNameToNodeName[name]] then
					self.checkNodeTimer = lua_app.add_update_timer(5000, self, "CheckNodeEnough", waitcheck)
					--print("NodeDispatch:CheckNodeEnough:: waiting node", server.serverConfig.svrNameToNodeName[name], name)
					return
				end
			end			
		end
	end
	for name, dtblist in pairs(server.dispatchCenter.dtblist) do
		if not self.servicelist[name] then
			self.servicelist[name] = {}
		end
		local nname = server.serverConfig.svrNameToNodeName[name]
		for index, _ in pairs(dtblist) do
			assert(type(index) == "number", index .. "(" .. type(index) .. ")")
			if not self.servicelist[name][index] and self.nodes[nname] then
				local node
				if nname == "cross" then
					node = tmpcrossdtbnode[index] or self:GetIdleNode(name)
					tmpcrossdtbnode[index] = node
				else
					node = self:GetIdleNode(name)
				end
				self:SetNode(node, name, index)
				table.insert(nodes, {
						node = node,
						name = name,
						area = index,
					})
			end
		end
	end
	if next(nodes) then
		server.mysqlCenter:insert_ms(tbname, nodes)
		lua_app.waitmultrun(function(_, info)
			local nname = server.serverConfig.svrNameToNodeName[info.name]
			if self.nodes[nname] then
				return server.nodeCenter:Call(nname, info.node, "SetNewServer", info.name, info.area)
			end
		end, nodes)
	end
end
-- 分配固定数量的服务
function NodeDispatch:SetNodeNumServer()
	if self.checkNodeNumTimer then
		lua_app.del_local_timer(self.checkNodeNumTimer)
		self.checkNodeNumTimer = nil
	end
	for nname, num in pairs(server.GetNodeNum()) do
		local count = 0
		for _, _ in pairs(self.nodes[nname] or {}) do
			count = count + 1
		end
		if count < num then
			self.checkNodeNumTimer = lua_app.add_update_timer(5000, self, "SetNodeNumServer")
			-- print("NodeDispatch:SetNodeNumServer:: waiting node", nname, num - count)
			return
		end
	end
	local nodes = {}
	local nums = server.GetServerNum()
	for name, num in pairs(nums) do
		if not self.servicelist[name] then
			self.servicelist[name] = {}
		end
		for index = 1, num do
			if not self.servicelist[name][index] then
				local node = self:GetIdleNode(name)
				self:SetNode(node, name, index)
				table.insert(nodes, {
						node = node,
						name = name,
						area = index,
					})
			end
		end
	end
	if next(nodes) then
		server.mysqlCenter:insert_ms(tbname, nodes)
		lua_app.waitmultrun(function(_, info)
			local nname = server.serverConfig.svrNameToNodeName[info.name]
			if self.nodes[nname] then
				return server.nodeCenter:Call(nname, info.node, "SetNewServer", info.name, info.area)
			end
		end, nodes)
	end
end
-- 自动删除无用节点并将节点服务转向新节点
function NodeDispatch:AotuRemoveUnableCrossNode()
	local remove = {}
	for name, info in pairs(self.nodelist) do
		for node, _ in pairs(info) do
			if not server.nodeCenter.svrlist[node] then
				remove[node] = name
			end
		end
	end
	for node, name in pairs(remove) do
		self:MoveNode(node, self:GetIdleNode(name))
	end
end

server.SetCenter(NodeDispatch, "nodeDispatch")
return NodeDispatch