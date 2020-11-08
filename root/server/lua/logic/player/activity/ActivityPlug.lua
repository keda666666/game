local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ActGen = require "resource.GenActivity"
local ItemConfig = require "common.resource.ItemConfig"

local ActivityPlug = oo.class()

function ActivityPlug:ctor(player)
	self.player = player
end

function ActivityPlug:onCreate()
	self:onLoad()
end

function ActivityPlug:onLoad()
	self.cache = self.player.cache.activity_record
end

function ActivityPlug:onInitClient()
	server.serverCenter:SendLocalMod("world", "activityMgr", "PlayerLogin", self.player.dbid)
	server.holyPetCenter:onInitClient(self.player.dbid)
	self:SendAccuLogin()
end

function ActivityPlug:onLogout(player)
end

function ActivityPlug:onLogin(player)
	self:AddAccuLogin()
end

function ActivityPlug:onDayTimer()
	self.player:SendServerTime()
	self.player:SendServerDay()
	server.serverCenter:SendLocalMod("world", "activityMgr", "onPlayerDayTimer", self.player.dbid)
end

function ActivityPlug:onLevelUp(oldlevel, newlevel)
	server.serverCenter:SendLocalMod("world", "activityMgr", "LevelUp", self.player.dbid, oldlevel, newlevel)
end

function ActivityPlug:onRechargeCash(cash)
	server.serverCenter:SendLocalMod("world", "activityMgr", "AddRechargeCash", self.player.dbid, cash)
end

function ActivityPlug:onRecharge(count)
	server.serverCenter:SendLocalMod("world", "activityMgr", "AddRecharge", self.player.dbid, count)
	self:SendRechargeInfo()
end

function ActivityPlug:onDoTarget()
	server.serverCenter:SendLocalMod("world", "activityMgr", "DoTarget", self.player.dbid, self:TargetData())
end

function ActivityPlug:onPowerUp(newpower)
	server.serverCenter:SendLocalMod("world", "activityMgr", "PowerUp", self.player.dbid, newpower)
end

function ActivityPlug:onBuyGift(giftid)
	lua_app.log_info("----------------------------1")
	server.serverCenter:SendLocalMod("world", "activityMgr", "BuyGift", self.player.dbid, giftid)
end

function ActivityPlug:ActivityReward(id, index)
	lua_app.log_info("----------------------------777:",id)
	server.serverCenter:SendLocalMod("world", "activityMgr", "ActivityReward", self.player.dbid, id, index)
end

function ActivityPlug:ActivityOpen(id)
	server.serverCenter:SendLocalMod("world", "activityMgr", "ActivityOpen", self.player.dbid, id)
end
function ActivityPlug:ActivityAction(id, ...)
	server.serverCenter:SendLocalMod("world", "activityMgr", "ActivityAction", self.player.dbid, id, ...)
end

function ActivityPlug:onChangeYuanBao(count)
	server.serverCenter:SendLocalMod("world", "activityMgr", "ChangeYuanBao", self.player.dbid, count)
end

function ActivityPlug:PlayerData()
	return {
		level = self.player.cache.level,
		dayrecharge = self.player.cache.recharger_data.daycount,
		dayrecash = self.player.cache.recharger_data.daycash,
		recharge = self.player.cache.recharge,
	}
end

function ActivityPlug:TargetData()
	return {
		arenarank = server.arenaCenter:GetRank(self.player.dbid),
		wildgeese = self.player.cache.wildgeeseFb.layer,
		heaven = self.player.cache.heavenFb.layer,
		chapter = self.player.cache.chapter.chapterlevel,
		treasuremap = self.player.treasuremap:MaxClear(),
		petcount = self.player.pet:PetCount(),
		quantityequips = self.player.role.equip:GetQuantityCount(),
		enhancelevel = self.player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Enhance),
		refinelevel = self.player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Refine),
		anneallevel = self.player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Anneal),
		gemlevel = self.player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Gem),
	}
end

function ActivityPlug:GiveReward(id, record, rewards, sourceName, ...)
	self:SetActData(id, record)
	self.player:GiveRewardAsFullMailDefault(rewards, sourceName, server.baseConfig.YuanbaoRecordType.Activity, ...)
end

function ActivityPlug:GetActData(id)
	return (self.cache.list[id] or {})
end

function ActivityPlug:SetActData(id, record)
	self.cache.list[id] = record
end

function ActivityPlug:SendRechargeInfo()
	self.player:sendReq("sc_recharge_count", 
		{
			total = self.player.cache.recharger_data.total, 
			today = self.player.cache.recharger_data.daycount,
		})
end

---------送十万元宝-------------
function ActivityPlug:SendAccuLogin()
	self.player:sendReq("sc_accu_login", {count = self.cache.acculogin.count, record = self.cache.acculogin.record})
end

function ActivityPlug:AddAccuLogin()
	self.cache.acculogin.record = self.cache.acculogin.record or 0
	self.cache.acculogin.count = self.cache.acculogin.count or 0
	if self.cache.acculogin.lastday ~= server.serverRunDay then
		self.cache.acculogin.lastday = server.serverRunDay
		self.cache.acculogin.count = self.cache.acculogin.count + 1
	end
end

function ActivityPlug:GetReward(index)
	local cfg = server.configCenter.PresentGoldConfig[index]
	if not cfg then return end

	if self.cache.acculogin.count < cfg.days then
		server.sendErr(self.player, "条件未达到")
		return
	end

	if self.cache.acculogin.record & (1<<(index)) ~= 0 then
		server.sendErr(self.player, "已经领取过该奖励")
		return
	end

	self.cache.acculogin.record = self.cache.acculogin.record | (1<<(index))
	self.player:GiveRewardAsFullMailDefault(table.wcopy(cfg.item), "送十万元宝", server.baseConfig.YuanbaoRecordType.Activity)
	self:SendAccuLogin()
end


function ActivityPlug:Test(func, ...)
	server.serverCenter:CallLocalMod("world", "activityMgr", func, self.player.dbid ,...)
end


server.playerCenter:SetEvent(ActivityPlug, "activityPlug")
return ActivityPlug
