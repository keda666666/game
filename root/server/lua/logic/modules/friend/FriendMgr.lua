local server = require "server"
local lua_app = require "lua_app"

local FriendMgr = {}

local _recomlength = 20

function FriendMgr:Init()
	self.offlinelist = {}
	self.offlinetime = {}
end


local function _FindInsertIndex(datas, data, beginindex, endindex, largerFunc)
	if beginindex >= endindex then
		return beginindex
	end
	local checkindex = beginindex + math.floor((endindex - beginindex)/2)
	if largerFunc(datas[checkindex], data) then
		return _FindInsertIndex(datas, data, checkindex + 1, endindex, largerFunc)
	else
		return _FindInsertIndex(datas, data, beginindex, checkindex, largerFunc)
	end
end

function FriendMgr:onLogin(player)
	local offlinetime = self.offlinetime[player.dbid]
	if not offlinetime then return end

	local data = {
		dbid = player.dbid,
		offlinetime = offlinetime,
	}
	local index = _FindInsertIndex(self.offlinelist, data, 1, #self.offlinelist + 1, function(data1, data2)
			return data1.offlinetime > data2.offlinetime
		end)

	for i = index, #self.offlinelist do
		if self.offlinelist[i].offlinetime ~= offlinetime then break end

		if self.offlinelist[i].dbid == player.dbid then
			table.remove(self.offlinelist, i)
			break
		end
	end
end

function FriendMgr:GetOfflinelist()
	return self.offlinelist
end

function FriendMgr:GiveFriendcoin(sendId, receiveId)
	local receiver = server.playerCenter:DoGetPlayerByDBID(receiveId)
	receiver.friend:onReceiveFriendcoin(sendId)
end

function FriendMgr:AddFuns(dbid, funsid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	return player.friend:AddMyfuns(funsid)
end

function FriendMgr:RemoveFuns(dbid, funsid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	player.friend:RemoveMyfuns(funsid)
end

function FriendMgr:ChatCheck(player, targetid)
	if not player.friend:SendCheck(targetid) then
		return 1
	end
	local target = server.playerCenter:DoGetPlayerByDBID(targetid)
	if not target.friend:SendCheck(player.dbid) then
		return 2
	end
	return 0
end

function FriendMgr:onLogout(player)
	local nowtime = lua_app.now()
	local data = {
		dbid = player.dbid,
		offlinetime = nowtime,
	}
	local index = _FindInsertIndex(self.offlinelist, data, 1, #self.offlinelist + 1, function(data1, data2)
			return data1.offlinetime > data2.offlinetime
		end)
	table.insert(self.offlinelist, index, data)
	self.offlinetime[player.dbid] = nowtime
end

server.SetCenter(FriendMgr, "friendCenter")
return FriendMgr
