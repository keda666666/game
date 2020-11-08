local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local WeightData = require "WeightData"
local FightConfig = require "resource.FightConfig"
local EntityConfig = require "resource.EntityConfig"
local ItemConfig = require "resource.ItemConfig"
local ShopConfig = require "resource.ShopConfig"

local GM = oo.class()

function GM:ctor(player)
	self.player = player
end

function GM:give(id, count)
	if id <= 1000 then
		self.player:GiveReward(ItemConfig.AwardType.Numeric, id, count, 1, server.baseConfig.YuanbaoRecordType.GMCMD)
	else
		self.player:GiveReward(ItemConfig.AwardType.Item, id, count, 1, server.baseConfig.YuanbaoRecordType.GMCMD)
	end
	return true
end

function GM:show(...)
	local args = {...}
	local value = self.player
	for _, v in ipairs(args) do
		value = value[v]
	end
	table.ptable(value, 5)
end

function GM:item(name, count)
	for id, cfg in pairs(server.configCenter.ItemConfig) do
		if cfg.name == name then
			self.player:GiveReward(ItemConfig.AwardType.Item, id, count, 1, server.baseConfig.YuanbaoRecordType.GMCMD)
			return true
		end
	end
end

function GM:mail(a)
	if a then
		server.mailCenter:SendMail(self.player.dbid, "testmail", "只是测试用的邮件", server.dropCenter:DropGroup(a))
	else
		server.mailCenter:SendMail(self.player.dbid, "no item mail", "也只是测试用的邮件")
	end
end

function GM:notice(a, b, ...)
	server.noticeCenter:Notice(a, ...)
	-- server.serverCenter:SendLocalMod("war", "fieldBoss", "RefreshFieldBoss", self.player.cache.guildid, 1)
	--server.serverCenter:SendLocal("war", "fieldBoss", "RefreshFieldBoss")
	--server.chatCenter:ChatLink(25, {}, self.player)
	--server.chatCenter:NoticeFb(a, self.player.dbid, b, self.player.cache.guildid)
	--server.guildCenter:SendBoss("Invade", self.player.cache.guildid, 1)
end

function GM:shop(a, ...)
	if a == "buy" then
		self.player.shop:BuyItem(...)
	elseif a == "refresh" then
		self.player.shop:RefreshBuyCountList(...)
	end
end

function GM:rank(a, t)
	local p1
	if a == "refresh" then
		if t then							-- 正常刷新t
			p1 = "RefreshRank"
		else 								-- 正常刷新所有
			p1 = "RefreshRanks"
		end
	elseif a == "rebuild" then				-- 重建排行版 t=true 为调用回调
		p1 = "ReBuildAllRankDatas"
	elseif a == "reset" then				-- 去掉 未开启的排名种类 并重建排行版
		p1 = "ResetAll"
	elseif a == "clear" then				-- 清空排行榜t
		p1 = "ClearRank"
	elseif a == "runfunc" then				-- 强制执行排行榜t的回调
		p1 = "RunRankFunc"
	elseif a == "open" then					-- 开启排行榜t
		p1 = "OpenRank"
	elseif a == "close" then				-- 关闭排行榜t
		p1 = "CloseRank"
	else 							-- 正常刷新所有
		p1 = "RefreshRanks"
	end
    server.serverCenter:SendLocalMod("world", "rankCenter", p1, t)
    server.serverCenter:SendDtbMod("world", "rankCenter", p1, t)
end

function GM:equip(a, ...)
	if a == "a" then
		self.player.role.equip:RedUpgrade(...)
	elseif a == "g" then
		self.player.role.equip:RedGenerate(...)
	elseif a == "i" then
		self.player.role.equip:InjectEqiup(...)
	end
end

function GM:role(a, b)
	self.player.role:ChangeBaseAttr(a, b)
	self.player:ToReCalcPower()
end
function GM:pet(a, b)
	self.player.pet:ChangeBaseAttr(a, b)
	self.player:ToReCalcPower()
