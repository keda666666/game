local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local MarryConfig = require "resource.MarryConfig"

local Marry = oo.class()

function Marry:ctor(player)
	self.player = player
	self.role = player.role
end

function Marry:onCreate()
	self:onLoad()
end

function Marry:onLoad()
	self.cache = self.player.cache.marry
	self.cache.today = self.cache.today or 0
	self.propose = {}		-- 求婚列表
	self.asked = {}			-- 被求婚列表
	self.invitation = {}
	self:LoadHouseAttr()
end

function Marry:onInitClient()
	self:GetMarryInfo()
	self:SendFrinds()
	self:SendLoginTip()
	self:SendPartnerHouseUp()
	self:DoLogin()
end

function Marry:onLogout(player)
	self:DoLogout()
	self:DenyAllAsked()
	self:RemoveAllPropose()
end

function Marry:onDayTimer()
	self.cache.today = 0
end

-- 移除被求婚
function Marry:DenyAllAsked()
	for id, asked in pairs(self.asked) do
		self:Answer(0, id)
	end
end

function Marry:DenyAsked(id)
	if self.asked[id] then
		self:Answer(0, id)
	end
end

function Marry:Check()
	local MarryBaseConfig = server.configCenter.MarryBaseConfig
	return server.funcOpen:Check(self.player, MarryBaseConfig.marry)
end

-- 移除求婚
function Marry:RemoveAllPropose()
	for id, _ in pairs(self.propose) do
		local target = server.playerCenter:DoGetPlayerByDBID(id)
		if target then
			target.marry:Answer(0, self.player.dbid)
			target:sendReq("sc_marry_remove_asked", {fromid = self.player.dbid})
		end
	end
	self.propose = {}
end

function Marry:RemovePropose(id)
	if self.propose[id] then
		local target = server.playerCenter:DoGetPlayerByDBID(id)
		if target then
			target.marry:Answer(0, self.player.dbid)
			target:sendReq("sc_marry_remove_asked", {fromid = self.player.dbid})
		end
	end
	self.propose[id] = nil
end

function Marry:SendFrinds()
	local msg = {friends = {}, today = self.cache.today}
	for id, _ in pairs(self.player.friend.myfriend) do
		local ispropose = (self.propose[id] ~= nil)
		local player = server.playerCenter:DoGetPlayerByDBID(id)
		if player then
			local ismarry = (player.marry.cache.partnerid > 0) or (not player.marry:Check())
			table.insert(msg.friends, {dbid = id, ispropose = true, ismarry = ismarry})
		end
	end
	self.player:sendReq("sc_marry_friends", msg)
end

-- 求婚
function Marry:Propose(msg)
	if not self:Check() then
		return
	end
	local MarryBaseConfig = server.configCenter.MarryBaseConfig
	local targetid = msg.targetid
	local grade = msg.grade
	local spouse = msg.spouse
	if not server.playerCenter:IsOnline(self.player.dbid) then
		return 1
	end

	if self.cache.partnerid > 0 then
		server.sendErr(self.player, "您当前是已婚状态，无法求婚")
		return 1
	end

	if not server.playerCenter:IsOnline(targetid) then
		server.sendErr(self.player, "对方已离线，无法向其求婚")
		return 1
	end

	local target = server.playerCenter:DoGetPlayerByDBID(targetid)
	if not target then
		server.sendErr(self.player, "对方已离线，无法向其求婚")
		return 1
	end

	if target.marry.cache.partnerid > 0 then
		server.sendErr(self.player, "对方已婚，无法向其求婚")
		return 1
	end

	-- if not self.player.friend:IsFriend(targetid) then
	-- 	server.sendErr(self.player, "必须是好友才可求婚")
	-- 	return 1
	-- end

	if self.propose[targetid] then
		server.sendErr(self.player, "您已向其求婚，请耐心等待答复")
		return 1
	end

	if self.cache.today >= MarryBaseConfig.frequency then
		server.sendErr(self.player, "今日还可结婚次数已达上限")
		return 1
	end

	local MarryProConfig = server.configCenter.MarryConfig[grade]
	if not MarryProConfig then
		return 1
	end
	
	if not self.player:PayRewards({MarryProConfig.price}, server.baseConfig.YuanbaoRecordType.Marry, "Marry:Propose") then
		server.sendErr(self.player, "元宝不足，无法向其求婚")
		return 1
	end

	self.propose[targetid] = msg
	local ask = {
		fromid = self.player.dbid,
		name = self.player.cache.name,
		grade = grade,
		spouse = spouse,
		power = self.player.cache.totalpower,
		level = self.player.cache.level,
		job = self.player.cache.job,
		sex = self.player.cache.sex,
		time = lua_app.now()
	}
	target.marry:Asked(ask)
	self:SendFrinds()
	return 0
