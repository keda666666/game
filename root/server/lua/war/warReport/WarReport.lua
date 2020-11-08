local server = require "server"
local oo = require "class"

local WarReport = oo.class()

function WarReport:ctor(sproto)
	self.sproto = sproto
	self.playerlist = {}
	self.guildlist = {}
	self.sharedata = {}
end

local function _UpdateDatas(sourcedatas, newdata)
	sourcedatas = sourcedatas or {}
	for k, v in pairs(newdata) do
		if type(v) == "table" then
			sourcedatas[k] = _UpdateDatas(sourcedatas[k], v)
		else
			sourcedatas[k] = v
		end
	end
	return sourcedatas
end

function WarReport:AddPlayer(dbid)
	if not self.playerlist[dbid] then
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		if not player then return end

		local baseinfo = player:BaseInfo()
		local origindata = {}
		origindata.guilddata = self.guildlist[baseinfo.guildid] or {}

		self.playerlist[dbid] = origindata
		self.guildlist[baseinfo.guildid] = origindata.guilddata
	end
end

function WarReport:AddRewards(dbid, rewards)
	local datas = self.playerlist[dbid]
	datas.rewards = table.GetTbPlus("count") + datas.rewards + rewards
end

function WarReport:AddPersonData(dbid, newdata)
	local datas = self.playerlist[dbid]
	datas.detail = _UpdateDatas(datas.detail, newdata)
end

function WarReport:AddAuctionRewards(guildid, rewards)
	local datas = self.guildlist[guildid] or {}
	datas.auctionrewards = table.GetTbPlus("count") + datas.auctionrewards + rewards
	self.guildlist[guildid] = datas
end

function WarReport:AddGuildData(guildid, newdata)
	local datas = self.guildlist[guildid] or {}
	datas.detail = _UpdateDatas(datas.detail, newdata)
	self.guildlist[guildid] = datas
end

function WarReport:AddShareData(datas)
	self.sharedata = _UpdateDatas(self.sharedata, datas)
end

function WarReport:BroadcastReport()
	for dbid, info in pairs(self.playerlist) do
		server.sendReqByDBID(dbid, self.sproto, {
				persondetail = info.detail,
				guilddetail = info.guilddata.detail,
				rewards = info.rewards,
				auctionrewards = info.guilddata.auctionrewards,
				sharedata = self.sharedata,
			})
	end
	self:Clear()
end

function WarReport:Clear()
	self.playerlist = {}
	self.guildlist = {}
	self.sharedata = {}
end

function WarReport:Reset(sproto)
	self.sproto = sproto
	self:Clear()
end

return WarReport