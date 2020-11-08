local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local _GivePlayerNumeric = require "player.item.GivePlayerNumeric"
local _PayPlayerNumeric = require "player.item.PayPlayerNumeric"
local _CheckPlayerNumeric = require "player.item.CheckPlayerNumeric"
local tools = require "player.platform.tools"
local ItemConfig = require "resource.ItemConfig"
local EntityConfig = require "resource.EntityConfig"
local RankConfig = require "resource.RankConfig"
local tbname = "players"

local Player = oo.class()

function Player:ctor()
	self.attrs = EntityConfig:GetZeroAttr(EntityConfig.Attr.atCount)
	self.exattrs = EntityConfig:GetZeroAttr(EntityConfig.ExAttr.eatCount)
	self.attrRecord = {}
	server.playerCenter:oncreateplug(self)
	self.server = server
end

function Player:SetLoginInfo(logininfo)
	self.account = logininfo.account
	self.gm_level = logininfo.gm_level
	self.ip = logininfo.ip
	self.uid = logininfo.uid
	self.channelId = logininfo.channelId
end

function Player:Create(datas)
	assert(not self.cache)
	self:Heartbeat()
	datas.account = self.account
	datas.serverid = server.serverid
	datas.name = datas.actorname
	datas.createtime = lua_app.now()
	datas.lastonlinetime = datas.createtime
	datas.createip = self.ip
	datas.lastloginip = self.ip
	datas.lastloginday = server.serverRunDay
	self.cache = server.mysqlBlob:CreateDmg(tbname, datas, true)
	self.dbid = self.cache.dbid
	self.nowserverid = server.serverid
	server.playerCenter:onevent(server.event.createplayer, self)
	lua_app.log_info("Player:Create:: new player regist", self.dbid, self.cache.account, self.cache.name, self.ip)
	server.serverCenter:SendDtbMod("httpr", "playerCenter", "PlayerCreateActor", self.cache.serverid, self.account, self.dbid,
		self.uid, self.channelId, self.cache.name, self.ip)
	self.firstLogin = true
end

function Player:Load(datas)
	assert(not self.cache)
	self:Heartbeat()
	self.cache = server.mysqlBlob:LoadOneDmg(tbname, datas)
	if not self.cache then
		return false
	end
	self.dbid = self.cache.dbid
	self.nowserverid = server.serverid
	self.loadpower = true
	server.playerCenter:onevent(server.event.loadplayer, self)
	return true
end

function Player:Release()
	if self.cache then
		server.playerCenter:onevent(server.event.releaseplayer, self)
		self.cache(true)
		self.cache = nil
		self.dbid = nil
	end
end

function Player:GetPlayerCacheStr(conds)
	local ret = {}
	for str, _ in pairs(conds) do
		local sp, modname = RankConfig:ParseRankData(str)
		local value = modname == "player" and self.cache or self[modname].cache
		for _, v in ipairs(sp) do
			value = value[v]
		end
		assert(value ~= (modname == "player" and self.cache or self[modname].cache))
		ret[str] = value
	end
	return ret
end

-- 对应 sc_show_other_player 这个协议
function Player:GetMsgData()
	local guild = server.guildCenter:GetGuild(self.cache.guildid or 0)
	local msg = {
		id = self.dbid,
		name = self.cache.name,
		level = self.cache.level,
		job = self.cache.job,
		sex = self.cache.sex,
		power = self.cache.totalpower,
		vip = self.cache.vip,
		guildName = guild and guild.cache.name,
		partner = self.marry.cache.partnername,
		petList = self.cache.pet.outbound,
		xianlvList = self.cache.xianlv.outbound,
		shows = self.role:GetShows(),
		attributeData = lua_util.ConverToArray(self.attrs, 0, EntityConfig.Attr.atCount),
		equipsData = self.role.equip:GetMsgData(),
		headframe = self.head:GetFrame(),
	}
	return msg
