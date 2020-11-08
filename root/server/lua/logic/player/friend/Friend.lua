local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ItemConfig = require "resource.ItemConfig"

local Friend = oo.class()

function Friend:ctor(player)
    self.player = player
end

function Friend:onCreate()
	self:onLoad()
end

function Friend:onLoad()
	self.cache = self.player.cache.friend_data
	self:Init(self.cache)

	self.myfriend = self.cache.myfriend
	self.myfuns = self.cache.myfuns
	self.blacklist = self.cache.blacklist
end

function Friend:Init(data)
	data.myfriend = data.myfriend or {}
	data.myfriendNum = data.myfriendNum or 0
	data.myfuns = data.myfuns or {}
	data.myfunsNum = data.myfunsNum or 0
	data.blacklist = data.blacklist or {}
	data.blacklistNum = data.blacklistNum or 0
	data.gifttime = data.gifttime or 0
	data.receivetime = data.receivetime or 0
end

function Friend:onInitClient()
	self:SendFriends()
	self:SendFuns()
	self:SendBlacklist()
	self:UpdateGiftReceive()
	self:NotifyStatusAlter()
end

--添加关注
function Friend:AddFriend(dbid)
	if self.myfriend[dbid] and not self.myfriend[dbid].del then 
		return false 
	end

	local VipPrivilegeConfig = server.configCenter.VipPrivilegeConfig
	local viplv = self.player.cache.vip

	if self.cache.myfriendNum >= VipPrivilegeConfig[viplv].friendnum then
		lua_app.log_info(">>Friend:AddFriend my friend num reach maximum", self.myfriendNum ,
			VipPrivilegeConfig[viplv].friendnum)
		return false
	end

	if self.blacklist[dbid] then
		self.blacklist[dbid] = nil
	end

	local ret = server.friendCenter:AddFuns(dbid, self.player.dbid)
	if not ret then return false end


	self.cache.myfriendNum = self.cache.myfriendNum + 1
	self.myfriend[dbid] = self.myfriend[dbid] or {
		gift = false,
	}

	self.myfriend[dbid].del = nil
	self:UpdateAllData(dbid)
	return true
end

function Friend:SendCheck(dbid)
	if self.blacklist[dbid] then
		return false
	end
	return true
end

--移除关注
function Friend:RemoveFriend(dbid)
	local friend = self.myfriend[dbid]
	if not friend then return end
	friend.del = true

	self.cache.myfriendNum = self.cache.myfriendNum - 1
	self:UpdateAllData(dbid)
	server.friendCenter:RemoveFuns(dbid, self.player.dbid)
	self.player.marry:RemovePropose(dbid)
	self.player.marry:DenyAsked(dbid)
end

function Friend:GetFriendByDBID(dbid)
	local friend = self.myfriend[dbid]
	if not friend then
		lua_app.log_error(">>Friend:GetFriendByDBID no friend.", dbid)
		return
	end
	return friend
end

function Friend:AddMyfuns(dbid)
	if self.myfuns[dbid] and not self.myfuns[dbid].del then 
		return false
	end
	local FriendBaseConfig = server.configCenter.FriendBaseConfig
	if self.cache.myfunsNum >= FriendBaseConfig.fanscount then
		lua_app.log_info(">>Friend:AddMyfuns my funs reach maximum.", self.cache.myfunsNum, FriendBaseConfig.fanscount)
		return false
	end
	self.myfuns[dbid] = self.myfuns[dbid] or {
			gift = false,
			gifttime = 0,
			receive = false,
		}
	self.myfuns[dbid].del = nil
	self.cache.myfunsNum = self.cache.myfunsNum + 1
	self:UpdateFunsData(dbid)
	return true
end

function Friend:IsFriend(dbid)
	if self.myfriend[dbid] and not self.myfriend[dbid].del then
		return true
	end
	if self.blacklist[dbid] then
		return true
	end
	return false
end

function Friend:RemoveMyfuns(dbid)
	local funs = self.myfuns[dbid]
	if not funs then return end
	funs.del = true
	self.cache.myfunsNum = self.cache.myfunsNum - 1
	server.sendReq(self.player, "sc_friend_funs_remove", {
			dbid = dbid,
		})
end

function Friend:GetMyfunsByDBID(dbid)
	local funs = self.myfuns[dbid]
	if not funs then
		lua_app.log_error(">>Friend:GetMyfunsByDBID no funs.", dbid)
	end
	return funs
