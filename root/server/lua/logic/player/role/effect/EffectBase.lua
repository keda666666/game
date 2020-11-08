local oo = require "class"
local lua_app = require "lua_app"
local server = require "server"
local lua_app = require "lua_app"

local EffectBase = oo.class()
function EffectBase:ctor(role)
	self.role = role
	self.player = role.player
	self.partcollect = {}
end

function EffectBase:Load()
	self.cache.termlist = self.cache.termlist or {}
	local attrs = {}
	for _, id in pairs(self.cache.ownlist) do
		local conf = self:GetItemConfig(id)
		attrs = conf.attrpower
		self:UpdateBaseAttr(attrs)
	end
	if self.cache.wearid ~= 0 then
		self:WearPartHook(self.cache.wearid)
	end
	for __, id in pairs(self.cache.ownlist) do
		self.partcollect[id] = true
	end
end

function EffectBase:onInitClient()
	self:CheckTerm()
	self:SendClientMsg()
end

function EffectBase:ActivatePart(partid)
	if self.partcollect[partid] then
		return 
	end
	local itemconf = self:GetItemConfig(partid)
	if not self.player:PayRewards({itemconf.itemid}, self.id, self.describe) then
		lua_app.log_info(">>EffectBase:ActivatePart not have part." , partid)
		return
	end
	self:DoActivatePart(partid)
end

function EffectBase:DoActivatePart(partid)
	print("EffectBase:DoActivatePart----------", partid)
	local itemconf = self:GetItemConfig(partid)
	local attrs = itemconf.attrpower
	self:UpdateBaseAttr(attrs)
	self.cache.wearid = partid
	self.partcollect[partid] = true
	table.insert(self.cache.ownlist, partid)
	self:ActivatePartHook(partid)
	self:WearPartHook(partid)
	if itemconf.term then
		self.cache.termlist[partid] = lua_app.now() + itemconf.term
	end
	self:SendClientMsg()
end

function EffectBase:ActivatePartHook(partid)
end

function EffectBase:WearPartHook(partid)
end

function EffectBase:ChangePart(partid)
	if not self.partcollect[partid] then return end
	self.cache.wearid = partid
	self:SendClientMsg()
	self:WearPartHook(partid)
end

-- 检查过期的
function EffectBase:CheckTerm()
	local isoutdate = false
	local now = lua_app.now()
	local newownlist = {}
	local outdatelist = {}
	for _,id in pairs(self.cache.ownlist) do
		if self.cache.termlist[id] and self.cache.termlist[id] > 0 and now > self.cache.termlist[id] then
			table.insert(outdatelist, id)
			self.cache.termlist[id] = nil
			self.partcollect[id] = nil
			isoutdate = true
		else
			table.insert(newownlist, id)
		end
	end
	if isoutdate then
		self.cache.ownlist = newownlist
	end
	for _, id in pairs(outdatelist) do
		print("EffectBase:CheckTerm effect outdate---", id)
		if self.cache.wearid == id then
			self.cache.wearid = 0
		end
		local itemconf = self:GetItemConfig(id)
		if itemconf then
			-- server.sendErr(self.player, itemconf.name.."已过期")
			server.mailCenter:SendMail(self.player.dbid, "过期通知", itemconf.name.."已过有效期")
			self.role:UpdateBaseAttr(itemconf.attrpower, {}, self.attrRecord, server.baseConfig.AttrRecord.EffectBase)
		end
	end
end

function EffectBase:UpdateBaseAttr(attrs)
	self.role:UpdateBaseAttr({}, attrs, self.attrRecord, server.baseConfig.AttrRecord.EffectBase)
end

function EffectBase:GetMsgData()
	local datas = {}
	datas.wearid = self.cache.wearid
	datas.ownlist = {}
	for __, id in ipairs(self.cache.ownlist) do
		local term = self.cache.termlist[id] or 0
		table.insert(datas.ownlist, {
				id = id,
				term = term,
			})
	end
	return datas
end

function EffectBase:GetBaseConfig()
	return server.configCenter[self.conf]
end

function EffectBase:GetItemConfig(id)
	local confing = self:GetBaseConfig()
	local item = confing[id]
	if not item then
		lua_app.log_error(">>EffectBase:GetItemConfig not exist id.", self.conf, id)
		return 
	end
	return (item[self.player.cache.sex] or item)
end

function EffectBase:GetOwnlistData()
	local data = {}
	for _,v in ipairs(self.cache.ownlist) do
		data[v] = 1 
	end
	return data
end

function EffectBase:SendClientMsg()
end

return EffectBase