end

function Player:BaseInfo()
	local info = {
		dbid = self.dbid,
		name = self.cache.name,
		level = self.cache.level,
		job = self.cache.job,
		sex = self.cache.sex,
		vip = self.cache.vip,
		power = self.cache.totalpower,
		guildid = self.cache.guildid,
		guildname = self.guild:GetGuildName(),
		shows = self.role:GetShows(),
	}
	return info
end

function Player:Heartbeat()
	self.heatbeatTime = lua_app.now()
end

function Player:DayTimer(day)
	for i = self.cache.lastloginday, day do
		server.playerCenter:onevent(server.event.daybyday, self, i)
	end
	self.cache.lastloginday = day
	self.cache.totalloginday = math.min(self.cache.totalloginday + 1, day)
	server.playerCenter:onevent(server.event.daytimer, self, day)
	self.cache.rankworship = 0
end

function Player:HalfHour(hour, minute)
	server.playerCenter:onevent(server.event.halfhourtimer, self, hour, minute)
end

function Player:BeforeLogin()
	if self.isLogin then
		return
	end
	self.loginLock = lua_app.now()
	self.heatbeatTime = lua_app.now()
	server.playerCenter:onevent(server.event.beforelogin, self)
	server.onevent(server.event.beforelogin, self)
	self.cache.lastonlinetime = lua_app.now()
	if self.cache.lastloginday == server.serverRunDay then
		return
	end
	self:DayTimer(server.serverRunDay)
end

function Player:Login()
	if self.isLogin then
		lua_app.log_error("Player:Login ERROR", self.cache.account, self.dbid, self.cache.name)
		return
	end
	lua_app.log_info("Player:Login", self.cache.serverid, self.cache.account, self.dbid, self.cache.name, self.ip)

	local tools = tools.new()
	tools:refresh(self.dbid)
	
	self.isLogin = lua_app.now()
	self.cache.lastloginip = self.ip
	server.playerCenter:onevent(server.event.login, self)
	server.onevent(server.event.login, self)
	self.loginLock = nil
	self:InitClient()
	server.serverCenter:SendTagMod(self.dbid, "httpr", "playerCenter", "PlayerLogin", self.cache.serverid, self.dbid, self.cache.account,
		self.cache.name, self.ip, self.cache.level, self.cache.yuanbao, self.cache.byb, self.cache.totalpower)
	local function _SendRecordInfoFunc()
		self.sendRecordInfoTimer = lua_app.add_timer(600000, _SendRecordInfoFunc)
		self:SendRecordPlayerInfo()
	end
	if self.sendRecordInfoTimer then
		lua_app.del_timer(self.sendRecordInfoTimer)
	end
	self.sendRecordInfoTimer = lua_app.add_timer(600000, _SendRecordInfoFunc)
end

function Player:InitClient()
	self.cache.lastloginip = self.ip
	self:SendServerTime()
	self:SendServerDay()
	local pingji = 1
	if self.cache.totalpower < 60000000 then
		pingji = 1
	else
		pingji = 10
	end
	server.sendReq(self, "sc_actor_base", {
			handle    = self.cache.handler,
			actorid   = self.dbid,
			serverid  = self.cache.serverid,
			actorname = self.cache.name,
			job  	  = self.cache.job,
			sex  	  = self.cache.sex,
			level     = self.cache.level,
			exp       = self.cache.exp,
			power     = self.cache.totalpower,
			gold      = self.cache.gold,
			yuanbao   = self.cache.yuanbao,
			byb   	  = self.cache.byb,
			vip       = self.cache.vip,
			contrib   = self.cache.contrib,
			bagnum    = self.cache.bagnum,
			clientvalue = self.cache.clientvalue,
			clientvaluelist = self.cache.clientvaluelist,
			guildid = self.cache.guildid,
			guildname = self.guild:GetGuildName(),
			friendcoin = self.cache.friend_data.friedncoin,
            pingji = pingji,
		})
	if self.firstLogin then
		self.firstLogin = false
		self:OnFirstLogin()
	end
	if self.cache.welcome == 1 then
		server.sendReq(self, "sc_welcome", {})
	end
	self:SendRankWorship()
	self:SendRenameCount()
	server.playerCenter:onevent(server.event.clientinit, self)
	server.onevent(server.event.clientinit, self)
	self:SendAttr()