end

--添加黑名单
function Friend:AddBlacklist(dbid)
	if self.blacklist[dbid] then return end
	self:RemoveFriend(dbid)
	self.blacklist[dbid] = true
	self:UpdateBlackList(dbid)
end

--移除黑名单
function Friend:RemoveBlacklist(dbid)
	self.blacklist[dbid] = nil
end

--赠送友情币
function Friend:GiveFriendcoin(dbid)
	local FriendBaseConfig = server.configCenter.FriendBaseConfig
	if self.cache.gifttime >= FriendBaseConfig.givecoin then
		lua_app.log_info("Friend:GiveFriendcoin give coin reach maximum")
		return
	end
	--赠送过返回
	local friend = self:GetFriendByDBID(dbid)
	if friend.gift then
		lua_app.log_info(">>Friend:GiveFriendcoin", friend.gift)
		return
	end
	friend.gift = true
	self:UpdateFriendData(dbid)
	self:UpdateGiftReceive({
			gifttime = 1,
		})
	server.friendCenter:GiveFriendcoin(self.player.dbid, dbid)
end

--接受赠送
function Friend:onReceiveFriendcoin(dbid)
	local funs = self:GetMyfunsByDBID(dbid)
	funs.gift = true
	funs.gifttime = lua_app.now()
	self:UpdateFunsData(dbid)
end

--领取友情币
function Friend:GetFriendcoin(dbid)
	local FriendBaseConfig = server.configCenter.FriendBaseConfig
	if self.cache.receivetime >= FriendBaseConfig.receivecoin then
		lua_app.log_info("Friend:GiveFriendcoin receive coin reach maximum")
		return
	end
	local funs = self:GetMyfunsByDBID(dbid)
	if not funs.gift then 
		lua_app.log_info(">>Friend:GetFriendcoin funs not gift.", dbid)
		return
	end
	funs.receive = true
	local rewards = {
		FriendBaseConfig.coincount,
	}
	self.player:GiveRewards(rewards, nil, server.baseConfig.YuanbaoRecordType.Friend)

	self:UpdateGiftReceive({
			receivetime = 1,
		})
	self:UpdateFunsData(dbid)
end