end
function GM:xianlv(a, b)
	self.player.xianlv:ChangeBaseAttr(a, b)
	self.player:ToReCalcPower()
end
function GM:tiannv(a, b)
	self.player.tiannv:ChangeBaseAttr(a, b)
	self.player:ToReCalcPower()
end
function GM:gwar(a, ...)
	if a == "enter" then
		server.guildwarMgr:EnterGuildwar(self.player.dbid)
	elseif a == "attack" then
		server.guildwarMgr:Attack(self.player.dbid,...)
	elseif a == "reset" then
		server.guildwarMgr:ResetBarrier(self.player.dbid, ...)
	elseif a == "next" then
		server.guildwarMgr:EnterNextBarrier(self.player.dbid, ...)
	elseif a == "pk" then
		server.guildwarMgr:Pk(self.player.dbid, ...)
	elseif a == "shut" then
		server.guildwarMgr:Test("Shut")
	elseif a == "open" then
		server.guildwarMgr:Test("Start")
	elseif a =="notify" then
		server.sendReq(self.player, "sc_record_add", {
				type = 1,
				record = {
					type = 2,
					str = "asdfa",
					time = lua_app.now(),
				}
			})
	elseif a == "last" then
		server.guildwarMgr:EnterLastBarrier(self.player.dbid)
	elseif a == "debug" then
		server.guildwarMgr:Debug(self.player.dbid)
	else
		server.guildwarMgr:Test(a, self.player.dbid, ...)
	end
	--server.guildwarMgr["Entrance"](server.guildwarMgr, 123, "ddd")
end

function GM:flypet(a)
	if a == "give" then
		self:RunCMD("2005011 1")
		self:RunCMD("2005040 2000")
		self:RunCMD("2005041 2000")
	elseif a == "exp" then
		self.player.pet:AddFlyexp(900011, 2)
	elseif a == "re" then
		self.player.pet:RestoreFlypet(900011)
	end
end

function GM:ka(a, ... )
	if a == "match" then
		server.kingArenaMgr:Match(self.player.dbid)
	elseif a == "open" then
		server.kingArenaMgr:Test("Open")
	elseif a == "close" then
		server.kingArenaMgr:Test("Close")
	elseif a == "print" then
		server.kingArenaMgr:TestPrint()
	elseif a == "enter" then
		server.kingArenaMgr:Enter(self.player.dbid)
	elseif a == "clear" then
		server.kingArenaMgr:TestClear()
	elseif a == "reward" then
		server.kingArenaMgr:ReceiveReward(self.player.dbid)
	elseif a == "tf" then
		server.kingArenaMgr:FightResult(self.player.dbid, true, {{type=0, id=2, count = 200}})
	else
		server.kingArenaMgr:Test(a, ...)
	end
end

function GM:test(...)
	-- local function _ConvertWeekTime(time)
	-- 	local ttime = lua_util.split(time, ":")
	-- 	local TW = tonumber(ttime[1])
	-- 	local TH = tonumber(ttime[2])
	-- 	local TM = tonumber(ttime[3])
	-- 	local TS = tonumber(ttime[4])
	-- 	return TW*3600*24 + TH*3600 + TM*60 + TS
	-- end
	-- print("-------------ddd")
	-- _ConvertWeekTime(lua_app.week()..":"..os.date("%H:%M:%S"))
	--table.ptable(self.player, 1)
	-- local tt = table.GetTbPlus("count") + nil + { type = 1, id=1000, count = 2}
	-- table.ptable(tt, 3)
end

function GM:getday()
	print("day===",server.serverRunDay)
end

function GM:time(a, b)
	server.onevent(server.event.halfhourtimer, a, b)
end