end

 function Player:OnFirstLogin()
 	server.sendReq(self, "first_register", {})
	server.serverCenter:SendDtbMod("httpr", "playerCenter", "PlayerFirstLogin", self.cache.serverid, self.cache.account)
 end

 function Player:WelcomeReward()
 	if self.cache.welcome == 0 then
 		return
 	end
 	self.cache.welcome = 0
 	local GuideBaseConfig = server.configCenter.GuideBaseConfig
	if GuideBaseConfig.givepet.id then
		self:GiveReward(GuideBaseConfig.givepet.type, GuideBaseConfig.givepet.id, GuideBaseConfig.givepet.count, 0, server.baseConfig.YuanbaoRecordType.Guide)
		self.pet:Active(GuideBaseConfig.givepet.petid)
		self.pet:OutBound(GuideBaseConfig.givepet.petid)
		self.pet:onInitClient()
	end
	local rewards = {}
	if GuideBaseConfig.givebyuan.id then
		table.insert(rewards, GuideBaseConfig.givebyuan)
	end
	if GuideBaseConfig.givegold.id then
		table.insert(rewards, GuideBaseConfig.givegold)
	end
	if GuideBaseConfig.giveweapon.id then
		table.insert(rewards, GuideBaseConfig.giveweapon)
	end
	if GuideBaseConfig.givesilver.id then
		table.insert(rewards, GuideBaseConfig.givesilver)
	end
	self:GiveRewards(rewards, 0, server.baseConfig.YuanbaoRecordType.Guide)
	self.vip:SetVip(GuideBaseConfig.givevip)
 end

 function Player:OnTaskComplete(taskid)
 	local GuideBaseConfig = server.configCenter.GuideBaseConfig
 	if GuideBaseConfig.givexianlv.taskid == taskid then
 		if GuideBaseConfig.givexianlv.id then
			self:GiveReward(GuideBaseConfig.givexianlv.type, GuideBaseConfig.givexianlv.id, GuideBaseConfig.givexianlv.count, 0, server.baseConfig.YuanbaoRecordType.Guide)
			self.xianlv:Active(GuideBaseConfig.givexianlv.petid)
			self.xianlv:OutBound(GuideBaseConfig.givexianlv.petid, self.xianlv.cache.outbound[2])
			self.xianlv:onInitClient()
		end
 	end
	if GuideBaseConfig.givetitle.taskid == taskid then
		self:GiveReward(GuideBaseConfig.givetitle.type, GuideBaseConfig.givetitle.id, GuideBaseConfig.givetitle.count, 0, server.baseConfig.YuanbaoRecordType.Guide)
		self.role.titleeffect:ActivatePart(GuideBaseConfig.givetitle.petid)
	end
	if GuideBaseConfig.catchtask == taskid then
		server.catchPetMgr:UnlockCatch(self)
	end
 end

function Player:BeforeLogout()
	if not self.isLogin then
		return
	end
	self.loginLock = lua_app.now()
	server.onevent(server.event.beforelogout, self)
	server.playerCenter:onevent(server.event.beforelogout, self)
end

