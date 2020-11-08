local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"

local PublicBossPlug = oo.class()

function PublicBossPlug:ctor(player)
	self.player = player
end

function PublicBossPlug:onCreate()
	local PublicBossBaseConfig = server.configCenter.PublicBossBaseConfig
	self:onLoad()
end

function PublicBossPlug:onLoad()
	self.cache = self.player.cache.publicboss
end

function PublicBossPlug:UpdateBossMark(data)
	self.cache.rebornmark = data
end

function PublicBossPlug:onInitClient()
	self:EstimateRecorve()
	self:SendClientMsg()
end

function PublicBossPlug:RebornEnterDefi(bossid)
	if not self:CheckReborn() then
		lua_app.log_info("PublicBossPlug:RebornEnterDefi  reborn boss error. bossid:",bossid)
		return
	end
	local PublicBossConfig = server.configCenter.PublicBossConfig[bossid]
	if self.player:PayRewards({PublicBossConfig.needprops}, server.baseConfig.YuanbaoRecordType.PublicBoss, "PublicBoss:reborn:purchase") or 
	self.player:PayRewards({PublicBossConfig.needmoney}, server.baseConfig.YuanbaoRecordType.PublicBoss, "PublicBoss:reborn:purchase") then
		self:RebornBoss(bossid)
		self:EnterDefi(bossid)
		return 
	end
	server.sendReq(self.player, "sc_public_boss_challenge_fail", {})
end

function PublicBossPlug:EnterDefi(bossid)
	if not self:CheckDefi() then
		lua_app.log_info("deficount insufficient. deficount:", self.cache.deficount)
		return
	end
	local packinfo = server.dataPack:FightInfo(self.player)
        packinfo.exinfo = {
            index = bossid,
        }
    local ret = server.raidMgr:Enter(server.raidConfig.type.PublicBoss, self.player.dbid, packinfo)
    if not ret then
    	lua_app.log_info("defi error")
    	server.sendReq(self.player, "sc_public_boss_challenge_fail", {})
    	return
    end
    self.cache.deficount = self.cache.deficount - 1
    self:EstimateRecorve()
	self:SendClientMsg()
	self.cache.totalcount = self.cache.totalcount + 1
	self.player.shop:onUpdateUnlock()
	self.player.task:onEventAdd(server.taskConfig.ConditionType.PublicBoss)
	self.player.dailyTask:onEventAdd(DailyTaskConfig.DailyTaskType.PublicBoss)
	server.teachersCenter:AddNum(self.player.dbid, 6)
	self.player.enhance:AddPoint(21, 1)
end

function PublicBossPlug:CheckReborn()
	local VipChallengeTimesConfig = server.configCenter.VipChallengeTimesConfig
	local viplv = self.player.cache.vip
	if self.cache.reborncount >= VipChallengeTimesConfig[viplv].purchasingtimes then
		return false
	end
	if self.cache.deficount <= 0 then
		return false
	end
	return true
end

function PublicBossPlug:CheckDefi()
	if self.cache.deficount > 0 then
		return true
	end
	return false
end

function PublicBossPlug:BuyChallenge()
	local VipChallengeTimesConfig = server.configCenter.VipChallengeTimesConfig
	local PublicBossBaseConfig = server.configCenter.PublicBossBaseConfig
	local viplv = self.player.cache.vip
	if self.cache.purchasecount > VipChallengeTimesConfig[viplv].buychasingtimes then
		lua_app.log_error("BuyChallenge error. account:", self.player.cache.name, "purchasecount:", self.cache.purchasecount, "viplv:",viplv)
		return
	end
	local cost = {
		type = ItemConfig.AwardType.Numeric,
		id = ItemConfig.NumericType.YuanBao,
		count = PublicBossBaseConfig.cost,
	}
	if not self.player:PayRewards({cost}, server.baseConfig.YuanbaoRecordType.PublicBoss, "PublicBoss buy challenge time") then
		lua_app.log_info(">>BuyChallenge yuanbao not enough.")
		return
	end
	self.cache.purchasecount = self.cache.purchasecount + 1
	self.cache.deficount = self.cache.deficount + PublicBossBaseConfig.income
	self:SendClientMsg()
end

function PublicBossPlug:IncreaseDefi()
	self.cache.deficount = math.min(self.cache.deficount + 1, server.configCenter.PublicBossBaseConfig.maxCount)
	self:EstimateRecorve()
	self:SendClientMsg()
end

function PublicBossPlug:EstimateRecorve()
	if server.publicBossMgr:VerifyRecorve(self.player.dbid) then return end

	local PublicBossBaseConfig = server.configCenter.PublicBossBaseConfig
	local maxCount = PublicBossBaseConfig.maxCount
	local retime = PublicBossBaseConfig.recoverTime * 60
	local nowtime = lua_app.now()
	local refreshtime = self.cache.refreshtime

	local recovercount = math.ceil((nowtime - refreshtime) / retime)
	if recovercount > 0 and refreshtime > 0 then
		self.cache.deficount = math.min(self.cache.deficount + recovercount, maxCount)
		refreshtime = refreshtime + recovercount*retime
	end

	if self.cache.deficount < PublicBossBaseConfig.maxCount then
		self.cache.refreshtime = (refreshtime-nowtime) > 0 and refreshtime or nowtime+retime
		server.publicBossMgr:AddActionRecover(self.player.dbid, self.cache.refreshtime)
	else
		self.cache.refreshtime = -1
	end
end

function PublicBossPlug:SendClientMsg()
	local msg = {
		challengenum = self.cache.deficount,
		recovertiem = self.cache.refreshtime,
		purchasecount = self.cache.purchasecount,
		reborncount = self.cache.reborncount,
		rebornmark = self.cache.rebornmark,
	}
	server.sendReq(self.player, "sc_public_boss_update_challenge", msg)
end

function PublicBossPlug:GetTotalCount()
	return self.cache.totalcount
end

function PublicBossPlug:RebornBoss(bossindex)
	server.raidMgr:CallRaidType(server.raidConfig.type.PublicBoss, "RebornPublicBoss", bossindex, self.player.dbid)
end

function PublicBossPlug:onDayTimer()
	self.cache.purchasecount = 0
	self.cache.reborncount = 0
	self:SendClientMsg()
end

function PublicBossPlug:Test(a)
	self.cache.deficount = a
	self:SendClientMsg()
end

server.playerCenter:SetEvent(PublicBossPlug, "publicboss")
return PublicBossPlug