end

-- 被求婚
function Marry:Asked(ask)
	self.asked[ask.fromid] = ask
	self.player:sendReq("sc_marry_asked", ask)
	local function _DenyAsked()
		self:DenyAsked(ask.fromid)
	end
	ask.timer = lua_app.add_timer(3600 * 1000, _DenyAsked)
end

function Marry:RemoveAsked(fromid)
	local asked = self.asked[fromid]
	if asked and asked.timer then
		lua_app.del_timer(asked.timer)
	end
	self.asked[fromid] = nil
end

function Marry:RemoveAskedPayBack(fromid)
	local asked = self.asked[fromid]
	if asked then
		local MarryProConfig = server.configCenter.MarryConfig[asked.grade]
		local MarryBaseConfig = server.configCenter.MarryBaseConfig
		local title = MarryBaseConfig.marrytitle
		local content = string.format(MarryBaseConfig.marrydes, self.player.cache.name)
		if self.cache.partnerid == fromid then
			local suitor = server.playerCenter:DoGetPlayerByDBID(fromid)
			local partner = server.playerCenter:DoGetPlayerByDBID(suitor.marry.cache.partnerid)
			title = MarryBaseConfig.moneytitle
			content = string.format(MarryBaseConfig.moneydes, partner.cache.name, self.player.cache.name)
		end
		server.mailCenter:SendMail(fromid, title, content, {table.wcopy(MarryProConfig.price)}, server.baseConfig.YuanbaoRecordType.Marry)
		self:RemoveAsked(fromid)
	end
end

-- 回应
function Marry:Answer(agree, fromid)
	if not self:Check() then
		return
	end
	local MarryBaseConfig = server.configCenter.MarryBaseConfig
	local suitor = server.playerCenter:DoGetPlayerByDBID(fromid)
	if agree == 1 then
		if self.cache.partnerid > 0 then
			self:RemoveAskedPayBack(fromid)
			server.sendErr(self.player, "您当前是已婚状态，无法接受求婚")
			return 1
		end

		if self.cache.today >= MarryBaseConfig.frequency then
			server.sendErr(self.player, "今日还可结婚次数已达上限")
			return 1
		end

		if not server.playerCenter:IsOnline(fromid) then
			self:RemoveAskedPayBack(fromid)
			server.sendErr(self.player, "对方离线，无法接受求婚")
			return 1
		end

		if not suitor then
			self:RemoveAskedPayBack(fromid)
			server.sendErr(self.player, "对方离线，无法接受求婚")
			return 1
		end

		if suitor.marry.cache.partnerid > 0 then
			self:RemoveAskedPayBack(fromid)
			server.sendErr(self.player, "对方已婚，无法接受求婚")
			return 1
		end

		-- if not self.player.friend:IsFriend(fromid) then
		-- 	self:RemoveAskedPayBack(fromid)
		-- 	server.sendErr(self.player, "必须是好友才能接受求婚")
		-- 	return 1
		-- end
	end

	if not suitor then
		return 1
	end

	local asked = self.asked[fromid]
	if not asked then
		return 1
	end

	suitor.marry.propose[self.player.dbid] = nil
	local answermsg = {
		dbid = self.player.dbid,
		name = self.player.cache.name,
		grade = asked.grade,
		agree = agree,
	}
	suitor:sendReq("sc_marry_answer", answermsg)
	if agree == 1 then
		self:RemoveAsked(fromid)
		local now = lua_app.now()
		suitor.marry:DoMarry(self.player.dbid, self:OtherSpouse(asked.spouse), now, asked.grade, self.player.cache.name)
		self:DoMarry(suitor.dbid, asked.spouse, now, asked.grade, suitor.cache.name)
		self:SendInvitation(asked.grade)

		suitor.marry:RemoveAllPropose()
		suitor.marry:DenyAllAsked()
		self:RemoveAllPropose()
		self:DenyAllAsked()

		local MarryProConfig = server.configCenter.MarryConfig[asked.grade]
		if MarryProConfig.weddingnotice then
			server.noticeCenter:Notice(MarryProConfig.weddingnotice, suitor.cache.name, self.player.cache.name)
		end
	else
		self:RemoveAskedPayBack(fromid)
	end
	return 0