function Player:Logout()
	if not self.isLogin then
		lua_app.log_error("Player:Logout ERROR", self.cache.account, self.dbid, self.cache.name)
		return
	end
	if self.sendRecordInfoTimer then
		lua_app.del_timer(self.sendRecordInfoTimer)
		self.sendRecordInfoTimer = nil
	end
	self:SendRecordPlayerInfo()
	lua_app.log_info("Player:Logout", self.cache.serverid, self.cache.account, self.dbid, self.cache.name, self.ip)
	server.serverCenter:SendTagMod(self.dbid, "httpr", "playerCenter", "PlayerLogout", self.cache.serverid, self.dbid, self.cache.account,
		self.cache.name, self.ip, self.cache.level, self.cache.yuanbao, self.cache.byb, self.cache.totalpower)
	self.ip = nil
	self.isLogin = false
	self.cache.lastonlinetime = lua_app.now()
	server.onevent(server.event.logout, self)
	server.playerCenter:onevent(server.event.logout, self)
	self.loginLock = nil
	self:PrintPower()
	self.cache()
end

function Player:SendRecordPlayerInfo()
	server.serverCenter:SendTagMod(self.dbid, "httpr", "playerCenter", "UpdatePlayerInfo", self.dbid, self.cache.level,
		self.cache.vip, self.cache.yuanbao, self.cache.byb, self.cache.totalpower, self.cache.chapter.chapterlevel, {
			curtaskid = (next(self.cache.task.tasks[server.taskConfig.TaskType.Main])),
		})
end

function Player:sendReq(name, param)
	server.sendToClient(self.protocol, self.socket, name, param)
end

function Player:GiveReward(type1, id, count, showTip, ttype, log)
	local count = math.floor(count or 1)
	if not ttype or ttype == 0 then
		lua_app.log_error("Player:GiveReward:: no type", id, log)
	end
	if type(type1) == "string" then
	type1=tonumber(type1)
	end
	if type(id) == "string" then
	id=tonumber(id)
	end
	if type(count) == "string" then
	count=tonumber(count)
	end
	if type1 == ItemConfig.AwardType.Numeric then
		_GivePlayerNumeric[id](self, count, ttype, log)
	elseif type1 == ItemConfig.AwardType.Item then
		self.bag:AddItem(id, count, nil, nil, showTip, ttype, log)
	else
		lua_app.log_error("invalid item.type =", type1)
	end
end

function Player:ClearItem()
	self.bag:Clear()
end



function Player:GiveRewards(reward, showTip, type, log)
	for _, v in ipairs(reward) do
		self:GiveReward(v.type, v.id, v.count, showTip, type, log)
	end
end

function Player:GiveRewardsList(rewards, showTip, type, log)
	for _, v in ipairs(rewards) do
		self:GiveRewards(v, showTip, type, log)
	end
end

function Player:GiveRewardIfCan(reward, showTip, type, log)
	if not self.bag:CheckRewardCanGive(reward) then return false end
	self:GiveRewards(reward, showTip, type, log)
	return true
end

function Player:GiveRewardAsFullMail(reward, head, context, type, log, showTip)
	if not self.isLogin or not self:GiveRewardIfCan(reward, showTip, type, log) then
		server.mailCenter:SendMail(self.dbid, head, context, reward, type, log)
	end
end

function Player:GiveRewardAsFullMailDefault(reward, sourceName, type, log, showTip)
	if not self.isLogin or not self:GiveRewardIfCan(reward, showTip, type, log) then
		server.mailCenter:SendMail(self.dbid, "背包已满", "这是在" .. sourceName .. "中获取的物品，背包已满，请清理背包后查收。", reward, type, log)
	end
end

function Player:SendMail(head, context, award, type, log, sendtime)
	server.mailCenter:SendMail(self.dbid, head, context, award, type, log, sendtime)
end

function Player:CheckReward(type, id, count)
	local count = math.floor(count or 1)
  	if type == ItemConfig.AwardType.Numeric then
    	return _CheckPlayerNumeric[id](self, count)
    elseif type == ItemConfig.AwardType.Item then
        return self.bag:CheckItem(id, count)
	else
        lua_app.log_error("invalid item.type =", type)
    end
end