function GM:gmine(a, ...)
	if a == "enter" then
		server.guildMinewarMgr:EnterMinewar(self.player.dbid)
	elseif a == "shut" then
		server.guildMinewarMgr:Test("Shut")
	elseif a == "open" then
		server.guildMinewarMgr:Test("Start")
	elseif a == "attack" then
		server.guildMinewarMgr:ForceJoinMine(self.player.dbid, ...)
	else
		server.guildMinewarMgr:Test(a, self.player.dbid, ...)
	end
	--server.guildwarMgr["Entrance"](server.guildwarMgr, 123, "ddd")
end

function GM:catchpet()
	--server.catchPetMgr:TestUnlock(self.player)
	server.catchPetMgr:TestCatch(self.player)
end

function GM:welfare(a,...)
	if a == "AddQueue" then
		server.bonusMgr:AddQueue(self.player.dbid, ...)
	end
end

function GM:mcity(a, ...)
	if a == "enter" then
		server.maincityMgr:Enter(self.player.dbid, ...)
	elseif a == "g" then
		local da = server.maincityMgr:GetChannelMsg()
		table.ptable(da, 3)
	elseif a == "debug" then
		server.maincityMgr:Debug(self.player.dbid, ...)
	end
end

function GM:ac(a, ...)
	if a == "reward" then
		self.player.activityPlug:ActivityReward(...)
	elseif a == "init" then

	else
		self.player.activityPlug:Test(...)
	end
end

function GM:day(num)
	server.serverRunDay = num or (server.serverRunDay + 1)
	print(server.serverRunDay.."-----------------")
	server.onevent(server.event.daytimer, server.serverRunDay)
	server.dataPack:BroadcastDtbAndLocal("onrecvevent", server.event.daytimer, server.serverRunDay)
	--server.playerCenter:onevent(server.event.daytimer, self.player)
end

function GM:server()
	server.timerCenter:SetResetServer()
end

function GM:skill(a)
	local SkillsConfig = server.configCenter.SkillsConfig[a]
	if not SkillsConfig then return end
	self.player.role.skilllist[1][SkillsConfig.runStatus] = {
		[a]		= true,
	}
end

function GM:god(a)
	for k, _ in pairs(self.player.role.attrs) do
		if a then
			self.player.role:ChangeBaseAttr(k, a)
		else
			self.player.role:ChangeBaseAttr(k, 99999)
		end
	end
end