end

function Marry:DoMarry(id, spouse, time, grade, name)
	self.cache.partnerid = id
	self.cache.partnername = name
	self.cache.spouse = spouse
	self.cache.level = self.cache.level or 1
	self.cache.time = time
	self.cache.today = self.cache.today + 1
	if grade > self.cache.grade then
		local oldgrade = self.cache.grade
		self.cache.grade = grade
		self:GradeHouseAttr(oldgrade, grade)
	end
	self.cache.partnerhouseup = 0
	self.cache.partnerhouseuptime = {}
	self.player:sendReq("sc_marry_new", {})
	self:GetMarryInfo()
	self.player.friend:AddFriend(id)
	self:DoLogin()
end

function Marry:OtherSpouse(spouse)
	if spouse == MarryConfig.spouse.Husband then
		return MarryConfig.spouse.Wife
	else
		return MarryConfig.spouse.Husband
	end
end

function Marry:GetMarryInfo()
	local ismarry = (self.cache.partnerid > 0)
	local msg = {marry = ismarry}
	msg.grade = self.cache.grade
	msg.houselv = self.cache.houselv
	msg.houseup = self.cache.houseup
	msg.today = self.cache.today
	if ismarry then
		msg.husband, msg.wife = self:GetSpouse()
		msg.level = self.cache.level
		msg.intimate = self.cache.intimate
		msg.intimacy = self.cache.intimacy
		msg.time = self.cache.time
	end
	self.player:sendReq("sc_marry_info", msg)
end