function Player:CheckRewards(reward)
	for _, v in ipairs(reward) do
		if not self:CheckReward(v.type, v.id, v.count) then
			if v.subid and v.subcount then
				if not self:CheckReward(v.type, v.subid, v.subcount) then
					return false
				end
			else
				return false
			end
		end
	end
	return true
end

function Player:PayReward(type, id, count, ttype, log)
	local count = math.floor(count or 1)
  	if type == ItemConfig.AwardType.Numeric then
    	return _PayPlayerNumeric[id](self, count, ttype, log)
    elseif type == ItemConfig.AwardType.Item then
        return self.bag:DelItemByID(id, count, ttype, log) ~= ItemConfig.ItemChangeResult.DEL_FAILED
	else
        lua_app.log_error("invalid item.type =", type)
    end
end

function Player:PayRewards(reward, ttype, log)
	if not self:CheckRewards(reward) then
		return false
	end
	for _, v in ipairs(reward) do
		if not self:PayReward(v.type, v.id, v.count, ttype, log) then
			if v.subid and v.subcount then
				if not self:PayReward(v.type, v.subid, v.subcount, ttype, log) then
					lua_app.log_error("Player:PayRewards:: 紧急的Clamant ERROR SUB", self.dbid, self.cache.name, ttype, log)
					table.ptable(reward, 3)
					return false
				end
			else
				lua_app.log_error("Player:PayRewards:: 紧急的Clamant ERROR", self.dbid, self.cache.name, ttype, log)
				table.ptable(reward, 3)
				return false
			end
		end
	end
	return true
end

function Player:PayRewardByShop(type, id, count, ttype, log, buyType)
	local paylist = {}
	table.insert(paylist, { type = type, id = id, count = count})
	return self:PayRewardsByShop(paylist, ttype, log, buyType)
end

function Player:PayRewardsByShop(reward, ttype, log, buyType)
	if lua_util.empty(reward) then
		return false
	end
	local payResult, paylist= server.shopCenter:CheckPayment(self, reward, buyType)
	-- print("Player:PayRewardsByShop",payResult,"buyType",buyType)
	if payResult then
		return self:PayRewards(paylist, ttype, log)
	end
	return false
end