function GM:all()
	self:RunCMD("vip 12")
	self:RunCMD("0 9999999999999999")
	self:RunCMD("1 999999999999999")
	self:RunCMD("2 999999999999999")
	self:RunCMD("3 999999999999999")
	self:RunCMD("坐骑直升丹 10")
	self:RunCMD("坐骑属性丹 10")
	self:RunCMD("坐骑技能书 30")
	self:RunCMD("5阶马鞍")
	self:RunCMD("6阶马蹬")
	-- self:RunCMD("1025060 2")
	-- self:RunCMD("1025061 2")
	-- self:RunCMD("1025062 2")
	-- self:RunCMD("1025063 2")
	self:RunCMD("生命丹 10")
	self:RunCMD("攻击丹 10")
	self:RunCMD("防御丹 10")
	self:RunCMD("命中丹 10")
	self:RunCMD("闪避丹 10")
	self:RunCMD("暴击丹 10")
	self:RunCMD("抗暴丹 10")
	self:RunCMD("攻速丹 10")
	self:RunCMD("经脉丹 150")
	self:RunCMD("突破丹")
	self:RunCMD("高级法器洗练石 30")

	self:RunCMD("神·黄金剑")
	self:RunCMD("大闹新秀")
	self:RunCMD("羽化登仙")
	self:RunCMD("锋芒毕露")
	self:RunCMD("谦谦君子")
	self:RunCMD("志同道合")
	self:RunCMD("一夫当关")
	self:RunCMD("勇往直前")
	self:RunCMD("坐骑贵族")
	self:RunCMD("挖个宝")
	self:RunCMD("上班探宝藏")
	self:RunCMD("赏金猎人")
	self:RunCMD("点石成金")

	self:RunCMD("守护直升丹 10")
	self:RunCMD("守护属性丹 10")
	self:RunCMD("守护技能书 30")
	self:RunCMD("精灵女皇")

	self:RunCMD("神兵直升丹 10")
	self:RunCMD("神兵属性丹 10")
	self:RunCMD("神兵技能书 30")
	self:RunCMD("星光魔法")

	self:RunCMD("坐骑直升丹 10")
	self:RunCMD("坐骑属性丹 10")
	self:RunCMD("坐骑技能书 30")
	self:RunCMD("祥瑞醒狮")
	self:RunCMD("金色羊驼")

	self:RunCMD("翅膀直升丹 10")
	self:RunCMD("翅膀属性丹 10")
	self:RunCMD("翅膀技能书 30")
	self:RunCMD("恶魔之翼")
	self:RunCMD("精炼石 9999999999")
	self:RunCMD("锻炼石 9999999999")
	self:RunCMD("宝石精华 9999999999")
	self:RunCMD("女儿国王的精魄")
	self:RunCMD("石矶娘娘的精魄")
	self:RunCMD("玉面狐狸的精魄")
	self:RunCMD("白骨精的精魄")
	self:RunCMD("蝎子精的精魄")
	self:RunCMD("紫霞仙子的精魄")
	self:RunCMD("嫦娥仙子的精魄")
	self:RunCMD("女儿国王碎片 2000")
	self:RunCMD("石矶娘娘碎片 2000")
	self:RunCMD("玉面狐狸碎片 2000")
	self:RunCMD("白骨精碎片 2000")
	self:RunCMD("蝎子精碎片 2000")
	self:RunCMD("紫霞仙子碎片 2000")
	self:RunCMD("嫦娥仙子碎片 2000")

	self:RunCMD("法阵直升丹 10")
	self:RunCMD("法阵属性丹 10")
	self:RunCMD("法阵技能书 30")

	self:RunCMD("仙位直升丹 10")
	self:RunCMD("仙位属性丹 10")
	self:RunCMD("仙位技能书 30")

	self:RunCMD("玄女属性丹")
	self:RunCMD("花辇直升丹 10")
	self:RunCMD("花辇属性丹 10")
	self:RunCMD("花辇技能书 30")
	self:RunCMD("灵气直升丹 10")
	self:RunCMD("灵气属性丹 10")
	self:RunCMD("灵气技能书 30")

	self:RunCMD("赤炎魔卡 10")
	self:RunCMD("瑶池青鸟卡 10")
	self:RunCMD("唐僧卡 10")
	self:RunCMD("齐天小圣卡 10")
	self:RunCMD("哪吒卡 10")

	self:RunCMD("通灵直升丹 10")
	self:RunCMD("通灵属性丹 10")
	self:RunCMD("通灵技能书 30")
	self:RunCMD("兽魂直升丹 10")
	self:RunCMD("兽魂属性丹 10")
	self:RunCMD("兽魂技能书 30")


end

function GM:power()
	for recordtype, attrs in pairs(self.player.attrRecord) do
		local power = 0
		local AttrPowerConfig = server.configCenter.AttrPowerConfig
		for k, v in pairs(attrs) do
			if AttrPowerConfig[k] then
				power = power + v * AttrPowerConfig[k].power
			end
		end
		power = math.floor(power / 100)
		print("power------", recordtype, power)
	end
end

function GM:ng()
	self.player.role:ChangeBaseAttr(EntityConfig.Attr.atAttack, 11 - self.player.role.attrs[EntityConfig.Attr.atAttack])
	self.player.pet:ChangeBaseAttr(EntityConfig.Attr.atAttack, 11 - self.player.pet.attrs[EntityConfig.Attr.atAttack])
	self.player.xianlv:ChangeBaseAttr(EntityConfig.Attr.atAttack, 11 - self.player.xianlv.attrs[EntityConfig.Attr.atAttack])
	self.player.tiannv:ChangeBaseAttr(EntityConfig.Attr.atAttack, 11 - self.player.tiannv.attrs[EntityConfig.Attr.atAttack])