function Marry:GetMarryObject(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	if not player then
		return {}
	end
	local baseinfo = player:BaseInfo()
	return baseinfo
end

function Marry:GetSpouse()
	local me = self:GetMarryObject(self.player.dbid)
	local partner = self:GetMarryObject(self.cache.partnerid)
	if self.cache.spouse == MarryConfig.spouse.Husband then
		return me, partner
	else
		return partner, me
	end
end

-- 发喜帖
function Marry:SendInvitation(grade)
	local msg = {}
	msg.husband, msg.wife = self:GetSpouse()
	msg.dbid = self.player.dbid
	msg.effect = 0
	if grade > 3 then
		msg.effect = 1
	end
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		if player.dbid ~= self.player.dbid and player.dbid ~= self.cache.partnerid then
			server.sendReq(player, "sc_marry_invitation", msg)
			player.marry.invitation[msg.dbid] = msg
		end
	end
end

-- 发贺礼
function Marry:SendGreeting(targetid, quantity)
	if not self.invitation[targetid] then
		server.sendErr(self.player, "您已向其赠送贺礼，无法继续赠送")
		return 1
	end

	local target = server.playerCenter:DoGetPlayerByDBID(targetid)
	if not target then
		return 1
	end

	local GiftsConfig = server.configCenter.GiftsConfig[quantity]
	if not self.player:PayRewards({GiftsConfig.price}, server.baseConfig.YuanbaoRecordType.Marry, "Marry:SendGreeting") then
		server.sendErr(self.player, "您的货币不足，无法赠送")
		return
	end

	self.invitation[targetid] = nil
	
	local MarryBaseConfig = server.configCenter.MarryBaseConfig
	-- server.mailCenter:SendMail(self.player.dbid, MarryBaseConfig.representtitle, MarryBaseConfig.representdes, table.wcopy(GiftsConfig.showreward), server.baseConfig.YuanbaoRecordType.Marry)
	self.player:GiveRewardAsFullMailDefault(table.wcopy(GiftsConfig.showreward), MarryBaseConfig.representtitle, server.baseConfig.YuanbaoRecordType.Marry)

	local content = string.format(MarryBaseConfig.presentdes, self.player.cache.name)
	server.mailCenter:SendMail(target.dbid, MarryBaseConfig.presenttitle, content, {table.wcopy(GiftsConfig.reward)}, server.baseConfig.YuanbaoRecordType.Marry)
	server.mailCenter:SendMail(target.marry.cache.partnerid, MarryBaseConfig.presenttitle, content, {table.wcopy(GiftsConfig.reward)}, server.baseConfig.YuanbaoRecordType.Marry)
	return 0
end

-- 甜蜜
function Marry:AddIntimate(intimate)
	self.cache.intimate = self.cache.intimate + intimate
end

-- 亲密
function Marry:AddIntimacy(intimacy)
	self.cache.intimacy = self.cache.intimacy + intimacy
end

-- 升级
function Marry:LevelUp()
	local IntimateConfig = server.configCenter.IntimateConfig
	if self.cache.level >= #IntimateConfig then
		server.sendErr(self.player, "甜蜜已满级")
		return 
	end

	if self.cache.partnerid == 0 then
		server.sendErr(self.player, "结婚后可进行升级")
		return 
	end
	local config = IntimateConfig[self.cache.level]
	local needintimate = config.intimate
	if self.cache.intimate < needintimate then
		server.sendErr(self.player, "甜蜜值不足")
		return 
	end

	self.cache.level = self.cache.level + 1
	self.cache.intimate = self.cache.intimate - needintimate
	self.player:GiveRewardAsFullMailDefault(table.wcopy(config.reward), "姻缘", server.baseConfig.YuanbaoRecordType.Marry)
	self:GetMarryInfo()
end

-- 送花
function Marry:SendFlower(quantity, count, autobuy)
	if self.cache.partnerid == 0 then
		server.sendErr(self.player, "您不处于结婚状态，无法赠送")
		return 1
	end

	local partner = server.playerCenter:DoGetPlayerByDBID(self.cache.partnerid)
	if not partner then
		server.sendErr(self.player, "您不处于结婚状态，无法赠送")
		return 1
	end

	local FlowersConfig = server.configCenter.FlowersConfig[quantity]
	if not FlowersConfig then
		return 1
	end
	local item = server.configCenter.ItemConfig[FlowersConfig.ID]
	if autobuy > 0 then
		if not self.player:PayRewardByShop(ItemConfig.AwardType.Item, FlowersConfig.ID, count, server.baseConfig.YuanbaoRecordType.Marry, "Marry:SendFlower", autobuy) then
			server.sendErr(self.player, "您当前元宝不足")
			return 1
		end
	else
		if not self.player:PayReward(ItemConfig.AwardType.Item, FlowersConfig.ID, count, server.baseConfig.YuanbaoRecordType.Marry, "Marry:SendFlower") then
			server.sendErr(self.player, string.format("您当前%s不足", item.name))
			return 1
		end
	end

	local addIntimacy = FlowersConfig.Intimacy * count
	self:AddIntimacy(addIntimacy)
	partner.marry:AddIntimacy(addIntimacy)
	
	local msg = {
		name = self.player.cache.name,
		intimacy = FlowersConfig.Intimacy,
		flower = item.name,
		count = count,
	}
	partner:sendReq("sc_marry_recv_flower", msg)

	local bromsg = {
		quantity = quantity,
		effect = 0,
	}
	if quantity > 3 then
		bromsg.effect = 1
	end

	server.broadcastReq("sc_marry_flower_bro", bromsg)
	partner.marry:GetMarryInfo()
	self:GetMarryInfo()

	if FlowersConfig.flowersnotice then
		server.noticeCenter:Notice(FlowersConfig.flowersnotice, 
			self.player.cache.name, partner.cache.name, count)
	end

	server.sendErr(self.player, string.format("成功赠送鲜花，获得亲密度%d", addIntimacy))
	return 0
end

function Marry:Divorce()
	local partnerid = self.cache.partnerid
	if partnerid == 0 then
		server.sendErr(self.player, "您不处于结婚状态，无法离婚")
		return 
	end

	local partner = server.playerCenter:DoGetPlayerByDBID(partnerid)
	if not partner then
		server.sendErr(self.player, "您不处于结婚状态，无法离婚")
		return 
	end

	self:DoDivorce()
	partner.marry:DoDivorce()
	local MarryBaseConfig = server.configCenter.MarryBaseConfig
	local content = string.format(MarryBaseConfig.divorcedes, self.player.cache.name)
	server.mailCenter:SendMail(partnerid, MarryBaseConfig.divorcetitle, content)

	local msg = {ids = {}}
	table.insert(msg.ids, self.player.dbid)
	table.insert(msg.ids, partnerid)
	server.broadcastReq("sc_marry_divorce_bro", msg)
end

function Marry:DoDivorce()
	table.insert(self.cache.ex, self.cache.partnerid)
	self.cache.partnerid = 0
	self.cache.partnername = ""
	self.cache.spouse = 0
	self.cache.partnerhouseup = 0
	self.cache.partnerhouseuptime = {}
	self:GetMarryInfo()
end

-- 使用贺礼
function Marry:UseGift(quantity, count)
	local GiftsConfig = server.configCenter.GiftsConfig[quantity]
	if not GiftsConfig then
		return
	end

	if not self.player:PayReward(ItemConfig.AwardType.Item, GiftsConfig.gifts, count, server.baseConfig.YuanbaoRecordType.Marry) then
		return
	end

	self:AddIntimacy(GiftsConfig.Intimacy)
	self:GetMarryInfo()
end

-- 上线通知
function Marry:SendLoginTip()
	if self.cache.partnerid == 0 then
		return 
	end

	if server.playerCenter:IsOnline(self.cache.partnerid) then
		server.sendReqByDBID(self.cache.partnerid, "sc_marry_login_tip", {partner = self:GetMarryObject(self.player.dbid)})
	end
end

function Marry:DoLogin()
	if self.cache.partnerid == 0 then
		return 
	end

	if server.playerCenter:IsOnline(self.cache.partnerid) then
		local partner = server.playerCenter:DoGetPlayerByDBID(self.cache.partnerid)
		partner.marry:OnPartnerLogin()
		server.sendReq(self.player, "sc_marry_token_status", {grade = self:GetToken(), isopen = true})
		if self.bufftimer then
			lua_app.del_timer(self.bufftimer)
		end
		local function _DoBuff()
			local TokenCfg = self:GetTokenConfig()
			self.bufftimer = lua_app.add_timer(TokenCfg.price.time * 1000, _DoBuff)
			self:AddIntimacy(TokenCfg.price.Intimacy)
			if server.playerCenter:IsOnline(self.cache.partnerid) then
				self:GetMarryInfo()
			end
		end
		local TokenConfig = self:GetTokenConfig()
		self.bufftimer = lua_app.add_timer(TokenConfig.price.time * 1000, _DoBuff)
	end
end

function Marry:OnPartnerLogin()
	server.sendReq(self.player, "sc_marry_token_status", {grade = self:GetToken(), isopen = true})
end

function Marry:DoLogout()
	if self.cache.partnerid == 0 then
		return 
	end

	if server.playerCenter:IsOnline(self.cache.partnerid) then
		local partner = server.playerCenter:DoGetPlayerByDBID(self.cache.partnerid)
		partner.marry:OnPartnerLogout()
	end
end

function Marry:OnPartnerLogout()
	server.sendReq(self.player, "sc_marry_token_status", {grade = self:GetToken(), isopen = false})
	if self.bufftimer then
		lua_app.del_timer(self.bufftimer)
	end
end

function Marry:GetToken()
	local cfg = server.configCenter.MarryConfig[self.cache.grade]
	if cfg then
		return cfg.normalreward
	else
		print("Marry:GetToken error ", self.cache.grade)
		return 0
	end
end

function Marry:GetTokenConfig()
	return server.configCenter.MarryTokenConfig[self:GetToken()]
end

function Marry:GetMarryExpAddition(exp)
	if self.cache.partnerid == 0 then
		return exp
	end

	if server.playerCenter:IsOnline(self.cache.partnerid) then
		local TokenConfig = self:GetTokenConfig()
		if not TokenConfig then
			return exp
		end
		exp = math.floor(exp * (1 + TokenConfig.income / 100))
		return exp
	else
		return exp
	end
end

-- 恩爱互动
function Marry:GetLoveInfo()
	local now = lua_app.now()
	local msg = {loves = {}}
	local loves = self.cache.loves
	for id, config in pairs(server.configCenter.LoveConfig) do
		loves[id] = loves[id] or {day = server.serverRunDay, daycount = 0, currcount = config.frequency, lasttime = 0}
		local isbuy = (config.price ~= nil)
		local love = loves[id]
		local interval = config.recoverytime
		local currcount = love.currcount
		if love.day ~= server.serverRunDay then
			love.daycount = 0
			love.day = server.serverRunDay
		end

		if not isbuy then
			if currcount < config.frequency then
				local addcount  = math.floor((now - love.lasttime) / interval)
				if addcount > 0 then
					love.currcount = math.min(currcount + addcount, config.frequency)
					love.lasttime = love.lasttime + addcount * interval
				end
			end
		end

		local remaintime = 0
		if not isbuy then
			if currcount < config.frequency then
		    	remaintime = love.lasttime + interval - now
		    end
	   	end
	    local info = {
			lovetype = id,
			daycount = love.daycount,
			count = currcount,
			time = remaintime,
		}
		table.insert(msg.loves, info)
	end
	self.player:sendReq("sc_marry_love_info", msg)
end

--恩爱互动
function Marry:LoveUse(lovetype)
	local love = self.cache.loves[lovetype]
	local config = server.configCenter.LoveConfig[lovetype]
	if not love then
		return 1
	end
	local isbuy = (config.price ~= nil)

	if self.cache.partnerid == 0 then
		server.sendErr(self.player, "结婚才可进行恩爱互动")
		return 1
	end

	if not isbuy and love.currcount <= 0 then
		server.sendErr(self.player, string.format("当前%s次数不足", config.category))
		return 1
	end

	if love.daycount >= config.quantity then
		server.sendErr(self.player, string.format("每日%s次数不足", config.category))
		return 1
	end

	if isbuy and not self.player:PayRewards({config.price}, server.baseConfig.YuanbaoRecordType.Marry, "Marry:LoveUse") then
		server.sendErr(self.player, "货币不足")
		return 1
	end

	love.daycount = love.daycount + 1

	if not isbuy then
		local lastcount = love.currcount
		love.currcount = lastcount - 1
		if lastcount >= config.frequency then
			love.lasttime = lua_app.now()
		end
	end

	self:GetLoveInfo()
	self:AddIntimate(config.intimate)
	self:GetMarryInfo()
	return 0
end

-- 恢复恩爱次数
function Marry:LoveRevert(lovetype)
	local love = self.cache.loves[lovetype]
	local config = server.configCenter.LoveConfig[lovetype]
	if not love then
		return 1
	end

	if love.currcount >= config.frequency then
		server.sendErr(self.player, "当前可操作次数已满，无需恢复")
		return 1
	end

	if love.daycount >= config.quantity then
		server.sendErr(self.player, string.format("每日%s次数不足，无需恢复", config.category))
		return 1
	end

	if not self.player:PayRewards({config.recoverymaterial}, server.baseConfig.YuanbaoRecordType.Marry, "Marry:LoveRevert") then
		server.sendErr(self.player, "恢复道具不足")
		return 1
	end

	love.currcount = config.frequency
	self:GetLoveInfo()
end

-- 房屋升大级
function Marry:GradeHouseAttr(oldgrade, newgrade)
	local houselv = self.cache.houselv
	-- local upnum = self.cache.houseup
	local oldconfig = server.configCenter.HouseConfig[oldgrade]
	local newconfig = server.configCenter.HouseConfig[newgrade]
	local newAttrs = table.wcopy(newconfig[houselv].attrpower or {})
	-- for i=1,upnum do
	-- 	for _, v in pairs(newconfig[houselv].increase) do
	-- 		table.insert(newAttrs, v)
	-- 	end
	-- end
	local oldAttrs = {}
	if oldconfig then
		oldAttrs = table.wcopy(oldconfig[houselv].attrpower or {})
		-- for i=1,upnum do
		-- 	for _, v in pairs(oldconfig[houselv].increase) do
		-- 		table.insert(oldAttrs, v)
		-- 	end
		-- end
	end
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.House)
end