function Player:UpDateLevel(level)
	local oldlevel = self.cache.level
	if level == oldlevel then return end
	assert(level <= #server.configCenter.ExpConfig)
	self.cache.level = level
	server.playerCenter:onevent(server.event.levelup, self, oldlevel, level)
end

function Player:AddExp(count)
	local tools = tools.new()
	tools:refresh(self.dbid)
	assert(count >= 0)
	count = math.ceil(count)
	local exp = self.cache.exp + count
	local level = self.cache.level
	level,exp = self:CalcExpLevel(level,exp,ItemConfig.UpLevelType.AutoUpgrade)
	self:UpDateLevel(level)
	self.cache.exp = exp
	--print("player level:"..self.cache.level..",exp:"..self.cache.exp)
	server.sendReq(self,"exp_change", {
			level = self.cache.level,
			exp = exp,
			upexp = count,
		})
end

-- 设置重算战力标志，防止频繁调用
function Player:ToReCalcPower()
	if self.powertimer then return end

	local function _RunReCalcPower()
		if self.powertimer then
			lua_app.del_timer(self.powertimer)
			self.powertimer = nil
		end
		self:ReCalcPower()
	end

	self.powertimer = lua_app.add_timer(1000, _RunReCalcPower)
end

function Player:ReCalcPower()
	local power = 0
	local attrs = EntityConfig:GetRealAttr(self.attrs, self.exattrs)
	local AttrPowerConfig = server.configCenter.AttrPowerConfig
	for k, v in pairs(attrs) do
		if AttrPowerConfig[k] then
			power = power + v * AttrPowerConfig[k].power
		end
	end
	power = math.floor(power / 100)
	local newpower = power + self.role.skill:GetSkillPower() + self.role.spellsRes:GetSkillPower() + self.role.fly:GetSkillPower()
	-- 防止掉战力
	self.changepower = self.changepower or 0
	if self.loadpower then
		self.loadpower = false
		if newpower < self.cache.totalpower then
			self.changepower = self.cache.totalpower - newpower
			print("Player:ReCalcPower---- Check Power!!!!!!!!!!!!!!", self.cache.name, self.dbid, newpower, self.cache.totalpower, self.changepower)
			self:PrintPower()
		else
			self.changepower = 0
		end
	end
	self.cache.totalpower = newpower + self.changepower
	-- 防止掉战力
	self.activityPlug:onPowerUp(self.cache.totalpower)
	self.guild:UpdatePlayerInfo()
	server.sendReq(self,"sub_role_att_change", {
			roleID = 0,
			attributeData = lua_util.ConverToArray(attrs, 0, EntityConfig.Attr.atCount),
			power = self.cache.totalpower,
		})

	lua_app.log_info("Player:ReCalcPower", self.dbid, self.cache.totalpower)
end

function Player:SendAttr()
	local attrs = EntityConfig:GetRealAttr(self.attrs, self.exattrs)
	server.sendReq(self,"sub_role_att_change", {
			roleID = 0,
			attributeData = lua_util.ConverToArray(attrs, 0, EntityConfig.Attr.atCount),
			power = self.cache.totalpower,
		})
end

function Player:PrintPower()
	lua_app.log_info("Player:PrintPower----", self.cache.name, self.dbid, self.cache.totalpower)
	for recordtype, attrs in pairs(self.attrRecord) do
		local power = 0
		local AttrPowerConfig = server.configCenter.AttrPowerConfig
		for k, v in pairs(attrs) do
			if AttrPowerConfig[k] then
				power = power + v * AttrPowerConfig[k].power
			end
		end
		power = math.floor(power / 100)
		lua_app.log_info("power--", recordtype, power)
	end
end

--手动升级
function Player:RequestUpdateLevel()
	local exp = self.cache.exp
	local level = self.cache.level
	level,exp = self:CalcExpLevel(level,exp,ItemConfig.UpLevelType.ManualUpgrade)
	self:UpDateLevel(level)
	self.cache.exp = exp
	server.sendReq(self,"exp_change", {
			level = self.cache.level,
			exp = exp,
			upexp = 0,
		})
end
--计算可升的等级
function Player:CalcExpLevel(level,exp,msgtype)
	local ExpConfig = server.configCenter.ExpConfig
	local RoleBaseConfig = server.configCenter.RoleBaseConfig
	local maxLevel = RoleBaseConfig.automaxlevel
	local retLevel = level
	local retExp = exp
	if msgtype == ItemConfig.UpLevelType.AutoUpgrade then
		if retLevel >= maxLevel then
			return retLevel,retExp
		end
		for i = retLevel, maxLevel - 1 do
			if retExp < ExpConfig[i].exp then break end
			retExp = retExp - ExpConfig[i].exp
			retLevel = retLevel + 1
		end
	elseif msgtype == ItemConfig.UpLevelType.ManualUpgrade then
		if retExp >= ExpConfig[retLevel].exp then
			retExp = retExp - ExpConfig[retLevel].exp
			retLevel = retLevel + 1
		end
	end
	return retLevel,retExp
end

-- 充值
function Player:Recharge(count)
	if count < 0 then
		lua_app.log_error("Player:Recharge: count(", count, ") < 0")
		return
	end
	self.cache.recharge = self.cache.recharge + count

	-- self:Set(config.recharge_lasttime, lua_app.now())
	-- if count > self:Get(config.recharge_maxone) then
	-- 	self:Set(config.recharge_maxone, count)
	-- end
	-- self:AddRechargeRankValue(count)
	-- self.task:onEventSet(server.taskConfig.Type.RechargeValue, nil, self:Get(config.recharge))
	-- server.heavenGifts:onUpdateStep(self, PayConfig.HeavenGiftsCondType.AddRecharge, count)
	-- server.heavenGifts:onUpdateStep(self, PayConfig.HeavenGiftsCondType.OneRecharge, count)
	self.vip:Update()
	self.recharge:UpDateMsg()
	self.activityPlug:onRechargeCash(count)
	self:RechargeNotice()
end

function Player:RechargeNotice()
	local rechargeCfg = table.matchValue(server.configCenter.FirstRechargeConfig, function(cfg)
			return self.cache.recharge - cfg.recharge
		end)
	local record = self.cache.rechargenotice
	local notice = rechargeCfg and not record[rechargeCfg.recharge]

	if notice and rechargeCfg.chatid then
		record[rechargeCfg.recharge] = true
		server.chatCenter:ChatLink(rechargeCfg.chatid, nil, nil, self.cache.name, ItemConfig:ConverLinkText(rechargeCfg.item[1]))
	end
end

function Player:CheckYuanbao(count)
	return self.cache.yuanbao >= count
end

function Player:PayYuanBao(count, type, log)
	if count < 0 then
		lua_app.log_error("Player:PayYuanBao: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
		return false
	end
	if self.cache.yuanbao < count then
		lua_app.log_info("Player:PayYuanBao: yuanbao(", self.cache.yuanbao, ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
		return false
	end
	self:ChangeYuanBao(-count, type, log)
	-- server.activityCenter:onPayYuanBao(self, count)
	-- server.heavenGifts:onUpdateStep(self, PayConfig.HeavenGiftsCondType.AddPayYuanbao, count)
	return true
end

function Player:ChangeYuanBao(count, type, log)
	if not type then
		lua_app.log_error("Player:ChangeYuanBao:: no type")
	end
	if count < 0 then
		self.activityPlug:onChangeYuanBao(count * -1)
		server.holyPetCenter:AddCash(self.dbid, count * -1)
	end
	local yuanbao = self.cache.yuanbao + count
	self.cache.yuanbao = yuanbao
	server.serverCenter:SendDtbMod("httpr", "cacheCenter", "InsertYuanbao", {
			serverid = self.cache.serverid,
			playerid = self.dbid,
			type = type or 0,
			type_name = log or server.baseConfig.YuanbaoRecordTypeToName[type] or "",
			yuanbao = count,
			-- ip = self.ip,
		})
	self:SendGoldChange(ItemConfig.NumericType.YuanBao, yuanbao)
end

function Player:PayBYB(count, type, log)
	if count < 0 then
		lua_app.log_error("Player:PayBYB: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
		return false
	end
	if self.cache.byb < count then
		lua_app.log_info("Player:PayBYB: byb(", self.cache.byb, ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
		return false
	end
	self:ChangeByb(-count, type, log)
	return true
end

function Player:ChangeByb(count, type, log)
	if not type then
		lua_app.log_error("Player:ChangeByb:: no type", log)
	end
    local byb = self.cache.byb + count
    self.cache.byb = byb
	server.serverCenter:SendDtbMod("httpr", "cacheCenter", "InsertBYB", {
			serverid = self.cache.serverid,
			playerid = self.dbid,
			type = type or 0,
			type_name = log or server.baseConfig.YuanbaoRecordTypeToName[type] or "",
			byb = count,
			-- ip = self.ip,
		})
    self:SendGoldChange(ItemConfig.NumericType.BYB, byb)
end

function Player:PayGold(count, type, log)
    if count < 0 then
        lua_app.log_error("Player:PayGold: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    if self.cache.gold < count then
        -- lua_app.log_info("Player:PayGold: gold(", self:Get(config.gold), ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    self:ChangeGold(-count, type, log)
    return true
end

function Player:ChangeGold(count, type, log)
    local gold = self.cache.gold + count
    self.cache.gold = gold
    self:SendGoldChange(ItemConfig.NumericType.Gold, gold)
end

function Player:PayContribute(count, type, log)
	if count < 0 then
        lua_app.log_error("Player:PayContribute: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    if self.cache.contrib < count then
        -- lua_app.log_info("Player:PayGold: gold(", self:Get(config.gold), ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    self:ChangeContribute(-count, type, log)
    return true
end

function Player:ChangeContribute(count, type, log)
    local contrib = self.cache.contrib + count
    self.cache.contrib = contrib
    self:SendGoldChange(ItemConfig.NumericType.GuildContrib, contrib)
end

function Player:PayMedal(count, type, log)
	if count < 0 then
        lua_app.log_error("Player:PayMedal: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    if self.cache.arena.medal < count then
        -- lua_app.log_info("Player:PayMedal: gold(", self:Get(config.gold), ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    self:ChangeMedal(-count, type, log)
    return true
end

function Player:ChangeMedal(count, type, log)
    local medal = self.cache.arena.medal + count
    self.cache.arena.medal = medal
    self:SendGoldChange(ItemConfig.NumericType.Medal, medal)
end

function Player:PayFriendcoin(count, type, log)
	if count < 0 then
        lua_app.log_error("Player:PayFriendcoin: count(", count, ") < 0", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    if self.cache.friend_data.friedncoin < count then
        -- lua_app.log_info("Player:PayMedal: gold(", self:Get(config.gold), ") < count(", count, ")", type, log or server.baseConfig.YuanbaoRecordTypeToName[type])
        return false
    end
    self:ChangeFriendcoin(-count, type, log)
    return true
end

function Player:ChangeFriendcoin(count, type, log)
    local friedncoin = self.cache.friend_data.friedncoin + count
    self.cache.friend_data.friedncoin = friedncoin
    self:SendGoldChange(ItemConfig.NumericType.Friendcoin, friedncoin)
end

function Player:SendGoldChange(type, value)
    server.sendReq(self, "gold_change", {
        type = type, 
        value = value, 
    })
end

function Player:SendServerDay()
	local data = {}
	data.day = server.serverRunDay
	data.loginDay = self.cache.totalloginday
	data.mergeDay = 1--server.svrMgr:GetMergeDay()
	server.sendReq(self,"sc_base_open_day",data)
end

function Player:SendServerTime()
	local data = {}
	data.time = lua_app.now()
	data.serverRunDay = server.serverRunDay
	server.sendReq(self,"sc_base_game_time",data)
end

function Player:CheckOpenFunc(condition)
	local FuncNoticeConfig = server.configCenter.FuncNoticeConfig
	for k,v in pairs(FuncNoticeConfig) do
		if condition.type == v.openLv[0] then
			if condition.value == v.openLv[1] then
				if self.cache.openfuncstate & (1<<(k)) == 0 then
					self.cache.openfuncstate = self.cache.openfuncstate | (1<<(k))
					self:GiveRewardAsFullMailDefault(table.wcopy(v.reward), "功能预告", server.baseConfig.YuanbaoRecordType.FuncNotice)
				end
			end
		end
	end
end

function Player:SendRankWorship()
	self:sendReq("sc_rank_worship", {status = self.cache.rankworship})
end

function Player:DoRankWorship()
	if self.cache.rankworship == 1 then
       return 
   end
   self.cache.rankworship = 1
   local cfg
   for k, v in pairs(server.configCenter.MorshipConfig) do
   		if self.cache.level >= v.level then
   			cfg = v
   		end
   end
   if cfg then
       self:GiveRewardAsFullMailDefault(table.wcopy(cfg.awards), "排行榜膜拜", server.baseConfig.YuanbaoRecordType.Marry)
   end
   self:SendRankWorship()
end

function Player:SendRenameCount()
	self:sendReq("sc_rename_count", {count = self.cache.renamecount})
end

return Player