end

function GM:team(a, b, c)
	if a == "q" then
		server.teamMgr:Quick(self.player.dbid, b or server.raidConfig.type.CrossTeamFb, c or 40)
	elseif a == "l" then
		server.teamMgr:Leave(self.player.dbid)
	elseif a == "f" then
		server.teamMgr:Fight(self.player.dbid, b or server.raidConfig.type.CrossTeamFb, c or 40)
	end
end

function GM:chapter(a)
	self.player.cache.chapter.chapterlevel = a
	self.player.chapter:SendChapterInitInfo()
end

function GM:go(a)
	self:chapter(a)
end

function GM:chat()
	-- print("-------------------------------------")
	-- server.chatCenter:ChatLink(1, self.player, nil, {
	-- 		type=1, value=10001, valueEx = 123, strvalue = "dddd"
	-- 	})
end

function GM:task(a, b)
	if not type(b) == "number" then
		return
	end
	if a == "rec" then
		self.player.task:ReceiveTask(b)
	elseif a == "com" then
		self.player.task:TaskComplete(b)
	elseif a == "reward" then
		self.player.task:GetReward(b)
	else
		self.player.task:TestComplete()
	end
end

function GM:clearbag(a)
	if not a then a = 1 end
	local bag = self.player.bag
	for _, slots in pairs(bag.bagList[a]) do
		if slots then
			while true do
				local _, item = next(slots)
				if not item then break end
				bag:DelItem(item.dbid, item.cache.count, server.baseConfig.YuanbaoRecordType.GMCMD)
			end
		end
	end
end

function GM:recharge(goodsid)
	server.recordMgr:Recharge(self.player.dbid, goodsid)
end

function GM:vip(lv)
	local oldlevel = self.player.cache.vip
	self.player.cache.vip = lv
	self.player.vip:SendVipInfo()
	server.playerCenter:onevent(server.event.viplevelup, self.player, oldlevel, lv)
	print("now viplv:"..self.player.cache.vip)
end

function GM:vipr(a)
	self.player.vip:GiveReward(a)
end

function GM:gboss(a)
	if a == "open" then
		server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "TestOpen")
	elseif a == "boss" then
		server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "BossEnter")
	elseif a == "hudun" then
		server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "ShieldDec", server.configCenter.KfBossBaseConfig.shieldvalue)
	elseif a == "close" then
		server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "Close")
	elseif a == "enter" then
		server.cs_kfboss_entermap(self.player.socket, {})
	elseif a == "print" then
		server.raidMgr:SendRaidType(server.raidConfig.type.GuildBoss, "TestPrint")
	end
end

function GM:map(a)
	if a == "e" then
		server.mapMgr:Enter(self.player.dbid, 100001)
	elseif a == "l" then
		server.mapMgr:Leave(self.player.dbid, 100001)
	elseif a == "m" then
		server.mapMgr:Move(self.player.dbid, 100001, 50, 50)
	elseif a == "t" then
		server.mapMgr:SetTitle(self.player.dbid, 100007, 1901)
	end
end

function GM:king(a, b)
	if a == "j" then
		server.kingMgr:Join(self.player, true)
	elseif a == "c" then
		server.kingMgr:AttackCity(self.player, b or 2)
	elseif a == "g" then
		server.kingMgr:Guard(self.player, b or 2)
	elseif a == "pk" then
		server.kingMgr:PK(self.player, b or 17179869189)
	elseif a == "r" then
		server.kingMgr:PayRevive(self.player.dbid)
	elseif a == "p" then
		server.kingMgr:GetPointInfo(self.player.dbid)
	elseif a == "ci" then
		server.kingMgr:GetCityData(self.player.dbid, b or 2)
	elseif a == "d" then
		server.kingMgr:TestDead(self.player.dbid)
	elseif a == "addp" then
		server.kingMgr:TestPoint(self.player.dbid, b or 1)
	elseif a == "start" then
		server.kingMgr:SendWar("Start")
	elseif a == "begin" then
		server.kingMgr:SendWar("Begin")
	elseif a == "end" then
		server.kingMgr:SendWar("End")
	elseif a == "kill" then
		server.kingMgr:SendWar("MapDo", self.player.dbid, "AddSeriesKill", 1)
	elseif a == "begin" then
		server.kingMgr:SendWar("Begin")
	end