local function _PackPlayerData(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local data = {
		name = player.cache.name,
		job = player.cache.job,
		sex = player.cache.sex,
		vip = player.cache.vip,
		level = player.cache.level,
		power = player.cache.totalpower,
		headframe = player.head:GetFrame(),
		dbid = player.dbid,
		guildId = player.cache.guildid,
		guildName = player.guild:GetGuildName(),
		offlineTime = player.isLogin and 0 or player.cache.lastonlinetime,
	}
	return data
end

--更新好友信息
function Friend:UpdateFriendData(dbid)
	local friend = self:GetFriendByDBID(dbid)
	local data = {
		friendInfo = _PackPlayerData(dbid),
		gift = friend.gift,
	}
	server.sendReq(self.player, "sc_friend_follow_update", {
			friendinfo = data,
		})
end

--更新粉丝信息
function Friend:UpdateFunsData(dbid)
	local funs = self:GetMyfunsByDBID(dbid)
	local data = {
		gift = funs.gift,
		gifttime = funs.gifttime,
		receive = funs.receive,
		isfriend = self:IsFriend(dbid),
		funsInfo = _PackPlayerData(dbid),
	}
	server.sendReq(self.player, "sc_friend_funs_update", {
			funsinfo = data,
		})
end

--更新黑名单信息
function Friend:UpdateBlackList(dbid)
	server.sendReq(self.player, "sc_friend_blacklist_update", {
			blackdata = _PackPlayerData(dbid),
		})
end

--更新赠送接收
function Friend:UpdateGiftReceive(data)
	data = data or {}
	self.cache.gifttime = self.cache.gifttime + (data.gifttime or 0)
	self.cache.receivetime = self.cache.receivetime + (data.receivetime or 0)
	server.sendReq(self.player, "sc_friend_gift_receive_info", {
			gifttime = self.cache.gifttime,
			receivetime = self.cache.receivetime,
		})
end

--发送好友列表
function Friend:SendFriends()
	local datas = {}
	for dbid, data in pairs(self.myfriend) do
		if not data.del then
			table.insert(datas, {
					gift = data.gift,
					friendInfo = _PackPlayerData(dbid),
				})
		end
	end
	server.sendReq(self.player, "sc_friend_follow_data", {
			friendlist = datas,
		})
end

--发送粉丝列表
function Friend:SendFuns()
	local datas = {}
	for dbid, data in pairs(self.myfuns) do
		if not data.del then
			table.insert(datas, {
					gift = data.gift,
					gifttime = data.gifttime,
					receive = data.receive,
					isfriend = self:IsFriend(dbid),
					funsInfo = _PackPlayerData(dbid),
				})
		end
	end
	server.sendReq(self.player, "sc_friend_funs_data", {
			funslist = datas,
		})
end

--发送黑名单
function Friend:SendBlacklist()
	local datas = {}
	for dbid,_ in pairs(self.blacklist) do
		table.insert(datas, _PackPlayerData(dbid))
	end
	server.sendReq(self.player, "sc_friend_black_list", {
			blacklist = datas,
		})
end

--发送推荐列表
function Friend:SendNominatefollow()
	local FriendBaseConfig = server.configCenter.FriendBaseConfig
	local onlineplayer = server.playerCenter:GetOnlinePlayers()
	local onlinelist = lua_util.randTB(onlineplayer, FriendBaseConfig.recomfriend + self.cache.myfriendNum)

	--table.ptable(onlinelist, 3)
	local recomcount = 0
	local playerinfos = {}
	for _, player in pairs(onlinelist) do
		if player.dbid ~= self.player.dbid and not self:IsFriend(player.dbid) then
			table.insert(playerinfos, _PackPlayerData(player.dbid))
			recomcount = recomcount + 1
		end
		if recomcount >= FriendBaseConfig.recomfriend then break end
	end

	--补充离线玩家
	local margin = FriendBaseConfig.recomfriend - recomcount
	if margin > 0 then
		local datas = server.friendCenter:GetOfflinelist()
		for _, data in ipairs(datas) do
			if not self:IsFriend(data.dbid) then
				table.insert(playerinfos, _PackPlayerData(data.dbid))
				recomcount = recomcount + 1
			end
			if recomcount >= FriendBaseConfig.recomfriend then break end
		end
	end

	server.sendReq(self.player, "sc_friend_follow_nominate_list", {
			playerinfos = playerinfos,
		})
end

--清理
function Friend:Clear()
	for dbid, data in pairs(self.myfuns) do
		if data.del then
			self.myfuns[dbid] = nil
		elseif data.gift and data.receive then
			data.gift = false
			data.receive = false
		end
	end

	for dbid, data in pairs(self.myfriend) do
		if data.del then
			self.myfriend[dbid] = nil
		else
			data.gift = false
		end
	end
end

--更新所有数据
function Friend:UpdateAllData(dbid)
	if self.myfriend[dbid] and not self.myfriend[dbid].del then
		self:UpdateFriendData(dbid)
	end
	if self.myfuns[dbid] and not self.myfuns[dbid].del then
		self:UpdateFunsData(dbid)
	end
end

--通知玩家状态改变
function Friend:NotifyStatusAlter()
	for dbid,_ in pairs(self.myfriend) do
		local target = server.playerCenter:GetPlayerByDBID(dbid)
		if target then
			target.friend:UpdateAllData(self.player.dbid)
		end
	end

	for dbid,_ in pairs(self.myfuns) do
		local target = server.playerCenter:GetPlayerByDBID(dbid)
		if target then
			target.friend:UpdateAllData(self.player.dbid)
		end
	end
end

function Friend:onLogout()
	self:NotifyStatusAlter()
end

function Friend:onDayTimer()
	self:Clear()
	self.cache.gifttime = 0
	self.cache.receivetime = 0
	self:SendFriends()
	self:SendFuns()
	self:SendBlacklist()
	self:UpdateGiftReceive()
end

function Friend:onLevelUp()
	self:NotifyStatusAlter()
end

function Friend:Debug()
	table.ptable(self.myfriend, 3)
	self.cache.myfriendNum = 1
end

function Friend:reset(a, b)
	self.cache.gifttime = a
	self.cache.receivetime = b
	server.sendReq(self.player, "sc_friend_gift_receive_info", {
			gifttime = self.cache.gifttime,
			receivetime = self.cache.receivetime,
		})
end

server.playerCenter:SetEvent(Friend, "friend")
return Friend