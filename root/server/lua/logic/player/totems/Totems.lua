local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"


local Totems = oo.class()

function Totems:ctor(player)
	self.player = player
	self.role = player.role
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Totems
end

function Totems:onCreate()
	self:onLoad()
end

function Totems:onLoad()
	--加载,计算属性
	self.cache = self.player.cache.totems

	local baseConfig = server.configCenter.TotemsBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	if self.player.cache.level < openConfig[baseConfig.openlv].conditionnum then return end

	local attrsConfig = server.configCenter.TotemsAttrsConfig
	local attrs = {}
	for id,data in pairs(self.cache.data) do
		local lv = data.lv
		if data.breach ~= 0 then
			lv = data.breach
		end

		local attrsConfig = server.configCenter.TotemsAttrsConfig
		for _,attr in pairs(attrsConfig[id][lv].attr) do
			table.insert(attrs, table.wcopy(attr))
		end
		if attrsConfig[id][lv].attrpower then
			for _,attr in pairs(attrsConfig[id][lv].attrpower) do
				table.insert(attrs, table.wcopy(attr))
			end
		end
	end
	self.role:UpdateBaseAttr({}, attrs)
end

function Totems:onInitClient()
	--登录发送
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_totems_info", msg) 
end

function Totems:onLogout(player)
	--离线
end

function Totems:onLogin(player)
	--加载后续处理？？
end

function Totems:onDayTimer()
	for _,data in pairs(self.cache.data) do
		data.todayNum = 0
		data.todayId = 1
	end
	self:onInitClient()
end

function Totems:onLevelUp(oldlevel, newlevel)
	--升级
end

function Totems:packInfo()
	local msg = {data={}}
	for id,info in pairs(self.cache.data) do
		table.insert(msg.data, info)
	end
	return msg
end

function Totems:Open(id)
	local baseConfig = server.configCenter.TotemsBaseConfig
	local openConfig = server.configCenter.FuncOpenConfig
	if self.player.cache.level < openConfig[baseConfig.openlv].conditionnum then return {ret = false} end

	local actConfig = server.configCenter.TotemsActConfig
	if not actConfig[id] then return {ret = false} end
	if self.cache.data[id] then return {ret = false} end
	if not self.player:PayRewards(actConfig[id].cost, self.YuanbaoRecordType, "totems open "..id) then
		return {ret = false}
	end
	local data = {
		id = id,
		lv = 1,
		upNum = 0,
		todayNum = 0,
		todayId = 1,
		breach = 0,
	}
	self.cache.data[id] = data

	local attrs = {}
	local attrsConfig = server.configCenter.TotemsAttrsConfig
	for _,attr in pairs(attrsConfig[id][data.lv].attr) do
		table.insert(attrs, table.wcopy(attr))
	end
	if attrsConfig[id][data.lv].attrpower then
		for _,attr in pairs(attrsConfig[id][data.lv].attrpower) do
			table.insert(attrs, table.wcopy(attr))
		end
	end
	self.role:UpdateBaseAttr({}, attrs)

	local msg = table.wcopy(data)
	msg.ret = true
	return msg
end