end

function GM:climb(a, b)
	if a == "e" then
		server.climbMgr:Enter(self.player)
	elseif a == "pk" then
		server.climbMgr:PK(self.player, b or 0)
	elseif a == "s" then
		server.climbMgr:TestAddScore(self.player.dbid, b or 2)
	elseif a == "mon" then
		server.climbMgr:TestRefeshMon(self.player.dbid)
	elseif a == "start" then
		server.climbMgr.testopen = true
		server.climbMgr:SendWar("Start")
	elseif a == "end" then
		server.climbMgr:SendWar("End")
	elseif a == "rank" then
		server.climbMgr:SendWar("DealWeekRank")
	elseif a == "reset" then
		server.climbMgr.cache.open = 0
	end
end

function GM:fieldboss(a, b)
	server.raidMgr:SendRaidType(server.raidConfig.type.FieldBoss, "RefreshFieldBoss")
end

function GM:kfboss(a, b)
	if a == "open" then
		server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "TestOpen")
	elseif a == "boss" then
		server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "BossEnter")
	elseif a == "hudun" then
		server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "ShieldDec", server.configCenter.KfBossBaseConfig.shieldvalue)
	elseif a == "close" then
		server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "Close")
	elseif a == "enter" then
		server.cs_kfboss_entermap(self.player.socket, {})
	elseif a == "print" then
		server.raidMgr:SendRaidType(server.raidConfig.type.KFBoss, "TestPrint")
	end
end

function GM:drop(a)
	local rewards = server.dropCenter:DropGroup(a)
	self.player:GiveRewardAsFullMailDefault(rewards, "GM", server.baseConfig.YuanbaoRecordType.GMCMD, nil)
end

function GM:center(funcname, ...)
	server.serverCenter:SendCenter("GM", funcname, ...)
end

function GM:match(matchtype, count)
	if matchtype == "p" then
		matchtype = "AutoDtbByNum"
	elseif matchtype == "t" then
		matchtype = "DtbByTest"
	end
	self:center("Match", matchtype or "DtbByTest", count)
end

function GM:marry(a, b)
	if a == "qin" then
		self.player.marry:AddIntimacy(b or 2)
		self.player.marry:GetMarryInfo()
	elseif a == "tian" then
		self.player.marry:AddIntimate(b or 2)
		self.player.marry:GetMarryInfo()
	elseif a == "gr" then
		self.player.marry.cache.grade = (b or 1)
		self.player.marry:GetMarryInfo()
	end
end

function GM:auc(a, b, c)
	if a == "r" then
		self.player.auctionPlug.rewards = {{type=1,id=2001207,count=2}}
	elseif a == "c" then
		self.player.auctionPlug:Select(b or 2)
	elseif a == "p" then
		self.player.auctionPlug:Offer(b, c or 0)
	elseif a == "ed" then
		self.player.auctionPlug:onAddActive(b or 200)
	elseif a == "s" then
		server.auctionMgr:ShelfGlobal(0, 1001070, 20)
	elseif a == "sl" then
		server.auctionMgr:ShelfLocal(0, 1001070, 20, self.player.cache.guildid)
	end
end

function GM:baby( ... )
	self:RunCMD("vip 10")
	self:RunCMD("0 9999999999")
	self:RunCMD("1 99999999")
	self:RunCMD("2 99999999")
	self:RunCMD("3 99999999")
	self:RunCMD("子母河水")
