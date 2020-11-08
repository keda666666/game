local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local DailyActivityConfig = require "resource.DailyActivityConfig"

-- 跨服争霸本地主控文件
local KingMgr = {}


function KingMgr:CallWar(funcname, ...)
	return server.serverCenter:CallDtb("war", "KingWarCall", funcname, ...)
end

function KingMgr:SendWar(funcname, ...)
	server.serverCenter:SendDtb("war", "KingWarSend", funcname, ...)
end

function server.KingLogicCall(src, funcname, ...)
	lua_app.ret(server.kingMgr[funcname](server.kingMgr, ...))
end

function server.KingLogicSend(src, funcname, ...)
	server.kingMgr[funcname](server.kingMgr, ...)
end

function KingMgr:Init()
	self.isopen = false
end

-- 进入活动
function KingMgr:Join(player, israndom)
	if not self.isopen then
		server.sendErr(player, "活动尚未开启")
		return
	end
	if not server.funcOpen:Check(player, 61) then
		server.sendErr(player, "功能尚未开启")
		return
	end
	local playerinfo = player:BaseInfo()
	server.dailyActivityCenter:SendJoinActivity("king", player.dbid)
	local ret = self:CallWar("Join", playerinfo, israndom)
	return ret
end

-- 攻城
function KingMgr:AttackCity(player, targetcamp)
	local datas = server.dataPack:FightInfo(player)
	datas.exinfo = {}
	return self:CallWar("AttackCity", datas, targetcamp)
end

-- 加入守卫
function KingMgr:Guard(player, citycamp)
	local datas = server.dataPack:SimpleFightInfo(player)
	self:SendWar("Guard", datas, citycamp)
end

-- 自由pk
function KingMgr:PK(player, targetid)
	local datas = server.dataPack:FightInfo(player)
	datas.exinfo = {}
	return self:CallWar("PK", datas, targetid)
end

-- 获取城池详细信息
function KingMgr:GetCityData(dbid, citycamp)
	self:SendWar("GetCityData", dbid, citycamp)
end

-- 花钱复活
function KingMgr:PayRevive(dbid)
	self:SendWar("PayRevive", dbid)
end

-- 离开游戏
function KingMgr:Leave(dbid)
	self:SendWar("Leave", dbid)
end

-- 领取积分奖励
function KingMgr:GetPointReward(dbid, ptype, index)
	self:SendWar("GetPointReward", dbid, ptype, index)
end

-- 积分数据
function KingMgr:GetPointData(dbid)
	self:SendWar("GetPointData", dbid)
end

-- 玩家变身
function KingMgr:Transform(dbid)
	self:SendWar("Transform", dbid)
end

function KingMgr:GetMyGuard(dbid)
	self:SendWar("GetMyGuard", dbid)
end

function KingMgr:TeamRecruit(dbid)
	self:SendWar("TeamRecruit", dbid)
end

function KingMgr:SetOpen(isopen)
	print('---------------------------跨服争霸')
	if not server.funcOpen:CheckOpen(server.configCenter.KingBaseConfig.serverday) then
		return
	end
	self.isopen = isopen
	if self.isopen then
		server.dailyActivityCenter:BroadcastMessage(DailyActivityConfig.type.King)
	end
	server.dailyActivityCenter:Brodcast()
	print("KingMgr:SetOpen------------", isopen)
end

function KingMgr:ServerInfo()
	return {lv = server.dailyActivityCenter:AvgLv(), serverday = server.serverRunDay}
end

function KingMgr:DoNotice(...)
	if not server.funcOpen:CheckOpen(server.configCenter.KingBaseConfig.serverday) then
		return
	end
	server.noticeCenter:Notice(...)
end

-- 快速死亡
function KingMgr:TestDead(dbid)
	self:SendWar("TestDead", dbid)
end

function KingMgr:TestPoint(dbid, point)
	self:SendWar("TestPoint", dbid, point)
end

function KingMgr:IsOpen()
	return self.isopen
end

server.SetCenter(KingMgr, "kingMgr")
return KingMgr