function Totems:AddExp(id, num, autobuy)
	local data = self.cache.data[id]
	if not data then return {ret = false} end
	if data.breach ~= 0 then return {ret = false} end
	local attrsConfig = server.configCenter.TotemsAttrsConfig
	if num > 50 then return {ret = false} end
	local baoJiConfig = server.configCenter.TotemsBaoJiConfig
	local baseConfig = server.configCenter.TotemsBaseConfig

	local randAllNum = 0
	for _,num in pairs(baseConfig.baojipro) do
		randAllNum = randAllNum + num
	end
	local crtNum = 0
	local oldLv = data.lv
	local tag = false
	for i=1,num do
		if not attrsConfig[id][data.lv].upnum then return {ret = false} end
		if not self.player:PayRewardsByShop(attrsConfig[id][data.lv].cost, self.YuanbaoRecordType, "totems addLv "..id, autobuy) then
			break
		end
		tag = true
		data.todayNum = data.todayNum + 1

		local addnum = 1
		
		if data.todayNum >= baoJiConfig[data.todayId].num then
			addnum = baoJiConfig[data.todayId].rat
			crtNum = crtNum + addnum
			data.todayNum = data.todayNum - baoJiConfig[data.todayId].num
			data.todayId = data.todayId + 1
			if not baoJiConfig[data.todayId] then
				data.todayId = 1
			end
		else
			local randNum = math.random(randAllNum)
			for crt,num in pairs(baseConfig.baojipro) do
				if randNum <= num then
					addnum = crt
					if crt > 1 then
						crtNum = crtNum + crt
					end
					break
				else
					randNum = randNum - num
				end
			end

		end
		
		data.upNum = data.upNum + addnum
		if data.upNum >= attrsConfig[id][data.lv].upnum then
			while true do
				data.upNum = data.upNum - attrsConfig[id][data.lv].upnum
				data.lv = data.lv + 1
				if not attrsConfig[id][data.lv].upnum then break end
				if data.breach == 0 and attrsConfig[id][data.lv].tpcost then
					data.breach = data.lv - 1
				end
				if data.upNum < attrsConfig[id][data.lv].upnum then break end
			end
		end
		if not attrsConfig[id][data.lv].upnum then break end
	end
	if not tag then return {ret = false} end

	local newLv = data.lv
	if data.breach ~= 0 then
		newLv = data.breach
	end
	if oldLv ~= newLv then
		local oldAttr = {}
		for _,attr in pairs(attrsConfig[id][oldLv].attr) do
			table.insert(oldAttr, table.wcopy(attr))
		end
		if attrsConfig[id][oldLv].attrpower then
			for _,attr in pairs(attrsConfig[id][oldLv].attrpower) do
				table.insert(oldAttr, table.wcopy(attr))
			end
		end

		local newAttr = {}
		for _,attr in pairs(attrsConfig[id][newLv].attr) do
			table.insert(newAttr, table.wcopy(attr))
		end
		if attrsConfig[id][newLv].attrpower then
			for _,attr in pairs(attrsConfig[id][newLv].attrpower) do
				table.insert(newAttr, table.wcopy(attr))
			end
		end
		self.role:UpdateBaseAttr(oldAttr, newAttr)
	end

	if crtNum > 0 then
		server.sendErr(self.player, string.format("触发了%s倍暴击，共获得%s点经验值", crtNum, crtNum * 10))
	end
	local msg = table.wcopy(data)
	msg.ret = true
	return msg
end

function Totems:Breach(id)
	local data = self.cache.data[id]
	if not data then return {ret = false} end
	if data.breach == 0 then return {ret = false} end
	local attrsConfig = server.configCenter.TotemsAttrsConfig
	local cost = attrsConfig[id][data.breach + 1].tpcost
	if not self.player:PayRewards(cost, self.YuanbaoRecordType,"totems breach "..id) then
		return {ret = false}
	end
	local oldLv = data.breach
	data.breach = 0
	for i = 1,data.lv - oldLv do
		local nextLv = oldLv + i + 1
		if attrsConfig[id][nextLv].tpcost then
			data.breach = nextLv
			break
		end
	end
	local newLv = data.lv
	if data.breach ~= 0 then
		newLv = data.breach
	end

	local oldAttr = {}
	for _,attr in pairs(attrsConfig[id][oldLv].attr) do
		table.insert(oldAttr, table.wcopy(attr))
	end
	if attrsConfig[id][oldLv].attrpower then
		for _,attr in pairs(attrsConfig[id][oldLv].attrpower) do
			table.insert(oldAttr, table.wcopy(attr))
		end
	end

	local newAttr = {}
	for _,attr in pairs(attrsConfig[id][newLv].attr) do
		table.insert(newAttr, table.wcopy(attr))
	end
	if attrsConfig[id][newLv].attrpower then
		for _,attr in pairs(attrsConfig[id][newLv].attrpower) do
			table.insert(newAttr, table.wcopy(attr))
		end
	end
	self.role:UpdateBaseAttr(oldAttr, newAttr)
	
	local msg = table.wcopy(data)
	msg.ret = true
	return msg
end

server.playerCenter:SetEvent(Totems, "totems")
return Totems