-- 房屋升小级
function Marry:LevelHouseAttr(oldlevel, newlevel)
	local grade = self.cache.grade
	local config = server.configCenter.HouseConfig[grade]
	if not config then
		return
	end

	local newAttrs = table.wcopy(config[newlevel].attrpower or {})
	local oldAttrs = table.wcopy(config[oldlevel].attrpower or {})
	-- for i = 1, config[oldlevel].upnum - 1 do
	-- 	for _, v in pairs(config[oldlevel].increase) do
	-- 		table.insert(oldAttrs, v)
	-- 	end
	-- end
	self.role:UpdateBaseAttr(oldAttrs, newAttrs, server.baseConfig.AttrRecord.House)
end

function Marry:LoadHouseAttr()
	if self.cache.grade > 0 then
		local config = server.configCenter.HouseConfig[self.cache.grade]
		local newAttrs = table.wcopy(config[self.cache.houselv].attrpower or {})
		self.role:UpdateBaseAttr({}, newAttrs, server.baseConfig.AttrRecord.House)
	end
end

function Marry:HouseAddExp()
	local partnerid = self.cache.partnerid
	local grade = self.cache.grade
	local lv = self.cache.houselv
	local houseup = self.cache.houseup
	local intimacy = self.cache.intimacy
	
	local gradeconfig = server.configCenter.HouseConfig[grade]
	if not gradeconfig then return end

	local config = gradeconfig[lv]
	if not config then return end

	if partnerid == 0 then
		server.sendErr(self.player, "结婚状态才能升阶房屋")
		return 1
	end

	local partner = server.playerCenter:DoGetPlayerByDBID(partnerid)
	if not partner then
		server.sendErr(self.player, "结婚状态才能升阶房屋")
		return 1
	end

	if lv >= #gradeconfig then
		self.cache.houselv = #gradeconfig
		server.sendErr(self.player, "房屋已满阶，无法升阶")
		return 1
	end

	if intimacy < config.Intimacy then
		server.sendErr(self.player, "亲密度不足")
		return 1
	end

	self.cache.intimacy = intimacy - config.Intimacy
	self.cache.houseup = houseup + config.exp
	if self.cache.houseup >= config.proexp then
		self.cache.houselv = lv + 1
		self.cache.houseup = self.cache.houseup - config.proexp
		self:LevelHouseAttr(lv, self.cache.houselv)
	-- else
	-- 	self.role:UpdateBaseAttr({}, config.increase)
	end
	partner.marry:OnPartnerHouseUp()
	
	self:GetMarryInfo()
