local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "climb"

-- 九重天本地主控文件
local ClimbMgr = {}


function ClimbMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "ClimbWarCall", funcname, ...)
end

function ClimbMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "ClimbWarSend", funcname, ...)
end

function server.ClimbLogicCall(src, funcname, ...)
	lua_app.ret(server.climbMgr[funcname](server.climbMgr, ...))
end

function server.ClimbLogicSend(src, funcname, ...)
	server.climbMgr[funcname](server.climbMgr, ...)
end

function ClimbMgr:Init()
	self.isopen = false
	self.leavetime = {}
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
end

function ClimbMgr:Enter(player)
	if not self.isopen then
		server.sendErr(player, "活动尚未开启")
		return
	end
	if not server.funcOpen:Check(player, 47) then
		server.sendErr(player, "功能尚未开启")
		return
	end
	local dbid = player.dbid
	server.dailyActivityCenter:SendJoinActivity("climb", dbid)
	self:CallWar("MapDo", dbid, "Enter", dbid)
end

function ClimbMgr:PK(player, targetid)
	local dbid = player.dbid
	local datas = server.dataPack:FightInfo(player)
	datas.exinfo = {}
	self:SendWar("MapDo", dbid, "LayerDo", dbid, "PK", dbid, datas, targetid)
end

function ClimbMgr:AttackMon(player)
	local dbid = player.dbid
	local datas = server.dataPack:FightInfo(player)
	datas.exinfo = {}
	self:SendWar("MapDo", dbid, "LayerDo", dbid, "AttackMon", dbid, datas)
end

function ClimbMgr:GetAllRank(dbid)
	self:SendWar("GetAllRank", dbid)
end

function ClimbMgr:GetCurrRank(dbid)
	if self.isopen then
		self:SendWar("MapDo", dbid, "GetCurrRank", dbid)
	else
		self:SendWar("GetCurrRank", dbid)
	end
end

function ClimbMgr:GetReward(dbid)
	self:SendWar("MapDo", dbid, "GetReward", dbid)
end

function ClimbMgr:Leave(dbid)
	self:SendWar("MapDo", dbid, "Leave", dbid)
	self:SetLeaveTime(dbid)
end

function ClimbMgr:SetLeaveTime(dbid)
	self.leavetime[dbid] = lua_app.now()
end

function ClimbMgr:SetOpen(isopen)

	if not server.funcOpen:CheckOpen(server.configCenter.ClimbTowerBaseConfig.serverday) then
		return
	end
	self.isopen = isopen
	if self.isopen then
		server.dailyActivityCenter:Brodcast()
		self.cache.open = self.cache.open + 1
	end
	print("ClimbMgr:SetOpen------------", isopen)
end

function ClimbMgr:IsOpen()
	return self.isopen
end

function ClimbMgr:ServerInfo()
	print("ClimbMgr:ServerInfo.............", self.cache.open)
	return {opencode = self:GetOpenCode()}
end

function ClimbMgr:GetOpenCode()
	local ClimbTowerBaseConfig = server.configCenter.ClimbTowerBaseConfig
	local specifyOpen = server.serverRunDay == ClimbTowerBaseConfig.appointime
	if specifyOpen then
		self.cache.openinterval = ClimbTowerBaseConfig.intervaltime
		return 1
	elseif self:CheckNormalOpen() then 
		return 2
	end
	return 0
end

function ClimbMgr:CheckNormalOpen()
	if self:IsActivityDay() and self.cache.openinterval == 0 and
	 server.serverRunDay >= server.configCenter.ClimbTowerBaseConfig.serverday then
		return true
	end
	return false
end

function ClimbMgr:IsActivityDay()
	local opendays = server.configCenter.ClimbTowerBaseConfig.openday
	local week = lua_app.week()
	for _, v in ipairs(opendays) do
		if v == week then 
			return true 
		end
	end
	if self.testopen then
		return true
	end
	return false
end

function ClimbMgr:onDayTimer(day)
	self.cache.openinterval = math.max(self.cache.openinterval - 1, 0)
end

function ClimbMgr:GetLeaveTime(dbid)
	return self.leavetime[dbid] or 0
end

function ClimbMgr:SendMailReward(playerlist)
	local scorerewards = server.configCenter.ClimbTowerBaseConfig.scoretask
	for dbid, mailinfo in pairs(playerlist) do
		local player = server.playerCenter:DoGetPlayerByDBID(dbid)
		if player then
			server.mailCenter:SendMail(dbid, mailinfo.title, mailinfo.content, mailinfo.rewards, server.baseConfig.YuanbaoRecordType.Climb)
		end
	end
end

function ClimbMgr:TestAddScore(dbid, score)
	self:SendWar("MapDo", dbid, "AddScore", dbid, score)
end

function ClimbMgr:TestRefeshMon(dbid)
	self:SendWar("MapDo", dbid, "LayerDo", dbid, "RefreshMon")
end

server.SetCenter(ClimbMgr, "climbMgr")
return ClimbMgr