end

function GM:next()
	server.advancedrCenter:DoReward()
	local cache = server.mysqlBlob:LoadUniqueDmg("datalist", "timers")
	cache.serverOpenTime = cache.serverOpenTime - (24 * 3600)
	server.serverOpenTime = cache.serverOpenTime
	server.serverCenter:CallLocalMod("world", "activityMgr", "SetServerOpenTime", server.serverOpenTime)
	server.serverCenter:CallLocalMod("world", "activityMgr", "ResetActivity")
	server.timerCenter:DayTimer()
	server.dataPack:BroadcastDtbAndLocal("onrecvevent", server.event.daytimer)
end

function GM:fore()
	local cache = server.mysqlBlob:LoadUniqueDmg("datalist", "timers")
	cache.serverOpenTime = cache.serverOpenTime + (24 * 3600)
	server.serverOpenTime = cache.serverOpenTime
	server.serverCenter:SendLocalMod("world", "activityMgr", "SetServerOpenTime", server.serverOpenTime)
	server.serverCenter:SendLocalMod("world", "activityMgr", "ResetActivity")
	server.timerCenter:DayTimer()
end

function GM:act(a, b, c)
	if a == "clear" then
		self.player.activityPlug.cache.list = {}
		local cache = server.mysqlBlob:LoadUniqueDmg("datalist", "timers")
		cache.serverOpenTime = lua_app.now() - 1
		server.serverOpenTime = cache.serverOpenTime
		cache.serverRunDay = 1
		server.serverRunDay = 1
		server.serverCenter:SendLocalMod("world", "activityMgr", "SetServerOpenTime", server.serverOpenTime)
		server.serverCenter:SendLocalMod("world", "activityMgr", "ResetActivity")
		server.timerCenter:DayTimer()
		server.timerCenter:SetResetServer()
	elseif a == "half" then
		server.onevent(server.event.halfhourtimer, b or 0, c or 0)
		server.dataPack:BroadcastDtbAndLocal("onrecvevent", server.event.halfhourtimer, b or 0, c or 0)
	elseif a == "del" then
		server.recordMgr:DelActivity(b or 12)
	elseif a == "rank" then
		server.advancedrCenter:DoReward()
	end
end

function GM:title(a)
	self.player.role.titleeffect:DoActivatePart(a or 1000)
end

function GM:r(modname,... )
	local tree = string.split(modname, ".")
	local max = #tree
	local nowmod = self.player.role
	for i = 1, max - 1 do
		nowmod = nowmod[tree[i]]
	end
	if nowmod[tree[max]] then
		nowmod[tree[max]](nowmod,...)
	else
		lua_app.log_info(modname..", not exist.")
	end
end

function GM:p(modname,... )
	local tree = string.split(modname, ".")
	local max = #tree
	local nowmod = self.player
	for i = 1, max - 1 do
		nowmod = nowmod[tree[i]]
	end
	if nowmod[tree[max]] then
		nowmod[tree[max]](nowmod,...)
	else
		lua_app.log_info(modname..", not exist.")
	end
end

function GM:answer()
	server.answerCenter:AStart()
end

function GM:s(modname,... )
	local tree = string.split(modname, ".")
	local max = #tree
	local nowmod = server
	for i = 1, max - 1 do
		nowmod = nowmod[tree[i]]
	end
	if nowmod[tree[max]] then
		nowmod[tree[max]](nowmod,...)
	else
		lua_app.log_info(modname..", not exist.")
	end
end

function GM:xdh(j,k,l)
	server.qualifyingMgr:CallWar("test",self.player.dbid, j, k, l)
end

function GM:petbuff(a)
	local bound = self.player.pet.cache.outbound[1]
	if not bound or bound == 0 then
		server.sendErr(self.player, "请先设置出战宠物")
		return
	end
	self.player.pet:ClearBuff()
	if type(a) == "number" then
		self.player.pet:AddBuff(a, true, 1)
	end