end

function Marry:OnPartnerHouseUp()
	local partnerhouseup = self.cache.partnerhouseup
	self.cache.partnerhouseup = partnerhouseup + 1
	table.insert(self.cache.partnerhouseuptime, lua_app.now())
	local function _SendPartnerHouseUp()
		if self.PartnerHouseUpTimer then
			lua_app.del_timer(self.PartnerHouseUpTimer)
			self.PartnerHouseUpTimer = nil
		end
		self:SendPartnerHouseUp()
	end
	if not self.PartnerHouseUpTimer then
		self.PartnerHouseUpTimer = lua_app.add_timer(60000, _SendPartnerHouseUp)
	end
	
end

function Marry:SendPartnerHouseUp()
	if self.cache.partnerhouseup == 0 then
		return
	end

	local gradeconfig = server.configCenter.HouseConfig[self.cache.grade]
	if not gradeconfig then return end
	if self.cache.houselv >= #gradeconfig then
		return
	end

	local msg = {
		upnum = self.cache.partnerhouseup,
		times = self.cache.partnerhouseuptime,
	}
	self.player:sendReq("sc_marry_house_partner_up", msg)
end

-- 使用伴侣的共享房屋进阶
function Marry:HouseUsePartner()
	if self.cache.partnerhouseup == 0 then
		return
	end

	local grade = self.cache.grade
	local gradeconfig = server.configCenter.HouseConfig[grade]

	local function _HouseUpOne()
		local config = gradeconfig[self.cache.houselv]
		if not config then return end
		self.cache.houseup = math.floor(self.cache.houseup + config.exp * server.configCenter.MarryBaseConfig.exp)
		if self.cache.houseup >= config.proexp then
			local lv = self.cache.houselv
			self.cache.houselv = lv + 1
			self.cache.houseup = self.cache.houseup - config.proexp
			self:LevelHouseAttr(lv, self.cache.houselv)
		-- else
		-- 	self.role:UpdateBaseAttr({}, config.increase)
		end
	end

	for i=1, self.cache.partnerhouseup do
		if self.cache.houselv < #gradeconfig then
			_HouseUpOne()
		end
	end

	self.cache.partnerhouseup = 0
	self.cache.partnerhouseuptime = {}

	self:GetMarryInfo()
end

-- 房屋装修
function Marry:HouseUpGrade(newgrade)
	local partnerid = self.cache.partnerid
	local grade = self.cache.grade
	local lv = self.cache.houselv

	if newgrade <= grade then
		return 1
	end

	if newgrade > #server.configCenter.HouseConfig then
		return 1
	end

	local gradeconfig = server.configCenter.HouseConfig[grade]
	if not gradeconfig then return end

	local config = gradeconfig[lv]
	if not config then return end

	if partnerid == 0 then
		server.sendErr(self.player, "只有结婚才可进行房屋装修升级")
		return 1
	end

	local partner = server.playerCenter:DoGetPlayerByDBID(partnerid)
	if not partner then
		server.sendErr(self.player, "只有结婚才可进行房屋装修升级")
		return 1
	end

	if grade >= #gradeconfig then
		server.sendErr(self.player, "房屋已是最高档，无需装修升级")
		return 1
	end

	local newconfig = server.configCenter.BasisConfig[newgrade]
	if not newconfig then return end

	local newvalue = newconfig.price
	if not newvalue then return end

	local oldconfig = server.configCenter.BasisConfig[self.cache.grade]
	if not oldconfig then return end
	local oldvalue = oldconfig.price
	if not oldvalue then return end

	local price = {}
	if newvalue.id == oldvalue.id then
		local newcout = newvalue.count - oldvalue.count
		if newcout <= 0 then
			return
		end
		table.insert(price, {type = newvalue.type, id = newvalue.id, count = newcout})
	else
		table.insert(price, table.wcopy(newvalue))
	end

	if not self.player:PayRewards(price, server.baseConfig.YuanbaoRecordType.Marry, "House:AddGrade") then
		server.sendErr(self.player, "元宝不足，无法装修")
		return 1
	end

	self.cache.grade = newgrade
	self:GradeHouseAttr(grade, newgrade)

	self:GetMarryInfo()
	partner.marry:OnPartnerUpGrade(newgrade)
	return 0
end

function Marry:OnPartnerUpGrade(newgrade)
	local grade = self.cache.grade
	if newgrade > grade then
		self.cache.grade = newgrade
		self:GradeHouseAttr(grade, newgrade)
		self:GetMarryInfo()
	end
end

server.playerCenter:SetEvent(Marry, "marry")
return Marry