end

function GM:dl(a, b)
	if a == "exp" then
		local exp = b or 9999999
		self.player.dailyTask.cache.exp = self.player.dailyTask.cache.exp + exp
		local today = {}
		for k,v in pairs(self.player.dailyTask.cache.today) do
			table.insert(today, {no = k, num = v})
		end
		local msg = {
			exp = self.player.dailyTask.cache.exp,
			active = self.player.dailyTask.cache.active,
			today = today,
		}
		server.sendReq(self.player, "sc_dailyTask_update", msg)
	end
	
end

function GM:RunCMD(str)
	if self.player.gm_level ~= 100 then
		lua_app.log_error("GM:RunCMD: not GM", self.player.cache.account, self.player.cache.name, self.player.ip, str)
		return
	end
	lua_app.log_info("== GM >>>", self.player.cache.account, self.player.cache.name, self.player.ip, "\n\t>>CMD::", str)
	local args = string.split(str, " ")
	for i = #args, 1, -1 do
		if args[i] == "" then
			table.remove(args, i)
		end
	end
	if args[1] and #args <= 2 then
		if tonumber(args[1]) then
			if self:give(tonumber(args[1]), tonumber(args[2])) then
				return
			end
		else
			if self:item(args[1], tonumber(args[2])) then
				return
			end
		end
	end
	local cmd = args[1]
	table.remove(args, 1)
	for i = 1, #args do
		if tonumber(args[i]) then
			args[i] = tonumber(args[i])
		end
	end
	if string.find(cmd,"cs_") then
		local msg = {}
		for _,v in ipairs(args) do
			print(v)
			local t = string.split(v, "=")
			if tonumber(t[2]) then
				t[2] = tonumber(t[2])
			end
			msg[t[1]] = t[2]
		end
		print("\n--- GM recvReq:", cmd)
		table.ptable(msg, 3)
		local data = server[cmd](self.player.socket, msg)
		if data then
			print("\n++++ GM sendReq", cmd)
			table.ptable(data, 3)
		end
		return
	end

	if self[cmd] then
		self[cmd](self, table.unpack(args))
		-- assert(pcall(self[cmd], self, table.unpack(args)))
		return
	end
	lua_app.log_error("error cmd:", str)
end

function GM:BRunCMD(str)

	lua_app.log_info("== GM >>>", self.player.cache.account, self.player.cache.name, self.player.ip, "\n\t>>CMD::", str)
	local args = string.split(str, " ")
	for i = #args, 1, -1 do
		if args[i] == "" then
			table.remove(args, i)
		end
	end
	if args[1] and #args <= 2 then
		if tonumber(args[1]) then
			if self:give(tonumber(args[1]), tonumber(args[2])) then
				return
			end
		else
			if self:item(args[1], tonumber(args[2])) then
				return
			end
		end
	end
	local cmd = args[1]
	table.remove(args, 1)
	for i = 1, #args do
		if tonumber(args[i]) then
			args[i] = tonumber(args[i])
		end
	end
	if string.find(cmd,"cs_") then
		local msg = {}
		for _,v in ipairs(args) do
			print(v)
			local t = string.split(v, "=")
			if tonumber(t[2]) then
				t[2] = tonumber(t[2])
			end
			msg[t[1]] = t[2]
		end
		print("\n--- GM recvReq:", cmd)
		table.ptable(msg, 3)
		local data = server[cmd](self.player.socket, msg)
		if data then
			print("\n++++ GM sendReq", cmd)
			table.ptable(data, 3)
		end
		return
	end

	if self[cmd] then
		self[cmd](self, table.unpack(args))
		-- assert(pcall(self[cmd], self, table.unpack(args)))
		return
	end
	lua_app.log_error("error cmd:", str)
end

server.playerCenter:SetEvent(GM, "gm")
return GM
